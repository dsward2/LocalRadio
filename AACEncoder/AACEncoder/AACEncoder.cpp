//
//  AACEncoder.cpp
//  AACEncoder
//
//  Created by Douglas Ward on 9/11/18.
//  Copyright © 2018 ArkPhone LLC. All rights reserved.
//


/* references -

https://github.com/JQJoe/AACEncodeAndDecode/blob/master/AACEncodeAndDecode/AACEncoder/AACEncoder.m
https://github.com/michaeltyson/TPAACAudioConverter/blob/master/TPAACAudioConverter.m
https://developer.apple.com/library/archive/samplecode/iPhoneExtAudioFileConvertTest/Introduction/Intro.html
https://stackoverflow.com/questions/12163240/avaudiorecorder-record-aac-m4a
https://stackoverflow.com/questions/9410807/kaudioformatlinearpcm-to-kaudioformatmpeg4aac
https://zebulon.bok.net/svn/BlueTune/trunk/Source/Plugins/Decoders/OsxAudioConverter/BltOsxAudioConverterDecoder.cpp
https://developer.apple.com/library/archive/documentation/NetworkingInternet/Conceptual/StreamingMediaGuide/FrequentlyAskedQuestions/FrequentlyAskedQuestions.html
ADTS header -
https://wiki.multimedia.cx/index.php/ADTS

*/

#include "AACEncoder.hpp"

#import <AudioToolbox/AudioToolbox.h>
#import <AudioToolbox/AudioConverter.h>

#include <sys/select.h>
#include <sys/ioctl.h>

#include <errno.h>
#include <signal.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>

#include <stdio.h>

#import <AudioToolbox/AudioToolbox.h>
#import <Accelerate/Accelerate.h>
#import "TPCircularBuffer.h"

unsigned int sampleRate;
unsigned int inputChannels;
UInt32 bitrate;

pthread_t inputBufferThreadID;
pthread_t audioConverterThreadID;

AudioBuffer audioConverterInputAudioBuffer;

AudioConverterRef inAudioConverter;     // AudioConverter for converting PCM data to AAC

AudioStreamBasicDescription audioConverterInputDescription;
AudioStreamBasicDescription audioConverterOutputDescription;

TPCircularBuffer inputCircularBuffer;        // TPCircularBuffer for storage and retrieval of input PCM data from stdin

AudioBufferList audioConverterOutputBufferList;

void * audioConverterOutputBufferPtr;
UInt32 audioConverterOutputBytes;

UInt8 * adtsPacketPtr;

unsigned int outputPacketCount;

typedef struct {
    void * inputBufferPtr;
    UInt32 inputBufferDataLength;
    UInt32 inputChannels;
    AudioStreamPacketDescription * packetDescription;
} FillComplexInputParam;

//==================================================================================
//    stopAudio()
//==================================================================================

void stopAudio()
{
    TPCircularBufferCleanup(&inputCircularBuffer);
}

//==================================================================================
//    logDescription()
//==================================================================================

void logDescription(AudioStreamBasicDescription * asbd, const char * name)
{
    fprintf(stderr, "AACEncoder - AudioStreamBasicDescription %s\n", name);
    fprintf(stderr, "   %s.mSampleRate=%f\n", name, asbd->mSampleRate);
    
    char c[5];
    c[0] = (asbd->mFormatID >> 24) & 0xFF;
    c[1] = (asbd->mFormatID >> 16) & 0xFF;
    c[2] = (asbd->mFormatID >> 8) & 0xFF;
    c[3] = (asbd->mFormatID >> 0) & 0xFF;
    c[4] = 0;
    
    char * formatID = (char *)&c;
    fprintf(stderr, "   %s.mFormatID=%s\n", name, formatID);
    
    fprintf(stderr, "   %s.mFormatFlags=%u\n", name, (unsigned int)asbd->mFormatFlags);
    fprintf(stderr, "   %s.mBytesPerPacket=%u\n", name, (unsigned int)asbd->mBytesPerPacket);
    fprintf(stderr, "   %s.mFramesPerPacket=%u\n", name, (unsigned int)asbd->mFramesPerPacket);
    fprintf(stderr, "   %s.mBytesPerFrame=%u\n", name, (unsigned int)asbd->mBytesPerFrame);
    fprintf(stderr, "   %s.mChannelsPerFrame=%u\n", name, (unsigned int)asbd->mChannelsPerFrame);
    fprintf(stderr, "   %s.mBitsPerChannel=%u\n", name, (unsigned int)asbd->mBitsPerChannel);
}

//==================================================================================
//    runInputBufferOnThread()
//==================================================================================

void * runInputBufferOnThread(void * ptr)
{
    pthread_setname_np("runInputBufferOnThread");

    //pid_t originalParentProcessPID = getppid();
    
    int packetIndex = 0;
    bool doExit = false;

    time_t lastReadTime = time(NULL) + 20;
    int nextTimeoutReportInterval = 5;

    //int32_t circularBufferLength = inputChannels * bufferKBPerChannel * 1024;
    //int32_t circularBufferLength = inputBufferSize;
    int32_t circularBufferLength = 2048 * 1024;
    TPCircularBufferInit(&inputCircularBuffer, circularBufferLength);
    
    fprintf(stderr, "AACEncoder runInputBufferOnThread circularBufferLength = %d\n", circularBufferLength);
    
    unsigned char * lpcmBuffer = (unsigned char *)malloc(circularBufferLength);
    
    // continuous run loop
    while (doExit == false)
    {
        //fprintf(stderr, "AACEncoder runInputBufferOnThread polling loop\n");
        
        CFRunLoopMode runLoopMode = kCFRunLoopDefaultMode;
        CFTimeInterval runLoopTimeInterval = 0.25f;
        Boolean returnAfterSourceHandled = false;
        CFRunLoopRunResult runLoopResult = CFRunLoopRunInMode(runLoopMode, runLoopTimeInterval, returnAfterSourceHandled);
        #pragma unused(runLoopResult)

        time_t currentTime = time(NULL);

        UInt32 bytesAvailableCount = 0;

        // use ioctl to determine amount of data available for reading on stdin, like the RTL-SDR USB serial device
        int ioctl_result = ioctl( STDIN_FILENO, FIONREAD, &bytesAvailableCount);
        if (ioctl_result < 0)
        {
            fprintf(stderr, "AACEncoder ioctl failed error: %s\n", strerror(errno));
            doExit = true;
            break;
        }

        if (bytesAvailableCount <= 0)
        {
            usleep(5000);
        }
        else
        {
            if (bytesAvailableCount % (inputChannels * sizeof(SInt16)) == 0)
            {
                memset(lpcmBuffer, 0, bytesAvailableCount);
                
                long readResult = read( STDIN_FILENO, lpcmBuffer, bytesAvailableCount);

                //fprintf(stderr, "AACEncoder runInputBufferOnThread - read completed, bytesAvailableCount = %d\n", bytesAvailableCount);

                if (readResult <= 0)
                {
                    fprintf(stderr, "AACEncoder read failed error: %s\n", strerror(errno));
                    break;
                }
                else
                {
                    lastReadTime = currentTime;
                    nextTimeoutReportInterval = 5;
                    
                    // copy RTL-SDR LPCM data to a circular buffer to be used as input for AudioConverter process
                    
                    bool produceBytesResult = TPCircularBufferProduceBytes(&inputCircularBuffer, lpcmBuffer, bytesAvailableCount);
                    
                    if (produceBytesResult == false)
                    {
                        TPCircularBufferClear(&inputCircularBuffer);

                        fprintf(stderr, "AACEncoder runInputBufferOnThread error - produce bytes failed, bytesAvailableCount = %d\n", bytesAvailableCount);
                    }
                }
            }
            else
            {
                fprintf(stderr, "AACEncoder bytesAvailableCount %d misaligned for packet size\n", bytesAvailableCount);
            }
        }

        time_t intervalSinceLastRead = currentTime - lastReadTime;
        if (intervalSinceLastRead >= nextTimeoutReportInterval)
        {
            fprintf(stderr, "AACEncoder intervalSinceLastRead >= %d\n", nextTimeoutReportInterval);

            nextTimeoutReportInterval += 5;
        }
        
        packetIndex++;
    }
    //pthread_exit(NULL);
    
    free(lpcmBuffer);
    
    TPCircularBufferCleanup(&inputCircularBuffer);
    
    return NULL;
}

//==================================================================================
//    createInputBufferThread()
//==================================================================================

void createInputBufferThread()
{
    pthread_attr_t attr; /* set of thread attributes */
    pthread_attr_init(&attr);

    int inputBufferThreadErr;
    inputBufferThreadErr = pthread_create(&inputBufferThreadID, &attr, &runInputBufferOnThread, NULL);
    pthread_detach(inputBufferThreadID);
}

//==================================================================================
//    freqIdxForAdtsHeader()
//==================================================================================

int freqIdxForAdtsHeader(int samplerate)
{
    // adapted from https://github.com/JQJoe/AACEncodeAndDecode
    int idx = 4;
    if (samplerate >= 7350 && samplerate < 8000) {
        idx = 12;
    }
    else if (samplerate >= 8000 && samplerate < 11025) {
        idx = 11;
    }
    else if (samplerate >= 11025 && samplerate < 12000) {
        idx = 10;
    }
    else if (samplerate >= 12000 && samplerate < 16000) {
        idx = 9;
    }
    else if (samplerate >= 16000 && samplerate < 22050) {
        idx = 8;
    }
    else if (samplerate >= 22050 && samplerate < 24000) {
        idx = 7;
    }
    else if (samplerate >= 24000 && samplerate < 32000) {
        idx = 6;
    }
    else if (samplerate >= 32000 && samplerate < 44100) {
        idx = 5;
    }
    else if (samplerate >= 44100 && samplerate < 48000) {
        idx = 4;
    }
    else if (samplerate >= 48000 && samplerate < 64000) {
        idx = 3;
    }
    else if (samplerate >= 64000 && samplerate < 88200) {
        idx = 2;
    }
    else if (samplerate >= 88200 && samplerate < 96000) {
        idx = 1;
    }
    else if (samplerate >= 96000) {
        idx = 0;
    }
    return idx;
}

//==================================================================================
//    logAudioConverterProperties()
//==================================================================================

void logAudioConverterProperties()
{
    // kAudioConverterPropertyCalculateInputBufferSize not used currently
    // kAudioConverterPropertyCalculateOutputBufferSize not used currently
    // kAudioConverterPropertyInputCodecParameters not used currently
    // kAudioConverterPropertyOutputCodecParameters not used currently
    // kAudioConverterSampleRateConverterAlgorithm not used currently
    // kAudioConverterSampleRateConverterInitialPhase not used currently
    // kAudioConverterPrimeMethod not used currently
    // kAudioConverterDecompressionMagicCookie not used currently
    // kAudioConverterCompressionMagicCookie not used currently
    // kAudioConverterAvailableEncodeChannelLayoutTags not used currently

    UInt32 tmpsiz = sizeof(UInt32);
    UInt32 encodeBitRate = 0;
    OSStatus encodeBitRateStatus =  AudioConverterGetProperty(inAudioConverter,
            kAudioConverterEncodeBitRate,
            &tmpsiz, &encodeBitRate);
    if (encodeBitRateStatus == noErr)
    {
        fprintf(stderr, "AACEncoder AudioConverterGetProperty kAudioConverterEncodeBitRate = %d\n", (int)encodeBitRate);
    }
    else
    {
        fprintf(stderr, "AACEncoder AudioConverterGetProperty kAudioConverterEncodeBitRate error = %d\n", (int)encodeBitRateStatus);
    }

    tmpsiz = sizeof(UInt32);
    UInt32 bitDepthHint = 0;
    OSStatus bitDepthHintStatus =  AudioConverterGetProperty(inAudioConverter,
            kAudioConverterPropertyBitDepthHint,
            &tmpsiz, &bitDepthHint);
    if (bitDepthHintStatus == noErr)
    {
        fprintf(stderr, "AACEncoder AudioConverterGetProperty kAudioConverterPropertyBitDepthHint = %d\n", (int)bitDepthHint);
    }
    else
    {
        fprintf(stderr, "AACEncoder AudioConverterGetProperty kAudioConverterPropertyBitDepthHint error = %d\n", (int)bitDepthHintStatus);
    }

    tmpsiz = sizeof(UInt32);
    UInt32 minimumInputBufferSize = 0;
    OSStatus minimumInputBufferSizeStatus =  AudioConverterGetProperty(inAudioConverter,
            kAudioConverterPropertyMinimumInputBufferSize,
            &tmpsiz, &minimumInputBufferSize);
    if (minimumInputBufferSizeStatus == noErr)
    {
        fprintf(stderr, "AACEncoder AudioConverterGetProperty kAudioConverterPropertyMinimumInputBufferSize = %d\n", (int)minimumInputBufferSize);
    }
    else
    {
        fprintf(stderr, "AACEncoder AudioConverterGetProperty kAudioConverterPropertyMinimumInputBufferSize error = %d\n", (int)minimumInputBufferSizeStatus);
    }

    tmpsiz = sizeof(UInt32);
    UInt32 minimumOutputBufferSize = 0;
    OSStatus minimumOutputBufferSizeStatus =  AudioConverterGetProperty(inAudioConverter,
            kAudioConverterPropertyMinimumOutputBufferSize,
            &tmpsiz, &minimumOutputBufferSize);
    if (minimumOutputBufferSizeStatus == noErr)
    {
        fprintf(stderr, "AACEncoder AudioConverterGetProperty kAudioConverterPropertyMinimumOutputBufferSize = %d\n", (int)minimumOutputBufferSize);
    }
    else
    {
        // returns 'prop', property not supported
        fprintf(stderr, "AACEncoder AudioConverterGetProperty kAudioConverterPropertyMinimumOutputBufferSize error = %d\n", (int)minimumOutputBufferSizeStatus);
    }

    tmpsiz = sizeof(UInt32);
    UInt32 maximumInputBufferSize = 0;
    OSStatus maximumInputBufferSizeStatus =  AudioConverterGetProperty(inAudioConverter,
            kAudioConverterPropertyMaximumInputBufferSize,
            &tmpsiz, &maximumInputBufferSize);
    if (maximumInputBufferSizeStatus == noErr)
    {
        fprintf(stderr, "AACEncoder AudioConverterGetProperty kAudioConverterPropertyMaximumInputBufferSize = %d\n", (int)maximumInputBufferSize);
    }
    else
    {
        fprintf(stderr, "AACEncoder AudioConverterGetProperty kAudioConverterPropertyMaximumInputBufferSize error = %d\n", (int)maximumInputBufferSizeStatus);
    }

    tmpsiz = sizeof(UInt32);
    UInt32 maximumInputPacketSize = 0;
    OSStatus maximumInputPacketSizeStatus =  AudioConverterGetProperty(inAudioConverter,
            kAudioConverterPropertyMaximumInputPacketSize,
            &tmpsiz, &maximumInputPacketSize);
    if (maximumInputPacketSizeStatus == noErr)
    {
        fprintf(stderr, "AACEncoder AudioConverterGetProperty kAudioConverterPropertyMaximumInputPacketSize = %d\n", (int)maximumInputPacketSize);
    }
    else
    {
        fprintf(stderr, "AACEncoder AudioConverterGetProperty kAudioConverterPropertyMaximumInputPacketSize error = %d\n", (int)maximumInputPacketSize);
    }

    tmpsiz = sizeof(UInt32);
    UInt32 maximumOutputPacketSize = 0;     //  indicates the size, in bytes, of the largest single packet of data in the output format (1536 for AAC?)
    OSStatus maximumOutputPacketSizeStatus =  AudioConverterGetProperty(inAudioConverter,
            kAudioConverterPropertyMaximumOutputPacketSize,
            &tmpsiz, &maximumOutputPacketSize);
    if (maximumOutputPacketSizeStatus == noErr)
    {
        fprintf(stderr, "AACEncoder AudioConverterGetProperty kAudioConverterPropertyMaximumOutputPacketSize = %d\n", (int)maximumOutputPacketSize);
    }
    else
    {
        fprintf(stderr, "AACEncoder AudioConverterGetProperty kAudioConverterPropertyMaximumOutputPacketSize error = %d\n", (int)maximumOutputPacketSizeStatus);
    }
    
    tmpsiz = sizeof(UInt32);
    UInt32 sampleRateConverterComplexity = 0;
    OSStatus sampleRateConverterComplexityStatus =  AudioConverterGetProperty(inAudioConverter,
            kAudioConverterSampleRateConverterComplexity,
            &tmpsiz, &sampleRateConverterComplexity);
    if (sampleRateConverterComplexityStatus == noErr)
    {
        fprintf(stderr, "AACEncoder AudioConverterGetProperty kAudioConverterSampleRateConverterComplexity = %d\n", (int)sampleRateConverterComplexity);
    }
    else
    {
        // returned 'prop', property not supported, perhaps because not resampling?
        fprintf(stderr, "AACEncoder AudioConverterGetProperty kAudioConverterSampleRateConverterComplexity error = %d\n", (int)sampleRateConverterComplexityStatus);
    }
    
    tmpsiz = sizeof(UInt32);
    UInt32 sampleRateConverterQuality = 0;
    OSStatus sampleRateConverterQualityStatus =  AudioConverterGetProperty(inAudioConverter,
            kAudioConverterSampleRateConverterQuality,
            &tmpsiz, &sampleRateConverterQuality);
    if (sampleRateConverterQualityStatus == noErr)
    {
        fprintf(stderr, "AACEncoder AudioConverterGetProperty kAudioConverterSampleRateConverterQuality = %d\n", (int)sampleRateConverterQuality);
    }
    else
    {
        // returned 'prop', property not supported, apparently for the aac codec?
        fprintf(stderr, "AACEncoder AudioConverterGetProperty kAudioConverterSampleRateConverterQuality error = %d\n", (int)sampleRateConverterQualityStatus);
    }
    
    tmpsiz = sizeof(UInt32);
    UInt32 codecQuality = 0;
    OSStatus codecQualityStatus =  AudioConverterGetProperty(inAudioConverter,
            kAudioConverterCodecQuality,
            &tmpsiz, &codecQuality);
    if (codecQualityStatus == noErr)
    {
        fprintf(stderr, "AACEncoder AudioConverterGetProperty kAudioConverterCodecQuality = %d\n", (int)codecQuality);
    }
    else
    {
        fprintf(stderr, "AACEncoder AudioConverterGetProperty kAudioConverterCodecQuality error = %d\n", (int)codecQualityStatus);
    }


    tmpsiz = sizeof(Float64);
    Float64 encodeAdjustableSampleRate = 0;
    OSStatus adjustableSampleRateStatus =  AudioConverterGetProperty(inAudioConverter,
            kAudioConverterEncodeAdjustableSampleRate,
            &tmpsiz, &encodeAdjustableSampleRate);
    if (adjustableSampleRateStatus == noErr)
    {
        fprintf(stderr, "AACEncoder AudioConverterGetProperty kAudioConverterEncodeAdjustableSampleRate = %d\n", (int)encodeAdjustableSampleRate);
    }
    else
    {
        fprintf(stderr, "AACEncoder AudioConverterGetProperty kAudioConverterEncodeAdjustableSampleRate error = %d\n", (int)adjustableSampleRateStatus);
    }

    tmpsiz = sizeof(AudioConverterPrimeInfo);
    AudioConverterPrimeInfo primeInfo;
    OSStatus primeInfoStatus =  AudioConverterGetProperty(inAudioConverter,
            kAudioConverterPrimeInfo,
            &tmpsiz, &primeInfo);
    if (primeInfoStatus == noErr)
    {
        fprintf(stderr, "AACEncoder AudioConverterGetProperty kAudioConverterPrimeInfo leadingFrames = %d, trailingFrames = %d\n", (int)primeInfo.leadingFrames, (int)primeInfo.trailingFrames);
    }
    else
    {
        fprintf(stderr, "AACEncoder AudioConverterGetProperty kAudioConverterPrimeInfo error = %d\n", (int)primeInfoStatus);
    }



    tmpsiz = sizeof(AudioChannelLayout);
    AudioChannelLayout inputChannelLayout;
    OSStatus inputChannelLayoutStatus =  AudioConverterGetProperty(inAudioConverter,
            kAudioConverterInputChannelLayout,
            &tmpsiz, &inputChannelLayout);
    if (inputChannelLayoutStatus == noErr)
    {
        fprintf(stderr, "AACEncoder AudioConverterGetProperty kAudioConverterInputChannelLayout mChannelLayoutTag = %d, mChannelBitmap = %d, mNumberChannelDescriptions = %d\n", inputChannelLayout.mChannelLayoutTag, inputChannelLayout.mChannelBitmap, inputChannelLayout.mNumberChannelDescriptions);
        AudioChannelDescription inputChannelDescription = inputChannelLayout.mChannelDescriptions[0];
        AudioChannelLabel inputChannelLabel = inputChannelDescription.mChannelLabel;
        AudioChannelFlags inputChannelFlags = inputChannelDescription.mChannelFlags;
        Float32 inputCoordinates0 = inputChannelDescription.mCoordinates[0];
        Float32 inputCoordinates1 = inputChannelDescription.mCoordinates[1];
        Float32 inputCoordinates2 = inputChannelDescription.mCoordinates[2];
        fprintf(stderr, "AACEncoder AudioConverterGetProperty kAudioConverterInputChannelLayout AudioChannelDescription AudioChannelLabel = %d, AudioChannelFlags = %d, coordinates = %f,%f,%f\n", inputChannelLabel, inputChannelFlags, inputCoordinates0, inputCoordinates1, inputCoordinates2);
    }
    else
    {
        fprintf(stderr, "AACEncoder AudioConverterGetProperty kAudioConverterInputChannelLayout error = %d\n", (int)inputChannelLayoutStatus);
    }

    tmpsiz = sizeof(AudioChannelLayout);
    AudioChannelLayout outputChannelLayout;
    OSStatus outputChannelLayoutStatus =  AudioConverterGetProperty(inAudioConverter,
            kAudioConverterOutputChannelLayout,
            &tmpsiz, &outputChannelLayout);
    if (outputChannelLayoutStatus == noErr)
    {
        fprintf(stderr, "AACEncoder AudioConverterGetProperty kAudioConverterOutputChannelLayout mChannelLayoutTag = %d, mChannelBitmap = %d, mNumberChannelDescriptions = %d\n", outputChannelLayout.mChannelLayoutTag, outputChannelLayout.mChannelBitmap, outputChannelLayout.mNumberChannelDescriptions);
        AudioChannelDescription outputChannelDescription = outputChannelLayout.mChannelDescriptions[0];
        AudioChannelLabel outputChannelLabel = outputChannelDescription.mChannelLabel;
        AudioChannelFlags outputChannelFlags = outputChannelDescription.mChannelFlags;
        Float32 outputCoordinates0 = outputChannelDescription.mCoordinates[0];
        Float32 outputCoordinates1 = outputChannelDescription.mCoordinates[1];
        Float32 outputCoordinates2 = outputChannelDescription.mCoordinates[2];
        fprintf(stderr, "AACEncoder AudioConverterGetProperty kAudioConverterOutputChannelLayout AudioChannelDescription AudioChannelLabel = %d, AudioChannelFlags = %d, coordinates = %f,%f,%f\n", outputChannelLabel, outputChannelFlags, outputCoordinates0, outputCoordinates1, outputCoordinates2);
    }
    else
    {
        fprintf(stderr, "AACEncoder AudioConverterGetProperty kAudioConverterOutputChannelLayout error = %d\n", (int)outputChannelLayoutStatus);
    }

    tmpsiz = sizeof(AudioStreamBasicDescription);
    AudioStreamBasicDescription currentOutputStreamDescription;
    OSStatus currentOutputStreamDescriptionStatus =  AudioConverterGetProperty(inAudioConverter,
            kAudioConverterCurrentOutputStreamDescription,
            &tmpsiz, &currentOutputStreamDescription);
    if (currentOutputStreamDescriptionStatus == noErr)
    {
        logDescription(&currentOutputStreamDescription, "kAudioConverterCurrentOutputStreamDescription");
    }
    else
    {
        fprintf(stderr, "AACEncoder AudioConverterGetProperty kAudioConverterCurrentOutputStreamDescription error = %d\n", (int)currentOutputStreamDescriptionStatus);
    }

    tmpsiz = sizeof(AudioStreamBasicDescription);
    AudioStreamBasicDescription currentInputStreamDescription;
    OSStatus currentInputStreamDescriptionStatus =  AudioConverterGetProperty(inAudioConverter,
            kAudioConverterCurrentInputStreamDescription,
            &tmpsiz, &currentInputStreamDescription);
    if (currentInputStreamDescriptionStatus == noErr)
    {
        logDescription(&currentInputStreamDescription, "kAudioConverterCurrentInputStreamDescription");
    }
    else
    {
        fprintf(stderr, "AACEncoder AudioConverterGetProperty kAudioConverterCurrentOutputStreamDescription error = %d\n", (int)currentInputStreamDescriptionStatus);
    }

    // get applicable bitrates
    AudioValueRange * applicableBitrates = NULL;
    ssize_t applicableBitratesCount = 0;
    OSStatus getApplicableBitratesCountStatus = AudioConverterGetPropertyInfo(inAudioConverter,
            kAudioConverterApplicableEncodeBitRates,
            &tmpsiz, NULL);
    if (getApplicableBitratesCountStatus == noErr)
    {
        applicableBitrates = (AudioValueRange *)malloc(tmpsiz);

        OSStatus getApplicableBitratesStatus =  AudioConverterGetProperty(inAudioConverter,
                kAudioConverterApplicableEncodeBitRates,
                &tmpsiz, applicableBitrates);
        if (getApplicableBitratesStatus == noErr)
        {
            applicableBitratesCount = tmpsiz / sizeof(AudioValueRange);
        }
        else
        {
            fprintf(stderr, "AACEncoder AudioConverterGetProperty getApplicableBitratesCountStatus error = %d\n", (int)getApplicableBitratesStatus);
        }
        
        fprintf(stderr, "AACEncoder kAudioConverterApplicableEncodeBitRates applicableBitratesCount = %zdd\n", applicableBitratesCount);
        
        for (int i = 0; i < applicableBitratesCount; i++)
        {
            Float64 minimum = applicableBitrates[i].mMinimum;
            Float64 maximum = applicableBitrates[i].mMaximum;
            fprintf(stderr, "AACEncoder kAudioConverterApplicableEncodeBitRates Applicable BitRate %d minimum=%f, maximum=%f\n", i, minimum,  maximum);
        }
        
        free(applicableBitrates);
    }
    else
    {
        fprintf(stderr, "AACEncoder AudioConverterGetPropertyInfo getApplicableBitrateStatus error = %d\n", (int)getApplicableBitratesCountStatus);
    }

    // get available bitrates
    AudioValueRange * availableBitrates = NULL;
    ssize_t availableBitratesCount = 0;
    OSStatus getAvailableBitratesCountStatus = AudioConverterGetPropertyInfo(inAudioConverter,
            kAudioConverterAvailableEncodeBitRates,
            &tmpsiz, NULL);
    if (getAvailableBitratesCountStatus == noErr)
    {
        availableBitrates = (AudioValueRange *)malloc(tmpsiz);

        OSStatus getAvailableBitratesStatus =  AudioConverterGetProperty(inAudioConverter,
                kAudioConverterApplicableEncodeBitRates,
                &tmpsiz, availableBitrates);
        if (getAvailableBitratesStatus == noErr)
        {
            availableBitratesCount = tmpsiz / sizeof(AudioValueRange);
        }
        else
        {
            fprintf(stderr, "AACEncoder AudioConverterGetProperty kAudioConverterApplicableEncodeBitRates error = %d\n", (int)getAvailableBitratesStatus);
        }
        
        fprintf(stderr, "AACEncoder kAudioConverterApplicableEncodeBitRates availableBitratesCount = %zdd\n", availableBitratesCount);
        
        for (int i = 0; i < availableBitratesCount; i++)
        {
            Float64 minimum = availableBitrates[i].mMinimum;
            Float64 maximum = availableBitrates[i].mMaximum;
            fprintf(stderr, "AACEncoder kAudioConverterApplicableEncodeBitRates Available Encode BitRate %d minimum=%f, maximum=%f\n", i, minimum,  maximum);
        }
        
        free(availableBitrates);
    }
    else
    {
        fprintf(stderr, "AACEncoder AudioConverterGetPropertyInfo kAudioConverterApplicableEncodeBitRates error = %d\n", (int)getAvailableBitratesCountStatus);
    }

    // get applicable encode sample rates
    AudioValueRange * applicableEncodeSampleRates = NULL;
    ssize_t applicableEncodeSampleRatesCount = 0;
    OSStatus getApplicableEncodeSampleRatesCountStatus = AudioConverterGetPropertyInfo(inAudioConverter,
            kAudioConverterApplicableEncodeSampleRates,
            &tmpsiz, NULL);
    if (getApplicableEncodeSampleRatesCountStatus == noErr)
    {
        applicableEncodeSampleRates = (AudioValueRange *)malloc(tmpsiz);

        OSStatus getApplicableEncodeSampleRatesStatus =  AudioConverterGetProperty(inAudioConverter,
                kAudioConverterApplicableEncodeSampleRates,
                &tmpsiz, applicableEncodeSampleRates);
        if (getApplicableEncodeSampleRatesStatus == noErr)
        {
            applicableEncodeSampleRatesCount = tmpsiz / sizeof(AudioValueRange);
        }
        else
        {
            fprintf(stderr, "AACEncoder AudioConverterGetProperty kAudioConverterApplicableEncodeSampleRates error = %d\n", (int)getApplicableEncodeSampleRatesStatus);
        }
        
        fprintf(stderr, "AACEncoder AudioConverterGetProperty kAudioConverterApplicableEncodeSampleRates  = %zdd\n", applicableEncodeSampleRatesCount);
        
        for (int i = 0; i < applicableEncodeSampleRatesCount; i++)
        {
            Float64 minimum = applicableEncodeSampleRates[i].mMinimum;
            Float64 maximum = applicableEncodeSampleRates[i].mMaximum;
            fprintf(stderr, "AACEncoder kAudioConverterApplicableEncodeSampleRates Applicable Encode Sample Rates %d minimum=%f, maximum=%f\n", i, minimum,  maximum);
        }
        
        free(applicableEncodeSampleRates);
    }
    else
    {
        fprintf(stderr, "AACEncoder AudioConverterGetPropertyInfo kAudioConverterApplicableEncodeSampleRates error = %d\n", (int)getApplicableEncodeSampleRatesCountStatus);
    }

    // get available encode sample rates
    AudioValueRange * availableEncodeSampleRates = NULL;
    ssize_t availableEncodeSampleRatesCount = 0;
    OSStatus getAvailableEncodeSampleRatesCountStatus = AudioConverterGetPropertyInfo(inAudioConverter,
            kAudioConverterAvailableEncodeSampleRates,
            &tmpsiz, NULL);
    if (getAvailableEncodeSampleRatesCountStatus == noErr)
    {
        availableEncodeSampleRates = (AudioValueRange *)malloc(tmpsiz);

        OSStatus getAvailableEncodeSampleRatesStatus =  AudioConverterGetProperty(inAudioConverter,
                kAudioConverterAvailableEncodeSampleRates,
                &tmpsiz, availableEncodeSampleRates);
        if (getAvailableEncodeSampleRatesStatus == noErr)
        {
            availableEncodeSampleRatesCount = tmpsiz / sizeof(AudioValueRange);
        }
        else
        {
            fprintf(stderr, "AACEncoder AudioConverterGetProperty kAudioConverterAvailableEncodeSampleRates error = %d\n", (int)getAvailableEncodeSampleRatesStatus);
        }
        
        fprintf(stderr, "AACEncoder kAudioConverterAvailableEncodeSampleRates availableEncodeSampleRatesCount = %zdd\n", availableEncodeSampleRatesCount);
        
        for (int i = 0; i < availableEncodeSampleRatesCount; i++)
        {
            Float64 minimum = availableEncodeSampleRates[i].mMinimum;
            Float64 maximum = availableEncodeSampleRates[i].mMaximum;
            fprintf(stderr, "AACEncoder kAudioConverterAvailableEncodeSampleRates Available Encode Sample Rates %d minimum=%f, maximum=%f\n", i, minimum,  maximum);
        }
        
        free(availableEncodeSampleRates);
    }
    else
    {
        fprintf(stderr, "AACEncoder AudioConverterGetPropertyInfo kAudioConverterAvailableEncodeSampleRates error = %d\n", (int)getAvailableEncodeSampleRatesCountStatus);
    }
    
    // get channel mapping
    SInt32 * channelMapping = NULL;
    ssize_t channelMappingCount = 0;
    OSStatus channelMappingCountStatus = AudioConverterGetPropertyInfo(inAudioConverter,
            kAudioConverterChannelMap,
            &tmpsiz, NULL);
    if (channelMappingCountStatus == noErr)
    {
        channelMapping = (SInt32 *)malloc(tmpsiz);

        OSStatus channelMappingStatus =  AudioConverterGetProperty(inAudioConverter,
                kAudioConverterChannelMap,
                &tmpsiz, channelMapping);
        if (channelMappingStatus == noErr)
        {
            channelMappingCount = tmpsiz / sizeof(SInt32);
        }
        else
        {
            fprintf(stderr, "AACEncoder AudioConverterGetPropertyInfo kAudioConverterChannelMap error = %d\n", (int)getAvailableBitratesCountStatus);
        }
        for (int i = 0; i < channelMappingCount; i++)
        {
            SInt32 value = channelMapping[i];
            fprintf(stderr, "AACEncoder kAudioConverterChannelMap %d value=%d\n", i,  (int)value);
        }
    }
    else
    {
        fprintf(stderr, "AACEncoder AudioConverterGetPropertyInfo kAudioConverterChannelMap error = %d\n", (int)channelMappingCountStatus);
    }

    // get format list
    AudioFormatListItem * audioFormatList = NULL;
    ssize_t audioFormatListCount = 0;
    OSStatus audioFormatListCountStatus = AudioConverterGetPropertyInfo(inAudioConverter,
            kAudioConverterPropertyFormatList,
            &tmpsiz, NULL);
    if (audioFormatListCountStatus == noErr)
    {
        audioFormatList = (AudioFormatListItem *)malloc(tmpsiz);

        OSStatus audioFormatListStatus =  AudioConverterGetProperty(inAudioConverter,
                kAudioConverterPropertyFormatList,
                &tmpsiz, audioFormatList);
        if (audioFormatListStatus == noErr)
        {
            audioFormatListCount = tmpsiz / sizeof(AudioFormatListItem);
        }
        else
        {
            fprintf(stderr, "AACEncoder AudioConverterGetPropertyInfo audioFormatListStatus error = %d\n", (int)audioFormatListStatus);
        }
        for (int i = 0; i < audioFormatListCount; i++)
        {
            AudioFormatListItem audioFormatListItem = audioFormatList[i];
            
            AudioStreamBasicDescription audioStreamBasicDescription = audioFormatListItem.mASBD;
            AudioChannelLayoutTag channelLayoutTag = audioFormatListItem.mChannelLayoutTag;
            
            logDescription(&audioStreamBasicDescription, "kAudioConverterPropertyFormatList");
            
            fprintf(stderr, "AACEncoder kAudioConverterPropertyFormatList %d AudioChannelLayoutTag=%u\n", i,  (unsigned int)channelLayoutTag);
        }
    }
    else
    {
        fprintf(stderr, "AACEncoder AudioConverterGetPropertyInfo kAudioConverterPropertyFormatList error = %d\n", (int)audioFormatListCountStatus);
    }

    // get property settings array
    OSStatus propertySettingsArrayCountStatus = AudioConverterGetPropertyInfo(inAudioConverter,
            kAudioConverterPropertySettings,
            &tmpsiz, NULL);
    if (propertySettingsArrayCountStatus == noErr)
    {
        if (tmpsiz != sizeof(CFArrayRef))
        {
            fprintf(stderr, "AACEncoder AudioConverterGetPropertyInfo kAudioConverterPropertySettings CFArrayRef error\n");
        }
        
        CFArrayRef propertySettingsArray = NULL;

        OSStatus propertySettingsArrayStatus =  AudioConverterGetProperty(inAudioConverter,
                kAudioConverterPropertySettings,
                &tmpsiz, &propertySettingsArray);
        if (propertySettingsArrayStatus == noErr)
        {
            //CFArrayRef propertySettingsArray = (CFArrayRef)&propertySettingsPtr;

            CFIndex i, c = CFArrayGetCount(propertySettingsArray);
            for (i = 0; i < c; i++)
            {
                const void * item = CFArrayGetValueAtIndex(propertySettingsArray, i);
                CFTypeID typeID = CFGetTypeID(item);
                if (typeID == CFDictionaryGetTypeID())
                {
                    CFDictionaryRef propertySettingsDictionary = (CFDictionaryRef)item;
                    
                    CFIndex propertySettingsDictionaryCount = CFDictionaryGetCount(propertySettingsDictionary);

                    if (propertySettingsDictionaryCount > 0)
                    {
                        // generate description of CFDictionary
                        CFStringRef dictionaryCFString = CFCopyDescription(propertySettingsDictionary);
                        const char * dictionaryCString = CFStringGetCStringPtr(dictionaryCFString, kCFStringEncodingUTF8);
                        fprintf(stderr, "AACEncoder AudioConverterGetProperty kAudioConverterPropertySettings = \n%s\n", dictionaryCString);
                    }
                    else
                    {
                        fprintf(stderr, "AACEncoder AudioConverterGetProperty kAudioConverterPropertySettings = count = 0\n");
                    }
                }
                else
                {
                    fprintf(stderr, "AACEncoder AudioConverterGetProperty kAudioConverterPropertySettings error unknown TypeID = \n%lu\n", typeID);
                }
            }
        }
        else
        {
            fprintf(stderr, "AACEncoder AudioConverterGetProperty kAudioConverterPropertySettings error = %d\n", (int)propertySettingsArrayStatus);
        }
    }
    else
    {
        fprintf(stderr, "AACEncoder AudioConverterGetPropertyInfo kAudioConverterPropertySettings error = %d\n", (int)propertySettingsArrayCountStatus);
    }
}



void logAudioEncoders()
{
    AudioClassDescription audioClassDescription;
    memset(&audioClassDescription, 0, sizeof(audioClassDescription));
    UInt32 size;

    OSStatus getPropertyInfoEncodersStatus = AudioFormatGetPropertyInfo(kAudioFormatProperty_Encoders,
                sizeof(audioConverterOutputDescription.mFormatID),
                &audioConverterOutputDescription.mFormatID,
                &size);

    uint32_t count = size / sizeof(AudioClassDescription);

    AudioClassDescription descriptions[count];
    OSStatus getPropertyEncodersStatus = AudioFormatGetProperty(kAudioFormatProperty_Encoders,
                sizeof(audioConverterOutputDescription.mFormatID),
                &audioConverterOutputDescription.mFormatID,
                &size,
                descriptions);
    
    for (uint32_t i = 0; i < count; i++)
    {
        AudioClassDescription aAudioClassDescription = descriptions[i];
     
        char mTypeString[5];
        mTypeString[0] = (aAudioClassDescription.mType >> 24) & 0xFF;
        mTypeString[1] = (aAudioClassDescription.mType >> 16) & 0xFF;
        mTypeString[2] = (aAudioClassDescription.mType >> 8) & 0xFF;
        mTypeString[3] = (aAudioClassDescription.mType >> 0) & 0xFF;
        mTypeString[4] = 0;
    
        char mSubTypeString[5];
        mSubTypeString[0] = (aAudioClassDescription.mSubType >> 24) & 0xFF;
        mSubTypeString[1] = (aAudioClassDescription.mSubType >> 16) & 0xFF;
        mSubTypeString[2] = (aAudioClassDescription.mSubType >> 8) & 0xFF;
        mSubTypeString[3] = (aAudioClassDescription.mSubType >> 0) & 0xFF;
        mSubTypeString[4] = 0;
    
        char mManufacturerString[5];
        mManufacturerString[0] = (aAudioClassDescription.mManufacturer >> 24) & 0xFF;
        mManufacturerString[1] = (aAudioClassDescription.mManufacturer >> 16) & 0xFF;
        mManufacturerString[2] = (aAudioClassDescription.mManufacturer >> 8) & 0xFF;
        mManufacturerString[3] = (aAudioClassDescription.mManufacturer >> 0) & 0xFF;
        mManufacturerString[4] = 0;
    
        fprintf(stderr, "AACEncoder AudioClassDescription %d, mType = %s, mSubType = %s, mManufacturer = %s\n", i, mTypeString, mSubTypeString, mManufacturerString);
    }
}

//==================================================================================
//    startAudioConverter()
//==================================================================================

void startAudioConverter()
{
    // Configure input and output AudioStreamBasicDescription (ADSB) for AudioConverter to convert PCM data to AAC
    
    logAudioEncoders();
 
    memset(&audioConverterInputDescription, 0, sizeof(audioConverterInputDescription));
    
    audioConverterInputDescription.mSampleRate = sampleRate;        // should be 48000
    audioConverterInputDescription.mFormatID = kAudioFormatLinearPCM;
    audioConverterInputDescription.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
    if (inputChannels == 1)
    {
        audioConverterInputDescription.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved;
    }
    audioConverterInputDescription.mBytesPerPacket = sizeof(SInt16) * inputChannels;
    audioConverterInputDescription.mFramesPerPacket = 1;
    audioConverterInputDescription.mBytesPerFrame = sizeof(SInt16) * inputChannels;
    audioConverterInputDescription.mChannelsPerFrame = inputChannels;
    audioConverterInputDescription.mBitsPerChannel = sizeof(SInt16) * 8;
    audioConverterInputDescription.mReserved = 0;
    
    logDescription(&audioConverterInputDescription, "audioConverterInputDescription");
    
    // set output AudioStreamBasicDescription fields for stereo output
    
    //audioConverterOutputDescription = audioConverterInputDescription;
    memset(&audioConverterOutputDescription, 0, sizeof(audioConverterOutputDescription));

    audioConverterOutputDescription.mBytesPerPacket = 0;
    audioConverterOutputDescription.mFramesPerPacket = 1024;
    audioConverterOutputDescription.mBytesPerFrame = 0;
    
    audioConverterOutputDescription.mChannelsPerFrame = inputChannels;
    
    audioConverterOutputDescription.mBitsPerChannel = 0;
    audioConverterOutputDescription.mReserved = 0;

    audioConverterOutputDescription.mSampleRate = sampleRate;    // frames per second of equivalent decompressed data

    
    if (bitrate >= 64000)
    {
        audioConverterOutputDescription.mFormatID = kAudioFormatMPEG4AAC;
        audioConverterOutputDescription.mFormatFlags = kMPEG4Object_AAC_LC;
    }
    else
    {
        //audioConverterOutputDescription.mFramesPerPacket = 0;

        // best streaming format if bitrate < 64000
        audioConverterOutputDescription.mFormatID = kAudioFormatMPEG4AAC_HE;
        //audioConverterOutputDescription.mFormatID = kAudioFormatMPEG4AAC_HE_V2;

        //audioConverterOutputDescription.mFormatFlags = kMPEG4Object_AAC_SBR;
        audioConverterOutputDescription.mFormatFlags = 0;

        audioConverterOutputDescription.mFramesPerPacket = 2048;    // for AAC-HE per https://lists.apple.com/archives/coreaudio-api/2011/Mar/msg00176.html
    }

    logDescription(&audioConverterOutputDescription, "audioConverterOutputDescription");
 
     // Create AudioConverter

    OSStatus audioConverterNewStatus = AudioConverterNew(&audioConverterInputDescription, &audioConverterOutputDescription, &inAudioConverter);
    if (audioConverterNewStatus != noErr)
    {
        char c[5];
        c[0] = (audioConverterNewStatus >> 24) & 0xFF;
        c[1] = (audioConverterNewStatus >> 16) & 0xFF;
        c[2] = (audioConverterNewStatus >> 8) & 0xFF;
        c[3] = (audioConverterNewStatus >> 0) & 0xFF;
        c[4] = 0;

        fprintf(stderr, "AACEncoder audioConverterNew audioConverterNewStatus error = %s, %d\n", (char *)&c, audioConverterNewStatus);
    }
    else
    {
        fprintf(stderr, "AACEncoder audioConverterNew audioConverterNewStatus success\n");
    }

    // Set AudioConverter properties

    //UInt32 bitRate = sampleRate * inputChannels;
    UInt32 bitrateSize = sizeof(bitrate);
    OSStatus bitrateError = AudioConverterSetProperty(inAudioConverter, kAudioConverterEncodeBitRate, bitrateSize, &bitrate);
    if (bitrateError != noErr)
    {
        fprintf(stderr, "AACEncoder AudioConverterSetProperty kAudioConverterEncodeBitRate %u error = %d\n", (unsigned int)bitrate, (int)bitrateError);
    }


    /*
    UInt32 controlMode = kAudioCodecBitRateControlMode_VariableConstrained;
    //UInt32 controlMode = kAudioCodecBitRateControlMode_Variable;
    UInt32 controlModeSize = sizeof(controlMode);
    OSStatus controlModeStatus = AudioConverterSetProperty(inAudioConverter, kAudioCodecPropertyBitRateControlMode, controlModeSize, &controlMode);
    if (controlModeStatus != noErr)
    {
        fprintf(stderr, "AACEncoder AudioConverterSetProperty kAudioCodecPropertyBitRateControlMode error = %d\n", (int)controlModeStatus);
    }

    UInt32 quality = kAudioCodecQuality_Max;
    UInt32 qualitySize = sizeof(quality);
    OSStatus qualityStatus = AudioConverterSetProperty(inAudioConverter, kAudioCodecPropertySoundQualityForVBR, qualitySize, &quality);
    if (qualityStatus != noErr)
    {
        fprintf(stderr, "AACEncoder AudioConverterSetProperty kAudioCodecPropertySoundQualityForVBR error = %d\n", (int)qualityStatus);
    }
    */

    
    logAudioConverterProperties();
}

//==================================================================================
//    audioConverterComplexInputDataProc()
//==================================================================================

/*
    @typedef    AudioConverterComplexInputDataProc
    @abstract   Callback function for supplying input data to AudioConverterFillComplexBuffer.
    @param      inAudioConverter
                    The AudioConverter requesting input.
    @param      ioNumberDataPackets
                    On entry, the minimum number of packets of input audio data the converter
                    would like in order to fulfill its current FillBuffer request. On exit, the
                    number of packets of audio data actually being provided for input, or 0 if
                    there is no more input.
    @param      ioData
                    On exit, the members of ioData should be set to point to the audio data
                    being provided for input.
    @param      outDataPacketDescription
                    If non-null, on exit, the callback is expected to fill this in with
                    an AudioStreamPacketDescription for each packet of input data being provided.
    @param      inUserData
                    The inInputDataProcUserData parameter passed to AudioConverterFillComplexBuffer().
    @result     An OSStatus result code.
    @discussion
                This callback function supplies input to AudioConverterFillComplexBuffer.
                The AudioConverter requests a minimum number of packets (*ioNumberDataPackets).
                The callback may return one or more packets. If this is less than the minimum,
                the callback will simply be called again in the near future.
                The callback manipulates the members of ioData to point to one or more buffers
                of audio data (multiple buffers are used with non-interleaved PCM data). The
                callback is responsible for not freeing or altering this buffer until it is
                called again.
                If the callback returns an error, it must return zero packets of data.
                AudioConverterFillComplexBuffer will stop producing output and return whatever
                output has already been produced to its caller, along with the error code. This
                mechanism can be used when an input proc has temporarily run out of data, but
                has not yet reached end of stream.
    Technical Q&A QA1317
    Signaling the end of data when using AudioConverterFillComplexBuffer
    Q:  When using AudioConverterFillComplexBuffer to convert data, what should I do when I am running out of data?
    A: There will be three cases when you are running out of data:
    1) End of stream - Inside your input procedure, you must set the total amount of packets read and the sizes of the data in the AudioBufferList to zero. The input procedure should also return noErr. This will signal the AudioConverter that you are out of data. More specifically, set ioNumberDataPackets and ioBufferList->mDataByteSize to zero in your input proc and return noErr. Where ioNumberDataPackets is the amount of data converted and ioBufferList->mDataByteSize is the size of the amount of data converted in each AudioBuffer within your input procedure callback. Your input procedure may be called a few more times; you should just keep returning zero and noErr.
    2) Some data available from the input stream, but not enough to satisfy the input request - If data was being streamed in real time, there can be a situation where there is not enough data to be processed that meets the amount of data requested in your callback. In this case, you should return noErr and the amount of packets processed from your input callback. Your input callback will be called again for the remaining packets.
    3) No data currently available - If there is no data currently available from the input stream, but data remains to be converted, set ioNumberDataPackets to zero and return an error (any non-zero value). The error will be propagated back to the caller. If any data was converted, that will also be returned to the caller.
    Note: If you think you will be in this situation, you should request for smaller amounts of data when calling AudioConverterFillComplexBuffer . You should not request large amounts of data and hope to get partial amounts.
    You should also never try to guess exactly how much data to request from your callback to convert an entire data buffer in one call. Codecs are allowed to keep any amount of data buffered internally; therefore, you should request smaller amounts of data. The overhead of requesting a conversion is small compared to the conversion itself. Requesting very large buffers is also bad for cache. It causes every internal buffer to have to be large, or to have to be split up into smaller chunks.
    See AudioConverter.h in AudioToolbox.framework for more details regarding the use of the AudioConverter.
*/

OSStatus audioConverterComplexInputDataProc(AudioConverterRef inAudioConverter,
        UInt32 * ioNumberDataPackets,
        AudioBufferList * ioData,
        AudioStreamPacketDescription ** ioDataPacketDescription,
        void * inUserData)
{
    FillComplexInputParam * fillComplexInputParam = (FillComplexInputParam *)inUserData;
    if (fillComplexInputParam->inputBufferDataLength <= 0)
    {
        *ioNumberDataPackets = 0;
        return 'zero';    // done for now, earlier packets may exist in the buffer ready for use
    }

    OSStatus result = noErr;
    
    ioData->mNumberBuffers = 1;
    ioData->mBuffers[0].mNumberChannels =  fillComplexInputParam->inputChannels;
    ioData->mBuffers[0].mDataByteSize = fillComplexInputParam->inputBufferDataLength;
    ioData->mBuffers[0].mData = fillComplexInputParam-> inputBufferPtr;

    *ioNumberDataPackets = 1;       // 1 for AAC output

    fillComplexInputParam-> inputBufferPtr = NULL;
    fillComplexInputParam->inputBufferDataLength = 0;
    fillComplexInputParam->inputChannels = 0;
    fillComplexInputParam->packetDescription = NULL;

    //fprintf(stderr, "AACEncoder - audioConverterComplexInputDataProc ioNumberDataPacketsRequested=%u, ioNumberDataPacketsProduced=%u,  result=%d\n", ioNumberDataPacketsRequested, ioNumberDataPacketsProduced, result);

    return result;
}

//==================================================================================
//    convertBuffer()
//==================================================================================

void convertBuffer(void * inputBufferPtr, unsigned int dataLength)
{
    // convert PCM audio data to AAC

    //const UInt32 numFrames = dataLength / (sizeof(SInt16) * audioConverterInputDescription.mChannelsPerFrame);
    
    audioConverterInputAudioBuffer.mNumberChannels = audioConverterInputDescription.mChannelsPerFrame;
    audioConverterInputAudioBuffer.mDataByteSize = (SInt32)dataLength;
    audioConverterInputAudioBuffer.mData = (void *)inputBufferPtr;

    FillComplexInputParam fillComplexInputParam;
    fillComplexInputParam. inputBufferPtr = inputBufferPtr;
    fillComplexInputParam.inputBufferDataLength = dataLength;
    fillComplexInputParam.inputChannels = inputChannels;
    fillComplexInputParam.packetDescription = NULL;

    memset(audioConverterOutputBufferPtr, 0, audioConverterOutputBytes);

    audioConverterOutputBufferList.mNumberBuffers = 1;
    audioConverterOutputBufferList.mBuffers[0].mNumberChannels = audioConverterOutputDescription.mChannelsPerFrame;
    audioConverterOutputBufferList.mBuffers[0].mDataByteSize = audioConverterOutputBytes;
    audioConverterOutputBufferList.mBuffers[0].mData = audioConverterOutputBufferPtr;

    UInt32 outputDataPacketSize = 1;    // for AAC

    //fprintf(stderr, "AACEncoder convertBuffer numFrames=%d, remain=%d\n", numFrames, audioConverterInputPacketsRemain);

    OSStatus convertResult = noErr;

    AudioStreamPacketDescription outputPacketDescriptions;
    memset(&outputPacketDescriptions, 0, sizeof(AudioStreamPacketDescription));

    convertResult = AudioConverterFillComplexBuffer(
            inAudioConverter,      // AudioConverterRef inAudioConverter
            audioConverterComplexInputDataProc, // AudioConverterComplexInputDataProc inInputDataProc
            &fillComplexInputParam,  // void *inInputDataProcUserData
            &outputDataPacketSize, // UInt32 *ioOutputDataPacketSize - entry: max packets capacity, exit: number of packets converted
            &audioConverterOutputBufferList,     // AudioBufferList *outOutputData
            &outputPacketDescriptions            // AudioStreamPacketDescription *outPacketDescription
            );
    
    //fprintf(stderr, "AACEncoder convertBuffer AudioConverterFillComplexBuffer result = %d, outputDataPacketSize = %d\n", convertResult, outputDataPacketSize);

    if ((convertResult == noErr) || (convertResult == 'zero'))
    {
        if (outputDataPacketSize > 0)   // number of packets converted
        {
            // produce encoded audio to stdout

            SInt64  mStartOffset = outputPacketDescriptions.mStartOffset;
            UInt32  mVariableFramesInPacket = outputPacketDescriptions.mVariableFramesInPacket;
            UInt32  mDataByteSize = outputPacketDescriptions.mDataByteSize;
            #pragma unused(mStartOffset, mVariableFramesInPacket, mDataByteSize)

            int32_t convertedDataLength = audioConverterOutputBufferList.mBuffers[0].mDataByteSize;
            void * convertedDataPtr = audioConverterOutputBufferList.mBuffers[0].mData;

            //fprintf(stderr, "AACEncoder convertBuffer AudioConverterFillComplexBuffer mStartOffset = %lld, mVariableFramesInPacket = %d, mDataByteSize = %d, convertedDataLength = %d\n", mStartOffset, mVariableFramesInPacket, mDataByteSize, convertedDataLength);
            
            // format ADTS header per  https://wiki.multimedia.cx/index.php/ADTS
            // ADTS header decoder: http://www.p23.nl/projects/aac-header/
            UInt32 adtsHeaderLength = 7;
            UInt8 adtsHeader[adtsHeaderLength];
            
            UInt32 profile = kMPEG4Object_AAC_LC;
            
            UInt32 freqIdx = freqIdxForAdtsHeader(48000);        // for sample rate 48000
            UInt32 chanCfg = 2;        // channels
            UInt32 fullLength = adtsHeaderLength + convertedDataLength;
            
            /*
            // adapted from https://github.com/JQJoe/AACEncodeAndDecode
            adtsHeader[0] = (UInt8)0xFF;     // syncword
            adtsHeader[1] = (UInt8)0xF9;     // syncword, mpeg version, layer, CRC protection absent
            adtsHeader[2] = (UInt8)(((profile-1)<<6) + (freqIdx<<2) + (chanCfg>>2));  // profile, sampling frequency index, private bit, channel configuration
            adtsHeader[3] = (UInt8)(((chanCfg&3)<<6) + (fullLength>>11));    // channel configuration, originality, home, copyrighted, copyright id, frame length
            adtsHeader[4] = (UInt8)((fullLength&0x7FF) >> 3);    // frame length
            adtsHeader[5] = (UInt8)(((fullLength&7)<<5) + 0x1F); // frame length, buffer fullness
            adtsHeader[6] = (UInt8)0xFC;     // buffer fullness, number of aac frames minus one
            */

            // adapted from http://lists.live555.com/pipermail/live-devel/2009-August/011113.html
            /* Sync point over a full byte */
            adtsHeader[0] = 0xFF;
            
            /* Sync point continued over first 4 bits + static 4 bits
            * (ID, layer, protection)*/
            
            
            if (bitrate >= 64000)
            {
                // for kMPEG4Object_AAC_LC
                adtsHeader[1] = 0xF9;   // 1111 1 00 1  = syncword, MPEG-2, Layer 0, CRC checksum absent
                //adtsHeader[1] = 0xF1;   // 1111 0 00 1  = syncword, MPEG-4, Layer 0, CRC checksum absent
            }
            else
            {
                // for kAudioFormatMPEG4AAC_HE
                //adtsHeader[1] = 0xF9;   // 1111 1 00 1  = syncword, MPEG-2, Layer 0, CRC checksum absent
                adtsHeader[1] = 0xF1;   // 1111 0 00 1  = syncword, MPEG-4, Layer 0, CRC checksum absent
            }

            /* Object type over first 2 bits */
            adtsHeader[2] = ((profile - 1) & 0x3) << 6;
            
            /* rate index over next 4 bits */
            adtsHeader[2] |= (freqIdx & 0xf) << 2;
            
            /* 3-bit channels, first bit */
            adtsHeader[2] |= (chanCfg & 0x4) >> 2;
            
            /* channels continued over next 2 bits + 4 bits at zero */
            adtsHeader[3] = (chanCfg & 0x3) << 6;
            
            /* 13-bit frame size, first two bits */
            adtsHeader[3] |= (fullLength & 0x1800) >> 11;
            
            /* frame size continued next eight bits */
            adtsHeader[4] = (fullLength & 0x07F8) >> 3;
            
            /* frame size continued last 3 bits */
            adtsHeader[5] = (fullLength & 0x7) << 5;
            
            /* 11-bit buffer fullness (0x7FF for VBR), first 5 bits*/
            adtsHeader[5] |= 0x1F;
            
            /* buffer fullness (0x7FF for VBR) continued, last 6 bits + 2 zeros
             * number of raw data blocks */
            adtsHeader[6] = 0xFC;

            // write encoded audio to stdout, can be piped to IcecastSource
            //fwrite(&adtsHeader[0], adtsHeaderLength, 1, stdout);    // write ADTS header
            //fwrite(convertedDataPtr, convertedDataLength, 1, stdout);   // write raw AAC data
            
            // assemble adts header and aac payload into a packet
            int packetLength = adtsHeaderLength + convertedDataLength;
            
            memcpy(adtsPacketPtr, &adtsHeader, adtsHeaderLength);
            memcpy(adtsPacketPtr + 7, convertedDataPtr, convertedDataLength);

            fwrite(adtsPacketPtr, packetLength, 1, stdout);   // write ADTS packet
            
            if (outputPacketCount == 0)
            {
                // log the first ADTS header
                fprintf(stderr, "AACEncoder convertBuffer packetLength = %d, adtsHeader %02x %02x %02x %02x %02x %02x %02x\n", packetLength, adtsHeader[0], adtsHeader[1], adtsHeader[2], adtsHeader[3], adtsHeader[4], adtsHeader[5], adtsHeader[6]);
            }
            
            outputPacketCount++;
        }
        else
        {
            //fprintf(stderr, "AACEncoder convertBuffer AudioConverterFillComplexBuffer outputDataPacketSize = 0 %d\n", convertResult);
        }
    }
    else
    {
        char c[5];
        c[0] = (convertResult >> 24) & 0xFF;
        c[1] = (convertResult >> 16) & 0xFF;
        c[2] = (convertResult >> 8) & 0xFF;
        c[3] = (convertResult >> 0) & 0xFF;
        c[4] = 0;

        fprintf(stderr, "AACEncoder convertBuffer error AudioConverterFillComplexBuffer failed %s, %d\n", (void *)&c, convertResult);
        AudioConverterReset(inAudioConverter);
    }
}

//==================================================================================
//    runAudioConverterOnThread()
//==================================================================================

void * runAudioConverterOnThread(void * ptr)
{
    pthread_setname_np("runAudioConverterOnThread");

    sleep(1); // allow time for startup

    //pid_t originalParentProcessPID = getppid();
    
    bool doExit = false;

    time_t lastReadTime = time(NULL) + 20;
    int nextTimeoutReportInterval = 5;
    
    startAudioConverter();     // resample PCM data to 48000 Hz

    audioConverterOutputBytes = 512 * 1024 * audioConverterOutputDescription.mChannelsPerFrame;
    audioConverterOutputBufferPtr = malloc(audioConverterOutputBytes);

    adtsPacketPtr = (UInt8 *)malloc(audioConverterOutputBytes);

    // continuous run loop
    while (doExit == false)
    {
        //fprintf(stderr, "AACEncoder runAudioConverterOnThread polling loop\n");

        CFRunLoopMode runLoopMode = kCFRunLoopDefaultMode;
        CFTimeInterval runLoopTimeInterval = 0.25f;
        Boolean returnAfterSourceHandled = false;
        CFRunLoopRunResult runLoopResult = CFRunLoopRunInMode(runLoopMode, runLoopTimeInterval, returnAfterSourceHandled);
        
        if (runLoopResult != kCFRunLoopRunFinished)
        {
            char const * runLoopResultString = "unknown";
            switch (runLoopResult)
            {
                case kCFRunLoopRunFinished: runLoopResultString = "kCFRunLoopRunFinished"; break;
                case kCFRunLoopRunStopped: runLoopResultString = "kCFRunLoopRunStopped"; break;
                case kCFRunLoopRunTimedOut: runLoopResultString = "kCFRunLoopRunTimedOut"; break;
                case kCFRunLoopRunHandledSource: runLoopResultString = "kCFRunLoopRunHandledSource"; break;
            }
            fprintf(stderr, "AACEncoder runAudioConverterOnThread runLoopResult %s\n", runLoopResultString);
        }

        time_t currentTime = time(NULL);

        int32_t bytesAvailableCount = 0;

        void * circularBufferDataPtr = TPCircularBufferTail(&inputCircularBuffer, &bytesAvailableCount);    // get pointer to read buffer
        
        if( bytesAvailableCount <= 0)
        {
            usleep(5000);
        }
        else
        {
            if (bytesAvailableCount % (inputChannels * sizeof(SInt16)) == 0)
            {
                lastReadTime = currentTime;
                nextTimeoutReportInterval = 5;
                
                int32_t bytesConsumedCount = bytesAvailableCount;

                int32_t maxBytesCount = (inputChannels * sizeof(SInt16) * 1024);    // 1024 samples = 2048 for one channel, 4096 for two channels

                if (bytesConsumedCount > maxBytesCount)
                {
                    bytesConsumedCount = maxBytesCount;     // kAudioConverterPropertyMaximumInputBufferSize = 4100
                }

                convertBuffer(circularBufferDataPtr, bytesConsumedCount);

                //fprintf(stderr, "AACEncoder runAudioConverterOnThread - Consume bytesAvailableCount = %d, circularBufferDataPtr = %p\n", bytesAvailableCount, circularBufferDataPtr);

                TPCircularBufferConsume(&inputCircularBuffer, bytesConsumedCount);
            }
            else
            {
                fprintf(stderr, "AACEncoder runAudioConverterOnThread error data size is not an integral multiple of frame size\n");
            }
        }

        time_t intervalSinceLastRead = currentTime - lastReadTime;
        if (intervalSinceLastRead >= nextTimeoutReportInterval)
        {
            fprintf(stderr, "AACEncoder runAudioConverterOnThread error intervalSinceLastRead >= %d\n", nextTimeoutReportInterval);

            nextTimeoutReportInterval += 5;
        }
    }
    //pthread_exit(NULL);
    
    AudioConverterDispose(inAudioConverter);
    
    free(audioConverterOutputBufferPtr);
    free(adtsPacketPtr);

    return NULL;
}

//==================================================================================
//    createAudioConverterThread()
//==================================================================================

void createAudioConverterThread()
{
    pthread_attr_t attr; /* set of thread attributes */
    pthread_attr_init(&attr);

    int audioConverterThreadErr;
    audioConverterThreadErr = pthread_create(&audioConverterThreadID, &attr, &runAudioConverterOnThread, NULL);
    pthread_detach(audioConverterThreadID);
}

//==================================================================================
//    runAACEncoder()
//==================================================================================

void runAACEncoder(unsigned int inSampleRate, unsigned int inChannels, unsigned int inBitrate)
{
    //raise(SIGSTOP); // Stop and wait for debugger. Click the Debugger's Resume button to continue execution
    
    sampleRate = inSampleRate;
    inputChannels = inChannels;
    bitrate = inBitrate;
    outputPacketCount = 0;
    
    // start threads for input buffering and AAC encoding
    inputBufferThreadID = 0;
    audioConverterThreadID = 0;

    createInputBufferThread();
    createAudioConverterThread();
}

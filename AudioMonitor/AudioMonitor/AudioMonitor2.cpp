//
//  AudioMonitor2.cpp
//  AudioMonitor
//
//  Created by Douglas Ward on 8/22/18.
//  Copyright © 2018 ArkPhone LLC. All rights reserved.
//

#include "AudioMonitor2.hpp"

//  Receive input 1-or-2 channel LPCM audio data at stdin, store in first TPCircularBuffer
//  Use AudioConverter to resample audio to 48000 Hz, store in second TPCircularBuffer, and output to stdout.
//  If volume > 0, enqueue 48000 Hz data to AudioQueue for playback with default hardware audio device.

//  This code was translated from Objective-C to C++

//  For more info, see -
//  https://github.com/michaeltyson/TPCircularBuffer
//  http://atastypixel.com/blog/four-common-mistakes-in-audio-development/


#import "AudioMonitor2.hpp"
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

//#import <CoreFoundation/CoreFoundation.h>

#import <AudioToolbox/AudioToolbox.h>
#import <Accelerate/Accelerate.h>
//#import "TPCircularBuffer+AudioBufferList.h"
#import "TPCircularBuffer.h"


// AudioQueue values
#define kAudioQueueBuffersCount 3
#define maxWhiteNoiseBufferLength 32000

AudioConverterRef inAudioConverter;     // AudioConverter for resampling PCM data to 48000 Hz

AudioStreamBasicDescription audioConverterInputDescription;
AudioStreamBasicDescription audioConverterOutputDescription;

TPCircularBuffer inputCircularBuffer;        // TPCircularBuffer for storage and retrieval of input PCM data from stdin

AudioBufferList audioConverterOutputBufferList;
void * audioConverterOutputBufferPtr;
UInt32 audioConverterOutputBytes;

AudioQueueRef audioQueue;               // AudioQueue for playing resampled PCM data to current audio output device, usually speakers

AudioStreamBasicDescription audioQueueDescription;
AudioQueueBufferRef buffers[kAudioQueueBuffersCount];
unsigned int audioQueueIndex;

TPCircularBuffer audioConverterCircularBuffer;        // TPCircularBuffer for storage and retrieval of resampled PCM data
unsigned int sampleRate;
unsigned int inputChannels;
double volume;
unsigned int inputBufferSize;
unsigned int audioConverterBufferSize;
unsigned int audioQueueBufferSize;

unsigned int packetOutputIndex;
CFAbsoluteTime lastValidPacketAbsoluteTime;

AudioBuffer audioConverterInputAudioBuffer;

pthread_t inputBufferThreadID;
pthread_t audioConverterThreadID;
pthread_t audioQueueThreadID;

void createAudioConverterThread();
void createAudioQueueThread();

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
    AudioQueueStop(audioQueue, false);
    AudioQueueDispose(audioQueue, false);
    
    TPCircularBufferCleanup(&inputCircularBuffer);
    TPCircularBufferCleanup(&audioConverterCircularBuffer);
}

void logHexData(void * dataPtr, int length)
{
    fprintf(stderr, "AudioMonitor2 - logHexData -\n");
    for (int i = 0; i < length; i++)
    {
        unsigned char * bytePtr = (unsigned char *)((unsigned long long)dataPtr + i);
        fprintf(stderr, "%02x ", *bytePtr);
        
        if (i > 0)
        {
            if (i % 16 == 15)
            {
                fprintf(stderr, " ***\n");
            }
            else if (i % 4 == 3)
            {
                fprintf(stderr, " ");
            }
        }
    }
    fprintf(stderr, "\n");
}

//==================================================================================
//    logDescription()
//==================================================================================

void logDescription(AudioStreamBasicDescription * asbd, const char * name)
{
    fprintf(stderr, "AudioMonitor2 - AudioStreamBasicDescription %s\n", name);
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
//    logAudioConverterProperties()
//==================================================================================

void logAudioConverterProperties()
{
    UInt32 tmpsiz = sizeof(UInt32);
    UInt32 encodeBitRate = 0;
    OSStatus encodeBitRateStatus =  AudioConverterGetProperty(inAudioConverter,
            kAudioConverterEncodeBitRate,
            &tmpsiz, &encodeBitRate);
    if (encodeBitRateStatus == noErr)
    {
        fprintf(stderr, "AudioMonitor2 AudioConverterGetProperty kAudioConverterEncodeBitRate = %d\n", (int)encodeBitRate);
    }
    else
    {
        fprintf(stderr, "AudioMonitor2 AudioConverterGetProperty kAudioConverterEncodeBitRate error = %d\n", (int)encodeBitRateStatus);
    }

    tmpsiz = sizeof(UInt32);
    UInt32 bitDepthHint = 0;
    OSStatus bitDepthHintStatus =  AudioConverterGetProperty(inAudioConverter,
            kAudioConverterPropertyBitDepthHint,
            &tmpsiz, &bitDepthHint);
    if (bitDepthHintStatus == noErr)
    {
        fprintf(stderr, "AudioMonitor2 AudioConverterGetProperty kAudioConverterPropertyBitDepthHint = %d\n", (int)bitDepthHint);
    }
    else
    {
        fprintf(stderr, "AudioMonitor2 AudioConverterGetProperty kAudioConverterPropertyBitDepthHint error = %d\n", (int)bitDepthHintStatus);
    }

    tmpsiz = sizeof(UInt32);
    UInt32 minimumInputBufferSize = 0;
    OSStatus minimumInputBufferSizeStatus =  AudioConverterGetProperty(inAudioConverter,
            kAudioConverterPropertyMinimumInputBufferSize,
            &tmpsiz, &minimumInputBufferSize);
    if (minimumInputBufferSizeStatus == noErr)
    {
        fprintf(stderr, "AudioMonitor2 AudioConverterGetProperty kAudioConverterPropertyMinimumInputBufferSize = %d\n", (int)minimumInputBufferSize);
    }
    else
    {
        fprintf(stderr, "AudioMonitor2 AudioConverterGetProperty kAudioConverterPropertyMinimumInputBufferSize error = %d\n", (int)minimumInputBufferSizeStatus);
    }

    tmpsiz = sizeof(UInt32);
    UInt32 minimumOutputBufferSize = 0;
    OSStatus minimumOutputBufferSizeStatus =  AudioConverterGetProperty(inAudioConverter,
            kAudioConverterPropertyMinimumOutputBufferSize,
            &tmpsiz, &minimumOutputBufferSize);
    if (minimumOutputBufferSizeStatus == noErr)
    {
        fprintf(stderr, "AudioMonitor2 AudioConverterGetProperty kAudioConverterPropertyMinimumOutputBufferSize = %d\n", (int)minimumOutputBufferSize);
    }
    else
    {
        // returns 'prop', property not supported
        fprintf(stderr, "AudioMonitor2 AudioConverterGetProperty kAudioConverterPropertyMinimumOutputBufferSize error = %d\n", (int)minimumOutputBufferSizeStatus);
    }

    tmpsiz = sizeof(UInt32);
    UInt32 maximumInputBufferSize = 0;
    OSStatus maximumInputBufferSizeStatus =  AudioConverterGetProperty(inAudioConverter,
            kAudioConverterPropertyMaximumInputBufferSize,
            &tmpsiz, &maximumInputBufferSize);
    if (maximumInputBufferSizeStatus == noErr)
    {
        fprintf(stderr, "AudioMonitor2 AudioConverterGetProperty kAudioConverterPropertyMaximumInputBufferSize = %d\n", (int)maximumInputBufferSize);
    }
    else
    {
        fprintf(stderr, "AudioMonitor2 AudioConverterGetProperty kAudioConverterPropertyMaximumInputBufferSize error = %d\n", (int)maximumInputBufferSizeStatus);
    }

    tmpsiz = sizeof(UInt32);
    UInt32 maximumInputPacketSize = 0;
    OSStatus maximumInputPacketSizeStatus =  AudioConverterGetProperty(inAudioConverter,
            kAudioConverterPropertyMaximumInputPacketSize,
            &tmpsiz, &maximumInputPacketSize);
    if (maximumInputPacketSizeStatus == noErr)
    {
        fprintf(stderr, "AudioMonitor2 AudioConverterGetProperty kAudioConverterPropertyMaximumInputPacketSize = %d\n", (int)maximumInputPacketSize);
    }
    else
    {
        fprintf(stderr, "AudioMonitor2 AudioConverterGetProperty kAudioConverterPropertyMaximumInputPacketSize error = %d\n", (int)maximumInputPacketSize);
    }

    tmpsiz = sizeof(UInt32);
    UInt32 maximumOutputPacketSize = 0;     //  indicates the size, in bytes, of the largest single packet of data in the output format (1536 for AAC?)
    OSStatus maximumOutputPacketSizeStatus =  AudioConverterGetProperty(inAudioConverter,
            kAudioConverterPropertyMaximumOutputPacketSize,
            &tmpsiz, &maximumOutputPacketSize);
    if (maximumOutputPacketSizeStatus == noErr)
    {
        fprintf(stderr, "AudioMonitor2 AudioConverterGetProperty kAudioConverterPropertyMaximumOutputPacketSize = %d\n", (int)maximumOutputPacketSize);
    }
    else
    {
        fprintf(stderr, "AudioMonitor2 AudioConverterGetProperty kAudioConverterPropertyMaximumOutputPacketSize error = %d\n", (int)maximumOutputPacketSizeStatus);
    }
    
    // kAudioConverterPropertyCalculateInputBufferSize not used currently
    // kAudioConverterPropertyCalculateOutputBufferSize not used currently
    
    tmpsiz = sizeof(UInt32);
    UInt32 sampleRateConverterComplexity = 0;
    OSStatus sampleRateConverterComplexityStatus =  AudioConverterGetProperty(inAudioConverter,
            kAudioConverterSampleRateConverterComplexity,
            &tmpsiz, &sampleRateConverterComplexity);
    if (sampleRateConverterComplexityStatus == noErr)
    {
        fprintf(stderr, "AudioMonitor2 AudioConverterGetProperty kAudioConverterSampleRateConverterComplexity = %d\n", (int)sampleRateConverterComplexity);
    }
    else
    {
        // returned 'prop', property not supported, perhaps because not resampling?
        fprintf(stderr, "AudioMonitor2 AudioConverterGetProperty kAudioConverterSampleRateConverterComplexity error = %d\n", (int)sampleRateConverterComplexityStatus);
    }
    
    tmpsiz = sizeof(UInt32);
    UInt32 sampleRateConverterQuality = 0;
    OSStatus sampleRateConverterQualityStatus =  AudioConverterGetProperty(inAudioConverter,
            kAudioConverterSampleRateConverterQuality,
            &tmpsiz, &sampleRateConverterQuality);
    if (sampleRateConverterQualityStatus == noErr)
    {
        fprintf(stderr, "AudioMonitor2 AudioConverterGetProperty kAudioConverterSampleRateConverterQuality = %d\n", (int)sampleRateConverterQuality);
    }
    else
    {
        // returned 'prop', property not supported, apparently for the aac codec?
        fprintf(stderr, "AudioMonitor2 AudioConverterGetProperty kAudioConverterSampleRateConverterQuality error = %d\n", (int)sampleRateConverterQualityStatus);
    }
    
    tmpsiz = sizeof(UInt32);
    UInt32 codecQuality = 0;
    OSStatus codecQualityStatus =  AudioConverterGetProperty(inAudioConverter,
            kAudioConverterCodecQuality,
            &tmpsiz, &codecQuality);
    if (codecQualityStatus == noErr)
    {
        fprintf(stderr, "AudioMonitor2 AudioConverterGetProperty kAudioConverterCodecQuality = %d\n", (int)codecQuality);
    }
    else
    {
        fprintf(stderr, "AudioMonitor2 AudioConverterGetProperty kAudioConverterCodecQuality error = %d\n", (int)codecQualityStatus);
    }


    tmpsiz = sizeof(Float64);
    Float64 encodeAdjustableSampleRate = 0;
    OSStatus adjustableSampleRateStatus =  AudioConverterGetProperty(inAudioConverter,
            kAudioConverterEncodeAdjustableSampleRate,
            &tmpsiz, &encodeAdjustableSampleRate);
    if (adjustableSampleRateStatus == noErr)
    {
        fprintf(stderr, "AudioMonitor2 AudioConverterGetProperty kAudioConverterEncodeAdjustableSampleRate = %d\n", (int)encodeAdjustableSampleRate);
    }
    else
    {
        fprintf(stderr, "AudioMonitor2 AudioConverterGetProperty kAudioConverterEncodeAdjustableSampleRate error = %d\n", (int)adjustableSampleRateStatus);
    }

    tmpsiz = sizeof(AudioConverterPrimeInfo);
    AudioConverterPrimeInfo primeInfo;
    OSStatus primeInfoStatus =  AudioConverterGetProperty(inAudioConverter,
            kAudioConverterPrimeInfo,
            &tmpsiz, &primeInfo);
    if (primeInfoStatus == noErr)
    {
        fprintf(stderr, "AudioMonitor2 AudioConverterGetProperty kAudioConverterPrimeInfo leadingFrames = %d, trailingFrames = %d\n", (int)primeInfo.leadingFrames, (int)primeInfo.trailingFrames);
    }
    else
    {
        fprintf(stderr, "AudioMonitor2 AudioConverterGetProperty kAudioConverterPrimeInfo error = %d\n", (int)primeInfoStatus);
    }



    tmpsiz = sizeof(AudioChannelLayout);
    AudioChannelLayout inputChannelLayout;
    OSStatus inputChannelLayoutStatus =  AudioConverterGetProperty(inAudioConverter,
            kAudioConverterInputChannelLayout,
            &tmpsiz, &inputChannelLayout);
    if (inputChannelLayoutStatus == noErr)
    {
        fprintf(stderr, "AudioMonitor2 AudioConverterGetProperty kAudioConverterInputChannelLayout mChannelLayoutTag = %d, mChannelBitmap = %d, mNumberChannelDescriptions = %d\n", inputChannelLayout.mChannelLayoutTag, inputChannelLayout.mChannelBitmap, inputChannelLayout.mNumberChannelDescriptions);
        AudioChannelDescription inputChannelDescription = inputChannelLayout.mChannelDescriptions[0];
        AudioChannelLabel inputChannelLabel = inputChannelDescription.mChannelLabel;
        AudioChannelFlags inputChannelFlags = inputChannelDescription.mChannelFlags;
        Float32 inputCoordinates0 = inputChannelDescription.mCoordinates[0];
        Float32 inputCoordinates1 = inputChannelDescription.mCoordinates[1];
        Float32 inputCoordinates2 = inputChannelDescription.mCoordinates[2];
        fprintf(stderr, "AudioMonitor2 AudioConverterGetProperty kAudioConverterInputChannelLayout AudioChannelDescription AudioChannelLabel = %d, AudioChannelFlags = %d, coordinates = %f,%f,%f\n", inputChannelLabel, inputChannelFlags, inputCoordinates0, inputCoordinates1, inputCoordinates2);
    }
    else
    {
        fprintf(stderr, "AudioMonitor2 AudioConverterGetProperty kAudioConverterInputChannelLayout error = %d\n", (int)inputChannelLayoutStatus);
    }

    tmpsiz = sizeof(AudioChannelLayout);
    AudioChannelLayout outputChannelLayout;
    OSStatus outputChannelLayoutStatus =  AudioConverterGetProperty(inAudioConverter,
            kAudioConverterOutputChannelLayout,
            &tmpsiz, &outputChannelLayout);
    if (outputChannelLayoutStatus == noErr)
    {
        fprintf(stderr, "AudioMonitor2 AudioConverterGetProperty kAudioConverterOutputChannelLayout mChannelLayoutTag = %d, mChannelBitmap = %d, mNumberChannelDescriptions = %d\n", outputChannelLayout.mChannelLayoutTag, outputChannelLayout.mChannelBitmap, outputChannelLayout.mNumberChannelDescriptions);
        AudioChannelDescription outputChannelDescription = outputChannelLayout.mChannelDescriptions[0];
        AudioChannelLabel outputChannelLabel = outputChannelDescription.mChannelLabel;
        AudioChannelFlags outputChannelFlags = outputChannelDescription.mChannelFlags;
        Float32 outputCoordinates0 = outputChannelDescription.mCoordinates[0];
        Float32 outputCoordinates1 = outputChannelDescription.mCoordinates[1];
        Float32 outputCoordinates2 = outputChannelDescription.mCoordinates[2];
        fprintf(stderr, "AudioMonitor2 AudioConverterGetProperty kAudioConverterOutputChannelLayout AudioChannelDescription AudioChannelLabel = %d, AudioChannelFlags = %d, coordinates = %f,%f,%f\n", outputChannelLabel, outputChannelFlags, outputCoordinates0, outputCoordinates1, outputCoordinates2);
    }
    else
    {
        fprintf(stderr, "AudioMonitor2 AudioConverterGetProperty kAudioConverterOutputChannelLayout error = %d\n", (int)outputChannelLayoutStatus);
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
        fprintf(stderr, "AudioMonitor2 AudioConverterGetProperty kAudioConverterCurrentOutputStreamDescription error = %d\n", (int)currentOutputStreamDescriptionStatus);
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
        fprintf(stderr, "AudioMonitor2 AudioConverterGetProperty kAudioConverterCurrentOutputStreamDescription error = %d\n", (int)currentInputStreamDescriptionStatus);
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
            fprintf(stderr, "AudioMonitor2 AudioConverterGetProperty getApplicableBitratesCountStatus error = %d\n", (int)getApplicableBitratesStatus);
        }
        
        fprintf(stderr, "AudioMonitor2 kAudioConverterApplicableEncodeBitRates applicableBitratesCount = %zdd\n", applicableBitratesCount);
        
        for (int i = 0; i < applicableBitratesCount; i++)
        {
            Float64 minimum = applicableBitrates[i].mMinimum;
            Float64 maximum = applicableBitrates[i].mMaximum;
            fprintf(stderr, "AudioMonitor2 kAudioConverterApplicableEncodeBitRates Applicable BitRate %d minimum=%f, maximum=%f\n", i, minimum,  maximum);
        }
        
        free(applicableBitrates);
    }
    else
    {
        fprintf(stderr, "AudioMonitor2 AudioConverterGetPropertyInfo getApplicableBitrateStatus error = %d\n", (int)getApplicableBitratesCountStatus);
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
            fprintf(stderr, "AudioMonitor2 AudioConverterGetProperty kAudioConverterApplicableEncodeBitRates error = %d\n", (int)getAvailableBitratesStatus);
        }
        
        fprintf(stderr, "AudioMonitor2 kAudioConverterApplicableEncodeBitRates availableBitratesCount = %zdd\n", availableBitratesCount);
        
        for (int i = 0; i < availableBitratesCount; i++)
        {
            Float64 minimum = availableBitrates[i].mMinimum;
            Float64 maximum = availableBitrates[i].mMaximum;
            fprintf(stderr, "AudioMonitor2 kAudioConverterApplicableEncodeBitRates Available Encode BitRate %d minimum=%f, maximum=%f\n", i, minimum,  maximum);
        }
        
        free(availableBitrates);
    }
    else
    {
        fprintf(stderr, "AudioMonitor2 AudioConverterGetPropertyInfo kAudioConverterApplicableEncodeBitRates error = %d\n", (int)getAvailableBitratesCountStatus);
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
            fprintf(stderr, "AudioMonitor2 AudioConverterGetProperty kAudioConverterApplicableEncodeSampleRates error = %d\n", (int)getApplicableEncodeSampleRatesStatus);
        }
        
        fprintf(stderr, "AudioMonitor2 AudioConverterGetProperty kAudioConverterApplicableEncodeSampleRates  = %zdd\n", applicableEncodeSampleRatesCount);
        
        for (int i = 0; i < applicableEncodeSampleRatesCount; i++)
        {
            Float64 minimum = applicableEncodeSampleRates[i].mMinimum;
            Float64 maximum = applicableEncodeSampleRates[i].mMaximum;
            fprintf(stderr, "AudioMonitor2 kAudioConverterApplicableEncodeSampleRates Applicable Encode Sample Rates %d minimum=%f, maximum=%f\n", i, minimum,  maximum);
        }
        
        free(applicableEncodeSampleRates);
    }
    else
    {
        fprintf(stderr, "AudioMonitor2 AudioConverterGetPropertyInfo kAudioConverterApplicableEncodeSampleRates error = %d\n", (int)getApplicableEncodeSampleRatesCountStatus);
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
            fprintf(stderr, "AudioMonitor2 AudioConverterGetProperty kAudioConverterAvailableEncodeSampleRates error = %d\n", (int)getAvailableEncodeSampleRatesStatus);
        }
        
        fprintf(stderr, "AudioMonitor2 kAudioConverterAvailableEncodeSampleRates availableEncodeSampleRatesCount = %zdd\n", availableEncodeSampleRatesCount);
        
        for (int i = 0; i < availableEncodeSampleRatesCount; i++)
        {
            Float64 minimum = availableEncodeSampleRates[i].mMinimum;
            Float64 maximum = availableEncodeSampleRates[i].mMaximum;
            fprintf(stderr, "AudioMonitor2 kAudioConverterAvailableEncodeSampleRates Available Encode Sample Rates %d minimum=%f, maximum=%f\n", i, minimum,  maximum);
        }
        
        free(availableEncodeSampleRates);
    }
    else
    {
        fprintf(stderr, "AudioMonitor2 AudioConverterGetPropertyInfo kAudioConverterAvailableEncodeSampleRates error = %d\n", (int)getAvailableEncodeSampleRatesCountStatus);
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
            fprintf(stderr, "AudioMonitor2 AudioConverterGetPropertyInfo kAudioConverterChannelMap error = %d\n", (int)getAvailableBitratesCountStatus);
        }
        for (int i = 0; i < channelMappingCount; i++)
        {
            SInt32 value = channelMapping[i];
            fprintf(stderr, "AudioMonitor2 kAudioConverterChannelMap %d value=%d\n", i,  (int)value);
        }
    }
    else
    {
        fprintf(stderr, "AudioMonitor2 AudioConverterGetPropertyInfo kAudioConverterChannelMap error = %d\n", (int)channelMappingCountStatus);
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
            fprintf(stderr, "AudioMonitor2 AudioConverterGetPropertyInfo audioFormatListStatus error = %d\n", (int)audioFormatListStatus);
        }
        for (int i = 0; i < audioFormatListCount; i++)
        {
            AudioFormatListItem audioFormatListItem = audioFormatList[i];
            
            AudioStreamBasicDescription audioStreamBasicDescription = audioFormatListItem.mASBD;
            AudioChannelLayoutTag channelLayoutTag = audioFormatListItem.mChannelLayoutTag;
            
            logDescription(&audioStreamBasicDescription, "kAudioConverterPropertyFormatList");
            
            fprintf(stderr, "AudioMonitor2 kAudioConverterPropertyFormatList %d AudioChannelLayoutTag=%u\n", i,  (unsigned int)channelLayoutTag);
        }
    }
    else
    {
        fprintf(stderr, "AudioMonitor2 AudioConverterGetPropertyInfo kAudioConverterPropertyFormatList error = %d\n", (int)audioFormatListCountStatus);
    }

    // get property settings array
    OSStatus propertySettingsArrayCountStatus = AudioConverterGetPropertyInfo(inAudioConverter,
            kAudioConverterPropertySettings,
            &tmpsiz, NULL);
    if (propertySettingsArrayCountStatus == noErr)
    {
        if (tmpsiz != sizeof(CFArrayRef))
        {
            fprintf(stderr, "AudioMonitor2 AudioConverterGetPropertyInfo kAudioConverterPropertySettings CFArrayRef error\n");
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
                        fprintf(stderr, "AudioMonitor2 AudioConverterGetProperty kAudioConverterPropertySettings = \n%s\n", dictionaryCString);
                    }
                }
            }
        }
        else
        {
            fprintf(stderr, "AudioMonitor2 AudioConverterGetProperty kAudioConverterPropertySettings error = %d\n", (int)propertySettingsArrayStatus);
        }
    }
    else
    {
        fprintf(stderr, "AudioMonitor2 AudioConverterGetPropertyInfo kAudioConverterPropertySettings error = %d\n", (int)propertySettingsArrayCountStatus);
    }
}

//==================================================================================
//    runInputBufferOnThread()
//==================================================================================

void * runInputBufferOnThread(void * ptr)
{
    pthread_setname_np("runInputBufferOnThread");

    //pid_t originalParentProcessPID = getppid();

    // instead of silence, send some white noise when needed
    char whiteNoiseBuffer[maxWhiteNoiseBufferLength];
    for (int i = 0; i < maxWhiteNoiseBufferLength; i++)
    {
        // signed 16-bit white noise ---- 0, 1, 0, -1 ---- 0000 0001 0000 FFFF
        unsigned char whiteNoiseChar = 0;
        if (i % 8 == 3)
        {
            whiteNoiseChar = 1;
        }
        else if (i % 8 == 6)
        {
            whiteNoiseChar = 255;
        }
        else if (i % 8 == 7)
        {
            whiteNoiseChar = 255;
        }
        whiteNoiseBuffer[i] = whiteNoiseChar;
    }

    //CFTimeInterval inputTimeoutInterval = 0.025f;
    //CFTimeInterval inputTimeoutInterval = 20000.0f / sampleRate;
    CFTimeInterval inputTimeoutInterval = 6.0f;
    float whiteNoiseBufferLengthFloat = (float)sampleRate * (float)inputChannels * inputTimeoutInterval;
    int whiteNoiseBufferLength = whiteNoiseBufferLengthFloat;
    if (whiteNoiseBufferLength > maxWhiteNoiseBufferLength)
    {
        whiteNoiseBufferLength = maxWhiteNoiseBufferLength;
    }
    
    fprintf(stderr, "AudioMonitor2 runInputBufferOnThread inputTimeoutInterval=%f, whiteNoiseBufferLength=%d\n", inputTimeoutInterval, whiteNoiseBufferLength);

    int packetIndex = 0;
    int droppedIndex = 0;
    bool doExit = false;

    int32_t circularBufferLength = inputBufferSize;
    TPCircularBufferInit(&inputCircularBuffer, circularBufferLength);
    
    fprintf(stderr, "AudioMonitor2 runInputBufferOnThread inputCircularBuffer=%p, circularBufferLength = %d\n", &inputCircularBuffer, circularBufferLength);

    unsigned char * rtlsdrBuffer = (unsigned char *)malloc(circularBufferLength);
    
    UInt64 loopCount = 0;

    // continuous run loop
    while (doExit == false)
    {
        //fprintf(stderr, "AudioMonitor2 runInputBufferOnThread polling loop\n");
        
        CFRunLoopMode runLoopMode = kCFRunLoopDefaultMode;
        CFTimeInterval runLoopTimeInterval = 0.0025f;
        Boolean returnAfterSourceHandled = false;
        CFRunLoopRunResult runLoopResult = CFRunLoopRunInMode(runLoopMode, runLoopTimeInterval, returnAfterSourceHandled);
        #pragma unused(runLoopResult)

        //time_t currentTime = time(NULL);

        // copy RTL-SDR LPCM data to a circular buffer to be used as input for AudioConverter process
        
        UInt32 bytesAvailableCount = 0;
        
        // use ioctl to determine amount of data available for reading on stdin, like the RTL-SDR USB serial device
        int ioctl_result = ioctl(STDIN_FILENO, FIONREAD, &bytesAvailableCount);
        if (ioctl_result < 0)
        {
            fprintf(stderr, "AudioMonitor2 ioctl failed: %s\n", strerror(errno));
            doExit = true;
            break;
        }

        CFAbsoluteTime currentAbsoluteTime = CFAbsoluteTimeGetCurrent();

        if (bytesAvailableCount > 0)
        {
            if (bytesAvailableCount % (inputChannels * sizeof(SInt16)) == 0)    // check frame/packet size
            {
                memset(rtlsdrBuffer, 0, bytesAvailableCount);
                
                long readResult = read(STDIN_FILENO, rtlsdrBuffer, bytesAvailableCount);

                //fprintf(stderr, "AudioMonitor2 runInputBufferOnThread - read completed, bytesAvailableCount = %d\n", bytesAvailableCount);

                if (readResult <= 0)
                {
                    fprintf(stderr, "AudioMonitor2 runInputBufferOnThread error - read failed: %s\n", strerror(errno));
                    break;
                }
                else
                {
                    if (bytesAvailableCount != readResult)
                    {
                        fprintf(stderr, "AudioMonitor2 runInputBufferOnThread error - bytesAvailableCount=%d, readResult =%ld\n", bytesAvailableCount, readResult);
                    }
                
                    //fprintf(stderr, "AudioMonitor2 runInputBufferOnThread inputBufferPtr=%p, bytesAvailableCount=%d\n", headPtr, bytesAvailableCount);
                    
                    int32_t availableSpace = (inputCircularBuffer.length - inputCircularBuffer.fillCount);
                    
                    //fprintf(stderr, "AudioMonitor2 runInputBufferOnThread test, bytesAvailableCount = %d, availableSpace = %d\n", bytesAvailableCount, availableSpace);
                    
                    if (bytesAvailableCount > availableSpace)
                    {
                        // If we attempt to call TPCircularBufferProduceBytes now, it will terminate the process
                        // due to insufficient buffer space - but it's radio, so we'll drop this block of data,
                        // give the resampling process a chance to catch up, and continue playing.
                        
                        fprintf(stderr, "AudioMonitor2 runInputBufferOnThread error bytesAvailableCount=%d, availableSpace=%d, packetIndex=%d, droppedIndex=%d\n", bytesAvailableCount, availableSpace, packetIndex, droppedIndex);
                        
                        //sleep(1);

                        //TPCircularBufferClear(&inputCircularBuffer);      // this doesn't work
                        
                        droppedIndex++;
                    }
                    else
                    {
                        bool produceBytesResult = TPCircularBufferProduceBytes(&inputCircularBuffer, rtlsdrBuffer, bytesAvailableCount);

                        packetIndex++;      // actually more than one packet

                        lastValidPacketAbsoluteTime = CFAbsoluteTimeGetCurrent();

                        //fprintf(stderr, "AudioMonitor2 runInputBufferOnThread input received bytesAvailableCount=%d, currentAbsoluteTime=%f\n", bytesAvailableCount, currentAbsoluteTime);

                        if (produceBytesResult == false)
                        {
                            fprintf(stderr, "AudioMonitor2 runInputBufferOnThread error - produce bytes failed, bytesAvailableCount = %d, packetIndex = %d\n", bytesAvailableCount, packetIndex);

                            sleep(1);

                            TPCircularBufferClear(&inputCircularBuffer);
                        }
                    }
                }
            }
            else
            {
            }
        }

        // In scanning mode with squelch, we might not get continuous audio data,
        // so send some white noise periodically during long periods of silence
        if (currentAbsoluteTime - lastValidPacketAbsoluteTime >= inputTimeoutInterval)
        {
            bool produceBytesResult = TPCircularBufferProduceBytes(&inputCircularBuffer, &whiteNoiseBuffer, whiteNoiseBufferLength);

            fprintf(stderr, "AudioMonitor2 runInputBufferOnThread - write white noise - interval=%f, inputTimeoutInterval=%f, length=%d\n", currentAbsoluteTime - lastValidPacketAbsoluteTime, inputTimeoutInterval, whiteNoiseBufferLength);

            lastValidPacketAbsoluteTime = currentAbsoluteTime;
        }
        
        usleep(1000);
        
        loopCount++;
    }
    //pthread_exit(NULL);

    free(rtlsdrBuffer);

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
//    startAudioConverter()
//==================================================================================

void startAudioConverter()
{
    // Configure input and output AudioStreamBasicDescription (ADSB) for AudioConverter to resample PCM data to 48000 Hz
    
    memset(&audioConverterInputDescription, 0, sizeof(audioConverterInputDescription));
    
    audioConverterInputDescription.mSampleRate = sampleRate;     // default is 10000 Hz
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
    
    logDescription(&audioConverterInputDescription, "audioConverterInputDescription");
    
    // set output AudioStreamBasicDescription fields for stereo output
    
    //audioConverterOutputDescription = audioConverterInputDescription;
    memset(&audioConverterOutputDescription, 0, sizeof(audioConverterOutputDescription));

    audioConverterOutputDescription.mSampleRate = 48000;        // AudioMonitor2 always outputs 2 channels
    audioConverterOutputDescription.mFormatID = kAudioFormatLinearPCM;
    audioConverterOutputDescription.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
    audioConverterOutputDescription.mBytesPerPacket = sizeof(SInt16) * 2;
    audioConverterOutputDescription.mFramesPerPacket = 1;
    audioConverterOutputDescription.mBytesPerFrame = sizeof(SInt16) * 2;
    audioConverterOutputDescription.mChannelsPerFrame = 2;      // Currently, AudioMonitor2 always outputs 2 channels
    audioConverterOutputDescription.mBitsPerChannel = sizeof(SInt16) * 8;
    
    logDescription(&audioConverterOutputDescription, "audioConverterOutputDescription");

    OSStatus audioConverterNewStatus = AudioConverterNew(&audioConverterInputDescription, &audioConverterOutputDescription, &inAudioConverter);
    if (audioConverterNewStatus != noErr)
    {
        fprintf(stderr, "AudioMonitor2 audioConverterNewStatus audioConverterNewStatus %d\n", audioConverterNewStatus);
    }

    audioConverterOutputBufferPtr = calloc(1, audioConverterBufferSize);

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
    UInt32 requestedNumberDataPackets = *ioNumberDataPackets;

    //fprintf(stderr, "AudioMonitor2 audioConverterComplexInputDataProc ioNumberDataPackets = %d, inputBufferDataLength = %d\n", *ioNumberDataPackets, fillComplexInputParam->inputBufferDataLength);

    if (fillComplexInputParam->inputBufferDataLength <= 0)
    {
        *ioNumberDataPackets = 0;
        return 'zero';    // done for now, earlier packets may exist in the buffer ready for use
    }

    OSStatus result = noErr;
    
    UInt32  availableNumberPackets = fillComplexInputParam->inputBufferDataLength / (fillComplexInputParam->inputChannels * sizeof(SInt16));
    
    UInt32 producedNumberPackets = availableNumberPackets;
    
    if (requestedNumberDataPackets < availableNumberPackets)
    {
        producedNumberPackets = requestedNumberDataPackets;
    }

    *ioNumberDataPackets = producedNumberPackets;
    
    // calculate new buffer pointer and data length for remaining data
    
    UInt32  producedPacketBytes = producedNumberPackets * fillComplexInputParam->inputChannels * sizeof(SInt16);

    ioData->mNumberBuffers = 1;
    ioData->mBuffers[0].mData = fillComplexInputParam->inputBufferPtr;
    ioData->mBuffers[0].mDataByteSize = producedPacketBytes;
    ioData->mBuffers[0].mNumberChannels =  fillComplexInputParam->inputChannels;

    fillComplexInputParam->inputBufferPtr = (void *)((UInt64)fillComplexInputParam->inputBufferPtr + producedPacketBytes);
    fillComplexInputParam->inputBufferDataLength = fillComplexInputParam->inputBufferDataLength - (UInt32)producedPacketBytes;
    
    //fprintf(stderr, "AudioMonitor2 - audioConverterComplexInputDataProc ioNumberDataPacketsRequested=%u, ioNumberDataPacketsProduced=%u,  result=%d\n", ioNumberDataPacketsRequested, ioNumberDataPacketsProduced, result);

    return result;
}

//==================================================================================
//    convertBuffer()
//==================================================================================

bool isAudioDataStarted(void * convertedDataPtr, UInt32 convertedDataLength)
{
    bool result = true;
    
    if (packetOutputIndex == 0)
    {
        bool dataFound = false;
        for (int i = 0; i < convertedDataLength; i++)
        {
            UInt8 * bytePtr = (UInt8 *)((UInt64)convertedDataPtr + i);
            if (*bytePtr != 0)
            {
                dataFound = true;
                break;
            }
        }
        
        result = dataFound;
    }
    
    return result;
}

//==================================================================================
//    convertBuffer()
//==================================================================================

void convertBuffer(void * inputBufferPtr, unsigned int dataLength)
{
    // use AudioConverter to resample PCM audio data from the RTL-SDR device sampling rate to 48000 Hz

    //fprintf(stderr, "AudioMonitor2 convertBuffer inputBufferPtr=%p, dataLength=%d\n", (void *)inputBufferPtr, dataLength);

    if (dataLength >= (1024 * audioConverterInputDescription.mChannelsPerFrame * sizeof(SInt16)))
    {
        const UInt32 numFrames = dataLength / (sizeof(SInt16) * audioConverterInputDescription.mChannelsPerFrame);

        audioConverterInputAudioBuffer.mNumberChannels = audioConverterInputDescription.mChannelsPerFrame;
        audioConverterInputAudioBuffer.mDataByteSize = (SInt32)dataLength;
        audioConverterInputAudioBuffer.mData = (void *)inputBufferPtr;

        FillComplexInputParam fillComplexInputParam;
        fillComplexInputParam.inputBufferPtr = inputBufferPtr;
        fillComplexInputParam.inputBufferDataLength = dataLength;
        fillComplexInputParam.inputChannels = inputChannels;
        fillComplexInputParam.packetDescription = NULL;

        audioConverterOutputBytes = numFrames * sizeof(SInt16) * audioConverterOutputDescription.mChannelsPerFrame;

        audioConverterOutputBufferList.mNumberBuffers = 1;
        audioConverterOutputBufferList.mBuffers[0].mNumberChannels = audioConverterOutputDescription.mChannelsPerFrame;
        audioConverterOutputBufferList.mBuffers[0].mDataByteSize = audioConverterOutputBytes;
        audioConverterOutputBufferList.mBuffers[0].mData = audioConverterOutputBufferPtr;

        UInt32 outputDataPacketSize = numFrames;    // on entry, max packets capacity
        
        //fprintf(stderr, "AudioMonitor2 convertBuffer numFrames=%d, remain=%d\n", numFrames, audioConverterInputPacketsRemain);

        OSStatus convertResult = noErr;
        
        while (convertResult == noErr)  // this loop will iterate for upsampling cases, e.g. 10000 to 48000
        {
            convertResult = AudioConverterFillComplexBuffer(
                    inAudioConverter,      // AudioConverterRef inAudioConverter
                    audioConverterComplexInputDataProc, // AudioConverterComplexInputDataProc inInputDataProc
                    &fillComplexInputParam,  // void *inInputDataProcUserData
                    &outputDataPacketSize, // UInt32 *ioOutputDataPacketSize - entry: max packets capacity, exit: number of packets converted
                    &audioConverterOutputBufferList,     // AudioBufferList *outOutputData
                    NULL                   // AudioStreamPacketDescription *outPacketDescription
                    );
        
            //fprintf(stderr, "AudioMonitor2 convertBuffer AudioConverterFillComplexBuffer result = %d, outputDataPacketSize = %d\n", convertResult, outputDataPacketSize);
            
            if ((convertResult == noErr) || (convertResult == 'zero'))
            {
                if (outputDataPacketSize > 0)   // number of packets converted
                {
                    // produce resampled audio to second circular buffer for speaker output via AudioQueue
                    
                    int32_t convertedDataLength = outputDataPacketSize * sizeof(SInt16) * audioConverterOutputBufferList.mBuffers[0].mNumberChannels;

                    void * convertedDataPtr = audioConverterOutputBufferList.mBuffers[0].mData;
                    
                    if (isAudioDataStarted(convertedDataPtr, convertedDataLength) == true)
                    {
                        int32_t availableSpace;
                        void * headPtr = TPCircularBufferHead(&audioConverterCircularBuffer, &availableSpace);  // for fprintf to stderr below
                        int64_t bufferFilledSize = (int64_t)headPtr - (int64_t)inputBufferPtr;
                        
                        if (availableSpace < convertedDataLength)
                        {
                            sleep(1);
                        }

                        fwrite(convertedDataPtr, convertedDataLength, 1, stdout);    // write resampled audio to stdout, can be piped to sox, etc.
                        
                        fflush(stdout);

                        /*
                        if (packetOutputIndex == 0)
                        {
                            logHexData(convertedDataPtr, convertedDataLength);
                        }
                        */
                        
                        packetOutputIndex++;

                        //fprintf(stderr, "AudioMonitor2 convertBuffer convertedDataLength = %d, space = %d, head = %p, bufferFilledSize = %lld\n", convertedDataLength, space, headPtr, bufferFilledSize);
                        
                        if (volume > 0.0)
                        {
                            // we are playing directly to the speakers
                            
                            bool  produceBytesResult = TPCircularBufferProduceBytes(&audioConverterCircularBuffer, convertedDataPtr, convertedDataLength);  // store for use by AudioQueue

                            if (produceBytesResult == false)
                            {
                                produceBytesResult = TPCircularBufferProduceBytes(&audioConverterCircularBuffer, convertedDataPtr, convertedDataLength);    // why not try again?

                                if (produceBytesResult == false)
                                {
                                    // If we get here, packets will be dropped
                                    
                                    fprintf(stderr, "AudioMonitor2 convertBuffer failed, drop packet, convertedDataLength = %d, availableSpace = %d, head = %p, bufferFilledSize = %lld\n", convertedDataLength, availableSpace, headPtr, bufferFilledSize);
                                }
                            }
                        }
                        else
                        {
                            usleep(2000);
                        }
                    }
                }
                else
                {
                    usleep(2000);
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
        
                fprintf(stderr, "AudioMonitor2 convertBuffer convertResult=%d %s\n", convertResult, c);
                AudioConverterReset(inAudioConverter);
            }
        }
    }
}

//==================================================================================
//    runAudioConverterOnThread()
//==================================================================================

void * runAudioConverterOnThread(void * ptr)
{
    // the main loop for resampling - convert the LPCM input to 48000 Hz sample rate
    pthread_setname_np("runAudioConverterOnThread");

    //sleep(1); // allow time for input thread to startup

    //pid_t originalParentProcessPID = getppid();
    
    bool doExit = false;

    time_t lastReadTime = time(NULL) + 20;
    int nextTimeoutReportInterval = 5;

    int32_t circularBufferLength = audioConverterBufferSize;
    TPCircularBufferInit(&audioConverterCircularBuffer, circularBufferLength);

    fprintf(stderr, "AudioMonitor2 runAudioConverterOnThread circularBufferLength = %d\n", circularBufferLength);

    startAudioConverter();     // resample PCM data to 48000 Hz

    // continuous run loop
    while (doExit == false)
    {
        //fprintf(stderr, "AudioMonitor2 runAudioConverterOnThread polling loop\n");

        CFRunLoopMode runLoopMode = kCFRunLoopDefaultMode;
        CFTimeInterval runLoopTimeInterval = 0.00125f;
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
            fprintf(stderr, "AudioMonitor2 runAudioConverterOnThread runLoopResult %s\n", runLoopResultString);
        }

        time_t currentTime = time(NULL);

        int32_t bytesAvailableCount = 0;

        void * circularBufferDataPtr = TPCircularBufferTail(&inputCircularBuffer, &bytesAvailableCount);    // get pointer to read buffer

        if( bytesAvailableCount <= 0)
        {
            usleep(1000);
        }
        else
        {
            if ((bytesAvailableCount > 1024) && (bytesAvailableCount % (inputChannels * sizeof(SInt16)) == 0))
            {
                lastReadTime = currentTime;
                nextTimeoutReportInterval = 5;
                
                //fprintf(stderr, "AudioMonitor2 runAudioConverterOnThread polling loop\n");
                
                int32_t bytesConsumedCount = bytesAvailableCount;

                int32_t maxBytes = 1024 * inputChannels * sizeof(SInt16);

                if (bytesConsumedCount > maxBytes)
                {
                    bytesConsumedCount = maxBytes;
                }
                
                // assure packet boundaries
                int32_t fullPackets = bytesConsumedCount / (inputChannels * sizeof(SInt16));
                bytesConsumedCount = fullPackets * (inputChannels * sizeof(SInt16));

                convertBuffer(circularBufferDataPtr, bytesConsumedCount);

                //fprintf(stderr, "AudioMonitor2 runAudioConverterOnThread - Consume bytesAvailableCount = %d, circularBufferDataPtr = %p\n", bytesAvailableCount, circularBufferDataPtr);

                TPCircularBufferConsume(&inputCircularBuffer, bytesConsumedCount);
            }
            else
            {
                // data size is not an integral multiple of frame size
            }
        }

        time_t intervalSinceLastRead = currentTime - lastReadTime;
        if (intervalSinceLastRead >= nextTimeoutReportInterval)
        {
            fprintf(stderr, "AudioMonitor2 runAudioConverterOnThread intervalSinceLastRead >= %d\n", nextTimeoutReportInterval);

            nextTimeoutReportInterval += 30;
        }
    }
    //pthread_exit(NULL);

    free(audioConverterOutputBufferPtr);
    audioConverterOutputBufferPtr = NULL;

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
//    audioQueueCallback()
//==================================================================================

void audioQueueCallback(void *custom_data, AudioQueueRef queue, AudioQueueBufferRef buffer)
{
    // called by AudioQueue to fill a buffer for rendering to default output device
    // the 48000 Hz PCM audio output of the AudioConvert process is used as input here
    
    //UInt32 audioQueueDataByteSize = buffer->mAudioDataByteSize;
    UInt32 audioQueueDataBytesCapacity = buffer->mAudioDataBytesCapacity;

    // get pointer to resampled LPCM data for reading
    int32_t availableBytes = 0;
    void * circularBufferDataPtr = TPCircularBufferTail(&(audioConverterCircularBuffer), &availableBytes);

    //fprintf(stderr, "AudioMonitor2 audioQueueCallback buffer=%p, availableBytes=%d, audioQueueDataBytesCapacity=%u\n", buffer, availableBytes, audioQueueDataBytesCapacity);

    if (availableBytes > 0)
    {
        int outputBytes = availableBytes;

        if (outputBytes > audioQueueDataBytesCapacity)
        {
            outputBytes = audioQueueDataBytesCapacity;
        }

        int samplesCount = outputBytes / sizeof(SInt16);

        SInt16 * sourcePtr = (SInt16 *)circularBufferDataPtr;
        SInt16 * destinationPtr = (SInt16 *)buffer->mAudioData;

        for (int i = 0; i < samplesCount; i++)
        {
            SInt16 channelSample = *sourcePtr;
            sourcePtr++;
            
            *destinationPtr = channelSample;
            destinationPtr++;
        }
        
        buffer->mAudioDataByteSize = outputBytes;
        
        if (volume > 0.0f)
        {
            // output resampled audio to the current system device
            OSStatus queueEnqueueStatus = AudioQueueEnqueueBuffer(queue, buffer, 0, NULL);
            if (queueEnqueueStatus != noErr)
            {
                fprintf(stderr, "AudioMonitor2 audioQueueCallback data queueEnqueueStatus %d\n", queueEnqueueStatus);
            }
        }

        //fprintf(stderr, "AudioMonitor2 audioQueueCallback - Consume availableBytes = %d, circularBufferDataPtr = %p\n", availableBytes, circularBufferDataPtr);

        //TPCircularBufferConsume(&audioConverterCircularBuffer, availableBytes);
        TPCircularBufferConsume(&audioConverterCircularBuffer, outputBytes);
    }
    else
    {
        // no data available in circular buffer, so output some packets of silence
        
        fprintf(stderr, "AudioMonitor2 audioQueueCallback - no input data available, output silence\n");
        //buffer->mAudioDataByteSize = 128 * sizeof(SInt16) * 2;      // 128 frames * 2 bytes per packet * 2 packets per frame
        buffer->mAudioDataByteSize = audioQueueDataBytesCapacity;

        memset(buffer->mAudioData, 0, buffer->mAudioDataByteSize);

        if (volume > 0.0f)
        {
            // output silent audio to the current system device
            OSStatus queueEnqueueStatus = AudioQueueEnqueueBuffer(queue, buffer, 0, NULL);
            if (queueEnqueueStatus != noErr)
            {
                fprintf(stderr, "AudioMonitor2 audioQueueCallback silence queueEnqueueStatus %d\n", queueEnqueueStatus);
            }
        }
    }
}

//==================================================================================
//    runAudioQueueOnThread()
//==================================================================================

void * runAudioQueueOnThread(void * ptr)
{
    pthread_setname_np("AudioMonitor2 runAudioQueueOnThread");

    sleep(1);     // allow time for startup

    if (volume > 0.0f)
    {
        // configure AudioQueue for rendering PCM audio data to default output device (i.e., speakers).

        audioQueueIndex = 0;

        unsigned int i;
        
        audioQueueDescription.mSampleRate       = 48000;
        audioQueueDescription.mFormatID         = kAudioFormatLinearPCM;
        
        audioQueueDescription.mFormatFlags      = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
        
        audioQueueDescription.mBitsPerChannel   = 8 * sizeof(SInt16);
        audioQueueDescription.mChannelsPerFrame = 2;
        audioQueueDescription.mBytesPerFrame    = sizeof(SInt16) * 2;
        audioQueueDescription.mFramesPerPacket  = 1;
        audioQueueDescription.mBytesPerPacket   = audioQueueDescription.mBytesPerFrame * audioQueueDescription.mFramesPerPacket;
        audioQueueDescription.mReserved         = 0;

        fprintf(stderr, "AudioMonitor2 runAudioQueueOnThread audioQueueBufferSize = %d\n", audioQueueBufferSize);
        logDescription(&audioQueueDescription, "audioQueueFormat");
        
        OSStatus newQueueOutputStatus = AudioQueueNewOutput(&audioQueueDescription, audioQueueCallback, NULL, CFRunLoopGetCurrent(), kCFRunLoopCommonModes, 0, &audioQueue);
        if (newQueueOutputStatus != noErr)
        {
            fprintf(stderr, "AudioMonitor2 runAudioQueueOnThread newQueueOutputStatus %d\n", newQueueOutputStatus);
        }

        // AudioQueue values for audio device output

        //UInt32 audioQueueBufferSize = 65536 * sizeof(SInt16) * 8;     // replace by global var

        for (i = 0; i < kAudioQueueBuffersCount; i++)
        {
            OSStatus queueAllocateStatus = AudioQueueAllocateBuffer(audioQueue, audioQueueBufferSize, &buffers[i]);
            if (queueAllocateStatus != noErr)
            {
                fprintf(stderr, "AudioMonitor2 runAudioQueueOnThread queueAllocateStatus %d\n", queueAllocateStatus);
            }

            buffers[i]->mAudioDataByteSize = audioQueueBufferSize;
            
            audioQueueCallback(NULL, audioQueue, buffers[i]);
        }
        
        UInt32 inNumberOfFramesToPrepare = 0;   // decode all enqueued buffers
        UInt32 outNumberOfFramesPrepared = 0;
        
        OSStatus queuePrimeStatus = AudioQueuePrime(audioQueue, inNumberOfFramesToPrepare, &outNumberOfFramesPrepared);
        if (queuePrimeStatus != noErr)
        {
            fprintf(stderr, "AudioMonitor2 runAudioQueueOnThread queuePrimeStatus %d\n", queuePrimeStatus);
        }
        
        OSStatus queueStartStatus = AudioQueueStart(audioQueue, NULL);
        if (queueStartStatus != noErr)
        {
            fprintf(stderr, "AudioMonitor2 runAudioQueueOnThread queueStartStatus %d\n", queueStartStatus);
        }
    }
    
    do {
        CFRunLoopRunInMode (kCFRunLoopDefaultMode, 0.25, false);
        usleep(5000);
    } while (true);

    //pthread_exit(NULL);

    return NULL;
}

//==================================================================================
//    createAudioQueueThread()
//==================================================================================

void createAudioQueueThread()
{
    pthread_attr_t attr; /* set of thread attributes */
    pthread_attr_init(&attr);

    int audioQueueThreadErr;
    audioQueueThreadErr = pthread_create(&audioQueueThreadID, &attr, &runAudioQueueOnThread, NULL);
    pthread_detach(audioQueueThreadID);
}

//==================================================================================
//    runAudioMonitor2()
//==================================================================================

void runAudioMonitor2(unsigned int inSampleRate, double inVolume, unsigned int inChannels, unsigned int inInputBufferSize, unsigned int inAudioConverterBufferSize, unsigned int inAudioQueueBufferSize)
{
    //raise(SIGSTOP); // Stop and wait for debugger. Click the Debugger's Resume button to continue execution
    
    sampleRate = inSampleRate;
    volume = inVolume;
    inputChannels = inChannels;
    inputBufferSize = inInputBufferSize;
    audioConverterBufferSize = inAudioConverterBufferSize * 2;
    audioQueueBufferSize = inAudioQueueBufferSize;
    
    fprintf(stderr, "AudioMonitor2 sampleRate=%d, inputChannels=%d, inputBufferSize=%d, audioConverterBufferSize=%d, audioQueueBufferSize=%d/n", sampleRate, inputChannels, inputBufferSize, audioConverterBufferSize, inAudioQueueBufferSize);

    // start threads for input buffering, resampling and playback to audio device
    inputBufferThreadID = 0;
    audioConverterThreadID = 0;
    audioQueueThreadID = 0;
    
    packetOutputIndex = 0;
    lastValidPacketAbsoluteTime = CFAbsoluteTimeGetCurrent();

    createInputBufferThread();
    usleep(5000);
    createAudioConverterThread();
    createAudioQueueThread();
}


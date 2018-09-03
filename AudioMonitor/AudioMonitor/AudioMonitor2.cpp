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


AudioBuffer audioConverterInputAudioBuffer;
UInt64 audioConverterInputBufferOffset;
UInt32 audioConverterInputPacketsRemain;

pthread_t inputBufferThreadID;
pthread_t audioConverterThreadID;
pthread_t audioQueueThreadID;

void createAudioConverterThread();
void createAudioQueueThread();

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
    int32_t circularBufferLength = inputBufferSize;
    TPCircularBufferInit(&inputCircularBuffer, circularBufferLength);
    
    fprintf(stderr, "AudioMonitor2 runInputBufferOnThread circularBufferLength = %d\n", circularBufferLength);
    
    // continuous run loop
    while (doExit == false)
    {
        //fprintf(stderr, "AudioMonitor runInputBufferOnThread polling loop\n");
        
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
            fprintf(stderr, "AudioMonitor2 ioctl failed: %s\n", strerror(errno));
            doExit = true;
            break;
        }

        if (bytesAvailableCount <= 0)
        {
            usleep(10000);
        }
        else
        {
            if (bytesAvailableCount % (inputChannels * sizeof(SInt16)) == 0)
            {
                unsigned char * rtlsdrBuffer = (unsigned char *)malloc(bytesAvailableCount);
                
                if (rtlsdrBuffer != NULL)
                {
                    memset(rtlsdrBuffer, 0, bytesAvailableCount);
                    
                    long readResult = read( STDIN_FILENO, rtlsdrBuffer, bytesAvailableCount);

                    //fprintf(stderr, "AudioMonitor2 runInputBufferOnThread - read completed, bytesAvailableCount = %d\n", bytesAvailableCount);

                    if (readResult <= 0)
                    {
                        fprintf(stderr, "AudioMonitor2 read failed: %s\n", strerror(errno));
                        break;
                    }
                    else
                    {
                        lastReadTime = currentTime;
                        nextTimeoutReportInterval = 5;
                        
                        // copy RTL-SDR LPCM data to a circular buffer to be used as input for AudioConverter process
                        
                        bool produceBytesResult = TPCircularBufferProduceBytes(&inputCircularBuffer, rtlsdrBuffer, bytesAvailableCount);
                        
                        if (produceBytesResult == false)
                        {
                            TPCircularBufferClear(&inputCircularBuffer);

                            fprintf(stderr, "AudioMonitor2 runInputBufferOnThread - produce bytes failed, bytesAvailableCount = %d\n", bytesAvailableCount);
                        }
                        else
                        {
                            if (audioConverterThreadID == 0)
                            {
                                //createAudioConverterThread();
                            }
                        }
                    }
                    
                    free(rtlsdrBuffer);
                }
                else
                {
                    fprintf(stderr, "AudioMonitor2 runInputBufferOnThread - rtlsdrBuffer allocation failed - rtlsdrBuffer=%d\n", bytesAvailableCount);
                }
            }
            else
            {
                fprintf(stderr, "AudioMonitor2 bytesAvailableCount %d misaligned for packet size\n", bytesAvailableCount);
            }
        }

        time_t intervalSinceLastRead = currentTime - lastReadTime;
        if (intervalSinceLastRead >= nextTimeoutReportInterval)
        {
            fprintf(stderr, "AudioMonitor2 intervalSinceLastRead >= %d\n", nextTimeoutReportInterval);

            nextTimeoutReportInterval += 5;
        }
        
        packetIndex++;
    }
    //pthread_exit(NULL);
    
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

    audioConverterOutputDescription.mSampleRate = 48000;
    audioConverterOutputDescription.mFormatID = kAudioFormatLinearPCM;
    audioConverterOutputDescription.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
    audioConverterOutputDescription.mBytesPerPacket = sizeof(SInt16) * 2;
    audioConverterOutputDescription.mFramesPerPacket = 1;
    audioConverterOutputDescription.mBytesPerFrame = sizeof(SInt16) * 2;
    audioConverterOutputDescription.mChannelsPerFrame = 2;
    audioConverterOutputDescription.mBitsPerChannel = sizeof(SInt16) * 8;
    
    logDescription(&audioConverterOutputDescription, "audioConverterOutputDescription");

    OSStatus audioConverterNewStatus = AudioConverterNew(&audioConverterInputDescription, &audioConverterOutputDescription, &inAudioConverter);
    if (audioConverterNewStatus != noErr)
    {
        fprintf(stderr, "AudioMonitor2 audioConverterNewStatus audioConverterNewStatus %d\n", audioConverterNewStatus);
    }
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
    // This is the AudioConverterComplexInputDataProc for resampling the radio audio data from a specified sampling rate to 48000 Hz
    
    OSStatus result = noErr;

    // this can get called multiple times from AudioConverterFillComplexBuffer, and needs to manage short blocks.
    if (ioDataPacketDescription != NULL)
    {
        fprintf(stderr, "AudioMonitor - audioConverterComplexInputDataProc ioDataPacketDescription not available\n");
        *ioDataPacketDescription = NULL;
        *ioNumberDataPackets = 0;
        ioData->mNumberBuffers = 0;
        return 501;
    }
    
    UInt32 ioNumberDataPacketsRequested = *ioNumberDataPackets;

    UInt32 ioNumberDataPacketsProduced = ioNumberDataPacketsRequested;
    if (ioNumberDataPacketsProduced > audioConverterInputPacketsRemain)
    {
        ioNumberDataPacketsProduced = audioConverterInputPacketsRemain;
    }

    void * offsetPtr = (char *)audioConverterInputAudioBuffer.mData + audioConverterInputBufferOffset;
    
    ioData->mNumberBuffers = 1;
    ioData->mBuffers[0].mNumberChannels =  inputChannels;
    ioData->mBuffers[0].mDataByteSize = ioNumberDataPacketsProduced * sizeof(SInt16) * inputChannels;
    ioData->mBuffers[0].mData = offsetPtr;

    *ioNumberDataPackets = ioNumberDataPacketsProduced;
    
    if (ioNumberDataPacketsProduced == 0)
    {
        result = 'zero';
    }
    else
    {
        // for testing breakpoint here
    }
    
    audioConverterInputBufferOffset += (ioNumberDataPacketsProduced * sizeof(SInt16) * inputChannels);
    audioConverterInputPacketsRemain -= ioNumberDataPacketsProduced;
    
    //fprintf(stderr, "AudioMonitor - audioConverterComplexInputDataProc ioNumberDataPacketsRequested=%u, ioNumberDataPacketsProduced=%u,  result=%d\n", ioNumberDataPacketsRequested, ioNumberDataPacketsProduced, result);

    return result;
}

//==================================================================================
//    convertBuffer()
//==================================================================================

void convertBuffer(void * inputBufferPtr, unsigned int dataLength)
{
    // use AudioConverter to resample PCM audio data from the RTL-SDR device sampling rate to 48000 Hz
    
    if (dataLength > 0)
    {
        const UInt32 numFrames = dataLength / (sizeof(SInt16) * audioConverterInputDescription.mChannelsPerFrame);

        audioConverterInputAudioBuffer.mNumberChannels = audioConverterInputDescription.mChannelsPerFrame;
        audioConverterInputAudioBuffer.mDataByteSize = (SInt32)dataLength;
        audioConverterInputAudioBuffer.mData = (void *)inputBufferPtr;

        audioConverterInputBufferOffset = 0;
        audioConverterInputPacketsRemain = numFrames;
        
        audioConverterOutputBufferPtr = calloc(numFrames, sizeof(SInt16) * audioConverterOutputDescription.mChannelsPerFrame);
        audioConverterOutputBytes = numFrames * sizeof(SInt16) * audioConverterOutputDescription.mChannelsPerFrame;

        audioConverterOutputBufferList.mNumberBuffers = 1;
        audioConverterOutputBufferList.mBuffers[0].mNumberChannels = audioConverterOutputDescription.mChannelsPerFrame;
        audioConverterOutputBufferList.mBuffers[0].mDataByteSize = audioConverterOutputBytes;
        audioConverterOutputBufferList.mBuffers[0].mData = audioConverterOutputBufferPtr;

        UInt32 outputDataPacketSize = numFrames;    // on entry, max packets capacity

        //fprintf(stderr, "AudioMonitor convertBuffer numFrames=%d, remain=%d\n", numFrames, audioConverterInputPacketsRemain);

        // for up-sampling (e.g., 10000 Hz to 41000 Hz), use multiple calls to AudioConverterFillComplexBuffer
        // in a loop here and check result for exit condition 'zero' indicating end of input buffer.
        // Down-sampling (e.g. 85000 Hz to 10000 Hz) seems to get the buffer processed without the loop.

        OSStatus convertResult = noErr;
        
        while (convertResult == noErr)
        {
            convertResult = AudioConverterFillComplexBuffer(
                    inAudioConverter,      // AudioConverterRef inAudioConverter
                    audioConverterComplexInputDataProc, // AudioConverterComplexInputDataProc inInputDataProc
                    NULL,  // void *inInputDataProcUserData
                    &outputDataPacketSize, // UInt32 *ioOutputDataPacketSize - entry: max packets capacity, exit: number of packets converted
                    &audioConverterOutputBufferList,     // AudioBufferList *outOutputData
                    NULL                   // AudioStreamPacketDescription *outPacketDescription - not applicable for PCM?
                    );
            
            //fprintf(stderr, "AudioMonitor convertBuffer AudioConverterFillComplexBuffer result = %d, outputDataPacketSize = %d\n", convertResult, outputDataPacketSize);

            if (outputDataPacketSize > 0)   // number of packets converted
            {
                // produce resampled audio to second circular buffer
                
                int32_t convertedDataLength = outputDataPacketSize * sizeof(SInt16) * 2;

                void * convertedDataPtr = audioConverterOutputBufferList.mBuffers[0].mData;

                int32_t space;
                void *ptr = TPCircularBufferHead(&audioConverterCircularBuffer, &space);  // for fprintf to stderr below

                fwrite(convertedDataPtr, 1, convertedDataLength, stdout);    // write resampled audio to stdout, can be piped to sox, etc.
                
                bool  produceBytesResult = TPCircularBufferProduceBytes(&audioConverterCircularBuffer, convertedDataPtr, convertedDataLength);

                if (produceBytesResult == false)
                {
                    // TODO: We are here to avoid buffer overrun, is TPCircularBufferConsume for audioConverterCircularBuffer getting missed somewhere?
                
                    // clear buffer and try again (not recommended practice)
                    TPCircularBufferClear(&(audioConverterCircularBuffer));
                    
                    produceBytesResult = TPCircularBufferProduceBytes(&audioConverterCircularBuffer, convertedDataPtr, convertedDataLength);

                    if (produceBytesResult == false)
                    {
                        // If we get here, packets will be dropped
                    
                        fprintf(stderr, "AudioMonitor convertBuffer Produce convertedDataLength = %d, space = %d, head = %p\n", convertedDataLength, space, ptr);
                        fprintf(stderr, "AudioMonitor convertBuffer - produce bytes failed, convertedDataLength = %d\n", convertedDataLength);
                    }
                }
                
                if (audioQueueThreadID == 0)
                {
                    //createAudioQueueThread();
                }
            }

            if (convertResult != noErr)
            {
                if (convertResult != 'zero')
                {
                    fprintf(stderr, "AudioMonitor convertResult=%d\n", convertResult);
                    AudioConverterReset(inAudioConverter);
                }
            }
        }
        
        free(audioConverterOutputBufferPtr);
        audioConverterOutputBufferPtr = NULL;
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

    //int32_t circularBufferLength = inputChannels * bufferKBPerChannel * 1024;
    int32_t circularBufferLength = audioConverterBufferSize;
    TPCircularBufferInit(&audioConverterCircularBuffer, circularBufferLength);

    fprintf(stderr, "AudioMonitor runAudioConverterOnThread circularBufferLength = %d\n", circularBufferLength);

    startAudioConverter();     // resample PCM data to 48000 Hz

    // continuous run loop
    while (doExit == false)
    {
        //fprintf(stderr, "AudioMonitor runAudioConverterOnThread polling loop\n");

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
            fprintf(stderr, "AudioMonitor runAudioConverterOnThread runLoopResult %s\n", runLoopResultString);
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
            //if (bytesAvailableCount % sizeof(SInt16) == 0)
            {
                lastReadTime = currentTime;
                nextTimeoutReportInterval = 5;
                
                //fprintf(stderr, "AudioMonitor runAudioConverterOnThread polling loop\n");

                convertBuffer(circularBufferDataPtr, bytesAvailableCount);

                //fprintf(stderr, "AudioMonitor runAudioConverterOnThread - Consume bytesAvailableCount = %d, circularBufferDataPtr = %p\n", bytesAvailableCount, circularBufferDataPtr);

                TPCircularBufferConsume(&inputCircularBuffer, bytesAvailableCount);
            }
            else
            {
                // data size is not an integral multiple of frame size
            }
        }

        time_t intervalSinceLastRead = currentTime - lastReadTime;
        if (intervalSinceLastRead >= nextTimeoutReportInterval)
        {
            fprintf(stderr, "AudioMonitor intervalSinceLastRead >= %d\n", nextTimeoutReportInterval);

            nextTimeoutReportInterval += 5;
        }
    }
    //pthread_exit(NULL);

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

    //fprintf(stderr, "AudioMonitor audioQueueCallback buffer=%p, availableBytes=%d, audioQueueDataBytesCapacity=%u\n", buffer, availableBytes, audioQueueDataBytesCapacity);

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

        //fprintf(stderr, "AudioMonitor audioQueueCallback - Consume availableBytes = %d, circularBufferDataPtr = %p\n", availableBytes, circularBufferDataPtr);

        //TPCircularBufferConsume(&audioConverterCircularBuffer, availableBytes);
        TPCircularBufferConsume(&audioConverterCircularBuffer, outputBytes);
    }
    else
    {
        // no data available in circular buffer, so output some packets of silence
        
        fprintf(stderr, "AudioMonitor audioQueueCallback - no input data available, output silence\n");
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

    sleep(3);     // allow time for startup

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
//    runAudioMonitor()
//==================================================================================

void runAudioMonitor(unsigned int inSampleRate, double inVolume, unsigned int inChannels, unsigned int inInputBufferSize, unsigned int inAudioConverterBufferSize, unsigned int inAudioQueueBufferSize)
{
    //raise(SIGSTOP); // Stop and wait for debugger. Click the Debugger's Resume button to continue execution
    
    sampleRate = inSampleRate;
    volume = inVolume;
    inputChannels = inChannels;
    inputBufferSize = inInputBufferSize;
    audioConverterBufferSize = inAudioConverterBufferSize;
    audioQueueBufferSize = inAudioQueueBufferSize;

    // start threads for input buffering, resampling and playback to audio device
    inputBufferThreadID = 0;
    audioQueueThreadID = 0;
    audioConverterThreadID = 0;

    createInputBufferThread();
    createAudioConverterThread();
    createAudioQueueThread();
}


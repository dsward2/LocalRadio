//
//  AudioMonitor.m
//  AudioMonitor
//
//  Created by Douglas Ward on 8/28/17.
//  Copyright © 2017 ArkPhone LLC. All rights reserved.
//

//  Use AudioConverter to resample audio to 48000 Hz, store in ring buffer,
//  then provide data to AudioQueue to play with default audio device.

//  Apparently, this code violates every rule listed here:
//  http://atastypixel.com/blog/four-common-mistakes-in-audio-development/


#import "AudioMonitor.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AudioToolbox/AudioConverter.h>

#include <sys/select.h>
#include <sys/ioctl.h>

#include <errno.h>
#include <signal.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>


#define kInputMaxPackets (4 * 1024)
#define kAudioQueueChannelsCount 1
#define kAudioQueueSampleRate 48000

#define kInputPacketLength sizeof(SInt16)
//#define kInputBufferLength (kInputMaxPackets * kInputPacketLength)

//#define kOutputPacketLength sizeof(SInt16)
//#define kOutputBufferLength (kInputMaxPackets * kOutputPacketLength)

#define kAudioQueueBufferSize (kInputMaxPackets * sizeof(SInt16) * 2)

@interface AudioMonitor ()
@end

@implementation AudioMonitor



- (void)dealloc
{
    AudioQueueStop(audioQueue, false);
    AudioQueueDispose(audioQueue, false);
    
    TPCircularBufferCleanup(&inputCircularBuffer);
    TPCircularBufferCleanup(&audioConverterCircularBuffer);
}


- (void)runAudioMonitorWithSampleRate:(NSInteger)sampleRate volume:(float)volume
{
    //raise(SIGSTOP); // Stop and wait for debugger. Click the Debugger's Resume button to continue execution

    self.sampleRate = sampleRate;
    self.volume = volume;

    // start threads for input buffering, resampling and playback to audio device
    [self performSelectorInBackground:@selector(runInputBufferOnThread) withObject:NULL];

    [self performSelectorInBackground:@selector(runAudioConverterOnThread) withObject:NULL];

    [self performSelectorInBackground:@selector(runAudioQueueOnThread) withObject:NULL];
    
    NSLog(@"runAudioMonitorOnThread sampleRate=%ld, volume=%f", self.sampleRate, self.volume    );
}



- (void)runInputBufferOnThread
{
    pid_t originalParentProcessPID = getppid();
    
    int packetIndex = 0;
    BOOL doExit = NO;

    NSTimeInterval lastReadTime = [NSDate timeIntervalSinceReferenceDate] + 20;
    NSTimeInterval nextTimeoutReportInterval = 5;

    int32_t circularBufferLength = 256 * 1024;
    TPCircularBufferInit(&inputCircularBuffer, circularBufferLength);
    
    // continuous run loop
    while (doExit == NO)
    {
        //NSLog(@"AudioMonitor runInputBufferOnThread polling loop");
        
        CFRunLoopMode runLoopMode = kCFRunLoopDefaultMode;
        CFTimeInterval runLoopTimeInterval = 0.1f;
        Boolean returnAfterSourceHandled = false;
        CFRunLoopRunResult runLoopResult = CFRunLoopRunInMode(runLoopMode, runLoopTimeInterval, returnAfterSourceHandled);

        NSTimeInterval currentTime = [NSDate timeIntervalSinceReferenceDate];

        UInt32 bytesAvailableCount = 0;

        // use ioctl to determine amount of data available for reading from the RTL-SDR USB serial device
        int ioctl_result = ioctl( STDIN_FILENO, FIONREAD, &bytesAvailableCount);
        if (ioctl_result < 0)
        {
            NSLog(@"AudioMonitor ioctl failed: %s\n", strerror( errno));
            doExit = YES;
            break;
        }

        if( bytesAvailableCount <= 0)
        {
            //[NSThread sleepForTimeInterval:0.01f];
            usleep(1000);
        }
        else
        {
            if (bytesAvailableCount % 2 == 0)
            {
                unsigned char * rtlsdrBuffer = (unsigned char *)malloc(bytesAvailableCount);
                
                if (rtlsdrBuffer != NULL)
                {
                    memset(rtlsdrBuffer, 0, bytesAvailableCount);
                    
                    long readResult = read( STDIN_FILENO, rtlsdrBuffer, bytesAvailableCount);
                    
                    if (readResult <= 0)
                    {
                        NSLog(@"AudioMonitor read failed: %s\n", strerror( errno));
                        break;
                    }
                    else
                    {
                        lastReadTime = currentTime;
                        nextTimeoutReportInterval = 5;
                        
                        // copy RTL-SDR LPCM data to a circular buffer to be used as input for AudioConverter process

                        int32_t space;
                        void *ptr = TPCircularBufferHead(&inputCircularBuffer, &space);
                        //NSLog(@"AudioMonitor runInputBufferOnThread Produce, bytesAvailableCount=%u, space = %d, head = %p", bytesAvailableCount, space, ptr);
                        
                        bool produceBytesResult = TPCircularBufferProduceBytes(&inputCircularBuffer, rtlsdrBuffer, bytesAvailableCount);
                        
                        if (produceBytesResult == false)
                        {
                            NSLog(@"AudioMonitor runInputBufferOnThread Produce, bytesAvailableCount=%u, space = %d, head = %p", bytesAvailableCount, space, ptr);
                            NSLog(@"AudioMonitor runInputBufferOnThread - produce bytes failed, bytesAvailableCount = %d", bytesAvailableCount);
                        }
                        
                        fwrite(rtlsdrBuffer, 1, bytesAvailableCount, stdout); // also write to stdout at original sampling rate, for sox, etc.
                    }
                    
                    free(rtlsdrBuffer);
                }
                else
                {
                    NSLog(@"AudioMonitor runInputBufferOnThread - rtlsdrBuffer allocation failed - rtlsdrBuffer=%d", bytesAvailableCount);
                }
            }
        }

        NSTimeInterval intervalSinceLastRead = currentTime - lastReadTime;
        if (intervalSinceLastRead >= nextTimeoutReportInterval)
        {
            //NSLog(@"AudioMonitor intervalSinceLastRead >= %f", nextTimeoutReportInterval);
            
            nextTimeoutReportInterval += 5;
            
            pid_t currentParentProcessPID = getppid();
            if (currentParentProcessPID != originalParentProcessPID)
            {
                //NSLog(@"AudioMonitor original parent process PID changed, terminating....");
                //self.doExit = YES;
            }
        }
        
        packetIndex++;
    }

    //NSLog(@"AudioMonitor exit");
    //fprintf(stderr, "AudioMonitor exit\n");
}




- (void)runAudioConverterOnThread
{
    [NSThread sleepForTimeInterval:0.1f];

    pid_t originalParentProcessPID = getppid();
    
    BOOL doExit = NO;

    NSTimeInterval lastReadTime = [NSDate timeIntervalSinceReferenceDate] + 20;
    NSTimeInterval nextTimeoutReportInterval = 5;

    int32_t circularBufferLength = 384 * 1024;
    TPCircularBufferInit(&audioConverterCircularBuffer, circularBufferLength);

    [self startAudioConverter];     // resample PCM data to 48000 Hz

    // continuous run loop
    while (doExit == NO)
    {
        //NSLog(@"AudioMonitor runAudioConverterOnThread polling loop");
        
        CFRunLoopMode runLoopMode = kCFRunLoopDefaultMode;
        CFTimeInterval runLoopTimeInterval = 0.1f;
        Boolean returnAfterSourceHandled = false;
        CFRunLoopRunResult runLoopResult = CFRunLoopRunInMode(runLoopMode, runLoopTimeInterval, returnAfterSourceHandled);

        NSTimeInterval currentTime = [NSDate timeIntervalSinceReferenceDate];

        int32_t bytesAvailableCount = 0;

        void * circularBufferDataPtr = TPCircularBufferTail(&inputCircularBuffer, &bytesAvailableCount);    // get pointer to read buffer
        
        if( bytesAvailableCount <= 0)
        {
            //[NSThread sleepForTimeInterval:0.01f];
            usleep(1000);
        }
        else
        {
            if (bytesAvailableCount % 2 == 0)
            {
                lastReadTime = currentTime;
                nextTimeoutReportInterval = 5;
                
                //NSLog(@"AudioMonitor sending data, length=%ld", bytesAvailableCount);
                
                if (self.volume > 0.0f)
                {
                    [self convertBuffer:circularBufferDataPtr length:bytesAvailableCount];
                }

                //NSLog(@"AudioMonitor runAudioConverterOnThread - Consume bytesAvailableCount = %d, circularBufferDataPtr = %p", bytesAvailableCount, circularBufferDataPtr);

                TPCircularBufferConsume(&inputCircularBuffer, bytesAvailableCount);
                
                //fwrite(&inputCircularBuffer, 1, bytesAvailableCount, stdout);    // also write to stdout at original sampling rate, for sox, etc.
            }
        }

        NSTimeInterval intervalSinceLastRead = currentTime - lastReadTime;
        if (intervalSinceLastRead >= nextTimeoutReportInterval)
        {
            //NSLog(@"AudioMonitor intervalSinceLastRead >= %f", nextTimeoutReportInterval);
            
            nextTimeoutReportInterval += 5;
            
            pid_t currentParentProcessPID = getppid();
            if (currentParentProcessPID != originalParentProcessPID)
            {
                //NSLog(@"AudioMonitor original parent process PID changed, terminating....");
                //self.doExit = YES;
            }
        }
    }
}






- (void)startAudioConverter
{
    // Configure input and output AudioStreamBasicDescription (ADSB) for AudioConverter to resample PCM data to 48000 Hz
    
    memset(&audioConverterInputDescription, 0, sizeof(audioConverterInputDescription));
    audioConverterInputDescription.mSampleRate = self.sampleRate;     // default is 10000 Hz
    audioConverterInputDescription.mFormatID = kAudioFormatLinearPCM;
    audioConverterInputDescription.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved;
    audioConverterInputDescription.mBitsPerChannel = kInputPacketLength * 8;
    audioConverterInputDescription.mChannelsPerFrame = 1;
    audioConverterInputDescription.mBytesPerFrame = kInputPacketLength;
    audioConverterInputDescription.mFramesPerPacket = 1;
    audioConverterInputDescription.mBytesPerPacket = kInputPacketLength;
    [self logDescription:&audioConverterInputDescription withName:@"audioConverterInputDescription"];
    
    // copy input AudioStreamBasicDescription fields to output ASBD, except mSampleRate
    audioConverterOutputDescription = audioConverterInputDescription;
    audioConverterOutputDescription.mSampleRate = 48000;
    [self logDescription:&audioConverterOutputDescription withName:@"audioConverterOutputDescription"];

    OSStatus audioConverterNewStatus = AudioConverterNew(&audioConverterInputDescription, &audioConverterOutputDescription, &inAudioConverter);
    if (audioConverterNewStatus != noErr)
    {
        NSError * error = [NSError errorWithDomain:NSOSStatusErrorDomain code:audioConverterNewStatus userInfo:NULL];
        NSLog(@"AudioMonitor audioConverterNewStatus audioConverterNewStatus %@", error);
    }
}




- (void)runAudioQueueOnThread
{
    [NSThread sleepForTimeInterval:0.2f];

    // configure AudioQueue for rendering PCM audio data to default output device (i.e., speakers).

    audioQueueIndex = 0;

    unsigned int i;
    
    audioQueueDescription.mSampleRate       = kAudioQueueSampleRate;
    audioQueueDescription.mFormatID         = kAudioFormatLinearPCM;
    audioQueueDescription.mFormatFlags      = kLinearPCMFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    audioQueueDescription.mBitsPerChannel   = 8 * sizeof(SInt16);
    audioQueueDescription.mChannelsPerFrame = kAudioQueueChannelsCount;
    audioQueueDescription.mBytesPerFrame    = sizeof(SInt16) * kAudioQueueChannelsCount;
    audioQueueDescription.mFramesPerPacket  = 1;
    audioQueueDescription.mBytesPerPacket   = audioQueueDescription.mBytesPerFrame * audioQueueDescription.mFramesPerPacket;
    audioQueueDescription.mReserved         = 0;
    [self logDescription:&audioQueueDescription withName:@"audioQueueFormat"];
    
    OSStatus newQueueOutputStatus = AudioQueueNewOutput(&audioQueueDescription, audioQueueCallback, (__bridge void *)self, CFRunLoopGetCurrent(), kCFRunLoopCommonModes, 0, &audioQueue);
    if (newQueueOutputStatus != noErr)
    {
        NSError * error = [NSError errorWithDomain:NSOSStatusErrorDomain code:newQueueOutputStatus userInfo:NULL];
        NSLog(@"AudioMonitor runAudioQueueOnThread newQueueOutputStatus %@", error);
    }
    
    for (i = 0; i < kAudioQueueBuffersCount; i++)
    {
        OSStatus queueAllocateStatus = AudioQueueAllocateBuffer(audioQueue, kAudioQueueBufferSize, &buffers[i]);
        if (queueAllocateStatus != noErr)
        {
            NSError * error = [NSError errorWithDomain:NSOSStatusErrorDomain code:queueAllocateStatus userInfo:NULL];
            NSLog(@"AudioMonitor runAudioQueueOnThread queueAllocateStatus %@", error);
        }

        buffers[i]->mAudioDataByteSize = kAudioQueueBufferSize;
        
        audioQueueCallback((__bridge void *)self, audioQueue, buffers[i]);
    }
    
    UInt32 inNumberOfFramesToPrepare = 0;   // decode all enqueued buffers
    UInt32 outNumberOfFramesPrepared = 0;
    OSStatus queuePrimeStatus = AudioQueuePrime(audioQueue, inNumberOfFramesToPrepare, &outNumberOfFramesPrepared);
    if (queuePrimeStatus != noErr)
    {
        NSError * error = [NSError errorWithDomain:NSOSStatusErrorDomain code:queuePrimeStatus userInfo:NULL];
        NSLog(@"AudioMonitor runAudioQueueOnThread queuePrimeStatus %@", error);
    }
	
    OSStatus queueStartStatus = AudioQueueStart(audioQueue, NULL);
    if (queueStartStatus != noErr)
    {
        NSError * error = [NSError errorWithDomain:NSOSStatusErrorDomain code:queueStartStatus userInfo:NULL];
        NSLog(@"AudioMonitor runAudioQueueOnThread queueStartStatus %@", error);
    }
    
    /*
    bool mIsRunning = true;
    
    do {
            CFRunLoopRunInMode (
                kCFRunLoopDefaultMode,
                0.1,
                false   // returnAfterSourceHandled
            );
    } while (mIsRunning == true);
    
    // After the audio queue has stopped, runs the run loop a bit longer to ensure that the audio queue buffer currently playing has time to finish
    CFRunLoopRunInMode (
        kCFRunLoopDefaultMode,
        1,
        false
    );
    */
    
    CFRunLoopRun();
}



void audioQueueCallback(void *custom_data, AudioQueueRef queue, AudioQueueBufferRef buffer)
{
    // called by AudioQueue to fill a buffer for rendering to default output device
    // the 48000 Hz PCM audio output of the AudioConvert process is used as input here
    
    //UInt32 audioQueueDataByteSize = buffer->mAudioDataByteSize;
    UInt32 audioQueueDataBytesCapacity = buffer->mAudioDataBytesCapacity;

    AudioMonitor * self = (__bridge AudioMonitor *)custom_data;
    
    int32_t availableBytes = 0;
    void * circularBufferDataPtr = TPCircularBufferTail(&(self->audioConverterCircularBuffer), &availableBytes);

    //NSLog(@"AudioMonitor audioQueueCallback buffer=%p, availableBytes=%d, audioQueueDataBytesCapacity=%u", buffer, availableBytes, audioQueueDataBytesCapacity);
    
    if (availableBytes > 0)
    {
        int channelOutputBytes = availableBytes * kAudioQueueChannelsCount;

        if (channelOutputBytes > audioQueueDataBytesCapacity)
        {
            channelOutputBytes = audioQueueDataBytesCapacity;
        }

        int samplesCount = (channelOutputBytes / kAudioQueueChannelsCount) / sizeof(SInt16);

        SInt16 * sourcePtr = (SInt16 *)circularBufferDataPtr;
        SInt16 * destinationPtr = (SInt16 *)buffer->mAudioData;

        for (int i = 0; i < samplesCount; i++)
        {
            SInt16 monoSample = *sourcePtr;
            sourcePtr++;
            
            for (int j = 0; j < kAudioQueueChannelsCount; j++)
            {
                *destinationPtr = monoSample;
                destinationPtr++;
            }
        }
        
        //NSLog(@"AudioMonitor audioQueueCallback - Consume availableBytes = %d, circularBufferDataPtr = %p", availableBytes, circularBufferDataPtr);
        
        TPCircularBufferConsume(&(self->audioConverterCircularBuffer), availableBytes);

        //fwrite(circularBufferDataPtr, 1, availableBytes, stdout);    // also write resampled audio to stdout, perhaps for sox, etc.

        buffer->mAudioDataByteSize = channelOutputBytes;
        
        // output resampled audio to the current system device
        OSStatus queueEnqueueStatus = AudioQueueEnqueueBuffer(queue, buffer, 0, NULL);
        if (queueEnqueueStatus != noErr)
        {
            NSError * error = [NSError errorWithDomain:NSOSStatusErrorDomain code:queueEnqueueStatus userInfo:NULL];
            NSLog(@"AudioMonitor runAudioQueueOnThread data queueEnqueueStatus %@", error);
        }
    }
    else
    {
        // no data available in circular buffer, so output some packets of silence
        
        //NSLog(@"AudioMonitor audioQueueCallback - no input data available, output silence");

        buffer->mAudioDataByteSize = sizeof(SInt16) * 256;      // 64 frames * 2 bytes per packet * 2 packets per frame

        memset(buffer->mAudioData, 0, buffer->mAudioDataByteSize);
        
        // output silent audio to the current system device
        OSStatus queueEnqueueStatus = AudioQueueEnqueueBuffer(queue, buffer, 0, NULL);
        if (queueEnqueueStatus != noErr)
        {
            NSError * error = [NSError errorWithDomain:NSOSStatusErrorDomain code:queueEnqueueStatus userInfo:NULL];
            NSLog(@"AudioMonitor runAudioQueueOnThread silence queueEnqueueStatus %@", error);
        }
    }
}







- (void)convertBuffer:(void *)inputBufferPtr length:(UInt32)dataLength
{
    // use AudioConverter to resample PCM audio data from the RTL-SDR device sampling rate to 48000 Hz
    
    if (dataLength > 0)
    {
        const UInt32 numFrames = dataLength / 2;

        audioConverterInputAudioBuffer.mNumberChannels = audioConverterInputDescription.mChannelsPerFrame;
        audioConverterInputAudioBuffer.mDataByteSize = (SInt32)dataLength;
        audioConverterInputAudioBuffer.mData = (void *)inputBufferPtr;

        audioConverterInputBufferOffset = 0;
        audioConverterInputPacketsRemain = numFrames;
        
        audioConverterOutputBufferPtr = calloc(numFrames, sizeof(SInt16));
        audioConverterOutputBytes = numFrames * sizeof(SInt16);

        audioConverterOutputBufferList.mNumberBuffers = 1;
        audioConverterOutputBufferList.mBuffers[0].mNumberChannels = audioConverterOutputDescription.mChannelsPerFrame;
        audioConverterOutputBufferList.mBuffers[0].mDataByteSize = audioConverterOutputBytes;
        audioConverterOutputBufferList.mBuffers[0].mData = audioConverterOutputBufferPtr;

        UInt32 outputDataPacketSize = numFrames;    // on entry, max packets capacity

        //NSLog(@"AudioMonitor convertBuffer numFrames=%d, remain=%d", numFrames, audioConverterInputPacketsRemain);
        
        // for up-sampling (e.g., 10000 Hz to 41000 Hz), AudioConverterFillComplexBuffer was not making multiple calls to inputProc,
        // so try multiple calls in a loop here and check result for exit condition 'zero' indicating end of input buffer.
        // Down-sampling (e.g. 85000 Hz to 10000 Hz) seems to get the buffer processed without the loop.

        OSStatus convertResult = noErr;
        
        while (convertResult == noErr)
        {
            convertResult = AudioConverterFillComplexBuffer(
                    inAudioConverter,      // AudioConverterRef inAudioConverter
                    audioConverterComplexInputDataProc, // AudioConverterComplexInputDataProc inInputDataProc
                    (__bridge void*)self,  // void *inInputDataProcUserData
                    &outputDataPacketSize, // UInt32 *ioOutputDataPacketSize - entry: max packets capacity, exit: number of packets converted
                    &audioConverterOutputBufferList,     // AudioBufferList *outOutputData
                    NULL                   // AudioStreamPacketDescription *outPacketDescription - not applicable for PCM?
                    );
            
            //NSLog(@"AudioMonitor convertBuffer AudioConverterFillComplexBuffer result = %d, outputDataPacketSize = %d", convertResult, outputDataPacketSize);
        
            if (outputDataPacketSize > 0)   // number of packets converted
            {
                int32_t convertedDataLength = outputDataPacketSize * sizeof(SInt16);

                void * convertedDataPtr = audioConverterOutputBufferList.mBuffers[0].mData;

                int32_t space;
                void *ptr = TPCircularBufferHead(&audioConverterCircularBuffer, &space);
                //NSLog(@"AudioMonitor convertBuffer Produce convertedDataLength = %d, space = %d, head = %p", convertedDataLength, space, ptr);
                
                bool  produceBytesResult = TPCircularBufferProduceBytes(&audioConverterCircularBuffer, convertedDataPtr, convertedDataLength);

                if (produceBytesResult == false)
                {
                    NSLog(@"AudioMonitor convertBuffer Produce convertedDataLength = %d, space = %d, head = %p", convertedDataLength, space, ptr);
                    NSLog(@"AudioMonitor convertBuffer - produce bytes failed, convertedDataLength = %d", convertedDataLength);
                }
            }

            if (convertResult != noErr)
            {
                if (convertResult != 'zero')
                {
                    NSError * error = [NSError errorWithDomain:NSOSStatusErrorDomain code:convertResult userInfo:NULL];
                    NSLog(@"AudioMonitor convertResult=%d %@", convertResult, error);
                    AudioConverterReset(inAudioConverter);
                }
            }
        }
        
        free(audioConverterOutputBufferPtr);
        audioConverterOutputBufferPtr = NULL;
    }
}





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
        NSLog(@"AudioMonitor - audioConverterComplexInputDataProc ioDataPacketDescription not available");
        *ioDataPacketDescription = NULL;
        *ioNumberDataPackets = 0;
        ioData->mNumberBuffers = 0;
        return 501;
    }
    
    __unsafe_unretained AudioMonitor * self = (__bridge AudioMonitor *)inUserData;
    
    UInt32 ioNumberDataPacketsRequested = *ioNumberDataPackets;

    UInt32 ioNumberDataPacketsProduced = ioNumberDataPacketsRequested;
    if (ioNumberDataPacketsProduced > self->audioConverterInputPacketsRemain)
    {
        ioNumberDataPacketsProduced = self->audioConverterInputPacketsRemain;
    }

    void * offsetPtr = (char *)self->audioConverterInputAudioBuffer.mData + self->audioConverterInputBufferOffset;
    
    ioData->mNumberBuffers = 1;         // One buffer is sufficient for non-interleaved data
    ioData->mBuffers[0].mNumberChannels =  self->audioConverterInputAudioBuffer.mNumberChannels;
    ioData->mBuffers[0].mDataByteSize = ioNumberDataPacketsProduced * kInputPacketLength;
    ioData->mBuffers[0].mData = offsetPtr;

    *ioNumberDataPackets = ioNumberDataPacketsProduced;
    
    if (ioNumberDataPacketsProduced == 0)
    {
        result = 'zero';
    }
    
    self->audioConverterInputBufferOffset += (ioNumberDataPacketsProduced * kInputPacketLength);
    self->audioConverterInputPacketsRemain -= ioNumberDataPacketsProduced;
    
    //NSLog(@"AudioMonitor - audioConverterComplexInputDataProc ioNumberDataPacketsRequested=%u, ioNumberDataPacketsProduced=%u,  result=%d", ioNumberDataPacketsRequested, ioNumberDataPacketsProduced, result);
    
    return result;
}









- (void)logDescription:(AudioStreamBasicDescription *)asbd withName:(NSString *)name
{
    NSLog(@"AudioStreamBasicDescription %@", name);
    NSLog(@"   %@.mSampleRate=%f", name, asbd->mSampleRate);
    NSLog(@"   %@.mFormatID=%c4", name, asbd->mFormatID);
    NSLog(@"   %@.AudioFormatFlags=%u", name, (unsigned int)asbd->mFormatFlags);
    NSLog(@"   %@.mBytesPerPacket=%u", name, (unsigned int)asbd->mBytesPerPacket);
    NSLog(@"   %@.mFramesPerPacket=%u", name, (unsigned int)asbd->mFramesPerPacket);
    NSLog(@"   %@.mBytesPerFrame=%u", name, (unsigned int)asbd->mBytesPerFrame);
    NSLog(@"   %@.mChannelsPerFrame=%u", name, (unsigned int)asbd->mChannelsPerFrame);
    NSLog(@"   %@.mBitsPerChannel=%u", name, (unsigned int)asbd->mBitsPerChannel);
}




@end

//
//  AudioMonitor.m
//  AudioMonitor
//
//  Created by Douglas Ward on 8/28/17.
//  Copyright © 2017 ArkPhone LLC. All rights reserved.
//

//  Resample audio to 41000 Hz with AudioConverter, and output to Novocaine buffer for playthrough with stdio
//  https://github.com/alexbw/novocaine
//  http://atastypixel.com/blog/four-common-mistakes-in-audio-development/


#import "AudioMonitor.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AudioToolbox/AudioConverter.h>

#include <mach/mach.h>

#include <sys/types.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <sys/un.h>
#include <sys/event.h>
#include <sys/ioctl.h>
#include <sys/sysctl.h>

#include <net/if.h>
#include <netinet/in.h>
#include <netinet/ip.h>
#include <netinet/tcp.h>
#include <arpa/telnet.h>
#include <arpa/inet.h>

#include <err.h>
#include <errno.h>
#include <limits.h>
#include <netdb.h>
#include <poll.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <inttypes.h>
#include <string.h>
#include <getopt.h>
#include <fcntl.h>
#include <pthread.h>

// smaller kInputMaxPackets (4096) work for down-sampling, larger values (8192) for up-sampling (10000 Hz)
//#define kInputMaxPackets 4096
#define kInputMaxPackets 8192
#define kInputPacketLength sizeof(SInt16)
#define kInputBufferLength (kInputMaxPackets*kInputPacketLength)

#define kOutputPacketLength (sizeof(float)*2)
#define kOutputBufferLength (kInputMaxPackets*kOutputPacketLength)



@interface AudioMonitor ()

@property (nonatomic, assign) RingBuffer *ringBuffer;

@end

@implementation AudioMonitor




- (void)runAudioMonitorWithSampleRate:(NSInteger)sampleRate volume:(float)volume
{
    self.sampleRate = sampleRate;
    self.volume = volume;

    [self performSelectorInBackground:@selector(runAudioMonitorOnThread) withObject:NULL];
}



- (void)runAudioMonitorOnThread
{
    //NSLog(@"AudioMonitor starting with sample rate %ld", self.sampleRate);

    pid_t originalParentProcessPID = getppid();
    
    int packetIndex = 0;
    BOOL doExit = NO;

    NSTimeInterval lastReadTime = [NSDate timeIntervalSinceReferenceDate] + 20;
    NSTimeInterval nextTimeoutReportInterval = 5;
    
    [self startAudioMonitor];

    while (doExit == NO)
    {
        //NSLog(@"AudioMonitor polling loop");

        NSTimeInterval currentTime = [NSDate timeIntervalSinceReferenceDate];

        UInt32 bytesAvailableCount = 0;
    
        int ioctl_result = ioctl( 0, FIONREAD, &bytesAvailableCount);
        if (ioctl_result < 0)
        {
            NSLog(@"AudioMonitor ioctl failed: %s\n", strerror( errno));
            doExit = YES;
            break;
        }

        if( bytesAvailableCount <= 0)
        {
            [NSThread sleepForTimeInterval:0.1f];
        }
        else
        {
            if (bytesAvailableCount > kInputBufferLength)
            {
                bytesAvailableCount = kInputBufferLength;
            }
        
            unsigned char buf[kInputBufferLength];
            memset(&buf, 0, kInputBufferLength);
            long readResult = read( 0, &buf, bytesAvailableCount);
            
            if (readResult <= 0)
            {
                NSLog(@"AudioMonitor read failed: %s\n", strerror( errno));
                break;
            }
            else
            {
                lastReadTime = currentTime;
                nextTimeoutReportInterval = 5;
                
                //NSLog(@"AudioMonitor sending data, length=%ld", bytesAvailableCount);
                
                if (self.volume > 0.0f)
                {
                    [self convertBuffer:&buf length:bytesAvailableCount];
                }
                
                fwrite(&buf, 1, bytesAvailableCount, stdout);    // also write a copy to stdout, perhaps for sox, etc.
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



- (void)startAudioMonitor
{
    __weak AudioMonitor * weakSelf = self;
    
    memset(&inputDescription, 0, sizeof(inputDescription));
    inputDescription.mSampleRate = self.sampleRate;     // default is 10000 Hz
    inputDescription.mFormatID = kAudioFormatLinearPCM;
    inputDescription.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved;
    inputDescription.mBitsPerChannel = kInputPacketLength * 8;
    inputDescription.mChannelsPerFrame = 1;
    inputDescription.mBytesPerFrame = kInputPacketLength;
    inputDescription.mFramesPerPacket = 1;
    inputDescription.mBytesPerPacket = kInputPacketLength;
    //[self logDescription:&inputDescription withName:@"inputDescription"];
    
    memset(&outputDescription, 0, sizeof(outputDescription));
    outputDescription.mSampleRate = 44100;      // Novocaine expects 44100?
    outputDescription.mFormatID = kAudioFormatLinearPCM;
    outputDescription.mFormatFlags = kLinearPCMFormatFlagIsFloat | kLinearPCMFormatFlagIsPacked;
    outputDescription.mBitsPerChannel = sizeof(float) * 8;
    outputDescription.mChannelsPerFrame = 2;
    outputDescription.mBytesPerFrame = kOutputPacketLength;
    outputDescription.mFramesPerPacket = 1;
    outputDescription.mBytesPerPacket = outputDescription.mBytesPerFrame * outputDescription.mFramesPerPacket;
    //[self logDescription:&outputDescription withName:@"outputDescription"];

    OSStatus audioConverterNewStatus = AudioConverterNew(&inputDescription, &outputDescription, &inAudioConverter);
    if (audioConverterNewStatus != noErr)
    {
        NSLog(@"audioConverterNewStatus = %d", (int)audioConverterNewStatus);
    }
    
    // create Novocaine ring buffer to store the converted audio samples
    self.ringBuffer = new RingBuffer(kOutputBufferLength, outputDescription.mChannelsPerFrame);
    self.audioManager = [Novocaine audioManager];

    outputBytes = kOutputBufferLength;
    outputBufferPtr = malloc(outputBytes);
    memset(outputBufferPtr, 0, outputBytes);
    
    // Novocaine pulls converted float LPCM data from ring buffer
    [self.audioManager setOutputBlock:^(float *outData, UInt32 numFrames, UInt32 numChannels) {
        weakSelf.ringBuffer->FetchInterleavedData(outData, numFrames, numChannels);     // executes on IOThread
    }];
    
    // Novocaine plays through current hardware audio device
    [self.audioManager play];
}






- (void)convertBuffer:(void *)inputBufferPtr length:(UInt32)dataLength
{
    // convert signed 16-bit integer one-channel PCM to 32-bit float two-channel PCM,
    // and output to RingBuffer for Novocaine rendering to current selected audio output device
    
    const UInt32 numFrames = dataLength / 2;

    inputAudioBuffer.mNumberChannels = inputDescription.mChannelsPerFrame;
    inputAudioBuffer.mDataByteSize = (SInt32)dataLength;
    inputAudioBuffer.mData = (void *)inputBufferPtr;

    inputBufferOffset = 0;
    inputPacketsRemain = numFrames;

    outputBufferList.mNumberBuffers = 1;
    outputBufferList.mBuffers[0].mNumberChannels = outputDescription.mChannelsPerFrame;
    outputBufferList.mBuffers[0].mDataByteSize = outputBytes;
    outputBufferList.mBuffers[0].mData = outputBufferPtr;

    UInt32 outputDataPacketSize = numFrames;

    //NSLog(@"numFrames=%d, remain=%d", numFrames, inputPacketsRemain);
    
    // for up-sampling (e.g., 10000 Hz to 41000 Hz), AudioConverterFillComplexBuffer was not making multiple calls to inputProc,
    // so try multiple calls in a loop here and check result for exit condition 'zero' indicating end of input buffer.
    // Down-sampling (e.g. 85000 Hz to 10000 Hz) seems to get the buffer processed without the loop.
    // Perhaps kInputMaxPackets and other defines should be replaced with computed values?
    OSStatus convertResult = noErr;
    while (convertResult == noErr)
    {
        convertResult = AudioConverterFillComplexBuffer(
                inAudioConverter,      // AudioConverterRef inAudioConverter
                audioConverterComplexInputDataProc, // AudioConverterComplexInputDataProc inInputDataProc
                (__bridge void*)self,  // void *inInputDataProcUserData
                &outputDataPacketSize, // UInt32 *ioOutputDataPacketSize - entry: max packets capacity, exit: number of packets converted
                &outputBufferList,     // AudioBufferList *outOutputData
                NULL                   // AudioStreamPacketDescription *outPacketDescription
                );

        if (outputDataPacketSize > 0)
        {
            const SInt64 numChannels = 2;
            //self.ringBuffer->AddNewInterleavedFloatData((float *)outputBufferPtr, outputDataPacketSize, numChannels);
            self.ringBuffer->AddNewInterleavedFloatData((float *)outputBufferList.mBuffers[0].mData, outputDataPacketSize, numChannels);
            
            //NSLog(@"ringBuffer AddNewInterleavedFloatData outputDataPacketSize=%u, numFrames=%u", (unsigned int)outputDataPacketSize, (unsigned int)numFrames);
        }

        if (convertResult != noErr)
        {
            //if (convertResult != 'zero')
            if (1)
            {
                char errChars[4];
                memcpy(&errChars, &convertResult, 4);
                //NSLog(@"AudioMonitor convertResult=%d %c%c%c%c", convertResult, errChars[3], errChars[2], errChars[1], errChars[0]);
            }
        }
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
    OSStatus result = noErr;

    // this can get called multiple times from AudioConverterFillComplexBuffer, and needs to manage short blocks.
    if(ioDataPacketDescription)
    {
        NSLog(@"AudioMonitor - audioConverterComplexInputDataProc ioDataPacketDescription not available");
        *ioDataPacketDescription = NULL;
        *ioNumberDataPackets = 0;
        ioData->mNumberBuffers = 0;
        return 501;
    }
    
    AudioMonitor * self = (__bridge AudioMonitor *)inUserData;
    
    UInt32 ioNumberDataPacketsRequested = *ioNumberDataPackets;

    ioData->mNumberBuffers = 1;
    ioData->mBuffers[0].mNumberChannels =  self->inputAudioBuffer.mNumberChannels;

    void * offsetPtr = (char *)self->inputAudioBuffer.mData + self->inputBufferOffset;
    ioData->mBuffers[0].mData =  offsetPtr;

    UInt32 ioNumberDataPacketsProduced = ioNumberDataPacketsRequested;
    
    if (ioNumberDataPacketsProduced > self->inputPacketsRemain)
    {
        ioNumberDataPacketsProduced = self->inputPacketsRemain;
    }
    
    ioData->mBuffers[0].mDataByteSize = ioNumberDataPacketsProduced * kInputPacketLength;

    *ioNumberDataPackets = ioNumberDataPacketsProduced;
    
    if (ioNumberDataPacketsProduced == 0)
    {
        result = 'zero';
    }
    
    //UInt64 oldOffset = self->inputBufferOffset;
    //SInt32 oldRemain = self->inputPacketsRemain;

    self->inputBufferOffset += (ioNumberDataPacketsProduced * kInputPacketLength);
    self->inputPacketsRemain -= ioNumberDataPacketsProduced;

    //NSLog(@"buffer req:%u prd:%u oldOffset:%llu oldRemain:%d newOffset:%llu newRemain:%d ptr:%llx result:%d", ioNumberDataPacketsRequested, (unsigned int)ioNumberDataPacketsProduced, oldOffset, oldRemain, self->inputBufferOffset, self->inputPacketsRemain, (unsigned long long)offsetPtr, (int)result);
    
    return result;
}



@end

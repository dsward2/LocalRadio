//
//  AudioMonitor.h
//  AudioMonitor
//
//  Created by Douglas Ward on 8/28/17.
//  Copyright © 2017-2018 ArkPhone LLC. All rights reserved.
//


#import <Foundation/Foundation.h>

#import <AudioToolbox/AudioToolbox.h>
#import <Accelerate/Accelerate.h>
//#import "TPCircularBuffer+AudioBufferList.h"
#import "TPCircularBuffer.h"


// AudioQueue values
#define kAudioQueueBuffersCount 3

@interface AudioMonitor : NSObject
{
    AudioConverterRef inAudioConverter;     // AudioConverter for resampling PCM data to 48000 Hz

    AudioStreamBasicDescription audioConverterInputDescription;
    AudioStreamBasicDescription audioConverterOutputDescription;

    AudioBuffer audioConverterInputAudioBuffer;
    UInt64 audioConverterInputBufferOffset;
    UInt32 audioConverterInputPacketsRemain;

    TPCircularBuffer inputCircularBuffer;        // TPCircularBuffer for storage and retrieval of input PCM data from stdin
    TPCircularBuffer audioConverterCircularBuffer;        // TPCircularBuffer for storage and retrieval of resampled PCM data
    
    AudioBufferList audioConverterOutputBufferList;
    void * audioConverterOutputBufferPtr;
    UInt32 audioConverterOutputBytes;

    AudioQueueRef audioQueue;               // AudioQueue for playing resampled PCM data to current audio output device, usually speakers
    
    AudioStreamBasicDescription audioQueueDescription;
    AudioQueueBufferRef buffers[kAudioQueueBuffersCount];
    NSUInteger audioQueueIndex;
}

@property (assign) NSInteger sampleRate;
@property (assign) UInt32 inputChannels;
@property (assign) float volume;



- (void)runAudioMonitorWithSampleRate:(NSInteger)sampleRate channels:(NSInteger)channels volume:(float)volume;
- (void)convertBuffer:(void *)inputBufferPtr length:(UInt32)dataLength;

@end


//
//  AudioMonitor.h
//  AudioMonitor
//
//  Created by Douglas Ward on 8/28/17.
//  Copyright © 2017 ArkPhone LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "Novocaine.h"
#import "RingBuffer.h"


@interface AudioMonitor : NSObject
{
    AudioConverterRef inAudioConverter;

    AudioStreamBasicDescription inputDescription;
    AudioStreamBasicDescription outputDescription;

    AudioBuffer inputAudioBuffer;
    UInt64 inputBufferOffset;
    UInt32 inputPacketsRemain;
    
    AudioBufferList outputBufferList;
    void * outputBufferPtr;
    UInt32 outputBytes;
}

@property (nonatomic, strong) Novocaine * audioManager;
@property (assign) NSInteger sampleRate;
@property (assign) float volume;


- (void)runAudioMonitorWithSampleRate:(NSInteger)sampleRate volume:(float)volume;
- (void)convertBuffer:(void *)inputBufferPtr length:(UInt32)dataLength;

@end


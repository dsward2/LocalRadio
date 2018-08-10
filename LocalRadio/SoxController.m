//
//  SoxController.m
//  LocalRadio
//
//  Created by Douglas Ward on 7/19/17.
//  Copyright © 2017-2018 ArkPhone LLC. All rights reserved.
//

//  Currently not used`
//  Was previous in LocalRadio to pipe audio from an external application via Core Audio virtual device, to Icecast

#import "SoxController.h"
#import "AppDelegate.h"
#import "LocalRadioAppSettings.h"
#import "TaskPipelineManager.h"
#import "TaskItem.h"

@implementation SoxController

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.soxControllerTaskPipelineManager = [[TaskPipelineManager alloc] init];
    }
    return self;
}

//==================================================================================
//	terminateTasks
//==================================================================================

- (void)terminateTasks
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [self.soxControllerTaskPipelineManager terminateTasks];
}

//==================================================================================
//	startSecondaryStreamForFrequencies:category:
//==================================================================================

- (void)startSecondaryStreamForFrequencies:(NSArray *)frequenciesArray category:(NSDictionary *)categoryDictionary
{
    NSString * streamSourceString = @"";
    
    if (categoryDictionary == NULL)
    {
        if (frequenciesArray.count == 1)
        {
            NSDictionary * firstFrequencyDictionary = frequenciesArray.firstObject;
            
            streamSourceString = [firstFrequencyDictionary objectForKey:@"stream_source"];
        }
        else
        {
            NSLog(@"LocalRadio error - wrong frequenciesArray.count");
        }
    }
    else
    {
        streamSourceString = [categoryDictionary objectForKey:@"scan_stream_source"];
    }

    NSCharacterSet * whitespaceCharacterSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    streamSourceString = [streamSourceString stringByTrimmingCharactersInSet:whitespaceCharacterSet];

    // construct commands for output to UDPListener/EZStream

    // "~/Library/Developer/Xcode/DerivedData/LocalRadio-ddsodcaiskiovrbpbiioihlrnhbo/Build/Products/Debug/LocalRadio.app/Contents/MacOS/sox" -r 48000 -e signed-integer -b 16 -t coreaudio "Soundflower (2ch)" -c 2 -t coreaudio "Built-in Line Out" vol 10
    
    // To monitor Soundflower (64) live -
    //"~/Library/Developer/Xcode/DerivedData/LocalRadio-ddsodcaiskiovrbpbiioihlrnhbo/Build/Products/Debug/LocalRadio.app/Contents/MacOS/sox" -e signed-integer -b 16 -c 1 -t coreaudio "Soundflower (64ch)"  -t coreaudio "Built-in Line Output"

    TaskItem * soxTaskItem = [self.soxControllerTaskPipelineManager makeTaskItemWithExecutable:@"sox" functionName:@"sox"];

    TaskItem * udpSenderTaskItem = [self.soxControllerTaskPipelineManager makeTaskItemWithExecutable:@"UDPSender" functionName:@"UDPSender"];


    // sox input
    [soxTaskItem addArgument:@"-V2"];    // debug verbosity, -V2 shows failures and warnings
    [soxTaskItem addArgument:@"-q"];     // quiet mode - don't show terminal-style audio meter
    [soxTaskItem addArgument:@"-r"];     // sample rate
    [soxTaskItem addArgument:@"48000"];
    [soxTaskItem addArgument:@"-e"];     // data type
    [soxTaskItem addArgument:@"signed-integer"];
    [soxTaskItem addArgument:@"-b"];     // bits per channel
    [soxTaskItem addArgument:@"16"];
    [soxTaskItem addArgument:@"-c"];     // channels
    //[soxTaskItem addArgument:@"1"];
    [soxTaskItem addArgument:@"2"];
    [soxTaskItem addArgument:@"-t"];      // audio format
    [soxTaskItem addArgument:@"coreaudio"];
    
    [soxTaskItem addArgument:streamSourceString];    // quotes are omitted intentionally
    
    // sox output
    [soxTaskItem addArgument:@"-e"];     // data type
    [soxTaskItem addArgument:@"signed-integer"];
    [soxTaskItem addArgument:@"-b"];     // bits per channel
    [soxTaskItem addArgument:@"16"];
    [soxTaskItem addArgument:@"-c"];     // one channel
    [soxTaskItem addArgument:@"1"];
    [soxTaskItem addArgument:@"-t"];      // audio format
    [soxTaskItem addArgument:@"raw"];
    [soxTaskItem addArgument:@"-"];       // pipe output
    
    // sox output filter
    [soxTaskItem addArgument:@"rate"];     // sox audio processing chain
    [soxTaskItem addArgument:@"48000"];    // LocalRadio always sets the filter rate 48000, users should not use rate
    
    //[soxTaskItem addArgument:@"vol"];      // sox audio processing chain
    //[soxTaskItem addArgument:@"10"];       // sox audio processing chain
    //[soxTaskItem addArgument:@"dither"];   // sox audio processing chain
    //[soxTaskItem addArgument:@"-s"];       // sox audio processing chain

    NSString * secondStageSoxFilterString = [self.appDelegate.localRadioAppSettings valueForKey:@"SecondStageSoxFilter"];
    if (secondStageSoxFilterString != NULL)
    {
        NSArray * soxFilterItems = [secondStageSoxFilterString componentsSeparatedByString:@" "];
        for (NSString * filterItem in soxFilterItems)
        {
            [soxTaskItem addArgument:filterItem];
        }
    }
    
    [udpSenderTaskItem addArgument:@"-p"];
    NSString * audioPort = self.appDelegate.audioPortTextField.stringValue;
    [udpSenderTaskItem addArgument:audioPort];

    // sox will output to UDPSender
    
    @synchronized (self.soxControllerTaskPipelineManager)
    {
        [self.soxControllerTaskPipelineManager addTaskItem:soxTaskItem];
        [self.soxControllerTaskPipelineManager addTaskItem:udpSenderTaskItem];
    }
    
    [self.soxControllerTaskPipelineManager startTasks];
}

//==================================================================================
//	soxTaskReceivedStderrData:
//==================================================================================

- (void)soxTaskReceivedStderrData:(NSNotification *)notif {

    NSFileHandle *fh = [notif object];
    NSData *data = [fh availableData];
    if (data.length > 0)
    {
        // if data is found, re-register for more data (and print)
        [fh waitForDataInBackgroundAndNotify];
        NSString * str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSLog(@"sox: %@" , str);
    }
}




@end

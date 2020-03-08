//
//  StreamingServerController.m
//  LocalRadio
//
//  Created by Douglas Ward on 2/17/20.
//  Copyright © 2020 ArkPhone LLC. All rights reserved.
//

#import "StreamingServerController.h"
#import "AppDelegate.h"
#import "LocalRadioAppSettings.h"
#import "NSFileManager+DirectoryLocations.h"
#import "TaskPipelineManager.h"
#import "TaskItem.h"

@implementation StreamingServerController

//==================================================================================
//    init
//==================================================================================

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.streamingServerTaskPipelineManager = [[TaskPipelineManager alloc] init];
        
        self.audioFormat = @"AAC";
    }
    return self;
}

//==================================================================================
//    terminateTasks
//==================================================================================

- (void)terminateTasks
{
    [self.streamingServerTaskPipelineManager terminateTasks];
}

//==================================================================================
//    startStreamingServer
//==================================================================================

- (void)startStreamingServer
{
    NSLog(@"Starting StreamingServer");
    
    //[self stopStreamingServer];   // TEST
    
    int streamingServerProcessID = [self.appDelegate processIDForProcessName:@"StreamingServer"];

    if (streamingServerProcessID == 0)
    {
        [self startStreamingServerTask];
    }
    else
    {
        NSNumber * streamingServerProcessIDNumber = [NSNumber numberWithInteger:streamingServerProcessID];
        
        [self performSelectorOnMainThread:@selector(poseStreamingServerProcessAlert:) withObject:streamingServerProcessIDNumber waitUntilDone:YES];
    }
}


//==================================================================================
//    poseStreamingServerProcessAlert:
//==================================================================================

- (void)poseStreamingServerProcessAlert:(NSNumber *)streamingServerProcessIDNumber
{
    NSAlert * alert = [[NSAlert alloc] init];
    
    [alert addButtonWithTitle:@"OK"];
    
    [alert setMessageText:@"StreamingServer is already running"];
    
    NSString * informativeText = [NSString stringWithFormat:@"An existing StreamingServer process is currently running on this Mac, so a new StreamingServer process was not created.\n\nThe existing StreamingServer process can be inspected and terminated with Activity Monitor.app with Process ID (PID) %@.", streamingServerProcessIDNumber];
    
    [alert setInformativeText:informativeText];
    
    [alert setAlertStyle:NSAlertStyleWarning];

    if ([alert runModal] == NSAlertFirstButtonReturn)
    {
        // OK clicked
    }
}

//==================================================================================
//    startStreamingServerTask
//==================================================================================

- (void)startStreamingServerTask
{
    // Set UDPListener arguments
    NSNumber * audioPortNumber = [self.appDelegate.localRadioAppSettings integerNumberForKey:@"AudioPort"];
    if (audioPortNumber.integerValue == 0)
    {
        audioPortNumber = [NSNumber numberWithInteger:17006];
    }
    NSString * audioPortString = [audioPortNumber stringValue];

    // Set UDPListener arguments
    TaskItem * udpListenerTaskItem = [self.streamingServerTaskPipelineManager makeTaskItemWithExecutable:@"UDPListener" functionName:@"UDPListener"];

    [udpListenerTaskItem addArgument:@"-l"];
    [udpListenerTaskItem addArgument:audioPortString];

    TaskItem * aacEncoderTaskItem = [self.streamingServerTaskPipelineManager makeTaskItemWithExecutable:@"AACEncoder" functionName:@"AACEncoder"];

    // Set AACEncoder arguments
    [aacEncoderTaskItem addArgument:@"-r"];     // input sample rate
    [aacEncoderTaskItem addArgument:@"48000"];
    [aacEncoderTaskItem addArgument:@"-c"];     // input channels
    [aacEncoderTaskItem addArgument:@"2"];
    [aacEncoderTaskItem addArgument:@"-b"];     // bitrate
    [aacEncoderTaskItem addArgument:self.appDelegate.aacBitrate];

    TaskItem * streamingServerTaskItem = [self.streamingServerTaskPipelineManager makeTaskItemWithExecutable:@"StreamingServer" functionName:@"StreamingServer"];

    // Set StreamingServer arguments
    NSString * hostName = self.appDelegate.localHostString;
    [streamingServerTaskItem addArgument:@"-h"];
    [streamingServerTaskItem addArgument:hostName];
    
    // We use the non-encrypted HTTP port for the source connection, since the server is local
    NSString * httpPortString = [NSString stringWithFormat:@"%ld", self.appDelegate.streamingServerHTTPPort];
    [streamingServerTaskItem addArgument:@"-p"];      // port
    [streamingServerTaskItem addArgument:httpPortString];

    [streamingServerTaskItem addArgument:@"-b"];     // bitrate
    [streamingServerTaskItem addArgument:self.appDelegate.aacBitrate];

    // Create NSTasks
    @synchronized (self.streamingServerTaskPipelineManager)
    {
        [self.streamingServerTaskPipelineManager addTaskItem:udpListenerTaskItem];
        [self.streamingServerTaskPipelineManager addTaskItem:aacEncoderTaskItem];
        [self.streamingServerTaskPipelineManager addTaskItem:streamingServerTaskItem];
    }
    
    [self.streamingServerTaskPipelineManager startTasks];

    [self.appDelegate.statusStreamingServerTextField performSelectorOnMainThread:@selector(setStringValue:) withObject:@"Running" waitUntilDone:NO];
    
    NSLog(@"StreamingServerController startStreamingServerTask startTasks");
}

//==================================================================================
//    streamingServerTaskReceivedStderrData:
//==================================================================================

/*
- (void)streamingServerTaskReceivedStderrData:(NSNotification *)notif {
    NSFileHandle *fh = [notif object];
    NSData *data = [fh availableData];
    if (data.length > 0)
    {
        // if data is found, re-register for more data (and print)
        [fh waitForDataInBackgroundAndNotify];
        NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSLog(@"StreamingServerController: %@" ,str);
    }
}
*/

@end

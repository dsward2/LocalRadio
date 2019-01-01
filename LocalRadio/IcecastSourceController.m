//
//  IcecastSourceController.m
//  LocalRadio
//
//  Created by Douglas Ward on 9/28/18.
//  Copyright © 2018 ArkPhone LLC. All rights reserved.
//

#import "IcecastSourceController.h"
#import "AppDelegate.h"
#import "LocalRadioAppSettings.h"
#import "NSFileManager+DirectoryLocations.h"
#import "TaskPipelineManager.h"
#import "TaskItem.h"

@implementation IcecastSourceController

//==================================================================================
//    init
//==================================================================================

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.icecastSourceTaskPipelineManager = [[TaskPipelineManager alloc] init];
        
        self.audioFormat = @"AAC";
    }
    return self;
}

//==================================================================================
//    terminateTasks
//==================================================================================

- (void)terminateTasks
{
    [self.icecastSourceTaskPipelineManager terminateTasks];
}

//==================================================================================
//    startIcecastSource
//==================================================================================

- (void)startIcecastSource
{
    NSLog(@"Starting IcecastSource");
    
    //[self stopIcecastSource];   // TEST
    
    int icecastSourceProcessID = [self.appDelegate processIDForProcessName:@"IcecastSource"];

    if (icecastSourceProcessID == 0)
    {
        [self startIcecastSourceTask];
    }
    else
    {
        NSNumber * icecastSourceProcessIDNumber = [NSNumber numberWithInteger:icecastSourceProcessID];
        
        [self performSelectorOnMainThread:@selector(poseIcecastSourceProcessAlert:) withObject:icecastSourceProcessIDNumber waitUntilDone:YES];
    }
}


//==================================================================================
//    poseIcecastSourceProcessAlert:
//==================================================================================

- (void)poseIcecastSourceProcessAlert:(NSNumber *)icecastSourceProcessIDNumber
{
    NSAlert *alert = [[NSAlert alloc] init];
    
    [alert addButtonWithTitle:@"OK"];
    
    [alert setMessageText:@"IcecastSource is already running"];
    
    NSString * informativeText = [NSString stringWithFormat:@"An existing IcecastSource process is currently running on this Mac, so a new IcecastSource process was not created.\n\nThe existing IcecastSource process can be inspected and terminated with Activity Monitor.app with Process ID (PID) %@.", icecastSourceProcessIDNumber];
    
    [alert setInformativeText:informativeText];
    
    [alert setAlertStyle:NSWarningAlertStyle];

    if ([alert runModal] == NSAlertFirstButtonReturn)
    {
        // OK clicked
    }
}

//==================================================================================
//    startIcecastSourceTask
//==================================================================================

- (void)startIcecastSourceTask
{
    // Set UDPListener arguments
    NSNumber * audioPortNumber = [self.appDelegate.localRadioAppSettings integerForKey:@"AudioPort"];
    if (audioPortNumber.integerValue == 0)
    {
        audioPortNumber = [NSNumber numberWithInteger:17006];
    }
    NSString * audioPortString = [audioPortNumber stringValue];

    // Set UDPListener arguments
    TaskItem * udpListenerTaskItem = [self.icecastSourceTaskPipelineManager makeTaskItemWithExecutable:@"UDPListener" functionName:@"UDPListener"];

    [udpListenerTaskItem addArgument:@"-l"];
    [udpListenerTaskItem addArgument:audioPortString];

    TaskItem * aacEncoderTaskItem = [self.icecastSourceTaskPipelineManager makeTaskItemWithExecutable:@"AACEncoder" functionName:@"AACEncoder"];

    // Set AACEncoder arguments
    [aacEncoderTaskItem addArgument:@"-r"];     // input sample rate
    [aacEncoderTaskItem addArgument:@"48000"];
    [aacEncoderTaskItem addArgument:@"-c"];     // input channels
    [aacEncoderTaskItem addArgument:@"2"];
    [aacEncoderTaskItem addArgument:@"-b"];     // bitrate
    [aacEncoderTaskItem addArgument:self.appDelegate.aacBitrate];

    TaskItem * icecastSourceTaskItem = [self.icecastSourceTaskPipelineManager makeTaskItemWithExecutable:@"IcecastSource" functionName:@"IcecastSource"];

    // Set IcecastSource arguments
    NSString * hostName = self.appDelegate.localHostString;
    [icecastSourceTaskItem addArgument:@"-h"];
    [icecastSourceTaskItem addArgument:hostName];
    
    // We use the non-encrypted HTTP port for the source connection, since the server is local
    NSString * httpPortString = [NSString stringWithFormat:@"%ld", self.appDelegate.icecastServerHTTPPort];
    [icecastSourceTaskItem addArgument:@"-p"];      // port
    [icecastSourceTaskItem addArgument:httpPortString];

    [icecastSourceTaskItem addArgument:@"-b"];     // bitrate
    [icecastSourceTaskItem addArgument:self.appDelegate.aacBitrate];

    [icecastSourceTaskItem addArgument:@"-u"];      // icecast server source user name
    [icecastSourceTaskItem addArgument:@"source"];

    NSString * icecastServerSourcePassword = [self.appDelegate.localRadioAppSettings valueForKey:@"IcecastServerSourcePassword"];

    [icecastSourceTaskItem addArgument:@"-pw"];  // icecast server password
    [icecastSourceTaskItem addArgument:icecastServerSourcePassword];

    [icecastSourceTaskItem addArgument:@"-m"];      // Icecast mount name
    [icecastSourceTaskItem addArgument:self.appDelegate.icecastServerMountName];

    NSString * httpsStreamURLString = [NSString stringWithFormat:@"https://%@:%ld/%@", hostName, self.appDelegate.icecastServerHTTPSPort, self.appDelegate.icecastServerMountName];

    [icecastSourceTaskItem addArgument:@"-o"];      // Icecast stream URL for display on Icecast web page
    [icecastSourceTaskItem addArgument:httpsStreamURLString];

    //NSString * applicationSupportDirectoryPath = [[NSFileManager defaultManager] applicationSupportDirectory];
    
    //[icecastSourceTaskItem addArgument:@"-cp"];      // icecast libshout certificates path
    //[icecastSourceTaskItem addArgument:applicationSupportDirectoryPath];

    // Create NSTasks
    @synchronized (self.icecastSourceTaskPipelineManager)
    {
        [self.icecastSourceTaskPipelineManager addTaskItem:udpListenerTaskItem];
        [self.icecastSourceTaskPipelineManager addTaskItem:aacEncoderTaskItem];
        [self.icecastSourceTaskPipelineManager addTaskItem:icecastSourceTaskItem];
    }
    
    [self.icecastSourceTaskPipelineManager startTasks];

    [self.appDelegate.statusIcecastSourceTextField performSelectorOnMainThread:@selector(setStringValue:) withObject:@"Running" waitUntilDone:NO];
    
    NSLog(@"IcecastSourceController startIcecastSourceTask startTasks");
}

//==================================================================================
//    icecastSourceTaskReceivedStderrData:
//==================================================================================

/*
- (void)icecastSourceTaskReceivedStderrData:(NSNotification *)notif {
    NSFileHandle *fh = [notif object];
    NSData *data = [fh availableData];
    if (data.length > 0)
    {
        // if data is found, re-register for more data (and print)
        [fh waitForDataInBackgroundAndNotify];
        NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSLog(@"IcecastSource: %@" ,str);
    }
}
*/

@end

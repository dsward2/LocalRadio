//
//  EZStreamController.h
//  LocalRadio
//
//  Created by Douglas Ward on 7/7/17.
//  Copyright © 2017 ArkPhone LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AppDelegate;
@class TaskPipelineManager;

@interface EZStreamController : NSObject

@property(strong) IBOutlet AppDelegate * appDelegate;

@property (strong) TaskPipelineManager * ezStreamTaskPipelineManager;

//@property (strong) NSTask * udpListenerTask;
//@property (strong) NSPipe * udpListenerTaskStandardErrorPipe;

//@property (strong) NSTask * ezStreamTask;
//@property (strong) NSPipe * ezStreamTaskStandardErrorPipe;

//@property (strong) NSTask * soxTask;
//@property (strong) NSPipe * soxTaskStandardErrorPipe;

//@property (strong) NSPipe * udpListenerSoxPipe;
//@property (strong) NSPipe * soxEZStreamPipe;

//@property (strong) NSString * quotedUDPListenerPath;
//@property (strong) NSString * quotedSoxPath;
//@property (strong) NSString * quotedEZStreamPath;

//@property (strong) NSString * udpListenerArgsString;
//@property (strong) NSString * soxArgsString;
//@property (strong) NSString * ezStreamArgsString;

//@property (assign) int ezStreamTaskProcessID;
//@property (assign) int soxTaskProcessID;
//@property (assign) int udpListenerTaskProcessID;

- (void)terminateTasks;

- (void)startEZStreamServer;
- (void)stopEZStreamServer;

@end

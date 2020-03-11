//
//  StreamingServerController.h
//  LocalRadio
//
//  Created by Douglas Ward on 2/17/20.
//  Copyright © 2020 ArkPhone LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AppDelegate;
@class TaskPipelineManager;

NS_ASSUME_NONNULL_BEGIN

@interface StreamingServerController : NSObject

@property (strong) IBOutlet AppDelegate * appDelegate;

@property (strong) TaskPipelineManager * streamingServerTaskPipelineManager;

@property (strong) NSString * audioFormat;

- (void)terminateTasks;

- (void)startStreamingServer;

- (void)restartStreamingServerIfNeeded;

@end

NS_ASSUME_NONNULL_END

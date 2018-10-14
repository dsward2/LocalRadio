//
//  EZStreamController.h
//  LocalRadio
//
//  Created by Douglas Ward on 7/7/17.
//  Copyright © 2017-2018 ArkPhone LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AppDelegate;
@class TaskPipelineManager;

@interface EZStreamController : NSObject

@property(strong) IBOutlet AppDelegate * appDelegate;

@property (strong) TaskPipelineManager * ezStreamTaskPipelineManager;

- (void)terminateTasks;

- (void)startEZStreamServer;
//- (void)stopEZStreamServer;

@end

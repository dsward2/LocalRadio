//
//  TaskPipelineManager.h
//  LocalRadio
//
//  Created by Douglas Ward on 12/21/17.
//  Copyright © 2017 ArkPhone LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

#define kTaskPipelineStatusIdle 0
#define kTaskPipelineStatusRunning 1
#define kTaskPipelineStatusTerminating 2
#define kTaskPipelineStatusTerminated 3

@class TaskItem;

@interface TaskPipelineManager : NSObject

@property (strong) NSMutableArray * taskItemsArray;
@property (assign) NSInteger taskPipelineStatus;

@property (strong) NSTimer * periodicTaskPipelineCheckTimer;

- (TaskItem *) makeTaskItemWithExecutable:(NSString *)executableName functionName:(NSString *)functionName;

- (void) addTaskItem:(TaskItem *)taskItem;

- (void) startTasks;

- (void) terminateTasks;

- (NSString *)tasksInfoString;

@end

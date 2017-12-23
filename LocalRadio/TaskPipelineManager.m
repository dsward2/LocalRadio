//
//  TaskPipelineManager.m
//  LocalRadio
//
//  Created by Douglas Ward on 12/21/17.
//  Copyright © 2017 ArkPhone LLC. All rights reserved.
//

#import "TaskPipelineManager.h"
#import "TaskItem.h"

@implementation TaskPipelineManager


- (instancetype)init
{
    self = [super init];
    if (self) {
        self.taskItemsArray = [NSMutableArray array];
    
        self.taskPipelineStatus = kTaskPipelineStatusIdle;
    }
    return self;
}




- (TaskItem *) makeTaskItemWithExecutable:(NSString *)executableName functionName:(NSString *)functionName
{
    NSString * executablePath = [NSBundle.mainBundle pathForAuxiliaryExecutable:executableName];
    executablePath = [executablePath stringByReplacingOccurrencesOfString:@" " withString:@"\\ "];
    
    TaskItem * taskItem = [[TaskItem alloc] init];
    
    taskItem.path = executablePath;
    taskItem.functionName = functionName;
    
    return taskItem;
}


- (void) addTaskItem:(TaskItem *)taskItem
{
    [self.taskItemsArray addObject:taskItem];
}



- (void) configureTaskPipes
{
    TaskItem * firstTaskItem = [self.taskItemsArray firstObject];
    TaskItem * lastTaskItem = [self.taskItemsArray lastObject];

    if (firstTaskItem != NULL)
    {
        [firstTaskItem.task setStandardInput:[NSPipe pipe]];       // empty pipe for first stage stdin
    }
    
    if (lastTaskItem != NULL)
    {
        [lastTaskItem.task setStandardOutput:[NSFileHandle fileHandleWithNullDevice]];  // set last task's stdout to /dev/null
    }
    
    for (TaskItem * taskItem in self.taskItemsArray)
    {
        if (taskItem != lastTaskItem)
        {
            // configure NSPipe to connect current task stdout to next task stdin

            NSPipe * intertaskPipe = [NSPipe pipe];

            [taskItem.task setStandardOutput:intertaskPipe];
            //[taskItem.task setStandardOutput:[NSFileHandle fileHandleWithNullDevice]];

            NSInteger currentTaskItemIndex = [self.taskItemsArray indexOfObject:taskItem];
            TaskItem * nextTaskItem = [self.taskItemsArray objectAtIndex:currentTaskItemIndex + 1];
            [nextTaskItem.task setStandardInput:intertaskPipe];
            
            [taskItem.task setStandardError:[NSFileHandle fileHandleWithNullDevice]];
        }
        else
        {
            // set last task's stdout to /dev/null
            [taskItem.task setStandardOutput:[NSFileHandle fileHandleWithNullDevice]];

            [taskItem.task setStandardError:[NSFileHandle fileHandleWithNullDevice]];
        }
    }
}


- (void) startTasks
{
    for (TaskItem * taskItem in self.taskItemsArray)
    {
        NSError * createTaskError = [taskItem createTask];
    }

    [self configureTaskPipes];
    
    //NSArray * reversedTaskItemsArray = [[self.taskItemsArray reverseObjectEnumerator] allObjects];

    //for (TaskItem * taskItem in reversedTaskItemsArray)
    for (TaskItem * taskItem in self.taskItemsArray)
    {
        NSError * startTaskError = [taskItem startTask];
        
        [NSThread sleepForTimeInterval:0.2f];
    }

    self.taskPipelineStatus = kTaskPipelineStatusRunning;
}


- (void) terminateTasks
{
    NSArray * reversedTaskItemsArray = [[self.taskItemsArray reverseObjectEnumerator] allObjects];

    for (TaskItem * taskItem in reversedTaskItemsArray)
    //for (TaskItem * taskItem in self.taskItemsArray)
    {
        NSError * terminateTaskError = [taskItem terminateTask];
    }
    
    [self.taskItemsArray removeAllObjects];

    self.taskPipelineStatus = kTaskPipelineStatusTerminated;

    [NSThread sleepForTimeInterval:0.1f];
}


- (NSString *)tasksInfoString
{
    NSMutableString * tasksInfoString = [NSMutableString stringWithString:@"\n\n"];
    
    if (self.taskItemsArray.count > 0)
    {
        for (TaskItem * taskItem in self.taskItemsArray)
        {
            NSString * taskInfoString = [taskItem taskInfoString];
            
            [tasksInfoString appendString:taskInfoString];
        }
    }
    else
    {
        [tasksInfoString appendString:@"No tasks currently running\n\n"];
    }

    return tasksInfoString;
}



@end

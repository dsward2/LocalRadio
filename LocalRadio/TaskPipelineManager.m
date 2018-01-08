//
//  TaskPipelineManager.m
//  LocalRadio
//
//  Created by Douglas Ward on 12/21/17.
//  Copyright © 2017 ArkPhone LLC. All rights reserved.
//

#import "TaskPipelineManager.h"
#import "TaskItem.h"
#import "AppDelegate.h"

@implementation TaskPipelineManager


- (void) dealloc
{
    [self.periodicTaskPipelineCheckTimer invalidate];
    self.periodicTaskPipelineCheckTimer = NULL;
}




- (instancetype)init
{
    self = [super init];
    if (self) {
        self.taskItemsArray = [NSMutableArray array];
    
        self.taskPipelineStatus = kTaskPipelineStatusIdle;

        self.periodicTaskPipelineCheckTimer = [NSTimer timerWithTimeInterval:5.0f target:self selector:@selector(periodicTaskPipelineCheckTimerFired:) userInfo:self repeats:YES];

        [[NSRunLoop mainRunLoop] addTimer:self.periodicTaskPipelineCheckTimer forMode:NSDefaultRunLoopMode];
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
    @synchronized (self)
    {
        for (TaskItem * taskItem in self.taskItemsArray)
        {
            NSError * createTaskError = [taskItem createTask];
        }

        [self configureTaskPipes];
        
        for (TaskItem * taskItem in self.taskItemsArray)
        {
            NSError * startTaskError = [taskItem startTask];
            
            [NSThread sleepForTimeInterval:0.2f];
        }

        self.taskPipelineStatus = kTaskPipelineStatusRunning;
    }
}




- (void) terminateTasks
{
    @synchronized (self)
    {
        self.taskPipelineStatus = kTaskPipelineStatusTerminating;

        for (TaskItem * taskItem in self.taskItemsArray)
        {
            if (taskItem.task.isRunning == YES)
            {
                @try {
                    NSError * terminateTaskError = [taskItem terminateTask];
                }
                @catch (NSException *exception) {
                    
                }
            }
        }
        
        [self.taskItemsArray removeAllObjects];
    }

    [NSThread sleepForTimeInterval:0.1f];

    self.taskPipelineStatus = kTaskPipelineStatusTerminated;
}



- (void) periodicTaskPipelineCheckTimerFired:(NSTimer *)timer
{
    BOOL failedTaskFound = NO;
    TaskItem * failedTaskItem = NULL;
    
    @synchronized (self)
    {
        for (TaskItem * taskItem in self.taskItemsArray)
        {
            if (taskItem.task.isRunning == NO)
            {
                failedTaskFound = YES;
                failedTaskItem = taskItem;
                break;
            }
        }
    }

    if (failedTaskFound == YES)
    {
        NSLog(@"TaskPipelineManager - TaskPipelineFailed - %@ - %@", failedTaskItem, self.taskItemsArray);

        [[NSNotificationCenter defaultCenter] postNotificationName:@"TaskPipelineFailedNotification" object:self];

        [self terminateTasks];
        
        AppDelegate * appDelegate = (AppDelegate *)[NSApp delegate];

        [appDelegate updateCurrentTasksText];
    }
}




- (NSString *)tasksInfoString
{
    NSMutableString * tasksInfoString = [NSMutableString stringWithString:@"\n\n"];
    
    if (self.taskItemsArray.count > 0)
    {
        @synchronized (self)
        {
            for (TaskItem * taskItem in self.taskItemsArray)
            {
                NSString * taskInfoString = [taskItem taskInfoString];
                
                [tasksInfoString appendString:taskInfoString];
            }
        }
    }
    else
    {
        [tasksInfoString appendString:@"No tasks currently running\n\n"];
    }

    return tasksInfoString;
}



@end

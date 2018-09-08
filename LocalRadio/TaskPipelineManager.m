//
//  TaskPipelineManager.m
//  LocalRadio
//
//  Created by Douglas Ward on 12/21/17.
//  Copyright © 2017-2018 ArkPhone LLC. All rights reserved.
//

#import "TaskPipelineManager.h"
#import "TaskItem.h"
#import "AppDelegate.h"
#import "IcecastController.h"
#import "LocalRadioAppSettings.h"

@implementation TaskPipelineManager

//==================================================================================
//    dealloc
//==================================================================================

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [self.periodicTaskPipelineCheckTimer invalidate];
    self.periodicTaskPipelineCheckTimer = NULL;
}

//==================================================================================
//    init
//==================================================================================

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

//==================================================================================
//    makeTaskItemWithExecutable:functionName:
//==================================================================================

- (TaskItem *) makeTaskItemWithExecutable:(NSString *)executableName functionName:(NSString *)functionName
{
    NSString * executablePath = [NSBundle.mainBundle pathForAuxiliaryExecutable:executableName];
    executablePath = [executablePath stringByReplacingOccurrencesOfString:@" " withString:@"\\ "];
    
    TaskItem * taskItem = [[TaskItem alloc] init];
    
    taskItem.path = executablePath;
    taskItem.functionName = functionName;
    
    return taskItem;
}

//==================================================================================
//    makeTaskItemWithPathToExecutable:functionName:
//==================================================================================

- (TaskItem *) makeTaskItemWithPathToExecutable:(NSString *)executablePath functionName:(NSString *)functionName
{
    TaskItem * taskItem = [[TaskItem alloc] init];
    
    taskItem.path = executablePath;
    taskItem.functionName = functionName;
    
    return taskItem;
}

//==================================================================================
//    addTaskItem:
//==================================================================================

- (void) addTaskItem:(TaskItem *)taskItem
{
    [self.taskItemsArray addObject:taskItem];
}

//==================================================================================
//    configureTaskPipes
//==================================================================================

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
            
            //[taskItem.task setStandardError:[NSFileHandle fileHandleWithNullDevice]];
        }
        else
        {
            // set last task's stdout to /dev/null
            [taskItem.task setStandardOutput:[NSFileHandle fileHandleWithNullDevice]];

            //[taskItem.task setStandardError:[NSFileHandle fileHandleWithNullDevice]];
        }

        AppDelegate * appDelegate = (AppDelegate *)[NSApp delegate];
        NSNumber * captureStderrNumber = [appDelegate.localRadioAppSettings integerForKey:@"CaptureStderr"];
        BOOL captureStderr = captureStderrNumber.boolValue;
        
        if (captureStderr == YES)
        {
            // send stderr from the NSTask to this object, which calls NSLog()
            taskItem.stderrPipe = [NSPipe pipe];
            [taskItem.task setStandardError:taskItem.stderrPipe];

            NSFileHandle * stderrFile = taskItem.stderrPipe.fileHandleForReading;

            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(taskReceivedStderrData:) name:NSFileHandleDataAvailableNotification object:stderrFile];

            [stderrFile waitForDataInBackgroundAndNotify];
            NSLog(@"LocalRadio TaskPipelineManager configureTaskPipes - captureStderr = YES");
        }
        else
        {
            // send the NSTask's stderr to /dev/null
            [taskItem.task setStandardError:[NSFileHandle fileHandleWithNullDevice]];
            NSLog(@"LocalRadio TaskPipelineManager configureTaskPipes - captureStderr = NO");
        }
    }
}

//==================================================================================
//    taskReceivedStderrData:
//==================================================================================

- (void)taskReceivedStderrData:(NSNotification *)notif {

    NSFileHandle * fileHandle = [notif object];
    NSData * data = [fileHandle availableData];
    if (data.length > 0)
    {
        // if data is found, re-register for more data (and print)
        NSString * str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSLog(@"LocalRadio stderr: %@" , str);
    }
    [fileHandle waitForDataInBackgroundAndNotify];
}

//==================================================================================
//    startTasks
//==================================================================================

- (void) startTasks
{
    @synchronized (self)
    {
        for (TaskItem * taskItem in self.taskItemsArray)
        {
            NSError * createTaskError = [taskItem createTask];
            
            if (createTaskError != NULL)
            {
                NSLog(@"LocalRadio TaskPipelineManager startTasks - createTaskError - %@", createTaskError);
            }
        }

        [self configureTaskPipes];
        
        for (TaskItem * taskItem in self.taskItemsArray)
        {
            NSError * startTaskError = [taskItem startTask];
            
            if (startTaskError != NULL)
            {
                NSLog(@"LocalRadio TaskPipelineManager startTasks - startTaskError - %@", startTaskError);
            }
            
            [NSThread sleepForTimeInterval:0.2f];
        }

        self.taskPipelineStatus = kTaskPipelineStatusRunning;
    }
}

//==================================================================================
//    terminateTasks
//==================================================================================

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

//==================================================================================
//    periodicTaskPipelineCheckTimerFired
//==================================================================================

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
        NSLog(@"LocalRadio TaskPipelineManager - TaskPipelineFailed - %@ - %@", failedTaskItem, self.taskItemsArray);

        [[NSNotificationCenter defaultCenter] postNotificationName:@"TaskPipelineFailedNotification" object:self];

        [self terminateTasks];
        
        AppDelegate * appDelegate = (AppDelegate *)[NSApp delegate];

        [appDelegate updateCurrentTasksText:self];
    }
}

//==================================================================================
//    tasksInfoString
//==================================================================================

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

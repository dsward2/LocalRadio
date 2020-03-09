//
//  TaskPipelineManager.m
//  LocalRadio
//
//  Created by Douglas Ward on 12/21/17.
//  Copyright © 2017-2020 ArkPhone LLC. All rights reserved.
//

#import "TaskPipelineManager.h"
#import "TaskItem.h"
#import "AppDelegate.h"
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
        
        self.taskInfoStringSyncObject = [[NSObject alloc] init];
        self.startTasksSyncObject = [[NSObject alloc] init];
        self.terminateTasksSyncObject = [[NSObject alloc] init];
        self.periodicSyncObject = [[NSObject alloc] init];

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
        //[firstTaskItem.task setStandardInput:[NSPipe pipe]];       // empty pipe for first stage stdin
        [firstTaskItem.task setStandardInput:[NSFileHandle fileHandleWithNullDevice]];       // null device for first stage stdin
    }
    
    /*
    if (lastTaskItem != NULL)
    {
        [lastTaskItem.task setStandardOutput:[NSFileHandle fileHandleWithNullDevice]];  // set last task's stdout to /dev/null
    }
    */
    
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
        }
        else
        {
            // set last task's stdout to /dev/null
            [taskItem.task setStandardOutput:[NSFileHandle fileHandleWithNullDevice]];
        }

        //AppDelegate * appDelegate = (AppDelegate *)[NSApp delegate];

        __block AppDelegate * appDelegate = NULL;
        
        if ([(NSThread*)[NSThread currentThread] isMainThread] == NO)
        {
            dispatch_sync(dispatch_get_main_queue(), ^{
                appDelegate = (AppDelegate *)[NSApp delegate];
            });
        }
        else
        {
            appDelegate = (AppDelegate *)[NSApp delegate];
        }


        NSNumber * captureStderrNumber = [appDelegate.localRadioAppSettings integerNumberForKey:@"CaptureStderr"];
        BOOL captureStderr = captureStderrNumber.boolValue;
        
        if (captureStderr == YES)
        {
            /*
            // send stderr from the NSTask to this object, which calls NSLog()
            taskItem.stderrPipe = [NSPipe pipe];
            [taskItem.task setStandardError:taskItem.stderrPipe];

            NSFileHandle * stderrFile = taskItem.stderrPipe.fileHandleForReading;

            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(taskReceivedStderrData:) name:NSFileHandleDataAvailableNotification object:stderrFile];

            [stderrFile waitForDataInBackgroundAndNotify];
            NSLog(@"LocalRadio TaskPipelineManager configureTaskPipes - captureStderr = YES - taskItem = %@", taskItem.path);
            */
        }
        else
        {
            // send the NSTask's stderr to /dev/null
            [taskItem.task setStandardError:[NSFileHandle fileHandleWithNullDevice]];
            NSLog(@"LocalRadio TaskPipelineManager configureTaskPipes - captureStderr = NO - taskItem = %@", taskItem.path);
        }
    }
}

//==================================================================================
//    taskReceivedStderrData:
//==================================================================================

- (void)taskReceivedStderrData:(NSNotification *)notif {

    id notifObject = [notif object];
    if ([[notifObject class] isKindOfClass:[NSFileHandle class]] == YES)
    {
        NSFileHandle * fileHandle = notifObject;
        NSData * data = [fileHandle availableData];
        if (data.length > 0)
        {
            NSString * str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            NSLog(@"LocalRadio stderr: %@" , str);
        }
        // request more data
        [fileHandle waitForDataInBackgroundAndNotify];
    }
    else
    {
        NSLog(@"LocalRadio taskReceivedStderrData error %@, %@", notif, notifObject);
    }
}

//==================================================================================
//    startTasks
//==================================================================================

- (void) startTasks
{
    @synchronized (self.startTasksSyncObject)
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

        //AppDelegate * appDelegate = (AppDelegate *)[NSApp delegate];

        __block AppDelegate * appDelegate = NULL;
        
        if ([(NSThread*)[NSThread currentThread] isMainThread] == NO)
        {
            dispatch_sync(dispatch_get_main_queue(), ^{
                appDelegate = (AppDelegate *)[NSApp delegate];
            });
        }
        else
        {
            appDelegate = (AppDelegate *)[NSApp delegate];
        }

        [appDelegate updateCurrentTasksText:self];
    }
}

//==================================================================================
//    terminateTasks
//==================================================================================

- (void) terminateTasks
{
    @synchronized (self.terminateTasksSyncObject)
    {
        self.taskPipelineStatus = kTaskPipelineStatusTerminating;

        for (TaskItem * taskItem in self.taskItemsArray)
        {
            if (taskItem.task.isRunning == YES)
            {
                @try {
                    NSError * terminateTaskError = [taskItem terminateTask];
                    #pragma unused(terminateTaskError)
                }
                @catch (NSException *exception) {
                    
                }
            }
        }

        [self.taskItemsArray removeAllObjects];
    }

    [NSThread sleepForTimeInterval:0.1f];

    self.taskPipelineStatus = kTaskPipelineStatusTerminated;

    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

//==================================================================================
//    periodicTaskPipelineCheckTimerFired
//==================================================================================

- (void) periodicTaskPipelineCheckTimerFired:(NSTimer *)timer
{
    BOOL failedTaskFound = NO;
    TaskItem * failedTaskItem = NULL;
    
    @synchronized (self.periodicSyncObject)
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
        NSLog(@"LocalRadio TaskPipelineManager error - TaskPipelineFailed - %@ - %@", failedTaskItem, self.taskItemsArray);

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
    NSMutableString * tasksInfoString = [NSMutableString string];
    
    if (self.taskItemsArray.count > 0)
    {
        @synchronized (self.taskInfoStringSyncObject)
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

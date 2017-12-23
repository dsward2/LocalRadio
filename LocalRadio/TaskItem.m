//
//  TaskItem.m
//  LocalRadio
//
//  Created by Douglas Ward on 12/21/17.
//  Copyright © 2017 ArkPhone LLC. All rights reserved.
//

#import "TaskItem.h"
#import "AppDelegate.h"

@implementation TaskItem


- (instancetype)init
{
    self = [super init];
    if (self) {
        self.argsArray = [NSMutableArray array];
    }
    return self;
}



- (void) addArgument:(NSString *)argItem
{
    NSString * fixedArgItem = argItem;
    if ([argItem isKindOfClass:[NSNumber class]] == YES)
    {
        NSNumber * numberItem = (NSNumber *)argItem;
        fixedArgItem = [numberItem stringValue];
    }

    [self.argsArray addObject:fixedArgItem];
}



- (NSString *) quotedPath
{
    return self.path;
}



- (NSString *) argsString
{
    NSMutableArray * fixedArgsArray = [NSMutableArray array];
    
    for (NSString * aArg in self.argsArray)
    {
        NSRange spaceRange = [aArg rangeOfString:@" "];
        if (spaceRange.location != NSNotFound)
        {
            // a space character was found, add quote characters around the argument
            NSString * fixedArg = [NSString stringWithFormat:@"\"%@\"", aArg];
            [fixedArgsArray addObject:fixedArg];
        }
        else
        {
            [fixedArgsArray addObject:aArg];
        }
    }

    NSString * argsString = [fixedArgsArray componentsJoinedByString:@" "];

    return argsString;
}



- (NSError *) createTask
{
    self.task = [[NSTask alloc] init];
    self.task.launchPath = self.path;
    self.task.arguments = self.argsArray;

    TaskItem * weakSelf = self;

    [self.task setTerminationHandler:^(NSTask* task)
    {
        int processIdentifier = task.processIdentifier;
        int terminationStatus = task.terminationStatus;
        long terminationReason = task.terminationReason;
        
        NSLog(@"TaskItem %@ enter terminationHandler, PID=%d", weakSelf.path, processIdentifier);

        if ([task terminationStatus] == 0)
        {
            NSLog(@"TaskItem - terminationStatus 0");
            NSLog(@"TaskItem - terminationReason %ld", terminationReason);
        }
        else
        {
            NSLog(@"TaskItem - terminationStatus %d", terminationStatus);
            NSLog(@"TaskItem - terminationReason %ld", terminationReason);
        }
        
        weakSelf.task = NULL;
        
        AppDelegate * appDelegate = (AppDelegate *)[NSApp delegate];

        [appDelegate updateCurrentTasksText];

        NSLog(@"TaskItem exit %@ terminationHandler, PID=%d", weakSelf.functionName, processIdentifier);
    }];


    return NULL;
}




- (NSError *) startTask
{
    [self.task launch];
    
    NSLog(@"TaskItem - Launched NSTask  PID=%d, %@  %@", self.task.processIdentifier, self.path, self.argsString);

    return NULL;
}



- (NSError *) terminateTask
{
    [self.task terminate];

    /*
    while ([self.task isRunning] == YES)
    {
        [NSThread sleepForTimeInterval:0.1f];
    }
    */

    return NULL;
}



- (NSString *) taskInfoString
{
    /* format like -
    SDRController rtl_fm_localradio - process ID = 11989

    "/Applications/LocalRadio.app/Contents/MacOS/rtl_fm_localradio" -M am -l 400 -t 3 -F 9 -g 49.6 -s 5000 -o 4 -A std -p 0 -c 17004 -E pad -E agc -f 118700000 -f 118950000 -f 119500000 -f 135400000 -f 257800000 -f 306200000 -f 339800000 -f 353600000 -f 119100000
    */
    
    NSMutableString * taskInfoString = [NSMutableString string];
    
    [taskInfoString appendString:self.functionName];
    [taskInfoString appendString:@" -  process ID = "];
    NSString * processIDString = [NSString stringWithFormat:@"%d", self.task.processIdentifier];
    [taskInfoString appendString:processIDString];
    [taskInfoString appendString:@" -  isRunning = "];
    NSString * terminationStatusString = [NSString stringWithFormat:@"%d", self.task.isRunning];
    [taskInfoString appendString:terminationStatusString];
    [taskInfoString appendString:@"\n\n"];
    
    [taskInfoString appendString:@"\""];
    [taskInfoString appendString:self.path];
    [taskInfoString appendString:@"\" "];
    [taskInfoString appendString:self.argsString];
    [taskInfoString appendString:@"\n\n"];
    
    return taskInfoString;
}


@end

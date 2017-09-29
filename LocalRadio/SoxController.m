//
//  SoxController.m
//  LocalRadio
//
//  Created by Douglas Ward on 7/19/17.
//  Copyright © 2017 ArkPhone LLC. All rights reserved.
//

//  Used in LocalRadio to pipe audio from an external application via Core Audio virtual device, to Icecast

#import "SoxController.h"
#import "AppDelegate.h"

@implementation SoxController

//==================================================================================
//	terminateTasks
//==================================================================================

- (void)terminateTasks
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [self stopSoxTask];
    [self stopUDPSenderTask];
}

//==================================================================================
//	stopSoxTask
//==================================================================================

- (void)stopSoxTask
{
    NSLog(@"SoxController stopSoxTask enter");

    if ([(NSThread*)[NSThread currentThread] isMainThread] == YES)
    {
        NSLog(@"stopSoxTask called on main thread");
    }
    
    if (self.soxTask != NULL)
    {
        if (self.soxTask.isRunning == YES)
        {
            NSLog(@"SoxController stopSoxTask sending terminate signal to soxTask");
            [self.soxTask terminate];
        }

        while (self.soxTask != NULL)
        {
            //NSLog(@"SoxController stopSoxTask waiting for self.soxTask != NULL");
            [NSThread sleepForTimeInterval:0.1f];
        }
    }

    NSLog(@"SoxController stopSoxTask exit");
}

//==================================================================================
//	stopUDPSenderTask
//==================================================================================

- (void)stopUDPSenderTask
{
    NSLog(@"SoxController stopUDPSenderTask enter");

    if ([(NSThread*)[NSThread currentThread] isMainThread] == YES)
    {
        NSLog(@"stopUDPSenderTask called on main thread");
    }

    if (self.udpSenderTask != NULL)
    {
        if (self.udpSenderTask.isRunning == YES)
        {
            NSLog(@"SoxController stopUDPSenderTask sending terminate signal to udpSenderTask");
            [self.udpSenderTask terminate];
        }

        while (self.udpSenderTask != NULL)
        {
            //NSLog(@"SoxController stopUDPSenderTask waiting for self.udpSenderTask != NULL");
            [NSThread sleepForTimeInterval:0.1f];
        }
    }

    NSLog(@"SoxController stopUDPSenderTask exit");
}

//==================================================================================
//	startSecondaryStreamForFrequencies:category:
//==================================================================================

/*
- (void)startSecondaryStreamForFrequenciesOLD:(NSArray *)frequenciesArray category:(NSDictionary *)categoryDictionary
{
    NSString * streamSourceString = @"";
    
    if (categoryDictionary == NULL)
    {
        if (frequenciesArray.count == 1)
        {
            NSDictionary * firstFrequencyDictionary = frequenciesArray.firstObject;
            
            streamSourceString = [firstFrequencyDictionary objectForKey:@"stream_source"];
        }
        else
        {
            NSLog(@"LocalRadio error - wrong frequenciesArray.count");
        }
    }
    else
    {
        streamSourceString = [categoryDictionary objectForKey:@"scan_stream_source"];
    }

    NSCharacterSet * whitespaceCharacterSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    streamSourceString = [streamSourceString stringByTrimmingCharactersInSet:whitespaceCharacterSet];

    // construct commands for output to UDPListener/EZStream

    // "~/Library/Developer/Xcode/DerivedData/LocalRadio-ddsodcaiskiovrbpbiioihlrnhbo/Build/Products/Debug/LocalRadio.app/Contents/MacOS/sox" -r 48000 -e signed-integer -b 16 -t coreaudio "Soundflower (2ch)" -c 2 -t coreaudio "Built-in Line Out" vol 10
    
    // To monitor Soundflower (64) live -
    //"~/Library/Developer/Xcode/DerivedData/LocalRadio-ddsodcaiskiovrbpbiioihlrnhbo/Build/Products/Debug/LocalRadio.app/Contents/MacOS/sox" -e signed-integer -b 16 -c 1 -t coreaudio "Soundflower (64ch)"  -t coreaudio "Built-in Line Output"
    
    NSString * soxPath = [NSBundle.mainBundle pathForAuxiliaryExecutable:@"sox"];
    NSString * udpSenderPath = [NSBundle.mainBundle pathForAuxiliaryExecutable:@"UDPSender"];
    
    NSMutableString * outputCommand = [NSMutableString stringWithFormat:@"\"%@\" ", soxPath];
    
    [outputCommand appendString:@"-V0 "];        // verbosity
    [outputCommand appendString:@"-q "];        // quiet mode
    [outputCommand appendString:@"-r 48000 "];
    [outputCommand appendString:@"-e signed-integer "];
    [outputCommand appendString:@"-b 16 "];
    //[outputCommand appendString:@"-c 1 "];
    [outputCommand appendString:@"-t coreaudio "];
    [outputCommand appendFormat:@"\"%@\" ", streamSourceString];
    [outputCommand appendString:@"-e signed-integer "];
    [outputCommand appendString:@"-b 16 "];
    [outputCommand appendString:@"-c 1 "];
    [outputCommand appendString:@"-t raw "];
    [outputCommand appendString:@"- "];         // stdout
    [outputCommand appendString:@"rate 48000 "];
    [outputCommand appendString:@"vol 10 "];
    [outputCommand appendString:@"dither -s "]; // hopefully, add some noise to keep audio streaming alive
    
    [outputCommand appendFormat:@"| \"%@\" ", udpSenderPath];         // pipe
    
    //[outputCommand appendString:@"-p "];
    //[outputCommand appendString:@"1234 "];
    NSString * audioPort = self.appDelegate.audioPortTextField.stringValue;
    [outputCommand appendFormat:@"-p %@ ", audioPort];

    //[outputCommand appendString:@"| /dev/null "];
    
    outputCommand = [[outputCommand stringByTrimmingCharactersInSet:whitespaceCharacterSet] mutableCopy];

    self.udpSenderArgsString = outputCommand;
    
    //sox -r 48000 -e signed -b 16 -c 1 -t raw - -t coreaudio "Soundflower (64ch)" vol 1

    NSArray * outputArgsArray = [NSArray arrayWithObjects:@"-c", outputCommand, NULL];
    
    NSLog(@"SoxController - startSecondaryStreamForFrequencies - launching sox NSTask: %@", outputCommand);

    self.soxTask = [[NSTask alloc] init];
    self.soxTask.launchPath = @"/bin/bash";
    self.soxTask.arguments = outputArgsArray;
    
    self.soxTaskStandardErrorPipe = [NSPipe pipe];
    [self.soxTask setStandardError:self.soxTaskStandardErrorPipe];
    NSFileHandle * standardErrorFileHandle = [self.soxTaskStandardErrorPipe fileHandleForReading];
    [standardErrorFileHandle waitForDataInBackgroundAndNotify];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(soxTaskReceivedStderrData:) name:NSFileHandleDataAvailableNotification object:standardErrorFileHandle];

    [self.soxTask setStandardOutput:[NSFileHandle fileHandleWithNullDevice]]; // send stdout to /dev/null
    
    SoxController * weakSelf = self;
    
    [self.soxTask setTerminationHandler:^(NSTask* task)
    {           
        int processIdentifier = task.processIdentifier;
        int terminationStatus = task.terminationStatus;
        long terminationReason = task.terminationReason;
        
        NSLog(@"SoxController enter sox terminationHandler, PID=%d", processIdentifier);

        if ([task terminationStatus] == 0)
        {
            NSLog(@"SoxController - startSecondaryStreamForFrequencies - terminationStatus 0");
            NSLog(@"SoxController - startSecondaryStreamForFrequencies - terminationReason %ld", terminationReason);
        }
        else
        {
            NSLog(@"SoxController - startSecondaryStreamForFrequencies - terminationStatus %d", terminationStatus);
            NSLog(@"SoxController - startSecondaryStreamForFrequencies - terminationReason %ld", terminationReason);
        }

        //[NSThread sleepForTimeInterval:1.0f];
        
        weakSelf.soxTask = NULL;
        weakSelf.soxTaskStandardErrorPipe = NULL;

        [weakSelf.appDelegate updateCurrentTasksText];

        NSLog(@"SoxController exit sox terminationHandler, PID=%d", processIdentifier);
    }];
    
    NSLog(@"launch soxTask");
    
    [self.soxTask launch];

    NSLog(@"SoxController - Launched NSTask  soxTask, PID=%d", self.soxTask.processIdentifier);

}

*/


//==================================================================================
//	startSecondaryStreamForFrequencies:category:
//==================================================================================

- (void)startSecondaryStreamForFrequencies:(NSArray *)frequenciesArray category:(NSDictionary *)categoryDictionary
{
    NSString * streamSourceString = @"";
    
    if (categoryDictionary == NULL)
    {
        if (frequenciesArray.count == 1)
        {
            NSDictionary * firstFrequencyDictionary = frequenciesArray.firstObject;
            
            streamSourceString = [firstFrequencyDictionary objectForKey:@"stream_source"];
        }
        else
        {
            NSLog(@"LocalRadio error - wrong frequenciesArray.count");
        }
    }
    else
    {
        streamSourceString = [categoryDictionary objectForKey:@"scan_stream_source"];
    }

    NSCharacterSet * whitespaceCharacterSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    streamSourceString = [streamSourceString stringByTrimmingCharactersInSet:whitespaceCharacterSet];

    // construct commands for output to UDPListener/EZStream

    // "~/Library/Developer/Xcode/DerivedData/LocalRadio-ddsodcaiskiovrbpbiioihlrnhbo/Build/Products/Debug/LocalRadio.app/Contents/MacOS/sox" -r 48000 -e signed-integer -b 16 -t coreaudio "Soundflower (2ch)" -c 2 -t coreaudio "Built-in Line Out" vol 10
    
    // To monitor Soundflower (64) live -
    //"~/Library/Developer/Xcode/DerivedData/LocalRadio-ddsodcaiskiovrbpbiioihlrnhbo/Build/Products/Debug/LocalRadio.app/Contents/MacOS/sox" -e signed-integer -b 16 -c 1 -t coreaudio "Soundflower (64ch)"  -t coreaudio "Built-in Line Output"
    
    NSString * soxPath = [NSBundle.mainBundle pathForAuxiliaryExecutable:@"sox"];
    soxPath = [soxPath stringByReplacingOccurrencesOfString:@" " withString:@"\\ "];
    self.quotedSoxPath = [NSMutableString stringWithFormat:@"\"%@\"", soxPath];
    NSMutableArray * soxArgsArray = [NSMutableArray array];
    
    NSString * udpSenderPath = [NSBundle.mainBundle pathForAuxiliaryExecutable:@"UDPSender"];
    udpSenderPath = [udpSenderPath stringByReplacingOccurrencesOfString:@" " withString:@"\\ "];
    self.quotedUDPSenderPath = [NSString stringWithFormat:@"\"%@\"", udpSenderPath];
    NSMutableArray * udpSenderArgsArray = [NSMutableArray array];

    // sox input
    [soxArgsArray addObject:@"-V2"];    // debug verbosity, -V2 shows failures and warnings
    [soxArgsArray addObject:@"-q"];     // quiet mode - don't show terminal-style audio meter
    [soxArgsArray addObject:@"-r"];     // sample rate
    [soxArgsArray addObject:@"48000"];
    [soxArgsArray addObject:@"-e"];     // data type
    [soxArgsArray addObject:@"signed-integer"];
    [soxArgsArray addObject:@"-b"];     // bits per channel
    [soxArgsArray addObject:@"16"];
    [soxArgsArray addObject:@"-c"];     // channels
    //[soxArgsArray addObject:@"1"];
    [soxArgsArray addObject:@"2"];
    [soxArgsArray addObject:@"-t"];      // audio format
    [soxArgsArray addObject:@"coreaudio"];
    
    [soxArgsArray addObject:streamSourceString];    // quotes are omitted intentionally
    
    //sox output
    [soxArgsArray addObject:@"-e"];     // data type
    [soxArgsArray addObject:@"signed-integer"];
    [soxArgsArray addObject:@"-b"];     // bits per channel
    [soxArgsArray addObject:@"16"];
    [soxArgsArray addObject:@"-c"];     // one channel
    [soxArgsArray addObject:@"1"];
    [soxArgsArray addObject:@"-t"];      // audio format
    [soxArgsArray addObject:@"raw"];
    [soxArgsArray addObject:@"-"];       // pipe output
    [soxArgsArray addObject:@"rate"];     // sox audio processing chain
    [soxArgsArray addObject:@"48000"];    // sox audio processing chain
    [soxArgsArray addObject:@"vol"];      // sox audio processing chain
    [soxArgsArray addObject:@"10"];       // sox audio processing chain
    [soxArgsArray addObject:@"dither"];   // sox audio processing chain
    [soxArgsArray addObject:@"-s"];       // sox audio processing chain
    
    
    [udpSenderArgsArray addObject:@"-p"];
    NSString * audioPort = self.appDelegate.audioPortTextField.stringValue;
    [udpSenderArgsArray addObject:audioPort];

    // sox will output to UDPSender
    self.soxTask = [[NSTask alloc] init];
    self.soxTask.launchPath = soxPath;
    self.soxTask.arguments = soxArgsArray;

    self.udpSenderTask = [[NSTask alloc] init];
    self.udpSenderTask.launchPath = udpSenderPath;
    self.udpSenderTask.arguments = udpSenderArgsArray;
    
    // configure NSPipe to connect sox stdout to udpSender stdin
    self.soxUDPSenderPipe = [NSPipe pipe];
    
    [self.soxTask setStandardOutput:self.soxUDPSenderPipe];
    [self.udpSenderTask setStandardInput:self.soxUDPSenderPipe];
    
    [self.udpSenderTask setStandardOutput:[NSFileHandle fileHandleWithNullDevice]]; // last stage stdout to /dev/null

    SoxController * weakSelf = self;
    
    [self.soxTask setTerminationHandler:^(NSTask* task)
    {           
        int processIdentifier = task.processIdentifier;
        int terminationStatus = task.terminationStatus;
        long terminationReason = task.terminationReason;
        
        NSLog(@"SoxController enter sox terminationHandler, PID=%d", processIdentifier);

        if ([task terminationStatus] == 0)
        {
            NSLog(@"SoxController - startSecondaryStreamForFrequencies - terminationStatus 0");
            NSLog(@"SoxController - startSecondaryStreamForFrequencies - terminationReason %ld", terminationReason);
        }
        else
        {
            NSLog(@"SoxController - startSecondaryStreamForFrequencies - terminationStatus %d", terminationStatus);
            NSLog(@"SoxController - startSecondaryStreamForFrequencies - terminationReason %ld", terminationReason);
        }

        //[NSThread sleepForTimeInterval:1.0f];
        
        weakSelf.soxTask = NULL;
        weakSelf.soxTaskStandardErrorPipe = NULL;
        weakSelf.soxTaskProcessID = 0;

        [weakSelf.appDelegate updateCurrentTasksText];

        NSLog(@"SoxController exit sox terminationHandler, PID=%d", processIdentifier);
    }];
    
    [self.udpSenderTask setTerminationHandler:^(NSTask* task)
    {           
        int processIdentifier = task.processIdentifier;
        int terminationStatus = task.terminationStatus;
        long terminationReason = task.terminationReason;
        
        NSLog(@"SoxController enter udpSenderTask terminationHandler, PID=%d", processIdentifier);

        if ([task terminationStatus] == 0)
        {
            NSLog(@"SoxController - startSecondaryStreamForFrequencies udpSenderTask - terminationStatus 0");
            NSLog(@"SoxController - startSecondaryStreamForFrequencies udpSenderTask - terminationReason %ld", terminationReason);
        }
        else
        {
            NSLog(@"SoxController - startSecondaryStreamForFrequencies udpSenderTask - terminationStatus %d", terminationStatus);
            NSLog(@"SoxController - startSecondaryStreamForFrequencies udpSenderTask - terminationReason %ld", terminationReason);
        }

        //[NSThread sleepForTimeInterval:1.0f];
        
        weakSelf.udpSenderTask = NULL;
        weakSelf.udpSenderTaskStandardErrorPipe = NULL;
        weakSelf.udpSenderTaskProcessID = 0;

        [weakSelf.appDelegate updateCurrentTasksText];

        NSLog(@"SoxController exit udpSenderTask terminationHandler, PID=%d", processIdentifier);
    }];

    self.soxTaskArgsString = [soxArgsArray componentsJoinedByString:@" "];
    self.udpSenderTaskArgsString = [udpSenderArgsArray componentsJoinedByString:@" "];

    [self.soxTask launch];
    NSLog(@"SoxController - Launched NSTask soxTask, PID=%d, args= %@ %@", self.soxTask.processIdentifier, self.quotedSoxPath, self.soxTaskArgsString);

    [self.udpSenderTask launch];
    NSLog(@"SoxController - Launched NSTask udpSenderTask, PID=%d, args= %@ %@", self.udpSenderTask.processIdentifier, self.quotedUDPSenderPath, self.udpSenderTaskArgsString);
}

//==================================================================================
//	soxTaskReceivedStderrData:
//==================================================================================

- (void)soxTaskReceivedStderrData:(NSNotification *)notif {

    NSFileHandle *fh = [notif object];
    NSData *data = [fh availableData];
    if (data.length > 0)
    {
        // if data is found, re-register for more data (and print)
        [fh waitForDataInBackgroundAndNotify];
        NSString * str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSLog(@"sox: %@" , str);
    }
}




@end

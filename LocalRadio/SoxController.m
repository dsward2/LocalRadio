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
    [self stopSoxTask];
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

    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    if (self.soxTask != NULL)
    {
        if (self.soxTask.isRunning == YES)
        {
            NSLog(@"SoxController stopSoxTask sending terminate signal");
            [self.soxTask terminate];
        }

        while (self.soxTask != NULL)
        {
            [NSThread sleepForTimeInterval:0.1f];
        }
    }

    NSLog(@"SoxController stopSoxTask exit");
}

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
    
    outputCommand = [outputCommand stringByTrimmingCharactersInSet:whitespaceCharacterSet];

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

        NSLog(@"SoxController exit sox terminationHandler, PID=%d", processIdentifier);
    }];
    
    NSLog(@"launch soxTask");
    
    [self.soxTask launch];

    NSLog(@"SoxController - Launched NSTask  soxTask, PID=%d", self.soxTask.processIdentifier);

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

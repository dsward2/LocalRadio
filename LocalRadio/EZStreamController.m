//
//  EZStreamController.m
//  LocalRadio
//
//  Created by Douglas Ward on 7/7/17.
//  Copyright © 2017 ArkPhone LLC. All rights reserved.
//

#import "EZStreamController.h"
#import "AppDelegate.h"
#import "LocalRadioAppSettings.h"
#import "NSFileManager+DirectoryLocations.h"

@implementation EZStreamController

// ================================================================

- (void)terminateTasks
{
    //[self.ezStreamTask terminate];
    
    [self stopEZStreamTask];
    [self stopSoxTask];
    [self stopUDPListenerTask];
}

//==================================================================================
//	startEZStreamServer
//==================================================================================

- (void)startEZStreamServer
{
    //NSLog(@"Starting EZStream server");
    
    //[self stopEZStreamServer];   // TEST
    
    int ezstreamProcessID = [self.appDelegate processIDForProcessName:@"ezstream"];

    if (ezstreamProcessID == 0)
    {
        [self startEZStreamTask];
    }
    else
    {
        NSNumber * ezstreamProcessIDNumber = [NSNumber numberWithInteger:ezstreamProcessID];
        
        [self performSelectorOnMainThread:@selector(poseEZStreamProcessAlert:) withObject:ezstreamProcessIDNumber waitUntilDone:YES];
    }
}


//==================================================================================
//	poseEZStreamProcessAlert
//==================================================================================

- (void)poseEZStreamProcessAlert:(NSNumber *)ezstreamProcessIDNumber
{
    NSAlert *alert = [[NSAlert alloc] init];
    
    [alert addButtonWithTitle:@"OK"];
    
    [alert setMessageText:@"EZStream is already running"];
    
    NSString * informativeText = [NSString stringWithFormat:@"An existing EZStream server process is currently running on this Mac, so a new EZStream server process was not created.\n\nThe existing EZStream process can be inspected and terminated with Activity Monitor.app with Process ID (PID) %@.", ezstreamProcessIDNumber];
    
    [alert setInformativeText:informativeText];
    
    [alert setAlertStyle:NSWarningAlertStyle];

    if ([alert runModal] == NSAlertFirstButtonReturn)
    {
        // OK clicked
    }
}

//==================================================================================
//	startEZStreamTask
//==================================================================================

- (void)startEZStreamTask
{
    NSString * udpListenerPath = [NSBundle.mainBundle pathForAuxiliaryExecutable:@"UDPListener"];
    udpListenerPath = [udpListenerPath stringByReplacingOccurrencesOfString:@" " withString:@"\\ "];
    self.quotedUDPListenerPath = [NSString stringWithFormat:@"\"%@\"", udpListenerPath];
    NSMutableArray * udpListenerArgsArray = [NSMutableArray array];

    NSString * soxPath = [NSBundle.mainBundle pathForAuxiliaryExecutable:@"sox"];
    soxPath = [soxPath stringByReplacingOccurrencesOfString:@" " withString:@"\\ "];
    self.quotedSoxPath = [NSMutableString stringWithFormat:@"\"%@\"", soxPath];
    NSMutableArray * soxArgsArray = [NSMutableArray array];

    NSString * ezStreamPath = [NSBundle.mainBundle pathForAuxiliaryExecutable:@"ezstream"];
    ezStreamPath = [ezStreamPath stringByReplacingOccurrencesOfString:@" " withString:@"\\ "];
    self.quotedEZStreamPath = [NSMutableString stringWithFormat:@"\"%@\"", ezStreamPath];
    NSMutableArray * ezStreamArgsArray = [NSMutableArray array];
    
    // write EZStream config file to sandboxed directory ~/Library/Containers/com.arkphone.LocalRadio/Data/Library/Application Support/
    NSString * ezstreamConfigPath = [self writeEZStreamConfig];

    NSNumber * audioPortNumber = [self.appDelegate.localRadioAppSettings integerForKey:@"AudioPort"];
    if (audioPortNumber.integerValue == 0)
    {
        audioPortNumber = [NSNumber numberWithInteger:17006];
    }
    NSString * audioPortString = [audioPortNumber stringValue];

    // sox MP3 encoder quality: "Instead of 0 you have to use .01 (or .99) to specify the highest quality (128.01 or 128.99)."
    NSString * mp3Settings = self.appDelegate.mp3SettingsTextField.stringValue;
    mp3Settings = [mp3Settings stringByReplacingOccurrencesOfString:@".0" withString:@".01"];
    
    // Set UDPListener arguments
    [udpListenerArgsArray addObject:@"-l"];
    [udpListenerArgsArray addObject:audioPortString];
    
    // Set Sox arguments
    [soxArgsArray addObject:@"-e"];     // start input arguments
    [soxArgsArray addObject:@"signed-integer"];
    [soxArgsArray addObject:@"-b"];
    [soxArgsArray addObject:@"16"];
    [soxArgsArray addObject:@"-c"];
    [soxArgsArray addObject:@"1"];
    [soxArgsArray addObject:@"-r"];
    [soxArgsArray addObject:@"48000"];
    [soxArgsArray addObject:@"-t"];
    [soxArgsArray addObject:@"raw"];
    [soxArgsArray addObject:@"-"];      // stdin
    [soxArgsArray addObject:@"-t"];     // start output arguments
    [soxArgsArray addObject:@"mp3"];    // LAME mp3 encode output
    [soxArgsArray addObject:@"-C"];     // variable or constant bit rate,  encoding quality - http://sox.sourceforge.net/soxformat.html
    [soxArgsArray addObject:mp3Settings];
    [soxArgsArray addObject:@"-"];      // stdout

    // Set EZStream arguments
    [ezStreamArgsArray addObject:@"-c"];
    [ezStreamArgsArray addObject:ezstreamConfigPath];

    // Create NSTasks
    self.udpListenerTask = [[NSTask alloc] init];
    self.udpListenerTask.launchPath = udpListenerPath;
    self.udpListenerTask.arguments = udpListenerArgsArray;

    self.soxTask = [[NSTask alloc] init];
    self.soxTask.launchPath = soxPath;
    self.soxTask.arguments = soxArgsArray;

    self.ezStreamTask = [[NSTask alloc] init];
    self.ezStreamTask.launchPath = ezStreamPath;
    self.ezStreamTask.arguments = ezStreamArgsArray;


    
    // configure NSPipe to connect UDPListener stdout to sox stdin
    self.udpListenerSoxPipe = [NSPipe pipe];
    [self.udpListenerTask setStandardOutput:self.udpListenerSoxPipe];
    [self.soxTask setStandardInput:self.udpListenerSoxPipe];
    
    // configure NSPipe to connect UDPListener stdout to sox stdin
    self.soxEZStreamPipe = [NSPipe pipe];
    [self.soxTask setStandardOutput:self.soxEZStreamPipe];
    [self.ezStreamTask setStandardInput:self.soxEZStreamPipe];
    
    
    
    [self.ezStreamTask setStandardOutput:[NSFileHandle fileHandleWithNullDevice]]; // last stage stdout to /dev/null

    EZStreamController * weakSelf = self;

    [self.udpListenerTask setTerminationHandler:^(NSTask* task)
    {           
        int processIdentifier = task.processIdentifier;
        int terminationStatus = task.terminationStatus;
        long terminationReason = task.terminationReason;
        
        NSLog(@"EZStreamController enter udpListenerTask terminationHandler, PID=%d", processIdentifier);

        if ([task terminationStatus] == 0)
        {
            NSLog(@"EZStreamController - udpListenerTask - terminationStatus 0");
            NSLog(@"EZStreamController - udpListenerTask - terminationReason %ld", terminationReason);
        }
        else
        {
            NSLog(@"EZStreamController - udpListenerTask - terminationStatus %d", terminationStatus);
            NSLog(@"EZStreamController - udpListenerTask - terminationReason %ld", terminationReason);
        }

        //[NSThread sleepForTimeInterval:1.0f];
        
        weakSelf.udpListenerTask = NULL;
        weakSelf.udpListenerTaskStandardErrorPipe = NULL;
        weakSelf.udpListenerTaskProcessID = 0;

        [weakSelf.appDelegate updateCurrentTasksText];

        NSLog(@"EZStreamController exit udpListenerTask terminationHandler, PID=%d", processIdentifier);
    }];
    
    [self.soxTask setTerminationHandler:^(NSTask* task)
    {           
        int processIdentifier = task.processIdentifier;
        int terminationStatus = task.terminationStatus;
        long terminationReason = task.terminationReason;
        
        NSLog(@"EZStreamController enter soxTask terminationHandler, PID=%d", processIdentifier);

        if ([task terminationStatus] == 0)
        {
            NSLog(@"EZStreamController - soxTask - terminationStatus 0");
            NSLog(@"EZStreamController - soxTask - terminationReason %ld", terminationReason);
        }
        else
        {
            NSLog(@"EZStreamController - soxTask - terminationStatus %d", terminationStatus);
            NSLog(@"EZStreamController - soxTask - terminationReason %ld", terminationReason);
        }

        //[NSThread sleepForTimeInterval:1.0f];
        
        weakSelf.soxTask = NULL;
        weakSelf.soxTaskStandardErrorPipe = NULL;
        weakSelf.soxTaskProcessID = 0;

        [weakSelf.appDelegate updateCurrentTasksText];

        NSLog(@"EZStreamController exit soxTask terminationHandler, PID=%d", processIdentifier);
    }];
    
    [self.ezStreamTask setTerminationHandler:^(NSTask* task)
    {           
        int processIdentifier = task.processIdentifier;
        int terminationStatus = task.terminationStatus;
        long terminationReason = task.terminationReason;
        
        NSLog(@"EZStreamController enter ezStreamTask terminationHandler, PID=%d", processIdentifier);

        if ([task terminationStatus] == 0)
        {
            NSLog(@"EZStreamController - ezStreamTask - terminationStatus 0");
            NSLog(@"EZStreamController - ezStreamTask - terminationReason %ld", terminationReason);
        }
        else
        {
            NSLog(@"EZStreamController - ezStreamTask - terminationStatus %d", terminationStatus);
            NSLog(@"EZStreamController - ezStreamTask - terminationReason %ld", terminationReason);
        }

        //[NSThread sleepForTimeInterval:1.0f];
        
        weakSelf.ezStreamTask = NULL;
        weakSelf.ezStreamTaskStandardErrorPipe = NULL;
        weakSelf.ezStreamTaskProcessID = 0;

        [weakSelf.appDelegate updateCurrentTasksText];

        NSLog(@"EZStreamController exit ezStreamTask terminationHandler, PID=%d", processIdentifier);
    }];
    

    self.udpListenerArgsString = [udpListenerArgsArray componentsJoinedByString:@" "];
    self.soxArgsString = [soxArgsArray componentsJoinedByString:@" "];
    self.ezStreamArgsString = [ezStreamArgsArray componentsJoinedByString:@" "];

    [self.udpListenerTask launch];
    NSLog(@"EZStreamController - Launched NSTask udpListenerTask, PID=%d, args= %@ %@", self.udpListenerTask.processIdentifier, self.quotedUDPListenerPath, self.udpListenerArgsString);

    [self.soxTask launch];
    NSLog(@"EZStreamController - Launched NSTask soxTask, PID=%d, args= %@ %@", self.soxTask.processIdentifier, self.quotedSoxPath, self.soxArgsString);

    [self.ezStreamTask launch];
    NSLog(@"EZStreamController - Launched NSTask ezStreamTask, PID=%d, args= %@ %@", self.ezStreamTask.processIdentifier, self.quotedEZStreamPath, self.ezStreamArgsString);

    self.udpListenerTaskProcessID = self.udpListenerTask.processIdentifier;
    self.soxTaskProcessID = self.soxTask.processIdentifier;
    self.ezStreamTaskProcessID = self.ezStreamTask.processIdentifier;

    [self.appDelegate.statusEZStreamServerTextField performSelectorOnMainThread:@selector(setStringValue:) withObject:@"Running" waitUntilDone:NO];
}

//==================================================================================
//	startEZStreamTaskOLD
//==================================================================================

- (void)startEZStreamTaskOLD
{
    NSString * udpListenerPath = [NSBundle.mainBundle pathForAuxiliaryExecutable:@"UDPListener"];

    NSString * soxPath = [NSBundle.mainBundle pathForAuxiliaryExecutable:@"sox"];
    
    NSString * ezStreamPath = [NSBundle.mainBundle pathForAuxiliaryExecutable:@"ezstream"];
    NSString * ezstreamConfigPath = [self writeEZStreamConfig];

    NSMutableString * outputCommand = [NSMutableString stringWithFormat:@"\"%@\" ", udpListenerPath];
    
    //[outputCommand appendString:@"-l "];
    //[outputCommand appendString:@"1234 "];
    //NSString * audioPort = self.appDelegate.audioPortTextField.stringValue;
    NSNumber * audioPortNumber = [self.appDelegate.localRadioAppSettings integerForKey:@"AudioPort"];
    if (audioPortNumber.integerValue == 0)
    {
        audioPortNumber = [NSNumber numberWithInteger:17006];
    }
    [outputCommand appendFormat:@"-l %@ ", audioPortNumber];

    [outputCommand appendFormat:@" | \"%@\" ", soxPath];         // pipe
    [outputCommand appendString:@"-e signed-integer "];
    [outputCommand appendString:@"-b 16 "];
    [outputCommand appendString:@"-c 1 "];
    [outputCommand appendString:@"-r 48000 "];
    [outputCommand appendString:@"-t raw "];
    [outputCommand appendString:@"- "];         // stdin
    [outputCommand appendString:@"-t mp3 "];
    
    //[outputCommand appendString:@"-C -4.2 "]; // LAMP mp3 compression  - standard VBR (variable bit rate) http://sox.sourceforge.net/soxformat.html

    // LAME mp3 compression  - variable or constant bit rate and encoding quality - http://sox.sourceforge.net/soxformat.html
    [outputCommand appendString:@"-C "];
    NSString * mp3Settings = self.appDelegate.mp3SettingsTextField.stringValue;
    mp3Settings = [mp3Settings stringByReplacingOccurrencesOfString:@".0" withString:@".01"];   // sox: "Instead of 0 you have to use .01 (or .99) to specify the highest quality (128.01 or 128.99)."
    [outputCommand appendString:mp3Settings];
    [outputCommand appendString:@" "];

    [outputCommand appendString:@"- "];         // stdout
    //[outputCommand appendString:audioOutputFilterString];
    
    
    [outputCommand appendFormat:@" | \"%@\" ", ezStreamPath];         // pipe
    [outputCommand appendFormat:@"-c \"%@\" ", ezstreamConfigPath];
    //[outputCommand appendString:@"-vv "];  // verbose
    //[outputCommand appendString:@"-q "];    // quiet
    
    NSArray * ezStreamTaskArgs = [NSArray arrayWithObjects:@"-c", outputCommand, NULL];

    NSLog(@"Launching ezStream NSTask: %@", outputCommand);
    
    self.ezStreamTask = [[NSTask alloc] init];
    self.ezStreamTask.launchPath = @"/bin/bash";
    self.ezStreamTask.arguments = ezStreamTaskArgs;
    
    self.ezStreamTaskStandardErrorPipe = [NSPipe pipe];
    [self.ezStreamTask setStandardError:self.ezStreamTaskStandardErrorPipe];
    NSFileHandle * standardErrorFileHandle = [self.ezStreamTaskStandardErrorPipe fileHandleForReading];
    [standardErrorFileHandle waitForDataInBackgroundAndNotify];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(ezStreamTaskReceivedStderrData:) name:NSFileHandleDataAvailableNotification object:standardErrorFileHandle];
    
    EZStreamController * weakSelf = self;
    
    [self.ezStreamTask setTerminationHandler:^(NSTask* task)
    {           
        NSLog(@"enter EZStreamController ezStreamTask terminationHandler, PID=%d", task.processIdentifier);

        if ([task terminationStatus] == 0)
        {
            NSLog(@"startEZStreamTask - ezstream terminationStatus 0");
        }
        else
        {
            NSLog(@"startEZStreamTask - ezstream terminationStatus %d", task.terminationStatus);
        }

        if ([(NSThread*)[NSThread currentThread] isMainThread] == NO)
        {
            //NSLog(@"EZStreamController.startEZStreamTask isMainThread = NO");
        }
        
        [weakSelf.appDelegate.statusEZStreamServerTextField performSelectorOnMainThread:@selector(setStringValue:) withObject:@"Not Running" waitUntilDone:NO];

        //weakSelf.appDelegate.statusEZStreamServerTextField.stringValue = @"Not Running";
        
        weakSelf.ezStreamTask = NULL;
    }];
    
    [self.ezStreamTask launch];

    NSLog(@"Launched ezStreamTask, PID=%d", self.ezStreamTask.processIdentifier);

    if ([(NSThread*)[NSThread currentThread] isMainThread] == NO)
    {
        //NSLog(@"EZStreamController.startEZStreamTask isMainThread = NO");
    }

    //self.appDelegate.statusEZStreamServerTextField.stringValue = @"Running";
    [self.appDelegate.statusEZStreamServerTextField performSelectorOnMainThread:@selector(setStringValue:) withObject:@"Running" waitUntilDone:NO];
}


//==================================================================================
//	ezStreamTaskReceivedStderrData:
//==================================================================================

- (void)ezStreamTaskReceivedStderrData:(NSNotification *)notif {
    NSFileHandle *fh = [notif object];
    NSData *data = [fh availableData];
    if (data.length > 0)
    {
        // if data is found, re-register for more data (and print)
        [fh waitForDataInBackgroundAndNotify];
        NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSLog(@"EZSteam: %@" ,str);
    }
}

//==================================================================================
//	stopEZStreamServer
//==================================================================================
/*
- (void)stopEZStreamServer
{
    NSLog(@"Stopping EZStream server");

    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    int ezstreamProcessID = [self.appDelegate processIDForProcessName:@"ezstream"];

    if (ezstreamProcessID != 0)
    {
        int knownEZStreamProcessID = [self.ezStreamTask processIdentifier];
        
        if (ezstreamProcessID == knownEZStreamProcessID)
        {
            // got double-confirmation of process ID of previous ezstream launch by this app, so terminate it
            kill(knownEZStreamProcessID, SIGTERM);
        }
    }
}
*/

//==================================================================================
//	stopEZStreamTask
//==================================================================================

- (void)stopEZStreamTask
{
    NSLog(@"EZStreamController stopEZStreamServer enter");

    if ([(NSThread*)[NSThread currentThread] isMainThread] == YES)
    {
        NSLog(@"stopEZStreamServer called on main thread");
    }

    if (self.ezStreamTask != NULL)
    {
        if (self.ezStreamTask.isRunning == YES)
        {
            NSLog(@"EZStreamController stopEZStreamServer sending terminate signal to ezStreamTask");
            [self.ezStreamTask terminate];
        }

        while (self.ezStreamTask != NULL)
        {
            [NSThread sleepForTimeInterval:0.1f];
        }
    }

    NSLog(@"SoxController stopEZStreamServer exit");
}

//==================================================================================
//	stopUDPListenerTask
//==================================================================================

- (void)stopUDPListenerTask
{
    NSLog(@"EZStreamController stopUDPListenerTask enter");

    if ([(NSThread*)[NSThread currentThread] isMainThread] == YES)
    {
        NSLog(@"stopUDPListenerTask called on main thread");
    }

    if (self.udpListenerTask != NULL)
    {
        if (self.udpListenerTask.isRunning == YES)
        {
            NSLog(@"EZStreamController stopUDPListenerTask sending terminate signal to udpListenerTask");
            [self.udpListenerTask terminate];
        }

        while (self.udpListenerTask != NULL)
        {
            [NSThread sleepForTimeInterval:0.1f];
        }
    }

    NSLog(@"SoxController stopUDPListenerTask exit");
}

//==================================================================================
//	stopSoxTask
//==================================================================================

- (void)stopSoxTask
{
    NSLog(@"EZStreamController stopSoxTask enter");

    if ([(NSThread*)[NSThread currentThread] isMainThread] == YES)
    {
        NSLog(@"stopSoxTask called on main thread");
    }

    if (self.soxTask != NULL)
    {
        if (self.soxTask.isRunning == YES)
        {
            NSLog(@"EZStreamController stopSoxTask sending terminate signal to soxTask");
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
//	writeEZStreamConfig
//==================================================================================

- (NSString *)writeEZStreamConfig
{
    // write a fresh copy of ezstream_mp3.xml to the (sandboxed) Application Support directory for this app, and return the path

    NSNumber * icecastServerModeNumber = [self.appDelegate.localRadioAppSettings integerForKey:@"IcecastServerMode"];
    NSString * icecastServerHost = [self.appDelegate.localRadioAppSettings valueForKey:@"IcecastServerHost"];
    NSString * icecastServerMountName = [self.appDelegate.localRadioAppSettings valueForKey:@"IcecastServerMountName"];
    NSNumber * icecastServerPortNumber = [self.appDelegate.localRadioAppSettings integerForKey:@"IcecastServerPort"];

    NSString * ezStreamConfigPath = [NSBundle.mainBundle pathForResource:@"ezstream_mp3" ofType:@"xml"];

    NSError * fileError = NULL;
    NSString * ezstreamXMLString = [NSString stringWithContentsOfFile:ezStreamConfigPath encoding:NSUTF8StringEncoding error:&fileError];

    NSError * xmlError = NULL;
    NSXMLDocument * xmlDocument = [[NSXMLDocument alloc] initWithXMLString:ezstreamXMLString options:0 error:&xmlError];

    NSXMLElement * rootElement = [xmlDocument rootElement];
    
    NSString * applicationSupportDirectoryPath = [[NSFileManager defaultManager] applicationSupportDirectory];

    //NSString * icecastHost = @"127.0.0.1";
    NSString * icecastHost = [self.appDelegate localHostString];
    if (icecastServerModeNumber.integerValue == 1)
    {
        icecastHost = icecastServerHost;
    }
    
    NSString * icecastPort = [NSString stringWithFormat:@"%ld", icecastServerPortNumber.integerValue];
    
    NSString * ezStreamURLString = [NSString stringWithFormat:@"http://%@:%@/%@",
            icecastHost, icecastPort, icecastServerMountName];
    
    NSError * error;
    
    // <url>http://192.168.10.8:17003/localradio</url>
    NSString * ezStreamURLQuery = @"url";
    NSArray * ezStreamURLResultArray = [rootElement nodesForXPath:ezStreamURLQuery error:&error];
    if (ezStreamURLResultArray.count > 0)
    {
        NSXMLElement * ezStreamURLElement = ezStreamURLResultArray.firstObject;
        [ezStreamURLElement setStringValue:ezStreamURLString];
    }

    // <svrinfourl>http://192.168.10.8/localradio</svrinfourl>
    NSString * svrinfourlQuery = @"svrinfourl";
    NSArray * svrinfourlResultArray = [rootElement nodesForXPath:svrinfourlQuery error:&error];
    if (svrinfourlResultArray.count > 0)
    {
        NSXMLElement * svrinfourlElement = svrinfourlResultArray.firstObject;
        [svrinfourlElement setStringValue:ezStreamURLString];   // same value as <url>
    }

    // <svrinfoname>My Stream</svrinfoname>
    NSString * svrinfonameQuery = @"svrinfoname";
    NSArray * svrinfonameResultArray = [rootElement nodesForXPath:svrinfonameQuery error:&error];
    if (svrinfonameResultArray.count > 0)
    {
        NSXMLElement * svrinfonameElement = svrinfonameResultArray.firstObject;
        [svrinfonameElement setStringValue:icecastServerMountName];
    }
    
    // <svrinfogenre>Live</svrinfogenre>
    NSString * svrinfogenreQuery = @"svrinfogenre";
    NSArray * svrinfogenreResultArray = [rootElement nodesForXPath:svrinfogenreQuery error:&error];
    if (svrinfogenreResultArray.count > 0)
    {
        NSXMLElement * svrinfogenreElement = svrinfogenreResultArray.firstObject;
        [svrinfogenreElement setStringValue:icecastServerMountName];
    }
    
    // <svrinfodescription>Description</svrinfodescription>
    NSString * svrinfodescriptionQuery = @"svrinfodescription";
    NSArray * svrinfodescriptionResultArray = [rootElement nodesForXPath:svrinfodescriptionQuery error:&error];
    if (svrinfodescriptionResultArray.count > 0)
    {
        NSXMLElement * svrinfodescriptionElement = svrinfodescriptionResultArray.firstObject;
        [svrinfodescriptionElement setStringValue:icecastServerMountName];
    }

    // <svrinfobitrate>128</svrinfobitrate> --- informational only
    NSString * svrinfobitrateQuery = @"svrinfobitrate";
    NSArray * svrinfobitrateResultArray = [rootElement nodesForXPath:svrinfobitrateQuery error:&error];
    if (svrinfobitrateResultArray.count > 0)
    {
        NSXMLElement * svrinfobitrateElement = svrinfobitrateResultArray.firstObject;
        [svrinfobitrateElement setStringValue:@"128"];
    }

    // <svrinfochannels>2</svrinfochannels> --- informational only
    NSString * svrinfochannelsQuery = @"svrinfochannels";
    NSArray * svrinfochannelsResultArray = [rootElement nodesForXPath:svrinfochannelsQuery error:&error];
    if (svrinfochannelsResultArray.count > 0)
    {
        NSXMLElement * svrinfochannelsElement = svrinfochannelsResultArray.firstObject;
        [svrinfochannelsElement setStringValue:@"2"];
    }

    // <svrinfosamplerate>48000</svrinfosamplerate> --- informational only
    NSString * svrinfosamplerateQuery = @"svrinfosamplerate";
    NSArray * svrinfosamplerateResultArray = [rootElement nodesForXPath:svrinfosamplerateQuery error:&error];
    if (svrinfosamplerateResultArray.count > 0)
    {
        NSXMLElement * svrinfosamplerateElement = svrinfosamplerateResultArray.firstObject;
        [svrinfosamplerateElement setStringValue:@"48000"];
    }

    // <svrinfopublic>0</svrinfopublic>
    NSString * svrinfopublicQuery = @"svrinfopublic";
    NSArray * svrinfopublicResultArray = [rootElement nodesForXPath:svrinfopublicQuery error:&error];
    if (svrinfopublicResultArray.count > 0)
    {
        NSXMLElement * svrinfopublicElement = svrinfopublicResultArray.firstObject;
        [svrinfopublicElement setStringValue:@"0"];
    }
    
    NSString * xmlString = [xmlDocument XMLString];
    NSString * newEZStreamConfigPath = [applicationSupportDirectoryPath stringByAppendingPathComponent:@"ezstream_mp3.xml"];
    NSError * writeError = NULL;
    [xmlString writeToFile:newEZStreamConfigPath atomically:NO encoding:NSUTF8StringEncoding error:&writeError];

    return newEZStreamConfigPath;
}



@end

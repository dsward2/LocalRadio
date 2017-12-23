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
#import "TaskPipelineManager.h"
#import "TaskItem.h"

@implementation EZStreamController




- (instancetype)init
{
    self = [super init];
    if (self) {
        self.ezStreamTaskPipelineManager = [[TaskPipelineManager alloc] init];
    }
    return self;
}

// ================================================================

- (void)terminateTasks
{
    [self.ezStreamTaskPipelineManager terminateTasks];
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



    TaskItem * udpListenerTaskItem = [self.ezStreamTaskPipelineManager makeTaskItemWithExecutable:@"UDPListener" functionName:@"UDPListener"];

    TaskItem * soxTaskItem = [self.ezStreamTaskPipelineManager makeTaskItemWithExecutable:@"sox" functionName:@"sox"];
    
    TaskItem * ezStreamTaskItem = [self.ezStreamTaskPipelineManager makeTaskItemWithExecutable:@"ezstream" functionName:@"ezstream"];


    
    // Set UDPListener arguments
    [udpListenerTaskItem addArgument:@"-l"];
    [udpListenerTaskItem addArgument:audioPortString];
    
    // Set Sox arguments
    [soxTaskItem addArgument:@"-e"];     // start input arguments
    [soxTaskItem addArgument:@"signed-integer"];
    [soxTaskItem addArgument:@"-b"];
    [soxTaskItem addArgument:@"16"];
    [soxTaskItem addArgument:@"-c"];
    [soxTaskItem addArgument:@"1"];
    [soxTaskItem addArgument:@"-r"];
    [soxTaskItem addArgument:@"48000"];
    [soxTaskItem addArgument:@"-t"];
    [soxTaskItem addArgument:@"raw"];
    [soxTaskItem addArgument:@"-"];      // stdin
    [soxTaskItem addArgument:@"-t"];     // start output arguments
    [soxTaskItem addArgument:@"mp3"];    // LAME mp3 encode output
    [soxTaskItem addArgument:@"-C"];     // variable or constant bit rate,  encoding quality - http://sox.sourceforge.net/soxformat.html
    [soxTaskItem addArgument:mp3Settings];
    [soxTaskItem addArgument:@"-"];      // stdout

    // Set EZStream arguments
    [ezStreamTaskItem addArgument:@"-c"];
    [ezStreamTaskItem addArgument:ezstreamConfigPath];

    // Create NSTasks
    [self.ezStreamTaskPipelineManager addTaskItem:udpListenerTaskItem];
    [self.ezStreamTaskPipelineManager addTaskItem:soxTaskItem];
    [self.ezStreamTaskPipelineManager addTaskItem:ezStreamTaskItem];
    
    [self.ezStreamTaskPipelineManager startTasks];

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

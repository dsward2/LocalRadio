//
//  AppDelegate.m
//  LocalRadio
//
//  Created by Douglas Ward on 4/22/17.
//  Copyright © 2017 ArkPhone LLC. All rights reserved.
//

//  AppDelegate start these subprocesses -
//      mac_rtl_fm - connects to rtl-sdr USB device, and send raw, signed 16-bit PCM data to stdout
//      lame - mac_rtl_fm data is sent to stdin, encoded MP3 data is sent to stdout
//      ezstream - lame data is sent to stdin, connects and relays audio data to icecast process
//      icecast -

#import "AppDelegate.h"
#import "LocalRadioAppSettings.h"
#import "WebServerController.h"
#import "SQLiteController.h"
#import "SDRController.h"
#import "IcecastController.h"
#import "EZStreamController.h"
#import "SoxController.h"
#import "NSFileManager+DirectoryLocations.h"
#import "WebViewDelegate.h"
#import "UDPStatusListenerController.h"
#import "FCCSearchController.h"
#import <IOKit/usb/IOUSBLib.h>
//#import <IOKit/hid/IOHIDManager.h>
#import <IOKit/hid/IOHIDLib.h>

// for GetBSDProcessList
#include <assert.h>
#include <errno.h>
#include <stdbool.h>
#include <stdlib.h>
#include <stdio.h>
#include <sys/sysctl.h>
typedef struct kinfo_proc kinfo_proc;

#import <string.h>
#import <sys/socket.h>
#import <arpa/inet.h>
#import <ifaddrs.h>






@interface AppDelegate ()
@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate


//==================================================================================
//	applicationWillTerminate:
//==================================================================================

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    // Insert code here to tear down your application
    
    //[self performSelectorInBackground:@selector(terminateTasks) withObject:NULL];
    
    [self.periodicUpdateTimer invalidate];
    self.periodicUpdateTimer = NULL;
    
    [self terminateTasks];
    
    BOOL result = [[NSUserDefaults standardUserDefaults] synchronize];
    #pragma unused (result)
    
    NSLog(@"AppDelegate applicationWillTerminate exit");
}

//==================================================================================
//	terminateTasks
//==================================================================================

- (void)terminateTasks
{
    [self.ezStreamController terminateTasks];
    
    [self.icecastController terminateTasks];
    
    [self.soxController terminateTasks];

    [self.sdrController terminateTasks];
}

//==================================================================================
//	applicationDidFinishLaunching:
//==================================================================================

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    BOOL conflictsFound = NO;

    [self checkForRTLSDRUSBDevice];
    
    if (self.rtlsdrDeviceFound  == YES)
    {
        conflictsFound = [self checkForProcessConflicts];
        
        if (conflictsFound == NO)
        {
            [self.sqliteController startSQLiteConnection];

            [self.localRadioAppSettings registerDefaultSettings];
                
            [self.icecastController configureIcecast];
            
            self.useWebViewAudioPlayerCheckbox.state = YES;
            self.listenMode = kListenModeIdle;
            
            [NSThread detachNewThreadSelector:@selector(startServices) toTarget:self withObject:NULL];
            
            [self resetRtlsdrStatusText];

            [self updateViews:self];
            
            self.periodicUpdateTimer = [NSTimer timerWithTimeInterval:0.1 target:self selector:@selector(periodicUpdateTimerFired:) userInfo:self repeats:YES];
            
            NSNumber * statusPortNumber = [self.localRadioAppSettings integerForKey:@"StatusPort"];
            [self.udpStatusListenerController runServerOnPort:statusPortNumber.integerValue];
        }
        else
        {
            // app termination in progress due to process confict
        }
    }
    else
    {
        // app termination in progress due RTL-SDR device not found
    }
}

//==================================================================================
//	periodicUpdateTimerFired:
//==================================================================================

- (void)periodicUpdateTimerFired:(NSNotification *)aNotification
{

}

//==================================================================================
//	startServices
//==================================================================================

- (void)startServices
{
    [self.icecastController startIcecastServer];

    [NSThread sleepForTimeInterval:1];
    
    [self.ezStreamController startEZStreamServer];
    
    [NSThread sleepForTimeInterval:1];

    [self.webServerController startHTTPServer];
    
    [self.webViewDelegate loadMainPage];
}


//==================================================================================
//	restartServices
//==================================================================================

- (void)restartServices
{
    // restart the server tasks
    [NSThread detachNewThreadSelector:@selector(restartServicesOnThread) toTarget:self withObject:NULL];
}

//==================================================================================
//	restartServicesOnThread
//==================================================================================

- (void)restartServicesOnThread
{
    // restart the server tasks - this will interrupt MP3 client players
    [self terminateTasks];
    
    [NSThread sleepForTimeInterval:2];
    
    [self startServices];
    
    [NSThread sleepForTimeInterval:1];

    if (self.listenMode == kListenModeFrequency)
    {
        NSInteger nowPlayingFrequencyID = self.statusFrequencyIDTextField.integerValue;
    
        NSString * frequencyIDString = [NSString stringWithFormat:@"%ld", nowPlayingFrequencyID];
        NSMutableDictionary * frequencyDictionary = [[self.sqliteController frequencyRecordForID:frequencyIDString] mutableCopy];
        
        if (frequencyDictionary != NULL)
        {
            [self.sdrController startRtlsdrTaskForFrequency:frequencyDictionary];
        }
    }
}

//==================================================================================
//	resetRtlsdrStatusText
//==================================================================================

- (void)resetRtlsdrStatusText
{
    /*
    self.statusRTLSDRTextField.stringValue = @"Not running";
    
    [self.statusCurrentTasksTextView setString:@""];

    self.statusFunctionTextField.stringValue = @"";
    self.statusFrequencyTextField.stringValue = @"";
    self.statusModulationTextField.stringValue = @"";
    self.statusSamplingRateTextField.stringValue = @"";
    self.statusSquelchLevelTextField.stringValue = @"";
    self.statusTunerGainTextField.stringValue = @"";
    self.statusSignalLevelTextField.stringValue = @"";
    */
}


//==================================================================================
//	processIsRunning
//==================================================================================

- (int) processIDForProcessName:(NSString *)processName
{
    int processID = 0;

    kinfo_proc * procList = NULL;
    size_t procCount;
    int processCountError = GetBSDProcessList(&procList, &procCount);
    
    if (processCountError == 0)
    {
        for (int i = 0; i < procCount; i++)
        {
            kinfo_proc procItem = procList[i];
            
            NSString * aProcessName = [NSString stringWithCString:procItem.kp_proc.p_comm encoding:NSUTF8StringEncoding];
            
            if ([processName isEqualToString:aProcessName] == YES)
            {
                processID = procItem.kp_proc.p_pid;
                break;
            }
        }
    }
    
    free(procList);

    return processID;
}

//==================================================================================
//	GetBSDProcessList()
//==================================================================================

static int GetBSDProcessList(kinfo_proc **procList, size_t *procCount)
    // Returns a list of all BSD processes on the system.  This routine
    // allocates the list and puts it in *procList and a count of the
    // number of entries in *procCount.  You are responsible for freeing
    // this list (use "free" from System framework).
    // On success, the function returns 0.
    // On error, the function returns a BSD errno value.
{
    int                 err;
    kinfo_proc *        result;
    bool                done;
    static const int    name[] = { CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0 };
    // Declaring name as const requires us to cast it when passing it to
    // sysctl because the prototype doesn't include the const modifier.
    size_t              length;

    assert( procList != NULL);
    assert(*procList == NULL);
    assert(procCount != NULL);

    *procCount = 0;

    // We start by calling sysctl with result == NULL and length == 0.
    // That will succeed, and set length to the appropriate length.
    // We then allocate a buffer of that size and call sysctl again
    // with that buffer.  If that succeeds, we're done.  If that fails
    // with ENOMEM, we have to throw away our buffer and loop.  Note
    // that the loop causes use to call sysctl with NULL again; this
    // is necessary because the ENOMEM failure case sets length to
    // the amount of data returned, not the amount of data that
    // could have been returned.

    result = NULL;
    done = false;
    do {
        assert(result == NULL);

        // Call sysctl with a NULL buffer.

        length = 0;
        err = sysctl( (int *) name, (sizeof(name) / sizeof(*name)) - 1,
                      NULL, &length,
                      NULL, 0);
        if (err == -1) {
            err = errno;
        }

        // Allocate an appropriately sized buffer based on the results
        // from the previous call.

        if (err == 0) {
            result = malloc(length);
            if (result == NULL) {
                err = ENOMEM;
            }
        }

        // Call sysctl again with the new buffer.  If we get an ENOMEM
        // error, toss away our buffer and start again.

        if (err == 0) {
            err = sysctl( (int *) name, (sizeof(name) / sizeof(*name)) - 1,
                          result, &length,
                          NULL, 0);
            if (err == -1) {
                err = errno;
            }
            if (err == 0) {
                done = true;
            } else if (err == ENOMEM) {
                assert(result != NULL);
                free(result);
                result = NULL;
                err = 0;
            }
        }
    } while (err == 0 && ! done);

    // Clean up and establish post conditions.

    if (err != 0 && result != NULL) {
        free(result);
        result = NULL;
    }
    *procList = result;
    if (err == 0) {
        *procCount = length / sizeof(kinfo_proc);
    }

    assert( (err == 0) == (*procList != NULL) );

    return err;
}

// ================================================================

- (NSString *)localHostString
{
    NSString * hostString = @"error";
    struct ifaddrs * interfaces = NULL;
    struct ifaddrs * temp_addr = NULL;
    int success = 0;

    // retrieve the current interfaces - returns 0 on success
    success = getifaddrs(&interfaces);
    if (success == 0)
    {
        // Loop through linked list of interfaces
        temp_addr = interfaces;
        while(temp_addr != NULL)
        {
            if(temp_addr->ifa_addr->sa_family == AF_INET)
            {
                // Get NSString from C String
                hostString = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
            }
            temp_addr = temp_addr->ifa_next;
        }
    }

    // Free memory
    freeifaddrs(interfaces);

    return hostString;
}

// ================================================================

- (NSString *)portString
{
    NSUInteger webHostPort = self.webServerController.webServerPort;
    
    NSString * portString = [NSString stringWithFormat:@"%lu", (unsigned long)webHostPort];
    
    return portString;
}

// ================================================================

- (NSString *)webServerControllerURLString
{
    NSString * hostString = [self localHostString];
    NSString * portString = [self portString];
    NSInteger portInteger = portString.integerValue;

    NSString * urlString = [NSString stringWithFormat:@"http://%@:%ld", hostString, portInteger];
    
    return urlString;
}


//==================================================================================
//	checkForProcessConflicts
//==================================================================================

- (BOOL)checkForProcessConflicts
{
    NSMutableString * processConflictReportString = [NSMutableString string];
    
    int icecastProcessID = [self processIDForProcessName:@"icecast"];
    if (icecastProcessID != 0)
    {
        [processConflictReportString appendFormat:@"icecast (Process Identifier = %d)\r", icecastProcessID];
    }

    int audioMonitorID = [self processIDForProcessName:@"AudioMonitor"];
    if (audioMonitorID != 0)
    {
        [processConflictReportString appendFormat:@"AudioMonitor (Process Identifier = %d)\r", audioMonitorID];
    }

    int ezstreamProcessID = [self processIDForProcessName:@"ezstream"];
    if (ezstreamProcessID != 0)
    {
        [processConflictReportString appendFormat:@"ezstream (Process Identifier = %d)\r", ezstreamProcessID];
    }

    int soxProcessID = [self processIDForProcessName:@"sox"];
    if (soxProcessID != 0)
    {
        [processConflictReportString appendFormat:@"sox (Process Identifier = %d)\r", soxProcessID];
    }

    int udpSenderProcessID = [self processIDForProcessName:@"UDPSender"];
    if (udpSenderProcessID != 0)
    {
        [processConflictReportString appendFormat:@"UDPSender (Process Identifier = %d)\r", udpSenderProcessID];
    }

    int udpListenerProcessID = [self processIDForProcessName:@"UDPListener"];
    if (udpListenerProcessID != 0)
    {
        [processConflictReportString appendFormat:@"UDPListener (Process Identifier = %d)\r", udpListenerProcessID];
    }

    int rtlFMProcessID = [self processIDForProcessName:@"rtl_fm_localradio"];
    if (rtlFMProcessID != 0)
    {
        [processConflictReportString appendFormat:@"rtl_fm_localradio (Process Identifier = %d)\r", rtlFMProcessID];
    }

    BOOL conflictFound = NO;
    if (processConflictReportString.length > 0)
    {
        [self performSelectorOnMainThread:@selector(poseProcessConflictAlert:) withObject:processConflictReportString waitUntilDone:YES];
        conflictFound = YES;
    }
    
    return conflictFound;
}

//==================================================================================
//	poseProcessConflictAlert
//==================================================================================

- (void)poseProcessConflictAlert:(NSString *)processConflictReportString
{
    NSAlert *alert = [[NSAlert alloc] init];
    
    [alert addButtonWithTitle:@"Quit"];
    [alert addButtonWithTitle:@"Show LocalRadio Clean-Up Workflow"];
    
    [alert setMessageText:@"Some conflicting processes must be terminated"];
    
    NSString * informativeText = [NSString stringWithFormat:@"One or more conflicting processes should be terminated before launching LocalRadio.\n\nRun the \"LocalRadio Clean-up\" workflow in Apple's Automator utility to automatically terminate the conflicting processes, or use Activity Monitor to terminate these processes: \n\n%@\n\nAfter the conflicting processes are terminated, try launching the LocalRadio app again.", processConflictReportString];
    
    [alert setInformativeText:informativeText];
    
    [alert setAlertStyle:NSWarningAlertStyle];

    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertSecondButtonReturn) {
            // Show LocalRadio Clean-Up Workflow button
            
            NSURL * cleanupWorkflowURL = [NSBundle.mainBundle URLForResource:@"LocalRadio Clean-Up" withExtension:@"workflow"];
            NSArray * fileURLs = [NSArray arrayWithObjects:cleanupWorkflowURL, NULL];
            [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:fileURLs];
            
            exit(0);
            
            return;
        }
        
        // Quit button clicked
        exit(0);
    }];
}


//==================================================================================
//	checkForRTLSDRUSBDevice
//==================================================================================

- (void)checkForRTLSDRUSBDevice
{
    // Realtek Semiconductor Corp. Vendor ID 0x0bda, RTL2832U product IDs 0x2832 and 0x2838

    // see https://stackoverflow.com/questions/10843559/cocoa-detecting-usb-devices-by-vendor-id
    
    self.rtlsdrDeviceFound = NO;
    
    io_iterator_t iter;
    kern_return_t kr;
    io_service_t device;
    long usbVendor = 0x0bda;        // Vendor ID for Realtek Semiconductor Corp.

    CFMutableDictionaryRef matchingDict = IOServiceMatching(kIOUSBDeviceClassName);
    if (matchingDict == NULL)
    {
        NSLog(@"IOServiceMatching returned NULL");
        return;
    }

    CFNumberRef refVendorId = CFNumberCreate (kCFAllocatorDefault, kCFNumberIntType, &usbVendor);
    CFDictionarySetValue (matchingDict, CFSTR (kUSBVendorID), refVendorId);
    CFRelease(refVendorId);

    //CFDictionarySetValue (matchingDict, CFSTR (kUSBProductID), CFSTR("*"));     // wildcard product ID

    long productID = 0x2838;        // Generic RTL2832U
    CFNumberRef refProductId = CFNumberCreate (kCFAllocatorDefault, kCFNumberIntType, &productID);
    CFDictionarySetValue (matchingDict, CFSTR (kUSBProductID), refProductId);
    CFRelease(refProductId);

    kr = IOServiceGetMatchingServices(kIOMasterPortDefault, matchingDict, &iter);
    if (kr == KERN_SUCCESS)
    {
        while ((device = IOIteratorNext(iter)))
        {
            self.rtlsdrDeviceFound = YES;

        }
    }
    IOObjectRelease(iter);
    
    if (self.rtlsdrDeviceFound == NO)
    {
        CFMutableDictionaryRef matchingDict = IOServiceMatching(kIOUSBDeviceClassName);
        if (matchingDict == NULL)
        {
            NSLog(@"IOServiceMatching returned NULL");
            return;
        }

        CFNumberRef refVendorId = CFNumberCreate (kCFAllocatorDefault, kCFNumberIntType, &usbVendor);
        CFDictionarySetValue (matchingDict, CFSTR (kUSBVendorID), refVendorId);
        CFRelease(refVendorId);

        productID = 0x2832;             // Generic RTL2832U OEM
        refProductId = CFNumberCreate (kCFAllocatorDefault, kCFNumberIntType, &productID);
        CFDictionarySetValue (matchingDict, CFSTR (kUSBProductID), refProductId);
        CFRelease(refProductId);

        kr = IOServiceGetMatchingServices(kIOMasterPortDefault, matchingDict, &iter);
        if (kr == KERN_SUCCESS)
        {
            while ((device = IOIteratorNext(iter)))
            {
                self.rtlsdrDeviceFound = YES;

            }
        }
        IOObjectRelease(iter);
    }
    
    if (self.rtlsdrDeviceFound == NO)
    {
        [self performSelectorOnMainThread:@selector(poseRTLSDRNotFoundAlert) withObject:NULL waitUntilDone:YES];
    }
}

//==================================================================================
//	poseRTLSDRNotFoundAlert
//==================================================================================

- (void)poseRTLSDRNotFoundAlert
{
    NSAlert *alert = [[NSAlert alloc] init];
    
    [alert addButtonWithTitle:@"Quit"];
    [alert addButtonWithTitle:@"More Info"];
    
    [alert setMessageText:@"RTL-SDR USB Device Not Found"];
    
    NSString * informativeText = @"LocalRadio requires an RTL-SDR device plugged into this Mac's USB port.  Please check the USB connection and try again.  For additional information, click the \"More Info\" button to open the LocalRadio project web page.";
    
    [alert setInformativeText:informativeText];
    
    [alert setAlertStyle:NSWarningAlertStyle];

    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertSecondButtonReturn) {
            // Show LocalRadio Clean-Up Workflow button
            [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/dsward2/LocalRadio"]];
            
            exit(0);
        }
        
        // Quit button clicked
        exit(0);
    }];
}

//==================================================================================
//	tabView:didSelectTabViewItem:
//==================================================================================

- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(nullable NSTabViewItem *)tabViewItem
{
    [self updateViews:self];
}


//==================================================================================
//	updateViews:
//==================================================================================

- (IBAction)updateViews:(id)sender
{
    if ([(NSThread*)[NSThread currentThread] isMainThread] == NO)
    {
        NSLog(@"AppDelegate.updateViews isMainThread = NO");
    }

    NSNumber * httpServerPortNumber = [self.localRadioAppSettings integerForKey:@"HTTPServerPort"];
    NSNumber * icecastServerModeNumber = [self.localRadioAppSettings integerForKey:@"IcecastServerMode"];
    NSString * icecastServerHost = [self.localRadioAppSettings valueForKey:@"IcecastServerHost"];
    NSString * icecastServerSourcePassword = [self.localRadioAppSettings valueForKey:@"IcecastServerSourcePassword"];
    NSString * icecastServerMountName = [self.localRadioAppSettings valueForKey:@"IcecastServerMountName"];
    NSNumber * icecastServerPortNumber = [self.localRadioAppSettings integerForKey:@"IcecastServerPort"];
    NSNumber * statusPortNumber = [self.localRadioAppSettings integerForKey:@"StatusPort"];
    NSNumber * controlPortNumber = [self.localRadioAppSettings integerForKey:@"ControlPort"];
    NSNumber * audioPortNumber = [self.localRadioAppSettings integerForKey:@"AudioPort"];
    NSString * mp3SettingsString = [self.localRadioAppSettings valueForKey:@"MP3Settings"];

    NSString * httpHostName = [self localHostString];
    
    if (httpServerPortNumber != NULL)
    {
        self.httpServerPortTextField.integerValue = httpServerPortNumber.integerValue;
    }
    else
    {
        self.httpServerPortTextField.stringValue = @"";
    }
    
    if (httpServerPortNumber != NULL)
    {
        self.httpServerURLTextField.stringValue = [NSString stringWithFormat:@"http://%@:%ld", httpHostName, httpServerPortNumber.integerValue];
    }
    else
    {
        self.httpServerURLTextField.stringValue = @"";
    }
    
    if (httpServerPortNumber != NULL)
    {
        self.httpServerPortTextField.integerValue = httpServerPortNumber.integerValue;
    }
    else
    {
        self.httpServerPortTextField.stringValue = @"";
    }
    
    if (httpServerPortNumber != NULL)
    {
        self.httpServerPortTextField.integerValue = httpServerPortNumber.integerValue;
    }
    else
    {
        self.httpServerPortTextField.stringValue = @"";
    }
    
    if (httpServerPortNumber != NULL)
    {
        self.editHttpServerURLTextField.stringValue = [NSString stringWithFormat:@"http://%@:%ld", httpHostName, httpServerPortNumber.integerValue];
    }
    else
    {
        self.editHttpServerURLTextField.stringValue = @"";
    }
    
    if (icecastServerHost != NULL)
    {
        self.icecastServerHostTextField.stringValue = icecastServerHost;
    }
    else
    {
        self.icecastServerHostTextField.stringValue = @"";
    }
    
    self.icecastServerSourcePasswordTextField.stringValue = icecastServerSourcePassword;
    
    self.icecastServerMountNameTextField.stringValue = icecastServerMountName;
    
    if (icecastServerPortNumber != NULL)
    {
        self.icecastServerPortTextField.integerValue = icecastServerPortNumber.integerValue;
        self.icecastServerWebURLTextField.stringValue = [NSString stringWithFormat:@"http://%@:%ld", icecastServerHost, icecastServerPortNumber.integerValue];
        self.statusIcecastURLTextField.stringValue = [NSString stringWithFormat:@"http://%@:%ld", icecastServerHost, icecastServerPortNumber.integerValue];
    }
    else
    {
        self.icecastServerPortTextField.stringValue = @"";
        self.icecastServerWebURLTextField.stringValue = @"";
        self.statusIcecastURLTextField.stringValue = @"";
    }
    
    self.statusLocalRadioURLTextField.stringValue = [self webServerControllerURLString];
    
    
    if (statusPortNumber != NULL)
    {
        self.statusPortTextField.stringValue = statusPortNumber.stringValue;
    }
    else
    {
        self.statusPortTextField.stringValue = @"";
    }
    
    if (controlPortNumber != NULL)
    {
        self.controlPortTextField.stringValue = controlPortNumber.stringValue;
    }
    else
    {
        self.controlPortTextField.stringValue = @"";
    }
    
    if (audioPortNumber != NULL)
    {
        self.audioPortTextField.stringValue = audioPortNumber.stringValue;
    }
    else
    {
        self.audioPortTextField.stringValue = @"";
    }
    
    if (mp3SettingsString != NULL)
    {
        self.mp3SettingsTextField.stringValue = mp3SettingsString;
        
        
        //float mp3SettingsFloat = mp3SettingsString.floatValue;
        //NSInteger mp3SettingsBitrate = fabs(mp3SettingsFloat);
        //NSInteger mp3SettingsQuality = (NSInteger)((fabs(mp3SettingsFloat) - (float)mp3SettingsBitrate) * 10.0f);

        NSDecimalNumber * mp3SettingsDecimalNumber = [[NSDecimalNumber alloc] initWithString:mp3SettingsString];

        NSDecimalNumberHandler * behavior = [NSDecimalNumberHandler decimalNumberHandlerWithRoundingMode:NSRoundUp scale:0 raiseOnExactness:NO raiseOnOverflow:NO raiseOnUnderflow:NO raiseOnDivideByZero:NO];
        NSDecimalNumber * bitrateDecimalNumber = [mp3SettingsDecimalNumber decimalNumberByRoundingAccordingToBehavior: behavior];
        NSDecimalNumber * encodingQualityDecimalNumber = [mp3SettingsDecimalNumber decimalNumberBySubtracting: bitrateDecimalNumber];
        encodingQualityDecimalNumber = [encodingQualityDecimalNumber decimalNumberByMultiplyingByPowerOf10: 1];
        
        NSString * bitrateString = [NSString stringWithFormat:@"%@", bitrateDecimalNumber];
        NSString * encodingQualityString = [NSString stringWithFormat:@"%@", encodingQualityDecimalNumber];

        float mp3Settings = mp3SettingsDecimalNumber.floatValue;
        NSInteger mp3SettingsBitrate = labs(bitrateString.integerValue);
        NSInteger mp3SettingsEncodingQuality = labs(encodingQualityString.integerValue);
        
        
        
        BOOL isVBR = NO;
        if (mp3Settings < 0)
        {
            isVBR = YES;
        }
        
        NSString * encodingQuality = @"Unknown Quality";
        switch (mp3SettingsEncodingQuality)
        {
            case 0:
                encodingQuality = @"Maximum Quality Encoding";
                break;
            case 1:
                encodingQuality = @"High Quality Encoding";
                break;
            case 2:
                encodingQuality = @"Default High Quality Encoding";
                break;
            case 3:
            case 4:
            case 5:
            case 6:
                encodingQuality = @"Good Quality Encoding";
                break;
            case 7:
            case 8:
                encodingQuality = @"Low Quality Encoding";
                break;
            case 9:
                encodingQuality = @"Minimum Quality Encoding";
                break;
        }
        
        NSString * bitrate = @"Unknown Bitrate";
        NSString * bitrateMode = @"";
        if (isVBR == YES)
        {
            bitrateMode = @"-";         // indicate variable bit rate
            switch (mp3SettingsBitrate)
            {
                case 0:
                    bitrate = @"Maximum Bitrate";
                    break;
                case 1:
                case 2:
                    bitrate = @"High Bitrate";
                    break;
                case 3:
                    bitrate = @"Medium Bitrate";
                    break;
                case 4:
                    bitrate = @"Default Medium Bitrate";
                    break;
                case 5:
                case 6:
                    bitrate = @"Medium Bitrate";
                    break;
                case 7:
                case 8:
                    bitrate = @"Low Bitrate";
                    break;
                case 9:
                    bitrate = @"Minimum Bitrate";
                    break;
            }
        }
        else
        {
            bitrate = [NSString stringWithFormat:@"Constant Bitrate %ld bps", mp3SettingsBitrate];
        }
        
        NSString * mp3SettingsDescription = [NSString stringWithFormat:@"%@, %@", bitrate, encodingQuality];
        self.mp3SettingsDescriptionTextField.stringValue = mp3SettingsDescription;
    }
    else
    {
        self.mp3SettingsTextField.stringValue = @"-4.2";
        self.mp3SettingsDescriptionTextField.stringValue = @"Default VBR Bitrate, Default Encoding Quality";
    }
}

//==================================================================================
//	mp3BitrateRadioButtonClicked:
//==================================================================================

- (IBAction)mp3BitrateRadioButtonClicked:(id)sender
{
    if (sender == self.editMP3ConstantRadioButton)
    {
        self.editMP3VariableRadioButton.state = NO;
    }
    else
    {
        self.editMP3ConstantRadioButton.state = NO;
    }
}

//==================================================================================
//	updateConfiguration
//==================================================================================

- (void)updateConfiguration
{
    NSInteger httpServerPort = self.editHttpServerPortTextField.integerValue;
    [self.localRadioAppSettings setInteger:httpServerPort forKey:@"HTTPServerPort"];
    
    NSInteger icecastServerMode = 0;
    [self.localRadioAppSettings setInteger:icecastServerMode forKey:@"IcecastServerMode"];
    
    NSString * icecastServerHost = self.editIcecastServerHostTextField.stringValue;
    [self.localRadioAppSettings setValue:icecastServerHost forKey:@"IcecastServerHost"];

    NSInteger icecastServerPort = self.editIcecastServerPortTextField.integerValue;
    [self.localRadioAppSettings setInteger:icecastServerPort forKey:@"IcecastServerPort"];
    
    NSString * icecastServerMountName = self.editIcecastServerMountNameTextField.stringValue;
    [self.localRadioAppSettings setValue:icecastServerMountName forKey:@"IcecastServerMountName"];
    
    NSString * icecastServerSourcePassword = self.editIcecastServerSourcePasswordTextField.stringValue;
    [self.localRadioAppSettings setValue:icecastServerSourcePassword forKey:@"IcecastServerSourcePassword"];
    
    NSInteger statusPort = self.editStatusPortTextField.integerValue;
    [self.localRadioAppSettings setInteger:statusPort forKey:@"StatusPort"];
    
    NSInteger controlPort = self.editControlPortTextField.integerValue;
    [self.localRadioAppSettings setInteger:controlPort forKey:@"ControlPort"];
    
    NSInteger audioPort = self.editAudioPortTextField.integerValue;
    [self.localRadioAppSettings setInteger:audioPort forKey:@"AudioPort"];
    
    BOOL useWebViewAudioPlayer = self.editUseWebViewAudioPlayerCheckbox.state;
    self.useWebViewAudioPlayerCheckbox.state = useWebViewAudioPlayer;
    
    NSString * vbrBitrateString = self.editMP3VariablePopUpButton.titleOfSelectedItem;
    NSInteger vbrBitrateInteger = vbrBitrateString.integerValue;
    NSString * constantBitrateString = self.editMP3ConstantPopUpButton.titleOfSelectedItem;
    NSInteger constantBitrateInteger = constantBitrateString.integerValue;
    NSString * encodingQualityString = self.editMP3EncodingQualityPopUpButton.titleOfSelectedItem;
    NSInteger encodingQualityInteger = encodingQualityString.integerValue;
    NSString * mp3SettingString = @"-4.2";
    if (self.editMP3VariableRadioButton.state == YES)
    {
        mp3SettingString = [NSString stringWithFormat:@"-%ld.%ld", vbrBitrateInteger, encodingQualityInteger];
    }
    else
    {
        mp3SettingString = [NSString stringWithFormat:@"%ld.%ld", constantBitrateInteger, encodingQualityInteger];
    }
    self.mp3SettingsTextField.stringValue = mp3SettingString;
    [self.localRadioAppSettings setValue:mp3SettingString forKey:@"MP3Settings"];
}

//==================================================================================
//	editSaveButtonAction
//==================================================================================

- (IBAction)editSaveButtonAction:(id)sender
{
    [self updateConfiguration];
    
    [self updateViews:self];
    
    [self.editConfigurationSheetWindow.sheetParent endSheet:self.editConfigurationSheetWindow returnCode:NSModalResponseOK];
    
    [self restartServices];
    
    [self.webViewDelegate.webView reload:self];
}

//==================================================================================
//	editCancelButtonAction
//==================================================================================

- (IBAction)editCancelButtonAction:(id)sender
{
    [self.editConfigurationSheetWindow.sheetParent endSheet:self.editConfigurationSheetWindow returnCode:NSModalResponseCancel];
}

//==================================================================================
//	editSetDefaultsButtonAction
//==================================================================================

- (IBAction)editSetDefaultsButtonAction:(id)sender
{
    NSBeep();
}

//==================================================================================
//	changeConfigurationButtonAction
//==================================================================================

- (IBAction)changeConfigurationButtonAction:(id)sender
{
    if ([(NSThread*)[NSThread currentThread] isMainThread] == NO)
    {
        NSLog(@"AppDelegate.changeConfigurationButtonAction isMainThread = NO");
    }

    //NSNumber * httpServerPortNumber = [self.localRadioAppSettings integerForKey:@"HTTPServerPort"];
    //NSNumber * icecastServerModeNumber = [self.localRadioAppSettings integerForKey:@"IcecastServerMode"];
    NSString * icecastServerHost = [self.localRadioAppSettings valueForKey:@"IcecastServerHost"];
    NSNumber * icecastServerPortNumber = [self.localRadioAppSettings integerForKey:@"IcecastServerPort"];
    NSString * icecastServerSourcePassword = [self.localRadioAppSettings valueForKey:@"IcecastServerSourcePassword"];
    NSString * icecastServerMountName = [self.localRadioAppSettings valueForKey:@"IcecastServerMountName"];
    NSNumber * statusPortNumber = [self.localRadioAppSettings integerForKey:@"StatusPort"];
    NSNumber * controlPortNumber = [self.localRadioAppSettings integerForKey:@"ControlPort"];
    NSNumber * audioPortNumber = [self.localRadioAppSettings integerForKey:@"AudioPort"];

    self.editIcecastServerHostTextField.stringValue = icecastServerHost;
    self.editIcecastServerPortTextField.integerValue = icecastServerPortNumber.integerValue;
    self.editIcecastServerMountNameTextField.stringValue = icecastServerMountName;
    self.editIcecastServerSourcePasswordTextField.stringValue = icecastServerSourcePassword;
    self.editIcecastServerWebURLTextField.stringValue = [NSString stringWithFormat:@"http://%@:%ld", icecastServerHost, icecastServerPortNumber.integerValue];
    self.editStatusPortTextField.integerValue = statusPortNumber.integerValue;
    self.editControlPortTextField.integerValue = controlPortNumber.integerValue;
    self.editAudioPortTextField.integerValue = audioPortNumber.integerValue;

    [self.window beginSheet:self.editConfigurationSheetWindow  completionHandler:^(NSModalResponse returnCode) {
    }];
}

//==================================================================================
//	openLocalRadioServerWebPage
//==================================================================================

- (IBAction)openLocalRadioServerWebPage:(id)sender
{
    NSString * urlString = [self webServerControllerURLString];

    if (urlString != NULL)
    {
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:urlString]];
    }
}

//==================================================================================
//	openIcecastServerWebPage
//==================================================================================

- (IBAction)openIcecastServerWebPage:(id)sender
{
    NSString * urlString = [self.icecastController icecastWebServerURLString];

    if (urlString != NULL)
    {
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:urlString]];
    }
}

//==================================================================================
//	showConfigurationFilesButtonAction:
//==================================================================================

- (IBAction)showConfigurationFilesButtonAction:(id)sender
{
    NSString * applicationSupportDirectoryPath = [[NSFileManager defaultManager] applicationSupportDirectory];

    [[NSWorkspace sharedWorkspace] openFile:applicationSupportDirectoryPath];
}


//==================================================================================
//	showInformationSheetWithMessage:informativeText:
//==================================================================================

- (void)showInformationSheetWithMessage:(NSString *)message informativeText:(NSString *)informativeText
{
    NSDictionary * infoDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
            message, @"message",
            informativeText, @"informativeText",
            nil];
    
    [self performSelectorOnMainThread:@selector(showInformationSheetWithInfo:) withObject:infoDictionary waitUntilDone:YES];
}

//==================================================================================
//	showInformationSheetWithMessage:
//==================================================================================

- (void)showInformationSheetWithInfo:(NSDictionary *)infoDictionary
{
    NSString * message = [infoDictionary objectForKey:@"message"];
    NSString * informativeText = [infoDictionary objectForKey:@"informativeText"];

    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:message];
    [alert setInformativeText:informativeText];
    [alert addButtonWithTitle:@"OK"];
    //[alert addButtonWithTitle:@"Cancel"];
    [alert setAlertStyle:NSWarningAlertStyle];

    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertSecondButtonReturn) {
            // Cancel button
            return;
        }
        
        // OK button clicked
    }];

}

//==================================================================================
//	showConfirmPanelSheetWithMessage:informativeText:completionHandler:
//==================================================================================
/*
- (void)showConfirmPanelSheetWithMessage:(NSString *)message informativeText:(NSString *)informativeText
        completionHandler:(nonnull void (^)(BOOL))completionHandler
{
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:message];
    [alert setInformativeText:informativeText];
    [alert addButtonWithTitle:@"OK"];
    [alert addButtonWithTitle:@"Cancel"];
    [alert setAlertStyle:NSWarningAlertStyle];

    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertSecondButtonReturn) {
            // Cancel button
            
            completionHandler(NO);
            
            return;
        }
        
        // OK button clicked
        completionHandler(YES);
    }];

}
*/

//==================================================================================
//	shortHertzString:
//==================================================================================

- (NSString *)shortHertzString:(NSString *)hertzString
{
    NSMutableString * resultString = [NSMutableString string];
    
    BOOL doConvertString = NO;
    
    NSInteger inputLength = [hertzString length];
    
    if (inputLength > 6)
    {
        doConvertString = YES;
    }
    
    for (NSInteger i = 0; i < inputLength; i++)
    {
        unichar aChar = [hertzString characterAtIndex:i];
        if ((aChar < '0') || (aChar > '9'))
        {
            doConvertString = NO;
            break;
        }
    }
    
    // check for scanner continuous range like "118M:137M:25k" - start frequency, end frequency, interval
    NSRange colonRange = [resultString rangeOfString:@":"];
    if (colonRange.location != NSNotFound)
    {
        // a colon was found in the frequency field, this is probably a scanning range
        doConvertString = NO;
    }
    
    if (doConvertString == YES)
    {
        NSInteger mhzMajorLength = inputLength - 6;
        NSRange mhzMajorRange = NSMakeRange(0, mhzMajorLength);
        NSString * mhzMajor = [hertzString substringWithRange:mhzMajorRange];

        NSInteger mhzMinorLength = inputLength - mhzMajorLength;
        NSRange mhzMinorRange = NSMakeRange(inputLength - 6, mhzMinorLength);
        NSString * mhzMinor = [hertzString substringWithRange:mhzMinorRange];
        
        BOOL continueTrim = NO;
        
        NSInteger minorLength = [mhzMinor length];
        
        if (minorLength > 1)
        {
            continueTrim = YES;
        }
        
        while (continueTrim == YES)
        {
            minorLength = [mhzMinor length];
            
            if (minorLength <= 1)
            {
                continueTrim = NO;
            }
            else
            {
                unichar lastChar = [mhzMinor characterAtIndex:minorLength - 1];
                
                if (lastChar != '0')
                {
                    continueTrim = NO;
                }
                else
                {
                    mhzMinor = [mhzMinor substringToIndex:minorLength - 1];
                }
            }
        }
        
        [resultString appendFormat:@"%@.%@ MHz", mhzMajor, mhzMinor];
    }
    else
    {
        [resultString appendString:@"0.0 MHz"];
    }
    
    return resultString;
}

//==================================================================================
//	hertzWithString:
//==================================================================================

- (NSInteger)hertzWithString:(NSString *)hertzString
{
    NSInteger result = 0;
    
    NSMutableString * numericString = [NSMutableString string];
    
    double multiplier = 1;
    
    for (NSInteger charIndex = 0; charIndex < [hertzString length]; charIndex++)
    {
        unichar aChar = [hertzString characterAtIndex:charIndex];
        
        if ((aChar >= '0') && (aChar <= '9'))
        {
            [numericString appendFormat:@"%C", aChar];
        }
        else if (aChar == '.')
        {
            [numericString appendFormat:@"%C", aChar];
        }
        else if (aChar == 'M')
        {
            multiplier = 1000000;
            break;
        }
        else if (aChar == 'm')
        {
            multiplier = 1000000;
            break;
        }
        else if (aChar == 'K')
        {
            multiplier = 1000;
            break;
        }
        else if (aChar == 'k')
        {
            multiplier = 1000;
            break;
        }
    }
    
    double frequencyDouble = [numericString doubleValue];
    frequencyDouble *= multiplier;
    
    result = frequencyDouble;
    
    return result;
}



@end

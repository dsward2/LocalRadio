//
//  AppDelegate.m
//  LocalRadio
//
//  Created by Douglas Ward on 4/22/17.
//  Copyright © 2017-2018 ArkPhone LLC. All rights reserved.
//

#import "AppDelegate.h"
#import "LocalRadioAppSettings.h"
#import "HTTPWebServerController.h"
#import "HTTPSWebServerController.h"
#import "SQLiteController.h"
#import "SDRController.h"
#import "IcecastController.h"
#import "IcecastSourceController.h"
#import "CustomTaskController.h"
//#import "SoxController.h"
#import "NSFileManager+DirectoryLocations.h"
#import "WebViewDelegate.h"
#import "UDPStatusListenerController.h"
#import "TaskPipelineManager.h"
#import "TaskItem.h"
#import "FCCSearchController.h"
#import "TLSManager.h"
#import "HTTPServer.h"
#import <IOKit/usb/IOUSBLib.h>
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
@end

@implementation AppDelegate


//==================================================================================
//	applicationWillTerminate:
//==================================================================================

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    self.applicationIsTerminating = YES;
    
    //[self performSelectorInBackground:@selector(terminateTasks) withObject:NULL];
    
    [self.periodicUpdateTimer invalidate];
    self.periodicUpdateTimer = NULL;
    
    [self terminateTasks];
    
    [self.httpWebServerController.httpServer stop:NO];
    [self.httpsWebServerController.httpServer stop:NO];

    BOOL result = [[NSUserDefaults standardUserDefaults] synchronize];
    #pragma unused (result)
    
    NSLog(@"AppDelegate applicationWillTerminate exit");
}

//==================================================================================
//	terminateTasks
//==================================================================================

- (void)terminateTasks
{
    [self.sdrController terminateTasks];

    [self.icecastSourceController terminateTasks];
    
    [self.icecastController terminateTasks];
    
    [self updateCurrentTasksText:self];
}

//==================================================================================
//	applicationDidFinishLaunching:
//==================================================================================

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [self performSelectorInBackground:@selector(configureServices) withObject:NULL];
}

//==================================================================================
//    configureServices
//==================================================================================

- (void)configureServices
{
    // runs on background thread
    BOOL conflictsFound = NO;

    [self checkForRTLSDRUSBDevice];
    
    if (self.rtlsdrDeviceFound  == YES)
    {
        conflictsFound = [self checkForProcessConflicts];
        
        if (conflictsFound == NO)
        {
            [self.tlsManager configureCertificates];
 
            [self.sqliteController startSQLiteConnection];

            [self.localRadioAppSettings registerDefaultSettings];

            //NSString * computerName = [[NSHost currentHost] localizedName];
            //NSString * bonjourName = [NSString stringWithFormat:@"%@.local", computerName];
            NSString * bonjourName = [self localHostString];
            [self.localRadioAppSettings setValue:bonjourName forKey:@"IcecastServerHost"];

            [self.icecastController configureIcecast];
            
            [self performSelectorOnMainThread:@selector(finishConfigureServices) withObject:NULL waitUntilDone:YES];
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


- (void)finishConfigureServices
{
    // runs on main thread for AppKit UI elements
    self.useWebViewAudioPlayerCheckbox.state = YES;
    self.listenMode = kListenModeIdle;

    NSNumber * logAllStderrMessagesNumber = [self.localRadioAppSettings integerForKey:@"CaptureStderr"];
    self.logAllStderrMessagesCheckbox.state = logAllStderrMessagesNumber.boolValue;

    [self updateCopiedSettingsValues];

    [NSThread detachNewThreadSelector:@selector(startServices) toTarget:self withObject:NULL];

    [self updateViews:self];

    self.periodicUpdateTimer = [NSTimer timerWithTimeInterval:0.1 target:self selector:@selector(periodicUpdateTimerFired:) userInfo:self repeats:YES];

    [[NSRunLoop mainRunLoop] addTimer:self.periodicUpdateTimer forMode:NSDefaultRunLoopMode];

    NSNumber * statusPortNumber = [self.localRadioAppSettings integerForKey:@"StatusPort"];
    [self.udpStatusListenerController runServerOnPort:statusPortNumber.integerValue];

    [self updateCurrentTasksText:self];
    
    [self.customTaskController updateTaskNamesArray];
}

//==================================================================================
//	periodicUpdateTimerFired:
//==================================================================================

- (void)periodicUpdateTimerFired:(NSTimer *)timer
{

}

//==================================================================================
//	startServices
//==================================================================================

- (void)startServices
{
    [self.httpWebServerController stopHTTPServer];
    
    [self.httpsWebServerController stopHTTPServer];

    [self.icecastController startIcecastServer];

    [self.httpWebServerController startHTTPServer];
    
    [self.httpsWebServerController startHTTPServer];
    
    [self.webViewDelegate loadMainPage];

    [self updateCurrentTasksText:self];

    [self.icecastSourceController startIcecastSource];

}

//==================================================================================
//    updateCopiedSettingsValues
//==================================================================================

- (void)updateCopiedSettingsValues
{
    self.aacBitrate = self.aacSettingsBitrateTextField.stringValue;
    
    self.useWebViewAudioPlayer = self.useWebViewAudioPlayerCheckbox.state;

    self.logAllStderrMessages = self.logAllStderrMessagesCheckbox.state;
    [self.localRadioAppSettings setInteger:self.logAllStderrMessages forKey:@"CaptureStderr"];

    self.icecastServerHTTPPort = self.icecastServerHTTPPortTextField.integerValue;
    self.icecastServerHTTPSPort = self.icecastServerHTTPSPortTextField.integerValue;
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
    // restart the server tasks - this will interrupt <audio> players in web browsers
    [self terminateTasks];
    
    [NSThread sleepForTimeInterval:2];
    
    [self startServices];
    
    [NSThread sleepForTimeInterval:1];

    if (self.listenMode == kListenModeFrequency)
    {
        __block NSInteger nowPlayingFrequencyID = 0;

        dispatch_async(dispatch_get_main_queue(), ^{
            nowPlayingFrequencyID = self.statusFrequencyIDTextField.integerValue;
        });
    
        if (nowPlayingFrequencyID > 0)
        {
            NSString * frequencyIDString = [NSString stringWithFormat:@"%ld", nowPlayingFrequencyID];
            NSMutableDictionary * frequencyDictionary = [[self.sqliteController frequencyRecordForID:frequencyIDString] mutableCopy];
            
            if (frequencyDictionary != NULL)
            {
                [self.sdrController startRtlsdrTasksForFrequency:frequencyDictionary];
            }
        }
        else
        {
            //NSBeep();
            // probably restarting a non-RTL-SDR source
        }
    }

    [self updateCurrentTasksText:self];
}

//==================================================================================
//	updateCurrentTasksText:
//==================================================================================

- (IBAction)updateCurrentTasksText:(id)sender
{
    if (self.applicationIsTerminating == NO)
    {
        NSMutableString * tasksString = [NSMutableString string];

        [tasksString appendString:@"--- Icecast tasks ---\n\n"];
        
        if (self.icecastController.icecastTaskProcessID != 0)
        {

            [tasksString appendFormat:@"Icecast - process ID = %d\n\n", self.icecastController.icecastTaskProcessID];
         
            [tasksString appendFormat:@"%@ %@\n\n",
                self.icecastController.quotedIcecastPath, self.icecastController.icecastTaskArgsString];

            AppDelegate * appDelegate = (AppDelegate *)[NSApp delegate];
            IcecastController * icecastController = appDelegate.icecastController;
            NSDictionary * icecastStatusDictionary = [icecastController icecastStatusDictionary];

            if (icecastStatusDictionary != NULL)
            {
                NSString * icecastStatusString = [icecastStatusDictionary description];
                [tasksString appendString:icecastStatusString];
            }
            else
            {
                [tasksString appendString:@"Icecast status not available\n\n"];
            }
            
            [tasksString appendString:@"\n\n"];
        }
        else
        {
            [tasksString appendString:@"No tasks currently running\n\n"];
        }

        [tasksString appendString:@"--- IcecastSource tasks ---\n\n"];

        NSString * icecastSourceTasksString = self.icecastSourceController.icecastSourceTaskPipelineManager.tasksInfoString;
        if (icecastSourceTasksString != NULL)
        {
            [tasksString appendString:icecastSourceTasksString];
        }

        [tasksString appendString:@"--- RTL-SDR radio tasks ---\n\n"];
        
        NSString * radioTasksString = self.sdrController.radioTaskPipelineManager.tasksInfoString;
        [tasksString appendString:radioTasksString];

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.statusCurrentTasksTextView setString:tasksString];
        });
    }
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


- (NSString *)localHostString
{
    NSString * bonjourName = [[NSHost currentHost] name];
    
    NSArray * hostNames = [[NSHost currentHost] names];
    
    for (NSString * aHostName in hostNames)
    {
        if ([aHostName hasSuffix:@".local"] == YES)
        {
            bonjourName = aHostName;
            break;
        }
    }
    
    return bonjourName;
}


- (NSString *)localHostIPString
{
    //NSArray * ipAddresses = [[NSHost currentHost] addresses];
    //NSArray * sortedIPAddresses = [ipAddresses sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];

    NSString * hostString = @"error";
    NSString * en0HostString = NULL;
    NSString * en1HostString = NULL;
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

                if([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"]) {
                    en0HostString = hostString;
                }
                if([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en1"]) {
                    en1HostString = hostString;
                }
            }
            temp_addr = temp_addr->ifa_next;
        }
    }

    // Free memory
    freeifaddrs(interfaces);
    
    if (en0HostString != NULL)
    {
        hostString = en0HostString;
    }
    else if (en1HostString != NULL)
    {
        hostString = en1HostString;
    }

    return hostString;
}


// ================================================================

- (NSString *)httpWebServerPortString
{
    NSUInteger webHostPort = self.httpWebServerController.serverClassPortNumber.integerValue;
    
    NSString * portString = [NSString stringWithFormat:@"%lu", (unsigned long)webHostPort];
    
    return portString;
}

// ================================================================

- (NSString *)httpsWebServerPortString
{
    NSUInteger webHostPort = self.httpsWebServerController.serverClassPortNumber.integerValue;
    
    NSString * portString = [NSString stringWithFormat:@"%lu", (unsigned long)webHostPort];
    
    return portString;
}

// ================================================================

- (NSString *)httpWebServerControllerURLString
{
    //NSString * hostString = [self localHostString];
    NSString * hostString = [self localHostIPString];
    NSString * portString = [self httpWebServerPortString];
    NSInteger portInteger = portString.integerValue;

    NSString * urlString = [NSString stringWithFormat:@"http://%@:%ld", hostString, portInteger];
    
    return urlString;
}

// ================================================================

- (NSString *)httpsWebServerControllerURLString
{
    NSString * hostString = [self localHostString];
    NSString * portString = [self httpsWebServerPortString];
    NSInteger portInteger = portString.integerValue;

    NSString * urlString = [NSString stringWithFormat:@"https://%@:%ld", hostString, portInteger];
    
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

    int icecastSourceProcessID = [self processIDForProcessName:@"IcecastSource"];
    if (icecastSourceProcessID != 0)
    {
        [processConflictReportString appendFormat:@"IcecastSource (Process Identifier = %d)\r", icecastSourceProcessID];
    }

    int audioMonitorID = [self processIDForProcessName:@"AudioMonitor"];
    if (audioMonitorID != 0)
    {
        [processConflictReportString appendFormat:@"AudioMonitor (Process Identifier = %d)\r", audioMonitorID];
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
    
    NSString * bundlePath = [[NSBundle mainBundle] bundlePath];
    NSArray * pathComponents = [bundlePath pathComponents];
    for (NSString * aPathComponent in pathComponents)
    {
        NSRange spaceRange = [aPathComponent rangeOfString:@" "];
        if (spaceRange.location != NSNotFound)
        {
            [self performSelectorOnMainThread:@selector(poseAppPathErrorAlert:) withObject:aPathComponent waitUntilDone:YES];
            
            conflictFound = YES;
            break;
        }
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
//	poseAppPathErrorAlert
//==================================================================================

- (void)poseAppPathErrorAlert:(NSString *)folderName
{
    NSAlert *alert = [[NSAlert alloc] init];
    
    [alert addButtonWithTitle:@"Quit"];
    [alert addButtonWithTitle:@"Open LocalRadio Project Web Page"];
    
    [alert setMessageText:@"LocalRadio Cannot Launch Due To Folder Name Problem"];
    
    NSString * informativeText = [NSString stringWithFormat:@"LocalRadio cannot launch due to a problem with a folder name.\n\nPlease remove all space characters from this folder name: \n\n%@\n\nAfter the folder is renamed, try launching the LocalRadio app again.\n\nSee the LocalRadio project web page for more information about the folder name bug.", folderName];
    
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

    NSNumber * localRadioServerHTTPPortNumber = [self.localRadioAppSettings integerForKey:@"LocalRadioServerHTTPPort"];
    NSNumber * localRadioServerHTTPSPortNumber = [self.localRadioAppSettings integerForKey:@"LocalRadioServerHTTPSPort"];
    NSString * icecastServerHost = [self.localRadioAppSettings valueForKey:@"IcecastServerHost"];
    NSString * icecastServerSourcePassword = [self.localRadioAppSettings valueForKey:@"IcecastServerSourcePassword"];
    NSString * icecastServerMountName = [self.localRadioAppSettings valueForKey:@"IcecastServerMountName"];
    NSNumber * icecastServerHTTPPortNumber = [self.localRadioAppSettings integerForKey:@"IcecastServerHTTPPort"];
    NSNumber * icecastServerHTTPSPortNumber = [self.localRadioAppSettings integerForKey:@"IcecastServerHTTPSPort"];
    NSNumber * statusPortNumber = [self.localRadioAppSettings integerForKey:@"StatusPort"];
    NSNumber * controlPortNumber = [self.localRadioAppSettings integerForKey:@"ControlPort"];
    NSNumber * audioPortNumber = [self.localRadioAppSettings integerForKey:@"AudioPort"];
    NSString * aacBitrateString = [self.localRadioAppSettings valueForKey:@"AACBitrate"];

    if (localRadioServerHTTPPortNumber != NULL)
    {
        self.localRadioHTTPServerPortTextField.integerValue = localRadioServerHTTPPortNumber.integerValue;
        self.editLocalRadioHTTPServerPortTextField.integerValue = localRadioServerHTTPPortNumber.integerValue;
    }
    else
    {
        self.localRadioHTTPServerPortTextField.stringValue = @"";
        self.editLocalRadioHTTPServerPortTextField.stringValue = @"";
    }
    
    if (localRadioServerHTTPSPortNumber != NULL)
    {
        self.localRadioHTTPSServerPortTextField.integerValue = localRadioServerHTTPSPortNumber.integerValue;
        self.editLocalRadioHTTPSServerPortTextField.integerValue = localRadioServerHTTPSPortNumber.integerValue;
    }
    else
    {
        self.localRadioHTTPSServerPortTextField.stringValue = @"";
        self.editLocalRadioHTTPSServerPortTextField.stringValue = @"";
    }
    
    if (icecastServerHost != NULL)
    {
        self.icecastServerHostTextField.stringValue = icecastServerHost;
        self.editIcecastServerHostTextField.stringValue = icecastServerHost;
    }
    else
    {
        self.icecastServerHostTextField.stringValue = @"";
        self.editIcecastServerHostTextField.stringValue = @"";
    }
    
    self.icecastServerSourcePasswordTextField.stringValue = icecastServerSourcePassword;
    self.editIcecastServerSourcePasswordTextField.stringValue = icecastServerSourcePassword;

    self.icecastServerMountNameTextField.stringValue = icecastServerMountName;
    self.icecastServerMountName = icecastServerMountName;
    self.editIcecastServerMountNameTextField.stringValue = icecastServerMountName;

    if (icecastServerHTTPSPortNumber != NULL)
    {
        self.icecastServerHTTPSPortTextField.integerValue = icecastServerHTTPSPortNumber.integerValue;
        self.editIcecastServerHTTPSPortTextField.integerValue = icecastServerHTTPSPortNumber.integerValue;

        self.icecastServerWebURLTextField.stringValue = [NSString stringWithFormat:@"https://%@:%ld", icecastServerHost, icecastServerHTTPSPortNumber.integerValue];
        self.editIcecastServerWebURLTextField.stringValue = [NSString stringWithFormat:@"https://%@:%ld", icecastServerHost, icecastServerHTTPSPortNumber.integerValue];

        self.statusIcecastURLTextField.stringValue = [NSString stringWithFormat:@"https://%@:%ld", icecastServerHost, icecastServerHTTPSPortNumber.integerValue];
    }
    else
    {
        self.icecastServerHTTPSPortTextField.stringValue = @"";
        self.editIcecastServerHTTPSPortTextField.stringValue = @"";
        
        self.icecastServerWebURLTextField.stringValue = @"";
        self.editIcecastServerWebURLTextField.stringValue = @"";

        self.statusIcecastURLTextField.stringValue = @"";
    }

    if (icecastServerHTTPPortNumber != NULL)
    {
        self.icecastServerHTTPPortTextField.integerValue = icecastServerHTTPPortNumber.integerValue;
        self.editIcecastServerHTTPPortTextField.integerValue = icecastServerHTTPPortNumber.integerValue;

        if (icecastServerHTTPSPortNumber == NULL)
        {
            self.icecastServerWebURLTextField.stringValue = [NSString stringWithFormat:@"http://%@:%ld", icecastServerHost, icecastServerHTTPPortNumber.integerValue];  // fallback to http
            self.editIcecastServerWebURLTextField.stringValue = [NSString stringWithFormat:@"http://%@:%ld", icecastServerHost, icecastServerHTTPPortNumber.integerValue];  // fallback to http

            self.statusIcecastURLTextField.stringValue = [NSString stringWithFormat:@"http://%@:%ld", icecastServerHost, icecastServerHTTPPortNumber.integerValue];  // fallback to http
        }
    }
    else
    {
        self.icecastServerHTTPPortTextField.stringValue = @"";
        self.editIcecastServerHTTPPortTextField.stringValue = @"";

        if (icecastServerHTTPSPortNumber == NULL)
        {
            self.icecastServerWebURLTextField.stringValue = @"";
            self.editIcecastServerWebURLTextField.stringValue = @"";

            self.statusIcecastURLTextField.stringValue = @"";
        }
    }
    
    
    self.localRadioHTTPSURLTextField.stringValue = [self httpsWebServerControllerURLString];
    self.localRadioHTTPURLTextField.stringValue = [self httpWebServerControllerURLString];

    
    if (statusPortNumber != NULL)
    {
        self.statusPortTextField.stringValue = statusPortNumber.stringValue;
        self.editStatusPortTextField.stringValue = statusPortNumber.stringValue;
    }
    else
    {
        self.statusPortTextField.stringValue = @"";
        self.editStatusPortTextField.stringValue = @"";
    }
    
    if (controlPortNumber != NULL)
    {
        self.controlPortTextField.stringValue = controlPortNumber.stringValue;
        self.editControlPortTextField.stringValue = controlPortNumber.stringValue;
    }
    else
    {
        self.controlPortTextField.stringValue = @"";
        self.editControlPortTextField.stringValue = @"";
    }
    
    if (audioPortNumber != NULL)
    {
        self.audioPortTextField.stringValue = audioPortNumber.stringValue;
        self.editAudioPortTextField.stringValue = audioPortNumber.stringValue;
    }
    else
    {
        self.audioPortTextField.stringValue = @"";
        self.editAudioPortTextField.stringValue = @"";
    }
    
    if (aacBitrateString != NULL)
    {
        self.aacSettingsBitrateTextField.stringValue = aacBitrateString;
        self.aacBitrate = aacBitrateString;
        [self.editAACSettingsBitratePopUpButton selectItemWithTag:aacBitrateString];
    }
    else
    {
        self.aacSettingsBitrateTextField.stringValue = @"64000";
        self.aacBitrate = aacBitrateString;
        [self.editAACSettingsBitratePopUpButton selectItemWithTag:aacBitrateString];
    }
}

//==================================================================================
//	updateConfiguration
//==================================================================================

- (void)updateConfiguration
{
    NSInteger localRadioServerHTTPPort = self.editLocalRadioHTTPServerPortTextField.integerValue;
    [self.localRadioAppSettings setInteger:localRadioServerHTTPPort forKey:@"LocalRadioServerHTTPPort"];
    
    NSInteger localRadioServerHTTPSPort = self.editLocalRadioHTTPSServerPortTextField.integerValue;
    [self.localRadioAppSettings setInteger:localRadioServerHTTPSPort forKey:@"LocalRadioServerHTTPSPort"];
    
    NSInteger icecastServerMode = 0;
    [self.localRadioAppSettings setInteger:icecastServerMode forKey:@"IcecastServerMode"];
    
    NSString * icecastServerHost = self.editIcecastServerHostTextField.stringValue;
    [self.localRadioAppSettings setValue:icecastServerHost forKey:@"IcecastServerHost"];

    NSInteger icecastServerHTTPPort = self.editIcecastServerHTTPPortTextField.integerValue;
    [self.localRadioAppSettings setInteger:icecastServerHTTPPort forKey:@"IcecastServerHTTPPort"];
    
    NSInteger icecastServerHTTPSPort = self.editIcecastServerHTTPSPortTextField.integerValue;
    [self.localRadioAppSettings setInteger:icecastServerHTTPSPort forKey:@"IcecastServerHTTPSPort"];
    
    NSString * icecastServerMountName = self.editIcecastServerMountNameTextField.stringValue;
    [self.localRadioAppSettings setValue:icecastServerMountName forKey:@"IcecastServerMountName"];
    self.icecastServerMountName = icecastServerMountName;
    
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

    BOOL logAllStderrMessages = self.editLogAllStderrMessagesCheckbox.state;
    self.logAllStderrMessagesCheckbox.state = logAllStderrMessages;

    NSString * aacBitrateString = self.editAACSettingsBitratePopUpButton.titleOfSelectedItem;
    self.aacSettingsBitrateTextField.stringValue = aacBitrateString;
    [self.localRadioAppSettings setValue:aacBitrateString forKey:@"AACBitrate"];

    [self updateCopiedSettingsValues];
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
    [self.localRadioAppSettings setDefaultSettings];
    
    [self updateViews:self];
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

    NSString * icecastServerHost = [self.localRadioAppSettings valueForKey:@"IcecastServerHost"];
    NSNumber * icecastServerHTTPPortNumber = [self.localRadioAppSettings integerForKey:@"IcecastServerHTTPPort"];
    NSNumber * icecastServerHTTPSPortNumber = [self.localRadioAppSettings integerForKey:@"IcecastServerHTTPSPort"];
    NSString * icecastServerSourcePassword = [self.localRadioAppSettings valueForKey:@"IcecastServerSourcePassword"];
    NSString * icecastServerMountName = [self.localRadioAppSettings valueForKey:@"IcecastServerMountName"];
    NSNumber * statusPortNumber = [self.localRadioAppSettings integerForKey:@"StatusPort"];
    NSNumber * controlPortNumber = [self.localRadioAppSettings integerForKey:@"ControlPort"];
    NSNumber * audioPortNumber = [self.localRadioAppSettings integerForKey:@"AudioPort"];
    NSString * aacBitrateString = [self.localRadioAppSettings valueForKey:@"AACBitrate"];

    self.editIcecastServerHostTextField.stringValue = icecastServerHost;
    self.editIcecastServerHTTPPortTextField.integerValue = icecastServerHTTPPortNumber.integerValue;
    self.editIcecastServerHTTPSPortTextField.integerValue = icecastServerHTTPSPortNumber.integerValue;
    self.editIcecastServerMountNameTextField.stringValue = icecastServerMountName;
    self.editIcecastServerSourcePasswordTextField.stringValue = icecastServerSourcePassword;
    self.editIcecastServerWebURLTextField.stringValue = [NSString stringWithFormat:@"https://%@:%ld", icecastServerHost, icecastServerHTTPSPortNumber.integerValue];
    self.editStatusPortTextField.integerValue = statusPortNumber.integerValue;
    self.editControlPortTextField.integerValue = controlPortNumber.integerValue;
    self.editAudioPortTextField.integerValue = audioPortNumber.integerValue;
    
    [self.editAACSettingsBitratePopUpButton selectItemWithTitle:aacBitrateString];
    self.aacBitrate = aacBitrateString;
    self.icecastServerMountName = icecastServerMountName;

    [self.window beginSheet:self.editConfigurationSheetWindow  completionHandler:^(NSModalResponse returnCode) {
    }];
}

//==================================================================================
//    openLocalRadioHTTPSServerWebPage
//==================================================================================

- (IBAction)openLocalRadioHTTPSServerWebPage:(id)sender
{
    NSString * urlString = [self httpsWebServerControllerURLString];

    if (urlString != NULL)
    {
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:urlString]];
    }
}

//==================================================================================
//    openLocalRadioHTTPServerWebPage
//==================================================================================

- (IBAction)openLocalRadioHTTPServerWebPage:(id)sender
{
    NSString * urlString = [self httpWebServerControllerURLString];

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
    NSString * urlString = [self.icecastController icecastWebServerHTTPSURLString];

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
    
    if (inputLength >= 6)
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
        
        if (mhzMajor.length == 0)
        {
            mhzMajor = @"0";
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

- (void)setStatusFrequencyString:(NSString *)value
{
    [self performSelectorOnMainThread:@selector(setStatusFrequencyStringOnThread:) withObject:value waitUntilDone:NO];
}

- (void)setStatusFrequencyStringOnThread:(NSString *)value
{
    self.statusFrequency = value;
    self.statusFrequencyTextField.stringValue = value;
}

- (void)setStatusNameString:(NSString *)value
{
    [self performSelectorOnMainThread:@selector(setStatusNameStringOnThread:) withObject:value waitUntilDone:NO];
}

- (void)setStatusNameStringOnThread:(NSString *)value
{
    self.statusName = value;
    self.statusNameTextField.stringValue = value;
}


- (void)setStatusFrequencyIDString:(NSString *)value
{
    [self performSelectorOnMainThread:@selector(setStatusFrequencyIDStringOnThread:) withObject:value waitUntilDone:NO];
}


- (void)setStatusFrequencyIDStringOnThread:(NSString *)value
{
    self.statusFrequencyID = value;
    self.statusFrequencyIDTextField.stringValue = value;
}


- (IBAction)reloadWebView:(id)sender
{
    [self.webViewDelegate.webView reload:self];
}



@end

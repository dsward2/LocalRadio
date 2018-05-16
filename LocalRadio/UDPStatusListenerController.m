//
//  UDPStatusListener.m
//  LocalRadio
//
//  Created by Douglas Ward on 7/28/17.
//  Copyright © 2017-2018 ArkPhone LLC. All rights reserved.
//

//  Based on Apple's UDPEcho sample codeproject

/*
    File:       UDPEcho.h

    Contains:   A class that implements a UDP echo protocol client and server.

    Written by: DTS

    Copyright:  Copyright (c) 2010-12 Apple Inc. All Rights Reserved.

    Disclaimer: IMPORTANT: This Apple software is supplied to you by Apple Inc.
                ("Apple") in consideration of your agreement to the following
                terms, and your use, installation, modification or
                redistribution of this Apple software constitutes acceptance of
                these terms.  If you do not agree with these terms, please do
                not use, install, modify or redistribute this Apple software.

                In consideration of your agreement to abide by the following
                terms, and subject to these terms, Apple grants you a personal,
                non-exclusive license, under Apple's copyrights in this
                original Apple software (the "Apple Software"), to use,
                reproduce, modify and redistribute the Apple Software, with or
                without modifications, in source and/or binary forms; provided
                that if you redistribute the Apple Software in its entirety and
                without modifications, you must retain this notice and the
                following text and disclaimers in all such redistributions of
                the Apple Software. Neither the name, trademarks, service marks
                or logos of Apple Inc. may be used to endorse or promote
                products derived from the Apple Software without specific prior
                written permission from Apple.  Except as expressly stated in
                this notice, no other rights or licenses, express or implied,
                are granted by Apple herein, including but not limited to any
                patent rights that may be infringed by your derivative works or
                by other works in which the Apple Software may be incorporated.

                The Apple Software is provided by Apple on an "AS IS" basis. 
                APPLE MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING
                WITHOUT LIMITATION THE IMPLIED WARRANTIES OF NON-INFRINGEMENT,
                MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, REGARDING
                THE APPLE SOFTWARE OR ITS USE AND OPERATION ALONE OR IN
                COMBINATION WITH YOUR PRODUCTS.

                IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT,
                INCIDENTAL OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
                TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
                DATA, OR PROFITS; OR BUSINESS INTERRUPTION) ARISING IN ANY WAY
                OUT OF THE USE, REPRODUCTION, MODIFICATION AND/OR DISTRIBUTION
                OF THE APPLE SOFTWARE, HOWEVER CAUSED AND WHETHER UNDER THEORY
                OF CONTRACT, TORT (INCLUDING NEGLIGENCE), STRICT LIABILITY OR
                OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE POSSIBILITY OF
                SUCH DAMAGE.

*/

#import "UDPStatusListenerController.h"
#import "AppDelegate.h"
#import "SDRController.h"
#import "SQLiteController.h"

#include <netdb.h>


#pragma mark * Utilities

static NSString * DisplayAddressForAddress(NSData * address)
    // Returns a dotted decimal string for the specified address (a (struct sockaddr) 
    // within the address NSData).
{
    int         err;
    NSString *  result;
    char        hostStr[NI_MAXHOST];
    char        servStr[NI_MAXSERV];
    
    result = nil;
    
    if (address != nil) {

        // If it's a IPv4 address embedded in an IPv6 address, just bring it as an IPv4 
        // address.  Remember, this is about display, not functionality, and users don't 
        // want to see mapped addresses.
        
        if ([address length] >= sizeof(struct sockaddr_in6)) {
            const struct sockaddr_in6 * addr6Ptr;
            
            addr6Ptr = [address bytes];
            if (addr6Ptr->sin6_family == AF_INET6) {
                if ( IN6_IS_ADDR_V4MAPPED(&addr6Ptr->sin6_addr) || IN6_IS_ADDR_V4COMPAT(&addr6Ptr->sin6_addr) ) {
                    struct sockaddr_in  addr4;
                    
                    memset(&addr4, 0, sizeof(addr4));
                    addr4.sin_len         = sizeof(addr4);
                    addr4.sin_family      = AF_INET;
                    addr4.sin_port        = addr6Ptr->sin6_port;
                    addr4.sin_addr.s_addr = addr6Ptr->sin6_addr.__u6_addr.__u6_addr32[3];
                    address = [NSData dataWithBytes:&addr4 length:sizeof(addr4)];
                    assert(address != nil);
                }
            }
        }
        err = getnameinfo([address bytes], (socklen_t) [address length], hostStr, sizeof(hostStr), servStr, sizeof(servStr), NI_NUMERICHOST | NI_NUMERICSERV);
        if (err == 0) {
            result = [NSString stringWithFormat:@"%s:%s", hostStr, servStr];
            assert(result != nil);
        }
    }

    return result;
}

static NSString * DisplayStringFromData(NSData *data)
    // Returns a human readable string for the given data.
{
    NSMutableString *   result;
    NSUInteger          dataLength;
    NSUInteger          dataIndex;
    const uint8_t *     dataBytes;

    assert(data != nil);
    
    dataLength = [data length];
    dataBytes  = [data bytes];

    result = [NSMutableString stringWithCapacity:dataLength];
    assert(result != nil);

    [result appendString:@"\""];
    for (dataIndex = 0; dataIndex < dataLength; dataIndex++) {
        uint8_t     ch;
        
        ch = dataBytes[dataIndex];
        if (ch == 10) {
            [result appendString:@"\n"];
        } else if (ch == 13) {
            [result appendString:@"\r"];
        } else if (ch == '"') {
            [result appendString:@"\\\""];
        } else if (ch == '\\') {
            [result appendString:@"\\\\"];
        } else if ( (ch >= ' ') && (ch < 127) ) {
            [result appendFormat:@"%c", (int) ch];
        } else {
            [result appendFormat:@"\\x%02x", (unsigned int) ch];
        }
    }
    [result appendString:@"\""];
    
    return result;
}

static NSString * DisplayErrorFromError(NSError *error)
    // Given an NSError, returns a short error string that we can print, handling 
    // some special cases along the way.
{
    NSString *      result;
    NSNumber *      failureNum;
    int             failure;
    const char *    failureStr;
    
    assert(error != nil);
    
    result = nil;
    
    // Handle DNS errors as a special case.
    
    if ( [[error domain] isEqual:(NSString *)kCFErrorDomainCFNetwork] && ([error code] == kCFHostErrorUnknown) ) {
        failureNum = [[error userInfo] objectForKey:(id)kCFGetAddrInfoFailureKey];
        if ( [failureNum isKindOfClass:[NSNumber class]] ) {
            failure = [failureNum intValue];
            if (failure != 0) {
                failureStr = gai_strerror(failure);
                if (failureStr != NULL) {
                    result = [NSString stringWithUTF8String:failureStr];
                    assert(result != nil);
                }
            }
        }
    }
    
    // Otherwise try various properties of the error object.
    
    if (result == nil) {
        result = [error localizedFailureReason];
    }
    if (result == nil) {
        result = [error localizedDescription];
    }
    if (result == nil) {
        result = [error description];
    }
    assert(result != nil);
    return result;
}

@implementation UDPStatusListenerController


//@synthesize echo      = _echo;
//@synthesize sendTimer = _sendTimer;
//@synthesize sendCount = _sendCount;

- (void)dealloc
{
    [self.udpStatusListener stop];
    [self.sendTimer invalidate];
}





- (instancetype)init
{
    self = [super init];
    if (self) {
        self.statusCacheDictionary = [NSMutableDictionary dictionary];
    }
    return self;
}


- (BOOL)runServerOnPort:(NSUInteger)port
{
    NSNumber * portNumber = [NSNumber numberWithUnsignedInteger:port];

    [self performSelectorInBackground:@selector(backgroundRunServerOnPort:) withObject:portNumber];
    
    return YES;
}

- (void)backgroundRunServerOnPort:(NSNumber *)portNumber
{
    NSUInteger port = portNumber.unsignedIntegerValue;

    assert(self.udpStatusListener == nil);
    
    self.udpStatusListener = [[UDPStatusListener alloc] init];
    assert(self.udpStatusListener != nil);
    
    self.udpStatusListener.delegate = self;

    [self.udpStatusListener startServerOnPort:port];
    
    while (self.udpStatusListener != nil) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
    }
    
    // The loop above is supposed to run forever.  If it doesn't, something must
    // have failed and we want main to return EXIT_FAILURE.
    
    //return NO;
}

- (BOOL)runClientWithHost:(NSString *)host port:(NSUInteger)port
    // One of two Objective-C 'mains' for this program.  This creates a UDPStatusListener
    // object in client mode, talking to the specified host and port, and then 
    // periodically sends packets via that object.

    // Currently not used in LocalRadio
{
    assert(host != nil);
    assert( (port > 0) && (port < 65536) );

    assert(self.udpStatusListener == nil);

    self.udpStatusListener = [[UDPStatusListener alloc] init];
    assert(self.udpStatusListener != nil);
    
    self.udpStatusListener.delegate = self;

    [self.udpStatusListener startConnectedToHostName:host port:port];
    
    while (self.udpStatusListener != nil) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
    }
    
    // The loop above is supposed to run forever.  If it doesn't, something must 
    // have failed and we want main to return EXIT_FAILURE.
    
    return NO;
}

- (void)sendPacket
    // Called by the client code to send a UDP packet.  This is called immediately 
    // after the client has 'connected', and periodically after that from the send 
    // timer.
{
    NSData *    data;

    assert(self.udpStatusListener != nil);
    assert( ! self.udpStatusListener.isServer );
    
    data = [[NSString stringWithFormat:@"%zu bottles of beer on the wall", (99 - self.sendCount)] dataUsingEncoding:NSUTF8StringEncoding];
    
    assert(data != nil);
    
    [self.udpStatusListener sendData:data];

    self.sendCount += 1;
    if (self.sendCount > 99) {
        self.sendCount = 0;
    }
}

- (void)udpStatusListener:(UDPStatusListener *)udpStatusListener didReceiveData:(NSData *)data fromAddress:(NSData *)addr
    // This UDPStatusListener delegate method is called after successfully receiving data.
{
    assert(udpStatusListener == self.udpStatusListener);
    #pragma unused(udpStatusListener)
    assert(data != nil);
    assert(addr != nil);
    
    //NSLog(@"received %@ from %@", DisplayStringFromData(data), DisplayAddressForAddress(addr));

    NSCharacterSet * whitespaceCharacterSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    
    NSString * statusString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    NSArray * statusLines = [statusString componentsSeparatedByString:@"\n"];
    
    for (NSString * aStatusLine in statusLines)
    {
        NSArray * lineComponents = [aStatusLine componentsSeparatedByString:@":"];
        
        if (lineComponents.count == 2)
        {
            NSString * itemName = [lineComponents objectAtIndex:0];
            itemName = [itemName stringByTrimmingCharactersInSet:whitespaceCharacterSet];
            
            NSString * itemValue = [lineComponents objectAtIndex:1];
            itemValue = [itemValue stringByTrimmingCharactersInSet:whitespaceCharacterSet];
            
            if ([itemName isEqualToString:@"Frequency"] == YES)
            {
                [self updateStatusViewsForFrequencyID:itemValue];
                //NSString * megahertzString = [self.appDelegate shortHertzString:itemValue];
                //self.appDelegate.statusFrequencyTextField.stringValue = megahertzString;
            }
            else if ([itemName isEqualToString:@"RMS Power"] == YES)
            {
                //self.appDelegate.statusSignalLevelTextField.stringValue = itemValue;
                [self performSelectorOnMainThread:@selector(setStatusSignalLevelTextFieldStringValue:) withObject:itemValue waitUntilDone:NO];
                
                NSInteger signalLevel = [itemValue integerValue];
                NSNumber * signalLevelNumber = [NSNumber numberWithInteger:signalLevel];
                [self.nowPlayingDictionary setObject:signalLevelNumber forKey:@"signal_level"];
                
                [self.nowPlayingDictionary setObject:self.appDelegate.sdrController.rtlsdrTaskMode forKey:@"rtlsdr_task_mode"];
            }
        }
    }
}

- (void)setStatusSignalLevelTextFieldStringValue:(NSString *)value
{
    self.appDelegate.statusSignalLevelTextField.stringValue = value;
}

- (void) updateStatusViewsForFrequencyID:(NSString *)frequencyString
{
    NSString * megahertzString = [self.appDelegate shortHertzString:frequencyString];
    
    //self.appDelegate.statusFrequencyTextField.stringValue = megahertzString;
    [self performSelectorOnMainThread:@selector(setStatusFrequencyTextFieldStringValue:) withObject:megahertzString waitUntilDone:NO];

    NSMutableDictionary * cachedFrequencyDictionary = self.nowPlayingDictionary;
    
    NSInteger nowPlayingFrequencyID = 0;
    
    if (self.nowPlayingDictionary != NULL)
    {
        NSNumber * nowPlayingFrequencyIDNumber = [self.nowPlayingDictionary objectForKey:@"id"];
        nowPlayingFrequencyID = [nowPlayingFrequencyIDNumber integerValue];   // will be zero if radio tuned without a database record
    }
    
    if (nowPlayingFrequencyID != 0)
    {
        cachedFrequencyDictionary = [self.statusCacheDictionary objectForKey:frequencyString];
        
        if (cachedFrequencyDictionary == NULL)
        {
            cachedFrequencyDictionary = [[self.appDelegate.sqliteController frequencyRecordForFrequency:frequencyString] mutableCopy];
            
            if (cachedFrequencyDictionary != NULL)
            {
                [self.statusCacheDictionary setObject:cachedFrequencyDictionary forKey:frequencyString];
            }
        }
    }
    
    if (cachedFrequencyDictionary != NULL)
    {
        self.nowPlayingDictionary = cachedFrequencyDictionary;
    
        NSString * stationName = [cachedFrequencyDictionary objectForKey:@"station_name"];
        
        //self.appDelegate.statusNameTextField.stringValue = stationName;
        [self performSelectorOnMainThread:@selector(setStatusNameTextFieldStringValue:) withObject:stationName waitUntilDone:NO];

        NSString * frequencyIDString = [cachedFrequencyDictionary objectForKey:@"id"];
        if (frequencyIDString != NULL)
        {
            //self.appDelegate.statusFrequencyIDTextField.stringValue = frequencyIDString;
            [self performSelectorOnMainThread:@selector(setStatusFrequencyIDTextFieldStringValue:) withObject:frequencyIDString waitUntilDone:NO];
        }
        else
        {
            //self.appDelegate.statusFrequencyIDTextField.stringValue = @"N/A";
            [self performSelectorOnMainThread:@selector(setStatusFrequencyIDTextFieldStringValue:) withObject:@"N/A" waitUntilDone:NO];
        }
    }
}


- (void)setStatusFrequencyTextFieldStringValue:(NSString *)value
{
    self.appDelegate.statusFrequencyTextField.stringValue = value;
}

- (void)setStatusNameTextFieldStringValue:(NSString *)value
{
    self.appDelegate.statusNameTextField.stringValue = value;
}


- (void)setStatusFrequencyIDTextFieldStringValue:(NSString *)value
{
    self.appDelegate.statusFrequencyIDTextField.stringValue = value;
}



- (void)udpStatusListener:(UDPStatusListener *)udpStatusListener didReceiveError:(NSError *)error
    // This UDPStatusListener delegate method is called after a failure to receive data.
{
    assert(udpStatusListener == self.udpStatusListener);
    #pragma unused(udpStatusListener)
    assert(error != nil);
    NSLog(@"UDPStatusListenerController - received error: %@", DisplayErrorFromError(error));
}

- (void)udpStatusListener:(UDPStatusListener *)udpStatusListener didSendData:(NSData *)data toAddress:(NSData *)addr
    // This UDPStatusListener delegate method is called after successfully sending data.
{
    assert(udpStatusListener == self.udpStatusListener);
    #pragma unused(udpStatusListener)
    assert(data != nil);
    assert(addr != nil);
    NSLog(@"UDPStatusListenerController -     sent %@ to   %@", DisplayStringFromData(data), DisplayAddressForAddress(addr));
}

- (void)udpStatusListener:(UDPStatusListener *)udpStatusListener didFailToSendData:(NSData *)data toAddress:(NSData *)addr error:(NSError *)error
    // This UDPStatusListener delegate method is called after a failure to send data.
{
    assert(udpStatusListener == self.udpStatusListener);
    #pragma unused(udpStatusListener)
    assert(data != nil);
    assert(addr != nil);
    assert(error != nil);
    NSLog(@"UDPStatusListenerController - sending %@ to   %@, error: %@", DisplayStringFromData(data), DisplayAddressForAddress(addr), DisplayErrorFromError(error));
}

- (void)udpStatusListener:(UDPStatusListener *)udpStatusListener didStartWithAddress:(NSData *)address
    // This UDPStatusListener delegate method is called after the object has successfully started up.
{
    assert(udpStatusListener == self.udpStatusListener);
    #pragma unused(udpStatusListener)
    assert(address != nil);
    
    if (self.udpStatusListener.isServer) {
        NSLog(@"UDPStatusListenerController - udpStatusListener receiving on %@", DisplayAddressForAddress(address));
    } else {
        NSLog(@"UDPStatusListenerController - udpStatusListener sending to %@", DisplayAddressForAddress(address));
    }
    
    /*
    if ( ! self.udpStatusListener.isServer ) {
        [self sendPacket];
        
        assert(self.sendTimer == nil);
        self.sendTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(sendPacket) userInfo:nil repeats:YES];
    }
    */
}

- (void)udpStatusListener:(UDPStatusListener *)udpStatusListener didStopWithError:(NSError *)error
    // This UDPStatusListener delegate method is called  after the object stops spontaneously.
{
    assert(udpStatusListener == self.udpStatusListener);
    #pragma unused(udpStatusListener)
    assert(error != nil);
    NSLog(@"UDPStatusListenerController - udpStatusListener failed with error: %@", DisplayErrorFromError(error));
    self.udpStatusListener = nil;
}

@end


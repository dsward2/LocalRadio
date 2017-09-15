//
//  UDPStatusListener.h
//  LocalRadio
//
//  Created by Douglas Ward on 7/28/17.
//  Copyright © 2017 ArkPhone LLC. All rights reserved.
//

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

#import <Foundation/Foundation.h>

#if TARGET_OS_EMBEDDED || TARGET_IPHONE_SIMULATOR
    #import <CFNetwork/CFNetwork.h>
#else
    #import <CoreServices/CoreServices.h>
#endif

@protocol UDPStatusListenerDelegate;

@interface UDPStatusListener : NSObject

- (id)init;

- (void)startServerOnPort:(NSUInteger)port;
    // Starts an UDPStatusListener server on the specified port.  Will call the
    // -udpStatusListener:didStartWithAddress: delegate method on success and the
    // -udpStatusListener:didStopWithError: on failure.  After that, the various
    // 'data' delegate methods may be called.

- (void)startConnectedToHostName:(NSString *)hostName port:(NSUInteger)port;
    // Starts a client targetting the specified host and port.  
    // Will call -udpStatusListener:didStartWithAddress: delegate method on success and
    // the -udpStatusListener:didStopWithError: on failure.  At that point you can call
    // -sendData: to send data to the server and the various 'data' delegate 
    // methods may be called.

- (void)sendData:(NSData *)data;
    // On the client, sends the specified data to the server.  The 
    // -udpStatusListener:didSendData:toAddress: or -udpStatusListener:didFailToSendData:toAddress:error:
    // delegate method will be called to indicate the success or failure 
    // of the send, and the -udpStatusListener:didReceiveData:fromAddress: delegate method
    // will be called if a response is received.

- (void)stop;
    // Will stop the object, preventing any future network operations or delegate 
    // method calls until the next start call.

@property (nonatomic, weak,   readwrite) id<UDPStatusListenerDelegate>    delegate;
@property (nonatomic, assign, readonly, getter=isServer) BOOL   server;
@property (nonatomic, copy,   readonly ) NSString *             hostName;       // valid in client mode
@property (nonatomic, copy,   readonly ) NSData *               hostAddress;    // valid in client mode after successful start
@property (nonatomic, assign, readonly ) NSUInteger             port;           // valid in client and server mode

@end

@protocol UDPStatusListenerDelegate <NSObject>

@optional

// In all cases an address is an NSData containing some form of (struct sockaddr), 
// specifically a (struct sockaddr_in) or (struct sockaddr_in6).

- (void)udpStatusListener:(UDPStatusListener *)updStatusListener didReceiveData:(NSData *)data fromAddress:(NSData *)addr;
    // Called after successfully receiving data.
    // On a server object a data response will be sent back to the sender.
    //
    // assert(udpStatusListener != nil);
    // assert(data != nil);
    // assert(addr != nil);
    
- (void)udpStatusListener:(UDPStatusListener *)udpStatusListener didReceiveError:(NSError *)error;
    // Called after a failure to receive data.
    //
    // assert(udpStatusListener != nil);
    // assert(error != nil);
    
- (void)udpStatusListener:(UDPStatusListener *)udpStatusListener didSendData:(NSData *)data toAddress:(NSData *)addr;
    // Called after successfully sending data.  On the server side this is typically 
    // the result of an echo.
    //
    // assert(echo != nil);
    // assert(data != nil);
    // assert(addr != nil);
    
- (void)udpStatusListener:(UDPStatusListener *)udpStatusListener didFailToSendData:(NSData *)data toAddress:(NSData *)addr error:(NSError *)error;
    // Called after a failure to send data.
    //
    // assert(udpStatusListener != nil);
    // assert(data != nil);
    // assert(addr != nil);
    // assert(error != nil);

- (void)udpStatusListener:(UDPStatusListener *)udpStatusListener didStartWithAddress:(NSData *)address;
    // Called after the object has successfully started up.  On the client addresses 
    // is the list of addresses associated with the host name passed to 
    // -startConnectedToHostName:port:.  On the server, this is the local address 
    // to which the server is bound.
    //
    // assert(udpStatusListener != nil);
    // assert(address != nil);
    
- (void)udpStatusListener:(UDPStatusListener *)udpStatusListener didStopWithError:(NSError *)error;
    // Called after the object stops spontaneously (that is, after some sort of failure, 
    // but now after a call to -stop).
    //
    // assert(udpStatusListener != nil);
    // assert(error != nil);

@end


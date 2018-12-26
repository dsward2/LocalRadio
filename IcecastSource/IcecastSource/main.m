//
//  main.m
//  IcecastSource
//
//  Created by Douglas Ward on 9/23/18.
//  Copyright © 2018 ArkPhone LLC. All rights reserved.
//

//  We configure two Icecast streaming ports for the LocalRadio.aac mount: http and https.
//  The unencrypted http port is used to send source audio to the Icecast server on the same host, which
//  automatically provides the same audio data for http and https streaming from Icecast.

//  Code sign note: use inherited entitlements
//  https://stackoverflow.com/questions/11821632/mac-os-app-sandbox-with-command-line-tool

//  Input received through stdin, usually from LocalRadio UDPListener
//  Output is sent to IP address 127.0.0.1 and specified port number as Icecast source

//  Icecast source protocol docs:
//  https://gist.github.com/ePirat/adc3b8ba00d85b7e3870
//
//  We are using the PUT style for starting the Icecast source, like this header example -
//      > PUT /stream.mp3 HTTP/1.1
//      > Host: example.com:8000
//      > Authorization: Basic c291cmNlOmhhY2ttZQ==
//      > User-Agent: curl/7.51.0
//      > Accept: */*
//      > Transfer-Encoding: chunked
//      > Content-Type: audio/mpeg
//      > Ice-Public: 1
//      > Ice-Name: Teststream
//      > Ice-Description: This is just a simple test stream
//      > Ice-URL: http://example.org
//      > Ice-Genre: Rock
//      > Expect: 100-continue
//      >
//      < HTTP/1.1 100 Continue
//      < Server: Icecast 2.5.0
//      < Connection: Close
//      < Accept-Encoding: identity
//      < Allow: GET, SOURCE
//      < Date: Tue, 31 Jan 2017 21:26:37 GMT
//      < Cache-Control: no-cache
//      < Expires: Mon, 26 Jul 1997 05:00:00 GMT
//      < Pragma: no-cache
//      < Access-Control-Allow-Origin: *
//      > [ Stream data sent by client ]
//      < HTTP/1.0 200 OK



@import Foundation;

// for receiving input via UDP port
#import "GCDAsyncUdpSocket.h"

// for sending output as the Icecast Source
#import "GCDAsyncSocket.h"

#include <sys/types.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <sys/un.h>
#include <sys/event.h>
#include <sys/ioctl.h>
#include <sys/sysctl.h>

#include <net/if.h>
#include <netinet/in.h>
#include <netinet/ip.h>
#include <netinet/tcp.h>
#include <arpa/telnet.h>
#include <arpa/inet.h>

#include <err.h>
#include <errno.h>
#include <limits.h>
#include <netdb.h>
#include <poll.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <inttypes.h>
#include <string.h>
#include <getopt.h>
#include <fcntl.h>
#include <pthread.h>


#define OPProcessValueUnknown UINT_MAX
//#define USE_SECURE_CONNECTION 1
//#define MANUALLY_EVALUATE_TRUST 1



#pragma mark * Main

#define zeroBufferLength 4096

@interface Main : NSObject <GCDAsyncSocketDelegate, GCDAsyncUdpSocketDelegate>
{
}
@end

@interface Main ()
@end

Main * mainObj;    // global singleton
pid_t originalParentProcessPID;
//GCDAsyncUdpSocket *  udpInputSocket;
GCDAsyncSocket * icecastSourceSocket;
NSString * userName;
NSString * password;
NSString * host;
NSString * icecastMountName;
NSString * iceURLString;
BOOL readyToSend;
int port;
int bitrate;
BOOL doExit;
int lastSignum;

@implementation Main

// ================================================================

static const char encodingTable[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

- (NSString *)base64Data:(NSData *)inputData
{
    if (inputData.length == 0)
        return @"";

    char *characters = malloc(((inputData.length + 2) / 3) * 4);
    if (characters == NULL)
        return nil;
    NSUInteger length = 0;
    
    NSUInteger i = 0;
    while (i < inputData.length)
    {
        char buffer[3] = {0,0,0};
        short bufferLength = 0;
        while (bufferLength < 3 && i < inputData.length)
            buffer[bufferLength++] = ((char *)inputData.bytes)[i++];
        
        //  Encode the bytes in the buffer to four characters, including padding "=" characters if necessary.
        characters[length++] = encodingTable[(buffer[0] & 0xFC) >> 2];
        characters[length++] = encodingTable[((buffer[0] & 0x03) << 4) | ((buffer[1] & 0xF0) >> 4)];
        if (bufferLength > 1)
            characters[length++] = encodingTable[((buffer[1] & 0x0F) << 2) | ((buffer[2] & 0xC0) >> 6)];
        else characters[length++] = '=';
        if (bufferLength > 2)
            characters[length++] = encodingTable[buffer[2] & 0x3F];
        else characters[length++] = '=';
    }
    
    return [[NSString alloc] initWithBytesNoCopy:characters length:length encoding:NSASCIIStringEncoding freeWhenDone:YES];
}

// ================================================================

//- (BOOL)runIcecastSourceToHost:(NSString *)host port:(NSUInteger)port
- (void)runIcecastSource
{
    //NSLog(@"IcecastSource starting on port %lu", (unsigned long)port);

    //NSString * formattedAuthorizationString = [NSString stringWithFormat:@"%@:%@", userName, password];
    //NSData * authData = [formattedAuthorizationString dataUsingEncoding:NSUTF8StringEncoding];
    //NSString * authorizationString = [self base64Data:authData];
    //NSLog(@"IcecastSource Icecast login %@ base64 %@", formattedAuthorizationString, authorizationString);

    //dispatch_queue_t senderQueue = dispatch_queue_create("com.arkphone.IcecastSource.LocalRadio.SenderQueue", NULL);
    //udpInputSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:(id)self delegateQueue: senderQueue];

    doExit = NO;

    NSTimeInterval lastReadTime = [NSDate timeIntervalSinceReferenceDate] + 20;
    NSTimeInterval nextTimeoutReportInterval = 5;
    
    // Main loop
    while (doExit == NO)
    {
        //NSLog(@"IcecastSource polling loop");

        NSTimeInterval currentTime = [NSDate timeIntervalSinceReferenceDate];

        unsigned long bytesAvailableCount = 0;
    
        int ioctl_result = ioctl( 0, FIONREAD, &bytesAvailableCount);
        if( ioctl_result < 0) {
            NSLog(@"IcecastSource ioctl failed: %s\n", strerror( errno));
            doExit = YES;
            break;
        }
        
        if( bytesAvailableCount <= 0)
        {
            if (readyToSend == YES)
            {
                usleep(5000);
            }
        }
        else
        {
            if (bytesAvailableCount > 4096)
            {
                bytesAvailableCount = 4096;
            }
        
            char * buf = malloc(bytesAvailableCount);
            long readResult = read( 0, buf, bytesAvailableCount);
            if( readResult <= 0) {
                NSLog(@"IcecastSource read failed: %s\n", strerror( errno));
                break;
            }
            else
            {
                lastReadTime = currentTime;
                nextTimeoutReportInterval = 5;

                if (icecastSourceSocket == NULL)
                {
                    [self startIcecastSourceSocketToHost:host port:port];
                }
                
                //NSLog(@"IcecastSource sending data, length=%ld", bytesAvailableCount);

                if (readyToSend == YES)
                {
                    NSData * bufferData = [[NSData alloc] initWithBytes:buf length:bytesAvailableCount];
                    
                    [icecastSourceSocket writeData:bufferData withTimeout:0.1 tag:0];

                    //NSLog(@"IcecastSource sent %lu bytes\n", (unsigned long)[bufferData length]);

                    //fwrite(buf, bytesAvailableCount, 1, stdout);    // also write a copy to stdout, perhaps for sox, etc.
                    //fflush(stdout);
                }
            }
            free(buf);
        }

        NSTimeInterval intervalSinceLastRead = currentTime - lastReadTime;
        if (intervalSinceLastRead >= nextTimeoutReportInterval)
        {
            //NSLog(@"IcecastSource intervalSinceLastRead >= %f", nextTimeoutReportInterval);
            
            nextTimeoutReportInterval += 5;
            
            pid_t currentParentProcessPID = getppid();
            if (currentParentProcessPID != originalParentProcessPID)
            {
                //NSLog(@"IcecastSource original parent process PID changed, terminating....");
                //self.doExit = YES;
            }
        }
    }

    //NSLog(@"IcecastSource polling loop exited");
}

// ====================================================================================

- (void)startIcecastSourceSocketToHost:(NSString *)host port:(uint16_t)port
{
    // Create our GCDAsyncSocket instance.
    //
    // Notice that we give it the normal delegate AND a delegate queue.
    // The socket will do all of its operations in a background queue,
    // and you can tell it which thread/queue to invoke your delegate on.
    // In this case, we're just saying invoke us on the main thread.
    // But you can see how trivial it would be to create your own queue,
    // and parallelize your networking processing code by having your
    // delegate methods invoked and run on background queues.
    icecastSourceSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    
    // Now we tell the ASYNCHRONOUS socket to connect.
    //
    // Recall that GCDAsyncSocket is ... asynchronous.
    // This means when you tell the socket to connect, it will do so ... asynchronously.
    // After all, do you want your main thread to block on a slow network connection?
    //
    // So what's with the BOOL return value, and error pointer?
    // These are for early detection of obvious problems, such as:
    //
    // - The socket is already connected.
    // - You passed in an invalid parameter.
    // - The socket isn't configured properly.
    //
    // The error message might be something like "Attempting to connect without a delegate. Set a delegate first."
    //
    // When the asynchronous sockets connects, it will invoke the socket:didConnectToHost:port: delegate method.
    
    NSError *error = nil;
    
    if ([icecastSourceSocket connectToHost:host onPort:port error:&error] == NO)
    {
        NSLog(@"IcecastSource Unable to connect to %@ %hu due to invalid configuration: %@", host, port, error);
    }
    else
    {
        NSLog(@"IcecastSource Connecting to \"%@\" on port %hu...", host, port);
    }
    
#if USE_SECURE_CONNECTION
    
    // The connect method above is asynchronous.
    // At this point, the connection has been initiated, but hasn't completed.
    // When the connection is established, our socket:didConnectToHost:port: delegate method will be invoked.
    //
    // Now, for a secure connection we have to connect to the HTTPS server running on port 443.
    // The SSL/TLS protocol runs atop TCP, so after the connection is established we want to start the TLS handshake.
    //
    // We already know this is what we want to do.
    // Wouldn't it be convenient if we could tell the socket to queue the security upgrade now instead of waiting?
    // Well in fact you can! This is part of the queued architecture of AsyncSocket.
    //
    // After the connection has been established, AsyncSocket will look in its queue for the next task.
    // There it will find, dequeue and execute our request to start the TLS security protocol.
    //
    // The options passed to the startTLS method are fully documented in the GCDAsyncSocket header file.


    #if MANUALLY_EVALUATE_TRUST
    {
        // Use socket:shouldTrustPeer: delegate method for manual trust evaluation
        
        NSDictionary *options = @{
            GCDAsyncSocketManuallyEvaluateTrust : @(YES),
            //GCDAsyncSocketSSLPeerName : CERT_HOST,
            GCDAsyncSocketSSLPeerName : host,
        };
        
        NSLog(@"IcecastSource Requesting StartTLS with options:\n%@", options);
        [icecastSourceSocket startTLS:options];
    }
    #else
    {
        // Use default trust evaluation, and provide basic security parameters
        
        NSDictionary *options = @{
            GCDAsyncSocketSSLPeerName : CERT_HOST,
        };
        
        NSLog(@"IcecastSource Requesting StartTLS with options:\n%@", options);
        [icecastSourceSocket startTLS:options];
    }
    #endif
    
#endif
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port
{
    NSLog(@"IcecastSource socket: didConnectToHost:%@ port:%hu, client port: %hu", host, port, sock.localPort);
    
    // HTTP is a really simple protocol.
    //
    // If you don't already know all about it, this is one of the best resources I know (short and sweet):
    // http://www.jmarshall.com/easy/http/
    //
    // We're just going to tell the server to send us the metadata (essentially) about a particular resource.
    // The server will send an http response, and then immediately close the connection.
    
    //NSString *requestStrFrmt = @"HEAD / HTTP/1.0\r\nHost: %@\r\nConnection: Close\r\n\r\n";
    
//      > PUT /stream.aac HTTP/1.1
//      > Host: example.com:8000
//      > Authorization: Basic c291cmNlOmhhY2ttZQ==
//      > User-Agent: curl/7.51.0
//      > Accept: */*
//      > Transfer-Encoding: chunked
//      > Content-Type: audio/aac
//      > Ice-Public: 1
//      > Ice-Name: Teststream
//      > Ice-Description: This is just a simple test stream
//      > Ice-URL: http://example.org
//      > Ice-Genre: Rock
//      > Expect: 100-continue

    NSString * formattedAuthorizationString = [NSString stringWithFormat:@"%@:%@", userName, password];
    NSData * authData = [formattedAuthorizationString dataUsingEncoding:NSUTF8StringEncoding];

    NSString * authorizationString = [self base64Data:authData];

    //NSString * streamURLString = [NSString stringWithFormat:@"https://%@:%hu/%@", host, port, icecastMountName];

    //NSString * iceBitrate = @"64";
    NSString * iceBitrate = [NSString stringWithFormat:@"%d", bitrate / 1000]; // 32, 64 or 128

    //NSString * iceAudioInfo = @"samplerate=48000;quality=10%2e0;channels=2";
    //NSString * iceAudioInfo = @"bitrate=64";
    NSString * iceAudioInfo = [NSString stringWithFormat:@"ice-bitrate=%@;ice-channels=2;ice-samplerate=48000;", iceBitrate];
    
    NSString * formatString = @"aac";   // for kMPEG4Object_AAC_LC
    if (bitrate < 64000)
    {
        formatString = @"aacp";     // for kAudioFormatMPEG4AAC_HE
    }

    NSString *requestStrFrmt =
            @"PUT /%@ HTTP/1.1\r\n"\
            @"Host: %@\r\n"\
            @"Authorization: Basic %@\r\n"\
            @"User-Agent: curl/7.51.0\r\n"\
            @"Accept: */*\r\n"\
            @"Content-Type: audio/%@\r\n"\
            @"Cache-Control: no-cache\r\n"\
            @"Transfer-Encoding: chunked\r\n"\
            @"Ice-Public: 0\r\n"\
            @"Ice-Name: LocalRadio for macOS\r\n"\
            @"Ice-Description: LocalRadio for macOS  - https://github.com/dsward2/localradio\r\n"\
            @"Ice-URL: %@\r\n"\
            @"Ice-Genre: LocalRadio\r\n"\
            @"Ice-Bitrate: %@\r\n"\
            @"Ice-Audio-Info: %@\r\n"\
            @"Connection: keep-alive\r\n"\
            @"Expect: 100-continue\r\n"\
            @"\r\n\r\n";        // end of HTTP header

    //NSString *requestStr = [NSString stringWithFormat:requestStrFrmt, icecastMountName, host, authorizationString, formatString, streamURLString, iceBitrate, iceAudioInfo];
    NSString *requestStr = [NSString stringWithFormat:requestStrFrmt, icecastMountName, host, authorizationString, formatString, iceURLString, iceBitrate, iceAudioInfo];
    
    NSData *requestData = [requestStr dataUsingEncoding:NSUTF8StringEncoding];
    
    [icecastSourceSocket writeData:requestData withTimeout:-1.0 tag:0];
    
    NSLog(@"IcecastSource httpRequest header:\n%@", requestStr);
    
    // Side Note:
    //
    // The AsyncSocket family supports queued reads and writes.
    //
    // This means that you don't have to wait for the socket to connect before issuing your read or write commands.
    // If you do so before the socket is connected, it will simply queue the requests,
    // and process them after the socket is connected.
    // Also, you can issue multiple write commands (or read commands) at a time.
    // You don't have to wait for one write operation to complete before sending another write command.
    //
    // The whole point is to make YOUR code easier to write, easier to read, and easier to maintain.
    // Do networking stuff when it is easiest for you, or when it makes the most sense for you.
    // AsyncSocket adapts to your schedule, not the other way around.
    
#if READ_HEADER_LINE_BY_LINE
    
    // Now we tell the socket to read the first line of the http response header.
    // As per the http protocol, we know each header line is terminated with a CRLF (carriage return, line feed).
    
    [asyncSocket readDataToData:[GCDAsyncSocket CRLFData] withTimeout:-1.0 tag:0];
    
#else
    
    // Now we tell the socket to read the full header for the http response.
    // As per the http protocol, we know the header is terminated with two CRLF's (carriage return, line feed).
    
    NSData *responseTerminatorData = [@"\r\n\r\n" dataUsingEncoding:NSASCIIStringEncoding];

    [icecastSourceSocket readDataToData:responseTerminatorData withTimeout:-1.0 tag:0];
    
#endif
}

- (void)socket:(GCDAsyncSocket *)sock didReceiveTrust:(SecTrustRef)trust
                                    completionHandler:(void (^)(BOOL shouldTrustPeer))completionHandler
{
    NSLog(@"IcecastSource socket:didReceiveTrust:");
    
    dispatch_queue_t bgQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(bgQueue, ^{
        
        // This is where you would (eventually) invoke SecTrustEvaluate.
        // Presumably, if you're using manual trust evaluation, you're likely doing extra stuff here.
        // For example, allowing a specific self-signed certificate that is known to the app.

        //SecTrustResultType result = kSecTrustResultDeny;
        SecTrustResultType result = kSecTrustResultProceed;

        OSStatus anchorStatus = SecTrustSetAnchorCertificates(trust, (CFArrayRef)[NSArray array]); // no anchors
        OSStatus keychainsStatus = SecTrustSetKeychains(trust, (CFArrayRef)[NSArray array]); // no keychains
        #pragma unused (anchorStatus, keychainsStatus)

        CSSM_APPLE_TP_ACTION_DATA tp_action_data;
        memset(&tp_action_data, 0, sizeof(tp_action_data));
        tp_action_data.Version = CSSM_APPLE_TP_ACTION_VERSION;
        tp_action_data.ActionFlags = CSSM_TP_ACTION_IMPLICIT_ANCHORS;

        CFDataRef action_data_ref =
                CFDataCreateWithBytesNoCopy(kCFAllocatorDefault,
                (UInt8 *)&tp_action_data,
                sizeof(tp_action_data), kCFAllocatorNull);
        
        OSStatus secTrustStatus = SecTrustSetParameters(trust, CSSM_TP_ACTION_DEFAULT,
                                 action_data_ref);

        OSStatus status = SecTrustEvaluate(trust, &result);
        
        if (status == noErr && (result == kSecTrustResultProceed || result == kSecTrustResultUnspecified)) {
            NSLog(@"IcecastSource SecTrustEvaluate completed");
            completionHandler(YES);
        }
        else {
            NSLog(@"IcecastSource SecTrustEvaluate failed");
            completionHandler(NO);
        }
    });
}

- (void)socketDidSecure:(GCDAsyncSocket *)sock
{
    // This method will be called if USE_SECURE_CONNECTION is set
    
    NSLog(@"IcecastSource socketDidSecure:");
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
    //NSLog(@"IcecastSource socket:didWriteDataWithTag:");
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    NSLog(@"IcecastSource socket:didReadData:withTag:");
    
    NSString *httpResponse = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
#if READ_HEADER_LINE_BY_LINE
    
    NSLog(@"IcecastSource Line httpResponse: %@", httpResponse);
    
    // As per the http protocol, we know the header is terminated with two CRLF's.
    // In other words, an empty line.
    
    if ([data length] == 2) // 2 bytes = CRLF
    {
        NSLog(@"IcecastSource <done>");
    }
    else
    {
        // Read the next line of the header
        [asyncSocket readDataToData:[GCDAsyncSocket CRLFData] withTimeout:-1.0 tag:0];
    }
    
#else
    
    NSLog(@"IcecastSource Full httpResponse:\n%@", httpResponse);


    if ([httpResponse isEqualToString:@"HTTP/1.1 100 Continue\r\n\r\n"] == YES)
    {
        readyToSend = YES;
    }

#endif
    
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
    // If we requested HTTP/1.0, we expect the server to close the connection as soon as it has sent the response.
    
    NSLog(@"IcecastSource socketDidDisconnect:%p withError:%@", sock, err);
}



@end

void signal_callback_handler(int signum)
{
   //printf("IcecastSource Caught signal %d\n",signum);   // TODO: printf not safe here?
   // Cleanup and close up stuff here
   // Terminate program
   doExit = YES;
   lastSignum = signum;
   //exit(signum);
}


// per https://stackoverflow.com/questions/21985925/how-to-get-parent-process-id-using-objective-c-in-os-x
int ProcessIDForParentOfProcessID(int pid)
{
    struct kinfo_proc info;
    size_t length = sizeof(struct kinfo_proc);
    int mib[4] = { CTL_KERN, KERN_PROC, KERN_PROC_PID, pid };
    if (sysctl(mib, 4, &info, &length, NULL, 0) < 0)
        return OPProcessValueUnknown;
    if (length == 0)
        return OPProcessValueUnknown;
    return info.kp_eproc.e_ppid;
}



int main(int argc, char **argv)
{
    #pragma unused(argc)
    #pragma unused(argv)
    int                 retVal;
    BOOL                success;
    //int                 port;
    struct sigaction sigact;
    
    @autoreleasepool {
        //raise(SIGSTOP); // Stop and wait for debugger. Click the Debugger's Resume button to continue execution

        NSLog(@"IcecastSource main() started\n");
        
        lastSignum = 0;
        sigact.sa_handler = &signal_callback_handler;
        sigemptyset(&sigact.sa_mask);
        sigact.sa_flags = 0;
        sigaction(SIGINT, &sigact, NULL);
        sigaction(SIGTERM, &sigact, NULL);
        sigaction(SIGQUIT, &sigact, NULL);
        sigaction(SIGPIPE, &sigact, NULL);

        originalParentProcessPID = getppid();
        icecastSourceSocket = NULL;

        retVal = EXIT_FAILURE;
        success = YES;

        //port = atoi(argv[argc - 1]);
        
        char const * argMode = "";
        char const * argUserName = "source";
        char const * argPassword = "missing_password";
        char const * argHost = "localhost";
        char const * argPort = "17003";
        char const * argBitrate = "64000";
        char const * argIcecastMountName = "localradio.aac";
        char const * argIceURL = "https://localhost:17004";      // for display only, we indicate the https link

        for (int i = 0; i < argc; i++)
        {
            char * argStringPtr = (char *)argv[i];
            
            if (strcmp(argStringPtr, "-u") == 0)        // user name
            {
                argMode = argStringPtr;
            }
            else if (strcmp(argMode, "-u") == 0)
            {
                argUserName = argStringPtr;
                argMode = "";
            }
            else if (strcmp(argStringPtr, "-pw") == 0)   // password
            {
                argMode = argStringPtr;
            }
            else if (strcmp(argMode, "-pw") == 0)
            {
                argPassword = argStringPtr;
                argMode = "";
            }
            else if (strcmp(argStringPtr, "-h") == 0)   // host for source connection
            {
                argMode = argStringPtr;
            }
            else if (strcmp(argMode, "-h") == 0)
            {
                argHost = argStringPtr;
                argMode = "";
            }
            else if (strcmp(argStringPtr, "-p") == 0)   // port
            {
                argMode = argStringPtr;
            }
            else if (strcmp(argMode, "-p") == 0)
            {
                argPort = argStringPtr;
                argMode = "";
            }
            else if (strcmp(argStringPtr, "-b") == 0)   // bitrate
            {
                argMode = argStringPtr;
            }
            else if (strcmp(argMode, "-b") == 0)
            {
                argBitrate = argStringPtr;
                argMode = "";
            }
            else if (strcmp(argStringPtr, "-m") == 0)   // Icecast mount name
            {
                argMode = argStringPtr;
            }
            else if (strcmp(argMode, "-m") == 0)
            {
                argIcecastMountName = argStringPtr;
                argMode = "";
            }
            else if (strcmp(argStringPtr, "-o") == 0)   // Ice-URL, audio stream for display on Icecast web page
            {
                argMode = argStringPtr;
            }
            else if (strcmp(argMode, "-o") == 0)
            {
                argIceURL = argStringPtr;
                argMode = "";
            }
        }
        
        host = [[NSString alloc] initWithCString:argHost encoding:NSUTF8StringEncoding];
        port = atoi(argPort);
        bitrate = atoi(argBitrate);
        
        userName = [[NSString alloc] initWithCString:argUserName encoding:NSUTF8StringEncoding];
        password = [[NSString alloc] initWithCString:argPassword encoding:NSUTF8StringEncoding];
        icecastMountName = [[NSString alloc] initWithCString:argIcecastMountName encoding:NSUTF8StringEncoding];
        iceURLString = [[NSString alloc] initWithCString:argIceURL encoding:NSUTF8StringEncoding];

        if ( (port > 0) && (port < 65536) )
        {
            retVal = EXIT_SUCCESS;

            // sender mode

            mainObj = [[Main alloc] init];
            assert(mainObj != nil);
            
            //[mainObj runIcecastSource:self];
            
            readyToSend = NO;
            
            [mainObj performSelectorInBackground:@selector(runIcecastSource) withObject:NULL];
            
            do {
                CFRunLoopRunInMode (kCFRunLoopDefaultMode, 0.25, false);
                //usleep(5000);
            } while (doExit == NO);
            
            success = YES;
        }
        
        if (success)
        {
            if (retVal == EXIT_FAILURE)
            {
                //fprintf(stderr, "usage: %s -l [port]\n",   getprogname());
                NSLog(@"usage: %s -h [host] -p [port] -u [user] -pw [password]\n",   getprogname());
            }
        }
        else
        {
            retVal = EXIT_FAILURE;
        }

        if (lastSignum != SIGTERM)
        {
            NSLog(@"IcecastSource main() exit, signum = %d, retVal = %d", lastSignum, retVal);
        }
    }
    
    return retVal;
}


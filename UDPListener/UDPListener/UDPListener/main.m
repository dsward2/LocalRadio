//
//  main.m
//  UDPListener
//
//  Created by Douglas Ward on 7/9/17.
//  Copyright © 2017-2018 ArkPhone LLC. All rights reserved.
//

//  Code sign note: use inherited entitlements
//  https://stackoverflow.com/questions/11821632/mac-os-app-sandbox-with-command-line-tool

@import Foundation;

#import "GCDAsyncUdpSocket.h"

#pragma mark * Main

#define pollingInterval 0.1f
#define whiteNoiseBufferLength 4096

@interface Main : NSObject <GCDAsyncUdpSocketDelegate>
{

}

@property (nonatomic, strong, readwrite) GCDAsyncUdpSocket *  udpSocket;
@property (assign) NSTimeInterval lastSendTime;
@property (assign) NSTimeInterval lastReceiveTime;
@property (strong) NSData * whiteNoiseData;
@property (assign) BOOL doExit;

- (BOOL)runServerOnPort:(NSUInteger)port;

@end

@interface Main ()


@end

@implementation Main


- (void)pollAudio
{
    

    NSTimeInterval currentTime = [NSDate timeIntervalSinceReferenceDate];
    
    //NSTimeInterval interval = currentTime - self.lastSendTime;
    NSTimeInterval interval = currentTime - self.lastReceiveTime;
    
    if (interval > 4.0f)
    {
        // audio input was not received recently, send some white noise to EZStream to keep Icecast connection alive

        //NSLog(@"UDPListener sending binary zeros to stdout");
        
        [self sendDataToEZStream:self.whiteNoiseData];
        
        //self.lastReceiveTime = currentTime;
    }
}


- (BOOL)runServerOnPort:(NSUInteger)port
{
    NSLog(@"UDPListener starting server on port %lu", (unsigned long)port);

    char whiteNoiseBuffer[whiteNoiseBufferLength];
    for (int i = 0; i < whiteNoiseBufferLength; i++)
    {
        // signed 16-bit white noise ---- 0, 1, 0, -1 ---- 0000 0001 0000 FFFF
        unsigned char whiteNoiseChar = 0;
        if (i % 8 == 3)
        {
            whiteNoiseChar = 1;
        }
        else if (i % 8 == 6)
        {
            whiteNoiseChar = 255;
        }
        else if (i % 8 == 7)
        {
            whiteNoiseChar = 255;
        }
        whiteNoiseBuffer[i] = whiteNoiseChar;
    }
    
    self.whiteNoiseData = [NSData dataWithBytes:&whiteNoiseBuffer length:whiteNoiseBufferLength];

    dispatch_queue_t listenerQueue = dispatch_queue_create("com.arkphone.LocalRadio.ListenerQueue", NULL);

	self.udpSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue: listenerQueue];

    NSError *error = nil;

    if (![self.udpSocket bindToPort:port error:&error])
    {
        NSLog(@"UDPListener Error starting server (bind): %@", error);
        return NO;
    }
    
    if (![self.udpSocket beginReceiving:&error])
    {
        [self.udpSocket close];
        
        NSLog(@"UDPListener Error starting server (recv): %@", error);
        return NO;
    }
    
    self.doExit = NO;

    while (self.doExit == NO)
    {
        [self pollAudio];

        CFRunLoopRunInMode (kCFRunLoopDefaultMode, 0.25, false);

        //[NSThread sleepForTimeInterval:pollingInterval];
        usleep(1000);
    }
    
    return YES;
}




- (void)sendDataToEZStream:(NSData *)streamData
{
    @synchronized (self) {
        //NSString *msg = [[NSString alloc] initWithData:streamData encoding:NSUTF8StringEncoding];
        
        NSInteger dataLength = streamData.length;
        void * dataPtr = (void *)streamData.bytes;

        size_t writeResult = fwrite(dataPtr, 1, dataLength, stdout);
        #pragma unused(writeResult)
        
        fflush(stdout);
        
        self.lastSendTime = [NSDate timeIntervalSinceReferenceDate];
    }
}



- (void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data
                                             fromAddress:(NSData *)address
                                       withFilterContext:(nullable id)filterContext
{
    //NSLog(@"UDPListener didReceiveData length=%ld", data.length);

    //NSLog(@"UDPListener sending buffered data to stdout, length: %ld", [data length]);
    
    const void * dataPtr = data.bytes;
    #pragma unused(dataPtr)
    
    //NSString * dataString = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
    //NSLog(@"UDPListener dataString: %@", dataString);

    self.lastReceiveTime = [NSDate timeIntervalSinceReferenceDate];

    [self sendDataToEZStream:data];
}



- (void)udpSocket:(GCDAsyncUdpSocket *)sock didConnectToAddress:(NSData *)address
{
    NSLog(@"UDPListener didConnectToAddress");
}




- (void)udpSocket:(GCDAsyncUdpSocket *)sock didNotConnect:(NSError * _Nullable)error
{
    NSLog(@"UDPListener didNotConnect error=%@", error);
}




- (void)udpSocket:(GCDAsyncUdpSocket *)sock didSendDataWithTag:(long)tag
{
    //NSLog(@"UDPListener didSendDataWithTag=%ld", tag);
}



- (void)udpSocket:(GCDAsyncUdpSocket *)sock didNotSendDataWithTag:(long)tag dueToError:(NSError * _Nullable)error
{
    NSLog(@"UDPListener didNotSendDataWithTag=%ld error=%@", tag, error);
}

- (void)udpSocketDidClose:(GCDAsyncUdpSocket *)sock withError:(NSError  * _Nullable)error
{
    NSLog(@"UDPListener udpSocketDidClose");
}



@end




int main(int argc, char **argv)
{
    #pragma unused(argc)
    #pragma unused(argv)
    int                 retVal;
    BOOL                success;
    Main *              mainObj;
    int                 port;
    
    @autoreleasepool {

        //raise(SIGSTOP); // Stop and wait for debugger. Click the Debugger's Resume button to continue execution

        //fprintf(stderr, "\nUDPListener main() started\n");
        NSLog(@"UDPListener main() started");
        
        retVal = EXIT_FAILURE;
        success = YES;
        if ( (argc >= 2) && (argc <= 3) ) {
            if (argc == 3) {
                port = atoi(argv[2]);
            } else {
                port = 7;
            }
            if ( (port > 0) && (port < 65536) ) {
                if (strcmp(argv[1], "-l") == 0) {
                    retVal = EXIT_SUCCESS;

                    // server mode

                    mainObj = [[Main alloc] init];
                    assert(mainObj != nil);
                    
                    success = [mainObj runServerOnPort:(NSUInteger) port];
                } else {
                    NSString *  hostName;
                    
                    hostName = [NSString stringWithUTF8String:argv[1]];
                    if (hostName == nil) {
                        //fprintf(stderr, "%s: invalid host host: %s\n", getprogname(), argv[1]);
                        NSLog(@"UDPListener %s: invalid host host: %s", getprogname(), argv[1]);
                    } else {
                        retVal = EXIT_FAILURE;
                    }
                }
            }
        }
        
        if (success) {
            if (retVal == EXIT_FAILURE) {
                //fprintf(stderr, "usage: %s -l [port]\n",   getprogname());
                NSLog(@"usage: %s -l [port]\n",   getprogname());
                
                //fprintf(stderr, "       %s host [port]\n", getprogname());
                NSLog(@"       %s host [port]\n", getprogname());
            }
        } else {
            retVal = EXIT_FAILURE;
        }

        NSLog(@"UDPListener main() exit, retVal = %d", retVal);
    }
    
    return retVal;
}

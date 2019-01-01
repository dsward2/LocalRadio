//
//  main.m
//  UDPSender
//
//  Created by Douglas Ward on 7/9/17.
//  Copyright © 2017-2018 ArkPhone LLC. All rights reserved.
//

//  Code sign note: use inherited entitlements
//  https://stackoverflow.com/questions/11821632/mac-os-app-sandbox-with-command-line-tool

@import Foundation;

#import "GCDAsyncUdpSocket.h"

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


#pragma mark * Main

#define zeroBufferLength 4096

@interface Main : NSObject <GCDAsyncUdpSocketDelegate>
{

}

@property (nonatomic, strong, readwrite) GCDAsyncUdpSocket *  udpSocket;
@property (assign) NSInteger sentDataIndex;
@property (assign) BOOL doExit;

- (BOOL)runSenderOnPort:(NSUInteger)port;

@end

@interface Main ()


@end

@implementation Main

Main * mainObj;    // global singleton
pid_t originalParentProcessPID;



- (void)logHexData:(void *)dataPtr length:(NSInteger)length
{
    NSMutableString * hexString = [NSMutableString string];
    for (NSInteger i = 0; i < length; i++)
    {
        UInt8 * bytePtr = (UInt8 *)((UInt64)dataPtr + i);
        [hexString appendFormat:@"%02x ", *bytePtr];
        
        if (i > 0)
        {
            if (i % 16 == 15)
            {
                [hexString appendString:@"\n"];
            }
            else if (i % 4 == 3)
            {
                [hexString appendString:@" "];
            }
        }
    }
    NSLog(@"UDPSender - logHexData -\n%@", hexString);
}


- (BOOL)runSenderOnPort:(NSUInteger)port
{
    //NSLog(@"UDPSender starting on port %lu", (unsigned long)port);

    dispatch_queue_t senderQueue = dispatch_queue_create("com.arkphone.LocalRadio.SenderQueue", NULL);

	self.udpSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue: senderQueue];

    self.doExit = NO;

    NSTimeInterval lastReadTime = [NSDate timeIntervalSinceReferenceDate] + 20;
    NSTimeInterval nextTimeoutReportInterval = 5;

    while (self.doExit == NO)
    {
        //NSLog(@"UDPSender polling loop");
        
        CFRunLoopRunInMode (kCFRunLoopDefaultMode, 0.0025, false);

        NSTimeInterval currentTime = [NSDate timeIntervalSinceReferenceDate];

        unsigned long bytesAvailableCount = 0;
    
        int ioctl_result = ioctl( 0, FIONREAD, &bytesAvailableCount);
        if( ioctl_result < 0) {
            NSLog(@"UDPSender ioctl failed: %s\n", strerror( errno));
            self.doExit = YES;
            break;
        }

        if (bytesAvailableCount <= 0)
        {
            usleep(1000);
       }
        else
        {
            unsigned long bytesConsumedCount = bytesAvailableCount;
        
            if (bytesConsumedCount > 2048)
            {
                bytesConsumedCount = 2048;
            }
        
            char * buf = malloc(bytesConsumedCount);
            long readResult = read( 0, buf, bytesConsumedCount);
            if( readResult <= 0) {
                NSLog(@"UDPSender read failed: %s\n", strerror( errno));
                break;
            }
            else
            {
                lastReadTime = currentTime;
                nextTimeoutReportInterval = 5;
                
                //NSLog(@"UDPSender sending data, bytesAvailableCount=%ld, bytesConsumedCount=%ld", bytesAvailableCount, bytesConsumedCount);

                NSData * bufferData = [[NSData alloc] initWithBytes:buf length:bytesConsumedCount];
                
                [self sendData:bufferData port:port];       // send to UDPListener > AACEncoder > IcecastSource
                
                fwrite(buf, bytesConsumedCount, 1, stdout);    // also write a copy to stdout
                
                fflush(stdout);
                
                /*
                if (self.sentDataIndex == 0)
                {
                    [self logHexData:buf length:bytesAvailableCount];
                }
                */
                
                self.sentDataIndex++;
            }
            free(buf);
        }

        NSTimeInterval intervalSinceLastRead = currentTime - lastReadTime;
        if (intervalSinceLastRead >= nextTimeoutReportInterval)
        {
            //NSLog(@"UDPSender intervalSinceLastRead >= %f", nextTimeoutReportInterval);
            
            nextTimeoutReportInterval += 5;
            
            pid_t currentParentProcessPID = getppid();
            if (currentParentProcessPID != originalParentProcessPID)
            {
                //NSLog(@"UDPSender original parent process PID changed, terminating....");
                //self.doExit = YES;
            }
        }
    }

    //NSLog(@"UDPSender polling loop exited");
    
    return YES;
}





- (void)sendData:(NSData *)streamData port:(NSUInteger)port
{
    //[self.udpSocket sendData:streamData toHost:@"127.0.0.1" port:1234 withTimeout:-1 tag:0];
    [self.udpSocket sendData:streamData toHost:@"127.0.0.1" port:port withTimeout:-1 tag:0];
}

// Delegate methods, not used for connectionless UDP

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didConnectToAddress:(NSData *)address
{
    //NSLog(@"UDPSender didConnectToAddress");
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didNotConnect:(NSError * _Nullable)error
{
    NSLog(@"UDPSender didNotConnect error: %@", error);
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didSendDataWithTag:(long)tag
{
    //NSLog(@"UDPSender didSendDataWithTag: %d", tag);
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didNotSendDataWithTag:(long)tag dueToError:(NSError * _Nullable)error
{
    NSLog(@"UDPSender didNotSendDataWithTag: %ld, error: %@", tag, error);
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data
                                             fromAddress:(NSData *)address
                                       withFilterContext:(nullable id)filterContext
{
    //NSLog(@"UDPSender didReceiveData");

}

- (void)udpSocketDidClose:(GCDAsyncUdpSocket *)sock withError:(NSError  * _Nullable)error
{
    //NSLog(@"UDPSender udpSocketDidClose error: %@", error);

}




@end

void signal_callback_handler(int signum)
{
   //printf("UDPSender Caught signal %d\n",signum);   // TODO: printf not safe here?
   // Cleanup and close up stuff here
   // Terminate program
   mainObj.doExit = YES;
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
    int                 port;
	struct sigaction sigact;
    
    @autoreleasepool {

        //raise(SIGSTOP); // Stop and wait for debugger. Click the Debugger's Resume button to continue execution

        //NSLog(@"UDPSender main() started");

        sigact.sa_handler = &signal_callback_handler;
        sigemptyset(&sigact.sa_mask);
        sigact.sa_flags = 0;
        sigaction(SIGINT, &sigact, NULL);
        sigaction(SIGTERM, &sigact, NULL);
        sigaction(SIGQUIT, &sigact, NULL);
        sigaction(SIGPIPE, &sigact, NULL);

        originalParentProcessPID = getppid();
        
        retVal = EXIT_FAILURE;
        success = YES;

        port = atoi(argv[argc - 1]);
        if ( (port > 0) && (port < 65536) )
        {
            retVal = EXIT_SUCCESS;

            // sender mode

            mainObj = [[Main alloc] init];
            assert(mainObj != nil);
            
            success = [mainObj runSenderOnPort:(NSUInteger) port];
        }
        
        if (success) {
            if (retVal == EXIT_FAILURE)
            {
                //fprintf(stderr, "usage: %s -l [port]\n",   getprogname());
                NSLog(@"usage: %s -l [port]\n",   getprogname());
                
                //fprintf(stderr, "       %s host [port]\n", getprogname());
                NSLog(@"       %s host [port]\n", getprogname());
            }
        }
        else
        {
            retVal = EXIT_FAILURE;
        }

        NSLog(@"UDPSender main() exit, retVal = %d", retVal);
    }
    
    return retVal;
}

//
//  main.m
//  StreamingServer
//
//  Created by Douglas Ward on 2/11/20.
//  Copyright © 2020 ArkPhone LLC. All rights reserved.
//

//   Wraps audio/aac data to audio/x-mpegurl

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AudioToolbox/AudioConverter.h>

#import "HTTPStreamingServerController.h"

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

@class GCDWebServer;

@interface Main : NSObject
{
}
@end

@interface Main ()
@end

Main * mainObj;    // global singleton
pid_t originalParentProcessPID;
NSString * host;
BOOL readyToSend;
unsigned int port;
int bitrate;
BOOL doExit;
int lastSignum;
HTTPStreamingServerController * streamingServerController;
NSMutableData * audioData;
NSData * silentAudioData;
NSData * longSilentAudioData;
NSMutableDictionary * responsesDictionary;

//NSMutableArray * audioDataArray;

@implementation Main


- (void)makeSilentAudioData
{
    // format ADTS header per  https://wiki.multimedia.cx/index.php/ADTS
    // ADTS header decoder: http://www.p23.nl/projects/aac-header/
    
    // ~130 ms silent packet 48k stereo -
    // ff f1 4c 80 02 3f fc 21 1c 46 c8 7e 43 64 3f 21 c0 - MPEG-4
    // ff f9 4c 80 02 3f fc 21 1c 46 c8 7e 43 64 3f 21 c0 - MPEG-2
    // 00 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 - offsets
    
    /*
    ID    MPEG-2
    MPEG Layer    0
    CRC checksum absent    1
    Profile    Low Complexity profile (AAC LC)
    Sampling frequency    48000
    Private bit    0
    Channel configuration    2
    Original/copy    0
    Home    0
    Copyright identification bit    0
    Copyright identification start    0
    AAC frame length    25
    ADTS buffer fullness    VBR
    No raw data blocks in frame    0
    */
    
    // FF F9 4C 80 03 3F FC 21 0B 93 E5 84 3E E0 E1 7B 50 3E 58 43 EE 0E 13 B5 07 - ~20 ms silence
    // 00 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 - offsets

    UInt32 adtsPacketLength = 25;
    UInt8 adtsPacket[adtsPacketLength];

    adtsPacket[0] = 0xff;
    adtsPacket[1] = 0xf9;
    adtsPacket[2] = 0x4c;
    adtsPacket[3] = 0x80;
    adtsPacket[4] = 0x03;
    adtsPacket[5] = 0x3f;
    adtsPacket[6] = 0xfc;
    adtsPacket[7] = 0x21;
    adtsPacket[8] = 0x0b;
    adtsPacket[9] = 0x93;
    adtsPacket[10] = 0xe5;
    adtsPacket[11] = 0x84;
    adtsPacket[12] = 0x3e;
    adtsPacket[13] = 0xe0;
    adtsPacket[14] = 0xe1;
    adtsPacket[15] = 0x7b;
    adtsPacket[16] = 0x50;
    adtsPacket[17] = 0x3e;
    adtsPacket[18] = 0x58;
    adtsPacket[19] = 0x43;
    adtsPacket[20] = 0xee;
    adtsPacket[21] = 0x0e;
    adtsPacket[22] = 0x13;
    adtsPacket[23] = 0xb5;
    adtsPacket[24] = 0x07;

    /*
    adtsPacket[0] = 0xff;
    //adtsPacket[1] = 0xf1;
    adtsPacket[1] = 0xf9;
    adtsPacket[2] = 0x4c;
    adtsPacket[3] = 0x80;
    adtsPacket[4] = 0x02;
    adtsPacket[5] = 0x3f;
    adtsPacket[6] = 0xfc;
    adtsPacket[7] = 0x21;
    adtsPacket[8] = 0x1c;
    adtsPacket[9] = 0x46;
    adtsPacket[10] = 0xc8;
    adtsPacket[11] = 0x7e;
    adtsPacket[12] = 0x43;
    adtsPacket[13] = 0x64;
    adtsPacket[14] = 0x3f;
    adtsPacket[15] = 0x21;
    adtsPacket[16] = 0xc0;
    */
    
    silentAudioData = [NSData dataWithBytes:adtsPacket length:adtsPacketLength];
    
    NSMutableData * buildLongSilentAudioData = [NSMutableData data];
    for (NSInteger i = 0; i < 10; i++)
    {
        [buildLongSilentAudioData appendData:silentAudioData];
    }
    longSilentAudioData = [NSData dataWithData:buildLongSilentAudioData];
}

- (void)startStreamingServerWithHost:(NSString *)host port:(int32_t)port
{
    fprintf(stdout, "Running in Streaming Response mode\n");
    
    //audioDataArray = [NSMutableArray array];
    
    [self makeSilentAudioData];
    
    streamingServerController = [[HTTPStreamingServerController alloc] init];
    
    BOOL startResult = [streamingServerController startProcessingWithPort:port];

    if (startResult == NO)
    {
        fprintf(stdout, "streamingServer startWithPort:bonjourName: failed\n");
    }
}

- (void)runStreamingServerBackgroundInputLoop
{
    doExit = NO;

    NSTimeInterval lastReadTime = [NSDate timeIntervalSinceReferenceDate] + 20;
    NSTimeInterval nextTimeoutReportInterval = 5;
    
    NSUInteger bytesReceived = 0;
    
    // Main loop
    while (doExit == NO)
    {
        //NSLog(@"StreamingServer polling loop");

        NSTimeInterval currentTime = [NSDate timeIntervalSinceReferenceDate];

        unsigned long bytesAvailableCount = 0;
    
        int ioctl_result = ioctl( 0, FIONREAD, &bytesAvailableCount);
        if( ioctl_result < 0) {
            NSLog(@"StreamingServer ioctl failed: %s\n", strerror( errno));
            doExit = YES;
            break;
        }
        
        if( bytesAvailableCount <= 0)
        {
            if (readyToSend == YES)
            {
                usleep(2000);
            }
        }
        else
        {
            /*
            if (bytesAvailableCount > 2048)
            {
                bytesAvailableCount = 2048;
            }
            */
            
            bytesReceived += bytesAvailableCount;
        
            char * buf = malloc(bytesAvailableCount);
            long readResult = read( 0, buf, bytesAvailableCount);
            
            if( readResult <= 0) {
                NSLog(@"StreamingServer read failed: %s\n", strerror( errno));
                break;
            }
            else
            {
                lastReadTime = currentTime;
                nextTimeoutReportInterval = 5;
                
                //NSLog(@"StreamingServer sending data, length=%ld", bytesAvailableCount);
                
                if (readyToSend == YES)
                {
                    //NSData * bufferData = [[NSData alloc] initWithBytes:buf length:bytesAvailableCount];
                    @synchronized (self)
                    {
                        NSMutableData * audioData = [[NSMutableData alloc] initWithBytes:buf length:bytesAvailableCount];  // add audio data to buffer
                        
                        [streamingServerController addAudioDataToConnections:audioData];
                        
                        //[audioData appendData:bufferedData];
                    }

                    //NSLog(@"StreamingServer sent %lu bytes\n", (unsigned long)[bufferData length]);
                    //NSLog(@"StreamingServer sent %lu bytes\n", (unsigned long)[audioData length]);

                    //fwrite(buf, bytesAvailableCount, 1, stdout);    // also write a copy to stdout, perhaps for sox, etc.
                    //fflush(stdout);
                }
            }
            
            free(buf);
        }

        NSTimeInterval intervalSinceLastRead = currentTime - lastReadTime;
        if (intervalSinceLastRead >= nextTimeoutReportInterval)
        {
            //NSLog(@"StreamingServer intervalSinceLastRead >= %f", nextTimeoutReportInterval);
            
            nextTimeoutReportInterval += 5;
            
            pid_t currentParentProcessPID = getppid();
            if (currentParentProcessPID != originalParentProcessPID)
            {
                //NSLog(@"StreamingServer original parent process PID changed, terminating....");
                //self.doExit = YES;
            }
        }
    }

    //NSLog(@"StreamingServer polling loop exited");
}


// GCDWebServer delegate calls

- (void)webServerDidStart:(GCDWebServer*)server {
  //
}

- (void)webServerDidCompleteBonjourRegistration:(GCDWebServer*)server {
  //
}

- (void)webServerDidUpdateNATPortMapping:(GCDWebServer*)server {
  //
}

- (void)webServerDidConnect:(GCDWebServer*)server {
  //
}

- (void)webServerDidDisconnect:(GCDWebServer*)server {
  //
}

- (void)webServerDidStop:(GCDWebServer*)server {
  //
}


@end


void signal_callback_handler(int signum)
{
   //printf("StreamingServer Caught signal %d\n",signum);   // TODO: printf not safe here?
   // Cleanup and close up stuff here
   // Terminate program
   doExit = YES;
   lastSignum = signum;
   //exit(signum);
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

        NSLog(@"StreamingServer main() started\n");
        
        lastSignum = 0;
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

        //port = atoi(argv[argc - 1]);
        
        char const * argMode = "";
        char const * argHost = "localhost";
        char const * argPort = "17004";
        char const * argBitrate = "64000";
        //char const * argIceURL = "https://localhost:17004";      // for display only, we indicate the https link

        for (int i = 0; i < argc; i++)
        {
            char * argStringPtr = (char *)argv[i];
            
            if (strcmp(argStringPtr, "-h") == 0)   // host for source connection
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
        }
        
        host = [[NSString alloc] initWithCString:argHost encoding:NSUTF8StringEncoding];
        port = atoi(argPort);
        bitrate = atoi(argBitrate);
        
        if ( (port > 0) && (port < 65536) )
        {
            retVal = EXIT_SUCCESS;

            // sender mode

            mainObj = [[Main alloc] init];
            assert(mainObj != nil);
            
            //[mainObj runStreamingServerSource:self];
            
            readyToSend = NO;
            
            audioData = [NSMutableData data];

            [mainObj startStreamingServerWithHost:host port:port];

            [mainObj performSelectorInBackground:@selector(runStreamingServerBackgroundInputLoop) withObject:NULL];
            
            readyToSend = YES;
            
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
            NSLog(@"StreamingServer main() exit, signum = %d, retVal = %d", lastSignum, retVal);
        }
    }
    
    return retVal;
}


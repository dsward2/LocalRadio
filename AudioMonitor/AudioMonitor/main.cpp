//
//  main.cpp
//  AudioMonitor
//
//  Created by Douglas Ward on 8/22/18.
//  Copyright © 2018 ArkPhone LLC. All rights reserved.
//

#include <stdio.h>
#include <string.h>
#include <netdb.h>
#include <netinet/in.h>
#include <unistd.h>
#include <pthread.h>
#include <AudioToolbox/AudioToolbox.h>

#include <CoreFoundation/CoreFoundation.h>
#include "AudioMonitor2.hpp"

// AudioMonitor -r 10000 -v 1
//   -r is sample rate
//   -v is volume, 0 is silent, 1 is no change, 2 is double volume (not implemented yet)


CFComparisonResult compareStrings(CFStringRef str1, CFStringRef str2)
{
   return CFStringCompareWithOptions(str1, str2, CFRangeMake(0,CFStringGetLength(str1)), kCFCompareCaseInsensitive);
}


int main(int argc, const char * argv[])
{
    //raise(SIGSTOP); // Stop and wait for debugger. Click the Debugger's Resume button to continue execution
    
    char const * argMode = "";
    char const * argSampleRate = "10000";
    char const * argVolume = "0";
    char const * argChannels = "1";
    char const * argBufferKBPerChannel = "768";

    for (int i = 0; i < argc; i++)
    {
        char * argStringPtr = (char *)argv[i];
        
        //NSLog(@"arg %d %@", i, argString);

        if (strcmp(argStringPtr, "-r") == 0)
        {
            argMode = argStringPtr;
        }
        else if (strcmp(argMode, "-r") == 0)
        {
            argSampleRate = argStringPtr;
            argMode = "";
        }
        else if (strcmp(argStringPtr, "-v") == 0)
        {
            argMode = argStringPtr;
        }
        else if (strcmp(argMode, "-v") == 0)
        {
            argVolume = argStringPtr;
            argMode = "";
        }
        else if (strcmp(argStringPtr, "-c") == 0)
        {
            argMode = argStringPtr;
        }
        else if (strcmp(argMode, "-c") == 0)
        {
            argChannels = argStringPtr;
            argMode = "";
        }
        else if (strcmp(argStringPtr, "-b") == 0)
        {
            argMode = argStringPtr;
        }
        else if (strcmp(argMode, "-b") == 0)
        {
            argBufferKBPerChannel = argStringPtr;
            argMode = "";
        }
    }
    
    int sampleRate = atoi(argSampleRate);
    if (sampleRate <= 0)
    {
        sampleRate = 10000;
    }
    
    double volume = atof(argVolume);

    int channels = atoi(argChannels);

    int bufferKBPerChannel = atoi(argBufferKBPerChannel);

    runAudioMonitor(sampleRate, volume, channels, bufferKBPerChannel);
    
    do {
        CFRunLoopRunInMode (kCFRunLoopDefaultMode, 0.25, false);
    } while (true);

    return 0;
}





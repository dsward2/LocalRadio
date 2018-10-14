//
//  main.cpp
//  AACEncoder
//
//  Created by Douglas Ward on 9/11/18.
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
#include "AACEncoder.hpp"

// AACEncoder -r 48000 -c 2
//   -r is sample rate
//   -c is number of input channels

int main(int argc, const char * argv[])
{
    //raise(SIGSTOP); // Stop and wait for debugger. Click the Debugger's Resume button to continue execution
    
    char const * argMode = "";
    char const * argSampleRate = "48000";
    char const * argChannels = "1";

    for (int i = 0; i < argc; i++)
    {
        char * argStringPtr = (char *)argv[i];
        
        //NSLog(@"arg %d %@", i, argString);

        if (strcmp(argStringPtr, "-r") == 0)        // sample rate
        {
            argMode = argStringPtr;
        }
        else if (strcmp(argMode, "-r") == 0)
        {
            argSampleRate = argStringPtr;
            argMode = "";
        }
        else if (strcmp(argStringPtr, "-c") == 0)   // channels
        {
            argMode = argStringPtr;
        }
        else if (strcmp(argMode, "-c") == 0)
        {
            argChannels = argStringPtr;
            argMode = "";
        }
    }
    
    int sampleRate = atoi(argSampleRate);
    if (sampleRate <= 0)
    {
        sampleRate = 48000;
    }

    int channels = atoi(argChannels);

    runAACEncoder(sampleRate, channels);
    
    do {
        CFRunLoopRunInMode (kCFRunLoopDefaultMode, 0.25, false);
        //usleep(5000);
    } while (true);

    return 0;
}





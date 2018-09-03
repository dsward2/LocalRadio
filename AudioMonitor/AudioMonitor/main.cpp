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

// AudioMonitor2 -r 10000 -v 1 -c 1 -b1 256 -b2 256 -b3 512
//   -r is sample rate
//   -v is volume, 0.0 is silent, 1.0 enables AudioQueue for output to the currently selected Core Audio device
//   -c is number of input channels
//   -b1 is input buffer size in kilobytes
//   -b2 is AudioConverter buffer size in kilobytes
//   -b3 is AudioQueue buffer size in kilobytes

// For rtl_fm_localradio wbfm mono -
// AudioMonitor2 -r 48000 -v 0 -c 1 -b1 256 -b2 256 -b3 256

// For rtl_fm_localradio wbfm stereo -
// AudioMonitor2 -r 48000 -v 0 -c 1 -b1 768 -b2 768 -b3 512

// For an external 2-channel source producing large bursts at one second intervals -
// AudioMonitor2 -r 44100 -v 0 -c 2 -b1 512 -b2 512 -b3 512


int main(int argc, const char * argv[])
{
    //raise(SIGSTOP); // Stop and wait for debugger. Click the Debugger's Resume button to continue execution
    
    char const * argMode = "";
    char const * argSampleRate = "10000";
    char const * argVolume = "0";
    char const * argChannels = "1";
    char const * argInputBufferSize = "256";
    char const * argAudioConverterBufferSize = "256";
    char const * argAudioQueueBufferSize = "256";

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
        else if (strcmp(argStringPtr, "-v") == 0)   // volume - 0.0 or 1.0
        {
            argMode = argStringPtr;
        }
        else if (strcmp(argMode, "-v") == 0)
        {
            argVolume = argStringPtr;
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
        else if (strcmp(argStringPtr, "-b1") == 0)  // Stage 1 - input buffer size
        {
            argMode = argStringPtr;
        }
        else if (strcmp(argMode, "-b1") == 0)
        {
            argInputBufferSize = argStringPtr;
            argMode = "";
        }
        else if (strcmp(argStringPtr, "-b2") == 0)  // Stage 2 - AudioConverter buffer size for resampling to 48000 Hz
        {
            argMode = argStringPtr;
        }
        else if (strcmp(argMode, "-b2") == 0)
        {
            argAudioConverterBufferSize = argStringPtr;
            argMode = "";
        }
        else if (strcmp(argStringPtr, "-b3") == 0)  // Stage 3 - AudioQueue buffer size for direct output to Core Audio device
        {
            argMode = argStringPtr;
        }
        else if (strcmp(argMode, "-b3") == 0)
        {
            argAudioQueueBufferSize = argStringPtr;
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

    int inputBufferSize = atoi(argInputBufferSize) * 1024;
    int audioConverterBufferSize = atoi(argAudioConverterBufferSize) * 1024;
    int audioQueueBufferSize = atoi(argAudioQueueBufferSize) * 1024;

    runAudioMonitor(sampleRate, volume, channels, inputBufferSize, audioConverterBufferSize, audioQueueBufferSize);
    
    do {
        CFRunLoopRunInMode (kCFRunLoopDefaultMode, 0.25, false);
        //usleep(5000);
    } while (true);

    return 0;
}





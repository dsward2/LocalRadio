//
//  SDRController.m
//  LocalRadio
//
//  Created by Douglas Ward on 5/29/17.
//  Copyright © 2017 ArkPhone LLC. All rights reserved.
//

#import "SDRController.h"
#import "NSFileManager+DirectoryLocations.h"
#import "AppDelegate.h"
#import "SoxController.h"
#import "UDPStatusListenerController.h"
#import "LocalRadioAppSettings.h"
#import "EZStreamController.h"
#import "TaskPipelineManager.h"
#import "TaskItem.h"

@implementation SDRController

//==================================================================================
//	dealloc
//==================================================================================

- (void)dealloc
{
    //[self.udpSocket close];
    //self.udpSocket = NULL;

    /*
    if (self.currentInfoSocket != NULL)
    {
        [self.currentInfoSocket disconnect];
        self.currentInfoSocket = NULL;
    }
    */
}

//==================================================================================
//	init
//==================================================================================

- (instancetype)init
{
    self = [super init];
    if (self) {
        /*
        self.udpSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
        
        NSError *error = nil;
        
        if (![self.udpSocket bindToPort:0 error:&error])
        {
            NSLog(@"Error binding: %@", error);
            return nil;
        }
        
        NSError * socketReceiveError = NULL;
        [self.udpSocket beginReceiving:&socketReceiveError];
        */

        self.radioTaskPipelineManager = [[TaskPipelineManager alloc] init];

        self.rtlsdrTaskMode = @"stopped";
    }
    return self;
}

//==================================================================================
//	terminateTasks
//==================================================================================

- (void)terminateTasks
{
    [self.radioTaskPipelineManager terminateTasks];
}


//==================================================================================
//	startRtlsdrTasksForAudioInputDevice:
//==================================================================================

- (void)startRtlsdrTasksForAudioInputDevice:(NSString *)audioInputDeviceName
{
    //NSLog(@"startRtlsdrTaskForFrequency:category");
    
    CGFloat delay = 0.0;
    
    //[self stopRtlsdrTask];

    if (self.radioTaskPipelineManager.taskPipelineStatus == kTaskPipelineStatusRunning)
    {
        [self.radioTaskPipelineManager terminateTasks];
        
        //delay = 1.0;    // one second
        delay = 0.2;
    }

    self.rtlsdrTaskMode = @"frequency";
    
    int64_t dispatchDelay = (int64_t)(delay * NSEC_PER_SEC);
    dispatch_time_t dispatchTime = dispatch_time(DISPATCH_TIME_NOW, dispatchDelay);

    //dispatch_after(dispatchTime, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    dispatch_after(dispatchTime, dispatch_get_main_queue(), ^{
        [self dispatchedStartRtlsdrTasksForFrequencies:NULL category:NULL device:audioInputDeviceName];
    });
}

//==================================================================================
//	startRtlsdrTasksForFrequency:
//==================================================================================

- (void)startRtlsdrTasksForFrequency:(NSDictionary *)frequencyDictionary
{
    //NSLog(@"startRtlsdrTaskForFrequency:category");
    
    CGFloat delay = 0.0;
    
    //[self stopRtlsdrTask];

    if (self.radioTaskPipelineManager.taskPipelineStatus == kTaskPipelineStatusRunning)
    {
        [self.radioTaskPipelineManager terminateTasks];
        
        //delay = 1.0;    // one second
        delay = 0.2;
    }

    self.rtlsdrTaskMode = @"frequency";
    
    int64_t dispatchDelay = (int64_t)(delay * NSEC_PER_SEC);
    dispatch_time_t dispatchTime = dispatch_time(DISPATCH_TIME_NOW, dispatchDelay);

    //dispatch_after(dispatchTime, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    dispatch_after(dispatchTime, dispatch_get_main_queue(), ^{

        NSArray * frequenciesArray = [NSArray arrayWithObject:frequencyDictionary];
        
        [self dispatchedStartRtlsdrTasksForFrequencies:frequenciesArray category:NULL device:NULL];
    });
}

//==================================================================================
//	startRtlsdrTasksForFrequencies:category:
//==================================================================================

- (void)startRtlsdrTasksForFrequencies:(NSArray *)frequenciesArray category:(NSMutableDictionary *)categoryDictionary
{
    //NSLog(@"startRtlsdrTaskForFrequencies:category");

    CGFloat delay = 0.0;
    
    if (self.radioTaskPipelineManager.taskPipelineStatus == kTaskPipelineStatusRunning)
    {
        [self.radioTaskPipelineManager terminateTasks];
        
        //delay = 1.0;    // one second
        delay = 0.2;    // one second
    }

    self.rtlsdrTaskMode = @"scan";
    self.rtlsdrCategoryDictionary = categoryDictionary;

    int64_t dispatchDelay = (int64_t)(delay * NSEC_PER_SEC);
    dispatch_time_t dispatchTime = dispatch_time(DISPATCH_TIME_NOW, dispatchDelay);
    
    //dispatch_after(dispatchTime, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    dispatch_after(dispatchTime, dispatch_get_main_queue(), ^{
        [self dispatchedStartRtlsdrTasksForFrequencies:frequenciesArray category:categoryDictionary device:NULL];
    });
}

//==================================================================================
//	dispatchedStartRtlsdrTasksForFrequencies:category:device:
//==================================================================================

- (void)dispatchedStartRtlsdrTasksForFrequencies:(NSArray *)frequenciesArray category:(NSDictionary *)categoryDictionary device:(NSString *)audioInputDeviceName
{
    // Create TaskItem for the audio source, send lpcm data to stdout at specified sample rate
    TaskItem * audioSourceTaskItem = [self makeAudioSourceTaskItemForFrequencies:frequenciesArray category:categoryDictionary];

    // Get lpcm from stdin, re-sample to 48000 Hz, optionally play audio directly to current system CoreAudio device, output to stdout
    TaskItem * audioMonitorTaskItem = [self makeAudioMonitorTaskItem];
    
    // Get lpcm from stdin, apply Sox audio processing filters, output MP3 data to stdout
    TaskItem * soxTaskItem = [self.radioTaskPipelineManager makeTaskItemWithExecutable:@"sox" functionName:@"sox"];

    // Get mp3 data from stdin, output to UDP port
    TaskItem * udpSenderTaskItem = [self.radioTaskPipelineManager makeTaskItemWithExecutable:@"UDPSender" functionName:@"UDPSender"];

    BOOL useSecondaryStreamSource = NO;
    
    if ([self.audioOutputString isEqualToString:@"icecast"])
    {
        // configure for output to UDPSender (then to EZStream/Icecast)
        
        [soxTaskItem addArgument:@"-r"];
        [soxTaskItem addArgument:@"48000"];      // assume input from AudioMonitor already resampled to 48000 Hz
        
        [soxTaskItem addArgument:@"-e"];
        [soxTaskItem addArgument:@"signed-integer"];
        
        [soxTaskItem addArgument:@"-b"];
        [soxTaskItem addArgument:@"16"];
        
        [soxTaskItem addArgument:@"-c"];
        [soxTaskItem addArgument:@"1"];
        
        [soxTaskItem addArgument:@"-t"];
        [soxTaskItem addArgument:@"raw"];
        
        [soxTaskItem addArgument:@"-"];         // stdin
        
        [soxTaskItem addArgument:@"-t"];
        [soxTaskItem addArgument:@"raw"];
        
        [soxTaskItem addArgument:@"-"];         // stdout
        
        [soxTaskItem addArgument:@"rate"];
        [soxTaskItem addArgument:@"48000"];
        
        NSArray * audioOutputFilterStringArray = [self.audioOutputFilterString componentsSeparatedByString:@" "];
        for (NSString * audioOutputFilterStringItem in audioOutputFilterStringArray)
        {
            [soxTaskItem addArgument:audioOutputFilterStringItem];
        }

        // configure UDPSender task

        [udpSenderTaskItem addArgument:@"-p"];
        NSNumber * audioPortNumber = [self.appDelegate.localRadioAppSettings integerForKey:@"AudioPort"];
        [udpSenderTaskItem addArgument:audioPortNumber.stringValue];
    }
    else
    {
        // configure for output to a Core Audio device
        // audioOutputString should be a Core Audio output devicename
        // and start a secondary sox task to relay from a different Core Audio device to UDPSender
        // This can be useful with some third-party audio routing utilities, like SoundFlower
        
        [soxTaskItem addArgument:@"-V2"];    // debug verbosity, -V2 shows failures and warnings
        [soxTaskItem addArgument:@"-q"];    // quiet mode - don't show terminal-style audio meter
        
        // input args

        [soxTaskItem addArgument:@"-r"];
        [soxTaskItem addArgument:@"48000"];      // assume input from AudioMonitor already resampled to 48000 Hz
        
        [soxTaskItem addArgument:@"-e"];
        [soxTaskItem addArgument:@"signed-integer"];
        
        [soxTaskItem addArgument:@"-b"];
        [soxTaskItem addArgument:@"16"];
        
        [soxTaskItem addArgument:@"-c"];
        [soxTaskItem addArgument:@"1"];
        
        [soxTaskItem addArgument:@"-t"];
        [soxTaskItem addArgument:@"raw"];
        
        [soxTaskItem addArgument:@"-"];         // stdin

        // output args
        
        [soxTaskItem addArgument:@"-e"];
        [soxTaskItem addArgument:@"float"];
        
        [soxTaskItem addArgument:@"-b"];
        [soxTaskItem addArgument:@"32"];
        
        [soxTaskItem addArgument:@"-c"];
        [soxTaskItem addArgument:@"2"];
        
        // send output to a Core Audio device
        [soxTaskItem addArgument:@"-t"];

        [soxTaskItem addArgument:@"coreaudio"];       // first stage audio output
        [soxTaskItem addArgument:self.audioOutputString];  // quotes are omitted intentionally
        
        [soxTaskItem addArgument:@"rate"];
        [soxTaskItem addArgument:@"48000"];

        // output sox options like vol, etc.
        NSArray * audioOutputFilterStringArray = [self.audioOutputFilterString componentsSeparatedByString:@" "];
        for (NSString * audioOutputFilterStringItem in audioOutputFilterStringArray)
        {
            [soxTaskItem addArgument:audioOutputFilterStringItem];
        }

        useSecondaryStreamSource = YES;     // create a separate task to get audio to EZStream
    }

    // TODO: BUG: For an undetermined reason, AudioMonitor fails to launch as an NSTask in a sandboxed app extracted from an Xcode Archive
    // if the application path contains a space (e.g., "~/Untitled Folder/LocalRadio.app".
    // Prefixing backslashes before spaces in the path did not help.  The error message in Console.log says "launch path not accessible".
    // As a workaround, alert the user if the condition exists and suggest removing the spaces from the folder name.
    
    @synchronized (self.radioTaskPipelineManager)
    {
        [self.radioTaskPipelineManager addTaskItem:audioSourceTaskItem];
        [self.radioTaskPipelineManager addTaskItem:audioMonitorTaskItem];
        [self.radioTaskPipelineManager addTaskItem:soxTaskItem];
        
        if (useSecondaryStreamSource == NO)
        {
            // send audio to EZStream/icecast
            [self.radioTaskPipelineManager addTaskItem:udpSenderTaskItem];
        }
        else
        {
            // send audio to user-specified output device for external processing in a separate app
            [self.appDelegate.soxController startSecondaryStreamForFrequencies:frequenciesArray category:categoryDictionary];
        }
    }

    [self.radioTaskPipelineManager startTasks];
    
    SDRController * weakSelf = self;

    dispatch_async(dispatch_get_main_queue(), ^{
    
        [weakSelf.appDelegate updateCurrentTasksText];
        
        self.appDelegate.statusRTLSDRTextField.stringValue = @"Running";

        self.appDelegate.statusFunctionTextField.stringValue = self.statusFunctionString;
        
        NSString * displayFrequencyString = [NSString stringWithFormat:@"%@", self.frequencyString];
        displayFrequencyString = [displayFrequencyString stringByReplacingOccurrencesOfString:@"-f " withString:@""];
        NSString * megahertzString = [self.appDelegate shortHertzString:displayFrequencyString];
        self.appDelegate.statusFrequencyTextField.stringValue = megahertzString;
        
        self.appDelegate.statusModulationTextField.stringValue = self.modulationString;
        self.appDelegate.statusSamplingRateTextField.stringValue = self.tunerSampleRateNumber.stringValue;
        self.appDelegate.statusSquelchLevelTextField.stringValue = self.squelchLevelNumber.stringValue;
        self.appDelegate.statusTunerGainTextField.stringValue = [NSString stringWithFormat:@"%@", self.tunerGainNumber];
        self.appDelegate.statusRtlsdrOptionsTextField.stringValue = self.optionsString;
        self.appDelegate.statusSignalLevelTextField.stringValue = @"0";
        self.appDelegate.statusAudioOutputTextField.stringValue = self.audioOutputString;
        self.appDelegate.statusAudioOutputFilterTextField.stringValue = self.audioOutputFilterString;
        self.appDelegate.statusStreamSourceTextField.stringValue = self.streamSourceString;
        
        if (self.enableTunerAGC == YES)
        {
            self.appDelegate.statusTunerAGCTextField.stringValue = @"On";
        }
        else
        {
            self.appDelegate.statusTunerAGCTextField.stringValue = @"Off";
        }
        
        if (self.enableDirectSamplingQBranchMode == NO)
        {
            self.appDelegate.statusSamplingModeTextField.stringValue = @"Standard";
        }
        else
        {
            self.appDelegate.statusSamplingModeTextField.stringValue = @"Direct Q-branch";
        }
    });
}

//==================================================================================
//	makeAudioSourceTaskItemForFrequencies:category:
//==================================================================================

- (TaskItem *)makeAudioSourceTaskItemForFrequencies:(NSArray *)frequenciesArray category:(NSDictionary *)categoryDictionary
{
    // values common to both Favorites and Categories

    self.frequencyString = [NSMutableString stringWithFormat:@"-f 89100000"];  // can be single frequency, multiple frequencies or range
    self.modulationString = @"fm";
    self.tunerGainNumber = [NSNumber numberWithFloat:49.5f];
    self.squelchLevelNumber = [NSNumber numberWithInteger:0];
    self.tunerSampleRateNumber = [NSNumber numberWithInteger:10000];
    self.optionsString = @"";
    self.audioOutputString = @"";
    self.audioOutputFilterString = @"";
    self.statusFunctionString = @"No active tuning";
    self.streamSourceString = @"";
    self.enableDirectSamplingQBranchMode = NO;
    self.enableTunerAGC = NO;

    NSString * nameString = @"";
    NSNumber * categoryScanningEnabledNumber = [NSNumber numberWithInteger:0];
    NSNumber * samplingModeNumber = [NSNumber numberWithInteger:0];
    NSNumber * tunerAGCNumber = [NSNumber numberWithInteger:0];
    NSNumber * oversamplingNumber = [NSNumber numberWithInteger:4];
    NSNumber * squelchDelayNumber = [NSNumber numberWithInteger:0];
    NSNumber * firSizeNumber = [NSNumber numberWithInteger:9];
    NSString * atanMathString = @"std";

    NSNumber * statusPortNumber = [self.appDelegate.localRadioAppSettings integerForKey:@"StatusPort"];

    if (categoryDictionary == NULL)
    {
        if (frequenciesArray.count == 1)
        {
            // tune to a single Favorites frequency
            NSDictionary * firstFrequencyDictionary = frequenciesArray.firstObject;

            self.tunerGainNumber = [firstFrequencyDictionary objectForKey:@"tuner_gain"];
            self.modulationString = [firstFrequencyDictionary objectForKey:@"modulation"];
            self.squelchLevelNumber = [firstFrequencyDictionary objectForKey:@"squelch_level"];
            self.tunerSampleRateNumber = [firstFrequencyDictionary objectForKey:@"sample_rate"];
            self.optionsString = [firstFrequencyDictionary objectForKey:@"options"];
            self.audioOutputFilterString = [firstFrequencyDictionary objectForKey:@"audio_output_filter"];
            self.audioOutputString = [firstFrequencyDictionary objectForKey:@"audio_output"];
            self.streamSourceString = [firstFrequencyDictionary objectForKey:@"stream_source"];
            
            nameString = [firstFrequencyDictionary objectForKey:@"station_name"];
            categoryScanningEnabledNumber = [NSNumber numberWithInteger:0];
            samplingModeNumber = [firstFrequencyDictionary objectForKey:@"sampling_mode"];
            tunerAGCNumber = [firstFrequencyDictionary objectForKey:@"tuner_agc"];
            oversamplingNumber = [firstFrequencyDictionary objectForKey:@"oversampling"];
            firSizeNumber = [firstFrequencyDictionary objectForKey:@"fir_size"];
            atanMathString = [firstFrequencyDictionary objectForKey:@"atan_math"];

            NSNumber * frequencyModeNumber = [firstFrequencyDictionary objectForKey:@"frequency_mode"]; // 0 = single frequency, 1 = frequency range
            NSInteger frequencyMode = [frequencyModeNumber integerValue];
            
            NSString * aFrequencyString = [firstFrequencyDictionary objectForKey:@"frequency"];
            NSString * aFrequencyScanEndString = [firstFrequencyDictionary objectForKey:@"frequency_scan_end"];
            NSString * aFrequencyScanIntervalString = [firstFrequencyDictionary objectForKey:@"frequency_scan_interval"];

            self.frequencyString = [NSMutableString stringWithFormat:@"-f %@", aFrequencyString];

            if (frequencyMode == 1)
            {
                // use scan range start, end and interval
                self.frequencyString = [NSMutableString stringWithFormat:@"-f %@:%@:%@", aFrequencyString, aFrequencyScanEndString, aFrequencyScanIntervalString];
            }
            
            NSInteger samplingMode = [samplingModeNumber integerValue];
            if (samplingMode == 2)
            {
                self.enableDirectSamplingQBranchMode = YES;
            }
            
            NSInteger tunerAGC = [tunerAGCNumber integerValue];
            if (tunerAGC == 1)
            {
                self.enableTunerAGC = YES;
            }
            
            self.statusFunctionString = [NSString stringWithFormat:@"Tuned to %@", nameString];

            self.appDelegate.udpStatusListenerController.nowPlayingDictionary = [firstFrequencyDictionary mutableCopy];
            [self.appDelegate.udpStatusListenerController.statusCacheDictionary removeAllObjects];
        }
        else
        {
            NSLog(@"LocalRadio error - wrong frequenciesArray.count");
            self.statusFunctionString = @"Error: wrong frequenciesArray.count";
        }
    }
    else
    {
        // scan one or more frequencies for the category
        self.tunerGainNumber = [categoryDictionary objectForKey:@"scan_tuner_gain"];
        self.modulationString = [categoryDictionary objectForKey:@"scan_modulation"];
        self.squelchLevelNumber = [categoryDictionary objectForKey:@"scan_squelch_level"];
        self.tunerSampleRateNumber = [categoryDictionary objectForKey:@"scan_sample_rate"];
        self.optionsString = [categoryDictionary objectForKey:@"scan_options"];
        self.audioOutputFilterString = [categoryDictionary objectForKey:@"scan_audio_output_filter"];
        self.audioOutputString = [categoryDictionary objectForKey:@"scan_audio_output"];
        self.streamSourceString = [categoryDictionary objectForKey:@"scan_stream_source"];

        nameString = [categoryDictionary objectForKey:@"category_name"];
        categoryScanningEnabledNumber = [categoryDictionary objectForKey:@"category_scanning_enabled"];
        samplingModeNumber = [categoryDictionary objectForKey:@"scan_sampling_mode"];
        tunerAGCNumber = [categoryDictionary objectForKey:@"scan_tuner_agc"];
        oversamplingNumber = [categoryDictionary objectForKey:@"scan_oversampling"];
        squelchDelayNumber = [categoryDictionary objectForKey:@"scan_squelch_delay"];
        firSizeNumber = [categoryDictionary objectForKey:@"scan_fir_size"];
        atanMathString = [categoryDictionary objectForKey:@"scan_atan_math"];

        [self.frequencyString setString:@""];
        
        for (NSDictionary * frequencyDictionary in frequenciesArray)
        {
            NSNumber * frequencyModeNumber = [frequencyDictionary objectForKey:@"frequency_mode"]; // 0 = single frequency, 1 = frequency range
            NSInteger frequencyMode = [frequencyModeNumber integerValue];

            NSString * aFrequencyString = [frequencyDictionary objectForKey:@"frequency"];
            NSString * aFrequencyScanEndString = [frequencyDictionary objectForKey:@"frequency_scan_end"];
            NSString * aFrequencyScanIntervalString = [frequencyDictionary objectForKey:@"frequency_scan_interval"];

            NSString * aFrequencyComboString = [NSMutableString stringWithFormat:@"-f %@", aFrequencyString];
            

            if (frequencyMode == 1) // use scan range start, end and interval
            {
                aFrequencyComboString = [NSMutableString stringWithFormat:@"-f %@:%@:%@", aFrequencyString, aFrequencyScanEndString, aFrequencyScanIntervalString];
            }

            if (self.frequencyString.length > 0)
            {
                [self.frequencyString appendString:@" "];
            }
            
            [self.frequencyString appendString:aFrequencyComboString];

            if ([frequenciesArray indexOfObject:frequencyDictionary] == 0)
            {
                self.appDelegate.udpStatusListenerController.nowPlayingDictionary = [frequencyDictionary mutableCopy];
                [self.appDelegate.udpStatusListenerController.statusCacheDictionary removeAllObjects];
            }
        }

        NSInteger samplingMode = [samplingModeNumber integerValue];
        if (samplingMode == 2)
        {
            self.enableDirectSamplingQBranchMode = YES;
        }

        NSInteger tunerAGC = [tunerAGCNumber integerValue];
        if (tunerAGC == 1)
        {
            self.enableTunerAGC = YES;
        }

        self.statusFunctionString = [NSString stringWithFormat:@"Scanning category: %@", nameString];
    }

    self.rtlsdrTaskFrequenciesArray = frequenciesArray;
    
    NSCharacterSet * whitespaceCharacterSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    self.audioOutputString = [self.audioOutputString stringByTrimmingCharactersInSet:whitespaceCharacterSet];
    self.streamSourceString = [self.streamSourceString stringByTrimmingCharactersInSet:whitespaceCharacterSet];

    // Create TaskItem for the audio source, send lpcm data to stdout at specified sample rate
    TaskItem * audioSourceTaskItem = [self.radioTaskPipelineManager makeTaskItemWithExecutable:@"rtl_fm_localradio" functionName:@"rtl_fm_localradio"];


    [audioSourceTaskItem addArgument:@"-M"];
    [audioSourceTaskItem addArgument:self.modulationString];
    [audioSourceTaskItem addArgument:@"-l"];
    [audioSourceTaskItem addArgument:self.squelchLevelNumber.stringValue];
    [audioSourceTaskItem addArgument:@"-t"];
    [audioSourceTaskItem addArgument:squelchDelayNumber.stringValue];
    [audioSourceTaskItem addArgument:@"-F"];
    [audioSourceTaskItem addArgument:firSizeNumber.stringValue];
    [audioSourceTaskItem addArgument:@"-g"];
    [audioSourceTaskItem addArgument:self.tunerGainNumber.stringValue];
    [audioSourceTaskItem addArgument:@"-s"];
    [audioSourceTaskItem addArgument:self.tunerSampleRateNumber.stringValue];
    
    if ([oversamplingNumber integerValue] > 0)
    {
        [audioSourceTaskItem addArgument:@"-o"];
        [audioSourceTaskItem addArgument:oversamplingNumber.stringValue];
    }
    
    [audioSourceTaskItem addArgument:@"-A"];
    [audioSourceTaskItem addArgument:atanMathString];
    [audioSourceTaskItem addArgument:@"-p"];
    [audioSourceTaskItem addArgument:@"0"];
    [audioSourceTaskItem addArgument:@"-c"];
    [audioSourceTaskItem addArgument:statusPortNumber.stringValue];

    [audioSourceTaskItem addArgument:@"-E"];
    [audioSourceTaskItem addArgument:@"pad"];
    
    if (self.enableDirectSamplingQBranchMode == YES)
    {
        [audioSourceTaskItem addArgument:@"-E"];
        [audioSourceTaskItem addArgument:@"direct"];
    }
    
    if (self.enableTunerAGC == YES)
    {
        [audioSourceTaskItem addArgument:@"-E"];
        [audioSourceTaskItem addArgument:@"agc"];
    }
    
    NSArray * optionsArray = [self.optionsString componentsSeparatedByString:@" "];
    for (NSString * aOptionString in optionsArray)
    {
        NSString * trimmedOptionString = [aOptionString stringByTrimmingCharactersInSet:whitespaceCharacterSet];
        if (trimmedOptionString.length > 0)
        {
            [audioSourceTaskItem addArgument:@"-E"];
            [audioSourceTaskItem addArgument:trimmedOptionString];
        }
    }
    
    NSArray * parsedFrequenciesArray = [self.frequencyString componentsSeparatedByString:@" "];
    for (NSString * parsedItem in parsedFrequenciesArray)
    {
        [audioSourceTaskItem addArgument:parsedItem];
    }

    return audioSourceTaskItem;
}


//==================================================================================
//	makeAudioMonitorTaskItem
//==================================================================================

- (TaskItem *)makeAudioMonitorTaskItem
{
    // Get lpcm from stdin, re-sample to 48000 Hz, optionally play audio directly to current system CoreAudio device, output to stdout
    TaskItem * audioMonitorTaskItem = [self.radioTaskPipelineManager makeTaskItemWithExecutable:@"AudioMonitor" functionName:@"AudioMonitor"];
    
    [audioMonitorTaskItem addArgument:@"-r"];
    [audioMonitorTaskItem addArgument:self.tunerSampleRateNumber.stringValue];

    NSString * livePlaythroughVolume = @"0.0";
    if (self.appDelegate.useWebViewAudioPlayerCheckbox.state == NO)
    {
        livePlaythroughVolume = @"1.0";
    }
    [audioMonitorTaskItem addArgument:@"-v"];
    [audioMonitorTaskItem addArgument:livePlaythroughVolume];
    
    return audioMonitorTaskItem;
}

//==================================================================================
//	radioTaskReceivedStderrData:
//==================================================================================

- (void)radioTaskReceivedStderrData:(NSNotification *)notif
{
    NSFileHandle *fh = [notif object];
    NSData *data = [fh availableData];
    if (data.length > 0)
    {
        // if data is found, re-register for more data (and print)
        //[fh waitForDataInBackgroundAndNotify];
        NSString * str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSLog(@"rtlsdr: %@" , str);
    }
    [fh waitForDataInBackgroundAndNotify];
}

//==================================================================================
//	retuneTaskForFrequency:
//==================================================================================
/*
- (void)retuneTaskForFrequency:(NSDictionary *)frequencyDictionary
{
    char retuneCommand[5];
    
    NSData * udpData = NULL;

    // begin retuning
    bzero(&retuneCommand, sizeof(retuneCommand));
    retuneCommand[0] = 0;
    int beginRetuningInteger = 0;
    memcpy(&retuneCommand[1], &beginRetuningInteger, sizeof(beginRetuningInteger));
    udpData = [[NSData alloc] initWithBytes:&retuneCommand length:sizeof(retuneCommand)];
    [self.udpSocket sendData:udpData toHost:@"127.0.0.1" port:6020 withTimeout:0 tag:self.udpTag++];
    //usleep(100000);
    
    // set modulation
    bzero(&retuneCommand, sizeof(retuneCommand));
    retuneCommand[0] = 1;
    char modulationMode = 0;
    NSString * modulationString = [frequencyDictionary objectForKey:@"modulation"];
    if ([modulationString isEqualToString:@"fm"] == YES)
    {
        modulationMode = 0;
    }
    else if ([modulationString isEqualToString:@"wbfm"] == YES)
    {
        modulationMode = 0;
    }
    else if ([modulationString isEqualToString:@"am"] == YES)
    {
        modulationMode = 1;
    }
    else if ([modulationString isEqualToString:@"usb"] == YES)
    {
        modulationMode = 2;
    }
    else if ([modulationString isEqualToString:@"lsb"] == YES)
    {
        modulationMode = 3;
    }
    retuneCommand[1] = modulationMode;
    udpData = [[NSData alloc] initWithBytes:&retuneCommand length:sizeof(retuneCommand)];
    [self.udpSocket sendData:udpData toHost:@"127.0.0.1" port:6020 withTimeout:0 tag:self.udpTag++];
    //usleep(100000);
    
    // set sample rate
    bzero(&retuneCommand, sizeof(retuneCommand));
    retuneCommand[0] = 2;
    NSNumber * sampleRateNumber = [frequencyDictionary objectForKey:@"sample_rate"];
    int sampleRateInteger = sampleRateNumber.intValue;
    memcpy(&retuneCommand[1], &sampleRateInteger, sizeof(sampleRateInteger));
    udpData = [[NSData alloc] initWithBytes:&retuneCommand length:sizeof(retuneCommand)];
    [self.udpSocket sendData:udpData toHost:@"127.0.0.1" port:6020 withTimeout:0 tag:self.udpTag++];
    //usleep(100000);
    
    // set tuner gain
    bzero(&retuneCommand, sizeof(retuneCommand));
    retuneCommand[0] = 4;
    NSNumber * tunerGainNumber = [frequencyDictionary objectForKey:@"tuner_gain"];
    int tunerGainInteger = tunerGainNumber.intValue;
    memcpy(&retuneCommand[1], &tunerGainInteger, sizeof(tunerGainInteger));
    udpData = [[NSData alloc] initWithBytes:&retuneCommand length:sizeof(retuneCommand)];
    [self.udpSocket sendData:udpData toHost:@"127.0.0.1" port:6020 withTimeout:0 tag:self.udpTag++];
    //usleep(100000);
    
    // set automatic gain control
    bzero(&retuneCommand, sizeof(retuneCommand));
    retuneCommand[0] = 5;
    NSNumber * agcNumber = [frequencyDictionary objectForKey:@"automatic_gain_control"];
    int agcInteger = agcNumber.intValue;
    memcpy(&retuneCommand[1], &agcInteger, sizeof(tunerGainInteger));
    udpData = [[NSData alloc] initWithBytes:&retuneCommand length:sizeof(retuneCommand)];
    [self.udpSocket sendData:udpData toHost:@"127.0.0.1" port:6020 withTimeout:0 tag:self.udpTag++];
    //usleep(100000);
    
    // set squelch level
    bzero(&retuneCommand, sizeof(retuneCommand));
    retuneCommand[0] = 6;
    NSNumber * squelchLevelNumber = [frequencyDictionary objectForKey:@"squelch_level"];
    int squelchLevelInteger = squelchLevelNumber.intValue;
    memcpy(&retuneCommand[1], &squelchLevelInteger, sizeof(squelchLevelInteger));
    udpData = [[NSData alloc] initWithBytes:&retuneCommand length:sizeof(retuneCommand)];
    [self.udpSocket sendData:udpData toHost:@"127.0.0.1" port:6020 withTimeout:0 tag:self.udpTag++];
    //usleep(100000);
    
    // set frequency
    bzero(&retuneCommand, sizeof(retuneCommand));
    retuneCommand[0] = 7;
    NSNumber * frequencyNumber = [frequencyDictionary objectForKey:@"frequency"];
    int frequencyInteger = frequencyNumber.intValue;
    memcpy(&retuneCommand[1], &frequencyInteger, sizeof(frequencyInteger));
    udpData = [[NSData alloc] initWithBytes:&retuneCommand length:sizeof(retuneCommand)];
    [self.udpSocket sendData:udpData toHost:@"127.0.0.1" port:6020 withTimeout:0 tag:self.udpTag++];
    //usleep(100000);

    // end retuning
    bzero(&retuneCommand, sizeof(retuneCommand));
    retuneCommand[0] = 8;
    int endRetuningInteger = 0;
    memcpy(&retuneCommand[1], &endRetuningInteger, sizeof(endRetuningInteger));
    udpData = [[NSData alloc] initWithBytes:&retuneCommand length:sizeof(retuneCommand)];
    [self.udpSocket sendData:udpData toHost:@"127.0.0.1" port:6020 withTimeout:0 tag:self.udpTag++];
    //usleep(100000);
}
*/



@end

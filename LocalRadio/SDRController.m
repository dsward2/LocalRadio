//
//  SDRController.m
//  LocalRadio
//
//  Created by Douglas Ward on 5/29/17.
//  Copyright © 2017-2018 ArkPhone LLC. All rights reserved.
//

#import "SDRController.h"
#import "NSFileManager+DirectoryLocations.h"
#import "AppDelegate.h"
//#import "SoxController.h"
#import "UDPStatusListenerController.h"
#import "LocalRadioAppSettings.h"
#import "EZStreamController.h"
#import "TaskPipelineManager.h"
#import "TaskItem.h"
#import "IcecastController.h"

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
//    startTasksForDevice:
//==================================================================================

- (void)startTasksForDevice:(NSString *)deviceName
{
    //NSLog(@"startTasksForDevice:category");

    CGFloat delay = 0.0;
    
    if (self.radioTaskPipelineManager.taskPipelineStatus == kTaskPipelineStatusRunning)
    {
        [self.radioTaskPipelineManager terminateTasks];
        
        //delay = 1.0;    // one second
        delay = 0.2;    // one second
    }

    self.rtlsdrTaskMode = @"device";
    self.deviceName = deviceName;

    int64_t dispatchDelay = (int64_t)(delay * NSEC_PER_SEC);
    dispatch_time_t dispatchTime = dispatch_time(DISPATCH_TIME_NOW, dispatchDelay);
    
    //dispatch_after(dispatchTime, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    dispatch_after(dispatchTime, dispatch_get_main_queue(), ^{
        [self dispatchedStartRtlsdrTasksForFrequencies:NULL category:NULL device:deviceName];
    });
}

//==================================================================================
//	dispatchedStartRtlsdrTasksForFrequencies:category:device:
//==================================================================================

- (void)dispatchedStartRtlsdrTasksForFrequencies:(NSArray *)frequenciesArray category:(NSDictionary *)categoryDictionary device:(NSString *)audioInputDeviceName
{
    // All of the "Listen" button actions eventually call this method
    
    [self checkIcecastAndEZStream];
    
    NSInteger sourceChannels = 0;

    // Create TaskItem for the audio source, send lpcm data to stdout at specified sample rate

    TaskItem * audioSourceTaskItem = NULL;
    if (audioInputDeviceName != NULL)
    {
        // configure for input from a Core Audio device
        sourceChannels = 2;

        audioSourceTaskItem = [self makeCoreAudioSourceTaskItem:audioInputDeviceName];
    }
    else
    {
        // configure for input from RTL-SDR device
        sourceChannels = 1;
    
        audioSourceTaskItem = [self makeRTLSDRAudioSourceTaskItemForFrequencies:frequenciesArray category:categoryDictionary];
    }
    
    NSInteger intermediateChannels = sourceChannels;
    TaskItem * stereoDemuxTaskItem = NULL;
    
    if (audioInputDeviceName == NULL)
    {
        if (frequenciesArray.count == 1)
        {
            NSDictionary * freequencyDictionary = frequenciesArray.firstObject;
            NSNumber * stereo_flagNumber = [freequencyDictionary objectForKey:@"stereo_flag"];
            NSNumber * sample_rateNumber = [freequencyDictionary objectForKey:@"sample_rate"];
            NSString * modulation = [freequencyDictionary objectForKey:@"modulation"];
            if (stereo_flagNumber.boolValue == YES)
            {
                if (sample_rateNumber.integerValue >= 106000)   // stereodemux requires sample rate >= 106000 Hz
                {
                    if ([modulation isEqualToString:@"fm"] == YES)
                    {
                        BOOL addStereoDemux = YES;
                        
                        if (sourceChannels > 1)
                        {
                            intermediateChannels = 2;
                            addStereoDemux = NO;
                        }
                        
                        if (addStereoDemux == YES)
                        {
                            intermediateChannels = 2;
                            stereoDemuxTaskItem = [self makeStereoDemuxTaskItem];
                        }
                    }
                }
            }
        }
    }
    
    // Get 1-or-2 channel lpcm from stdin, resample to 48000, output 2-channel lpcm to stdout, and optionally play audio directly to current system CoreAudio device
    TaskItem * audioMonitorTaskItem = [self makeAudioMonitorTaskItemForSourceChannels:intermediateChannels];
    
    // Get lpcm from stdin, apply Sox audio processing filters, output lpcm data to stdout
    TaskItem * soxTaskItem = NULL;
    NSString * trimmedFilterString = [self.audioOutputFilterString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (trimmedFilterString.length > 0)
    {
        //soxTaskItem = [self.radioTaskPipelineManager makeTaskItemWithExecutable:@"sox" functionName:@"sox"];
        soxTaskItem = [self makeSoxTaskItem];
    }

    // Get lpcm data from stdin, output to UDP port
    TaskItem * udpSenderTaskItem = [self.radioTaskPipelineManager makeTaskItemWithExecutable:@"UDPSender" functionName:@"UDPSender"];

    // configure UDPSender task for sending to EZStream/Icecast

    [udpSenderTaskItem addArgument:@"-p"];
    NSNumber * audioPortNumber = [self.appDelegate.localRadioAppSettings integerForKey:@"AudioPort"];
    [udpSenderTaskItem addArgument:audioPortNumber.stringValue];

    // TODO: BUG: For an undetermined reason, AudioMonitor fails to launch as an NSTask in a sandboxed app extracted from an Xcode Archive
    // if the application path contains a space (e.g., "~/Untitled Folder/LocalRadio.app".
    // Prefixing backslashes before spaces in the path did not help.  The error message in Console.log says "launch path not accessible".
    // As a workaround, alert the user if the condition exists and suggest removing the spaces from the folder name.
    
    @synchronized (self.radioTaskPipelineManager)
    {
        [self.radioTaskPipelineManager addTaskItem:audioSourceTaskItem];

        if (stereoDemuxTaskItem != NULL)
        {
            [self.radioTaskPipelineManager addTaskItem:stereoDemuxTaskItem];
        }

        [self.radioTaskPipelineManager addTaskItem:audioMonitorTaskItem];
        
        if (soxTaskItem != NULL)
        {
            [self.radioTaskPipelineManager addTaskItem:soxTaskItem];    // perform user-specified SoX processing
        }
        
        // send audio to EZStream/icecast
        [self.radioTaskPipelineManager addTaskItem:udpSenderTaskItem];
    }

    [self.radioTaskPipelineManager startTasks];
    
    SDRController * weakSelf = self;

    dispatch_async(dispatch_get_main_queue(), ^{
    
        [weakSelf.appDelegate updateCurrentTasksText:self];
        
        self.appDelegate.statusRTLSDRTextField.stringValue = @"Running";

        self.appDelegate.statusFunctionTextField.stringValue = self.statusFunctionString;
        
        NSString * displayFrequencyString = [NSString stringWithFormat:@"%@", self.frequencyString];
        displayFrequencyString = [displayFrequencyString stringByReplacingOccurrencesOfString:@"-f " withString:@""];
        NSString * megahertzString = [self.appDelegate shortHertzString:displayFrequencyString];
        //self.appDelegate.statusFrequencyTextField.stringValue = megahertzString;
        [self.appDelegate setStatusFrequency:megahertzString];
        
        NSString * extendedModulationString = self.modulationString;
        if ([extendedModulationString isEqualToString:@"fm"] == YES)
        {
            if (stereoDemuxTaskItem != NULL)
            {
                extendedModulationString = @"fm stereo";
            }
        }
        self.appDelegate.statusModulationTextField.stringValue = extendedModulationString;
        self.appDelegate.statusModulation = extendedModulationString;
        
        self.appDelegate.statusSamplingRateTextField.stringValue = self.tunerSampleRateNumber.stringValue;
        self.appDelegate.statusSamplingRate = self.tunerSampleRateNumber.stringValue;

        self.appDelegate.statusSquelchLevelTextField.stringValue = self.squelchLevelNumber.stringValue;
        self.appDelegate.statusTunerGainTextField.stringValue = [NSString stringWithFormat:@"%@", self.tunerGainNumber];
        self.appDelegate.statusRtlsdrOptionsTextField.stringValue = self.optionsString;
        self.appDelegate.statusSignalLevelTextField.stringValue = @"0";
        self.appDelegate.statusAudioOutputFilterTextField.stringValue = self.audioOutputFilterString;
        
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
//    makeCoreAudioSourceTaskItem:
//==================================================================================

- (TaskItem *)makeCoreAudioSourceTaskItem:(NSString *)audioInputDeviceName
{
    self.tunerSampleRateNumber = [NSNumber numberWithInteger:48000];    // needed for audioMonitorTaskItem

    TaskItem * audioSourceTaskItem = [self.radioTaskPipelineManager makeTaskItemWithExecutable:@"sox" functionName:@"sox"];

    [audioSourceTaskItem addArgument:@"-V2"];    // debug verbosity, -V2 shows failures and warnings
    [audioSourceTaskItem addArgument:@"-q"];    // quiet mode - don't show terminal-style audio meter

    // input args

    [audioSourceTaskItem addArgument:@"-r"];
    [audioSourceTaskItem addArgument:@"48000"];      // assume input from AudioMonitor already resampled to 48000 Hz

    [audioSourceTaskItem addArgument:@"-e"];
    [audioSourceTaskItem addArgument:@"float"];

    [audioSourceTaskItem addArgument:@"-b"];
    [audioSourceTaskItem addArgument:@"32"];

    [audioSourceTaskItem addArgument:@"-c"];
    [audioSourceTaskItem addArgument:@"2"];

    // input from Core Audio device
    [audioSourceTaskItem addArgument:@"-t"];
    [audioSourceTaskItem addArgument:@"coreaudio"];       // first stage audio output
    [audioSourceTaskItem addArgument:audioInputDeviceName];  // quotes are omitted intentionally

    // output args

    [audioSourceTaskItem addArgument:@"-e"];
    [audioSourceTaskItem addArgument:@"signed-integer"];

    [audioSourceTaskItem addArgument:@"-b"];
    [audioSourceTaskItem addArgument:@"16"];

    [audioSourceTaskItem addArgument:@"-c"];
    [audioSourceTaskItem addArgument:@"2"];

    [audioSourceTaskItem addArgument:@"-t"];
    [audioSourceTaskItem addArgument:@"raw"];

    [audioSourceTaskItem addArgument:@"-"];             // stdout

    self.statusFunctionString = [NSString stringWithFormat:@"Using Core Audio Input '%@'", audioInputDeviceName];

    self.frequencyString = [@"N/A" mutableCopy];
    self.modulationString = @"lpcm";
    self.squelchLevelNumber = [NSNumber numberWithInteger:0];
    self.tunerGainNumber = [NSNumber numberWithInteger:0];
    self.optionsString = @"";
    self.audioOutputFilterString = @"";

    //[audioSourceTaskItem addArgument:@"rate"];
    //[audioSourceTaskItem addArgument:@"48000"];

    return audioSourceTaskItem;
}

//==================================================================================
//    makeSoxTaskItem
//==================================================================================

- (TaskItem *)makeSoxTaskItem
{
    NSString * trimmedFilterString = [self.audioOutputFilterString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSArray * audioOutputFilterStringArray = [trimmedFilterString componentsSeparatedByString:@" "];

    TaskItem * soxTaskItem = [self.radioTaskPipelineManager makeTaskItemWithExecutable:@"sox" functionName:@"sox"];;

    [soxTaskItem addArgument:@"-V2"];    // debug verbosity, -V2 shows failures and warnings
    [soxTaskItem addArgument:@"-q"];    // quiet mode - don't show terminal-style audio meter

    [soxTaskItem addArgument:@"-r"];
    [soxTaskItem addArgument:@"48000"];      // assume input from AudioMonitor already resampled to 48000 Hz
    
    [soxTaskItem addArgument:@"-e"];
    [soxTaskItem addArgument:@"signed-integer"];
    
    [soxTaskItem addArgument:@"-b"];
    [soxTaskItem addArgument:@"16"];
    
    [soxTaskItem addArgument:@"-c"];
    [soxTaskItem addArgument:@"2"];
    
    [soxTaskItem addArgument:@"-t"];
    [soxTaskItem addArgument:@"raw"];
    
    [soxTaskItem addArgument:@"-"];         // stdin

    // audio output arguments

    //[soxTaskItem addArgument:@"-r"];
    //[soxTaskItem addArgument:@"48000"];

    [soxTaskItem addArgument:@"-e"];
    [soxTaskItem addArgument:@"signed-integer"];
    
    [soxTaskItem addArgument:@"-b"];
    [soxTaskItem addArgument:@"16"];
    
    [soxTaskItem addArgument:@"-c"];
    [soxTaskItem addArgument:@"2"];

    [soxTaskItem addArgument:@"-t"];
    [soxTaskItem addArgument:@"raw"];
    
    [soxTaskItem addArgument:@"-"];         // stdout
    
    [soxTaskItem addArgument:@"rate"];
    [soxTaskItem addArgument:@"48000"];
    
    for (NSString * audioOutputFilterStringItem in audioOutputFilterStringArray)
    {
        [soxTaskItem addArgument:audioOutputFilterStringItem];
    }
    
    return soxTaskItem;
}

//==================================================================================
//	makeRTLSDRAudioSourceTaskItemForFrequencies:category:
//==================================================================================

- (TaskItem *)makeRTLSDRAudioSourceTaskItemForFrequencies:(NSArray *)frequenciesArray category:(NSDictionary *)categoryDictionary
{
    // values common to both Favorites and Categories

    self.frequencyString = [NSMutableString stringWithFormat:@"-f 89100000"];  // can be single frequency, multiple frequencies or range
    self.modulationString = @"fm";
    self.tunerGainNumber = [NSNumber numberWithFloat:49.5f];
    self.squelchLevelNumber = [NSNumber numberWithInteger:0];
    self.tunerSampleRateNumber = [NSNumber numberWithInteger:10000];
    self.optionsString = @"";
    self.audioOutputFilterString = @"";
    self.statusFunctionString = @"No active tuning";
    self.enableDirectSamplingQBranchMode = NO;
    self.enableTunerAGC = NO;
    self.stereoFlag = NO;

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
            
            nameString = [firstFrequencyDictionary objectForKey:@"station_name"];
            categoryScanningEnabledNumber = [NSNumber numberWithInteger:0];
            samplingModeNumber = [firstFrequencyDictionary objectForKey:@"sampling_mode"];
            tunerAGCNumber = [firstFrequencyDictionary objectForKey:@"tuner_agc"];
            oversamplingNumber = [firstFrequencyDictionary objectForKey:@"oversampling"];
            firSizeNumber = [firstFrequencyDictionary objectForKey:@"fir_size"];
            atanMathString = [firstFrequencyDictionary objectForKey:@"atan_math"];
            
            NSNumber * stereoFlagNumber = [firstFrequencyDictionary objectForKey:@"stereo_flag"];
            if (stereoFlagNumber.integerValue == 1)
            {
                self.stereoFlag = YES;
            }

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
        NSString * trimmedOptionString = [aOptionString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
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
//    makeStereoDemuxTaskItem
//==================================================================================

- (TaskItem *)makeStereoDemuxTaskItem
{
    // Get lpcm from stdin, output to stdout
    TaskItem * stereoDemuxTaskItem = [self.radioTaskPipelineManager makeTaskItemWithExecutable:@"stereodemux" functionName:@"StereoDemux"];

    [stereoDemuxTaskItem addArgument:@"-r"];
    [stereoDemuxTaskItem addArgument:self.tunerSampleRateNumber.stringValue];

    return stereoDemuxTaskItem;
}

//==================================================================================
//	makeAudioMonitorTaskItemForSourceChannels:
//==================================================================================

- (TaskItem *)makeAudioMonitorTaskItemForSourceChannels:(NSInteger)sourceChannels
{
    // Get lpcm from stdin, re-sample to 48000 Hz, optionally play audio directly to current system CoreAudio device, output to stdout
    TaskItem * audioMonitorTaskItem = [self.radioTaskPipelineManager makeTaskItemWithExecutable:@"AudioMonitor" functionName:@"AudioMonitor"];
    
    [audioMonitorTaskItem addArgument:@"-r"];
    [audioMonitorTaskItem addArgument:self.tunerSampleRateNumber.stringValue];
    
    [audioMonitorTaskItem addArgument:@"-c"];
    [audioMonitorTaskItem addArgument:[NSString stringWithFormat:@"%ld", sourceChannels]];

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
//    checkIcecastAndEZStream
//==================================================================================

- (void)checkIcecastAndEZStream
{
    BOOL restartServices = NO;

    if (self.appDelegate.icecastController.icecastTask == NULL)
    {
        restartServices = YES;
    }

    if (self.appDelegate.ezStreamController.ezStreamTaskPipelineManager.taskPipelineStatus != kTaskPipelineStatusRunning)
    {
        restartServices = YES;
    }
    
    if (restartServices == YES)
    {
        [self.appDelegate restartServices];
    }
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

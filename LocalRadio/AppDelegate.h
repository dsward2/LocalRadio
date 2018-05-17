//
//  AppDelegate.h
//  LocalRadio
//
//  Created by Douglas Ward on 4/22/17.
//  Copyright © 2017-2018 ArkPhone LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class LocalRadioAppSettings;
@class WebServerController;
@class SDRController;
@class IcecastController;
@class EZStreamController;
@class SoxController;
@class SQLiteController;
@class WebViewDelegate;
@class UDPStatusListenerController;
@class FCCMapController;

#define kListenModeIdle 0
#define kListenModeFrequency 1
#define kListenModeScan 1

@interface AppDelegate : NSObject <NSApplicationDelegate, NSStreamDelegate, NSTabViewDelegate>

//NS_ASSUME_NONNULL_BEGIN

@property (weak) IBOutlet WebViewDelegate * webViewDelegate;

@property (strong) IBOutlet LocalRadioAppSettings * localRadioAppSettings;
@property (strong) IBOutlet SQLiteController * sqliteController;
@property (strong) IBOutlet WebServerController * webServerController;
@property (strong) IBOutlet SDRController * sdrController;
@property (strong) IBOutlet IcecastController * icecastController;
@property (strong) IBOutlet EZStreamController * ezStreamController;
@property (strong) IBOutlet SoxController * soxController;
@property (strong) IBOutlet UDPStatusListenerController * udpStatusListenerController;
@property (strong) IBOutlet FCCMapController * fccMapController;

@property (weak) IBOutlet NSTextField * statusIcecastServerTextField;
@property (weak) IBOutlet NSTextField * statusEZStreamServerTextField;
@property (weak) IBOutlet NSTextField * statusRTLSDRTextField;
@property (weak) IBOutlet NSTextField * statusFunctionTextField;
@property (weak) IBOutlet NSTextField * statusNameTextField;
@property (weak) IBOutlet NSTextField * statusFrequencyTextField;
@property (weak) IBOutlet NSTextField * statusFrequencyIDTextField;
@property (weak) IBOutlet NSTextField * statusModulationTextField;
@property (weak) IBOutlet NSTextField * statusSamplingRateTextField;
@property (weak) IBOutlet NSTextField * statusTunerGainTextField;
@property (weak) IBOutlet NSTextField * statusTunerAGCTextField;
@property (weak) IBOutlet NSTextField * statusSamplingModeTextField;
@property (weak) IBOutlet NSTextField * statusAudioOutputTextField;
@property (weak) IBOutlet NSTextField * statusAudioOutputFilterTextField;
@property (weak) IBOutlet NSTextField * statusStreamSourceTextField;
@property (weak) IBOutlet NSTextField * statusSignalLevelTextField;
@property (weak) IBOutlet NSTextField * statusSquelchLevelTextField;
@property (weak) IBOutlet NSTextField * statusRtlsdrOptionsTextField;
@property (weak) IBOutlet NSTextField * statusLocalRadioURLTextField;
@property (weak) IBOutlet NSTextField * statusIcecastURLTextField;

@property (strong) IBOutlet NSTextView * statusCurrentTasksTextView;

@property (weak) IBOutlet NSButton * statusOpenIcecastWebPage;

@property (weak) IBOutlet NSTextField * httpServerPortTextField;
@property (weak) IBOutlet NSTextField * httpServerURLTextField;

@property (weak) IBOutlet NSTextField * icecastServerHostTextField;
@property (weak) IBOutlet NSTextField * icecastServerPortTextField;
@property (weak) IBOutlet NSTextField * icecastServerMountNameTextField;
@property (weak) IBOutlet NSTextField * icecastServerSourcePasswordTextField;
@property (weak) IBOutlet NSTextField * icecastServerWebURLTextField;
@property (weak) IBOutlet NSButton * openIcecastWebPageButton;

@property (weak) IBOutlet NSTextField * statusPortTextField;
@property (weak) IBOutlet NSTextField * controlPortTextField;
@property (weak) IBOutlet NSTextField * audioPortTextField;

@property (weak) IBOutlet NSTextField * mp3SettingsTextField;
@property (weak) IBOutlet NSTextField * mp3SettingsDescriptionTextField;

@property (weak) IBOutlet NSButton * useWebViewAudioPlayerCheckbox;
@property (weak) IBOutlet NSButton * useAutoPlayCheckbox;


@property (weak) IBOutlet NSTextField * editHttpServerPortTextField;
@property (weak) IBOutlet NSTextField * editHttpServerURLTextField;

@property (weak) IBOutlet NSTextField * editIcecastServerHostTextField;
@property (weak) IBOutlet NSTextField * editIcecastServerPortTextField;
@property (weak) IBOutlet NSTextField * editIcecastServerMountNameTextField;
@property (weak) IBOutlet NSTextField * editIcecastServerSourcePasswordTextField;
@property (weak) IBOutlet NSTextField * editIcecastServerWebURLTextField;

@property (weak) IBOutlet NSTextField * editStatusPortTextField;
@property (weak) IBOutlet NSTextField * editControlPortTextField;
@property (weak) IBOutlet NSTextField * editAudioPortTextField;

@property (weak) IBOutlet NSButton * editMP3ConstantRadioButton;
@property (weak) IBOutlet NSPopUpButton * editMP3ConstantPopUpButton;
@property (weak) IBOutlet NSPopUpButton * editMP3EncodingQualityPopUpButton;

@property (weak) IBOutlet NSTextField * editSecondStageSoxFilterTextField;


@property (weak) IBOutlet NSButton * editUseWebViewAudioPlayerCheckbox;

@property (weak) IBOutlet NSButton * editSaveButton;
@property (weak) IBOutlet NSButton * editCancelButton;
@property (weak) IBOutlet NSButton * editSetDefaultsButton;

@property (weak) IBOutlet NSWindow * editConfigurationSheetWindow;

@property (weak) IBOutlet NSButton * showConfigurationFilesButton;
@property (weak) IBOutlet NSButton * changeConfigurationButton;

@property (strong) NSTimer * periodicUpdateTimer;

@property (strong) NSString * mp3Settings;
@property (assign) BOOL useWebViewAudioPlayer;
@property (assign) BOOL useAutoPlay;
@property (assign) NSUInteger icecastServerPort;
@property (strong) NSString * statusFrequencyID;
@property (strong) NSString * statusFrequency;
@property (strong) NSString * statusName;
@property (strong) NSString * statusModulation;
@property (strong) NSString * statusSamplingRate;


@property (assign) NSInteger listenMode;

@property (assign) BOOL rtlsdrDeviceFound;
@property (assign) BOOL applicationIsTerminating;

//NS_ASSUME_NONNULL_END

- (void)restartServices;

- (NSString *)webServerControllerURLString;


- (IBAction)openLocalRadioServerWebPage:(id)sender;
- (IBAction)openIcecastServerWebPage:(id)sender;
- (IBAction)showConfigurationFilesButtonAction:(id)sender;
- (IBAction)changeConfigurationButtonAction:(id)sender;

- (IBAction)editSaveButtonAction:(id)sender;
- (IBAction)editCancelButtonAction:(id)sender;
- (IBAction)editSetDefaultsButtonAction:(id)sender;

- (void)updateCurrentTasksText;

- (NSString *)localHostString;
- (NSString *)portString;

- (int) processIDForProcessName:(NSString *)processName;

- (void)showInformationSheetWithMessage:(NSString *)message informativeText:(NSString *)informativeText;

- (NSString *)shortHertzString:(NSString *)hertzNumericString;
- (NSInteger)hertzWithString:(NSString *)hertzString;
- (void)setStatusFrequencyString:(NSString *)value;
- (void)setStatusNameString:(NSString *)value;
- (void)setStatusFrequencyIDString:(NSString *)value;

@end


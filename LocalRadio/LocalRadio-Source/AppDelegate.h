//
//  AppDelegate.h
//  LocalRadio
//
//  Created by Douglas Ward on 4/22/17.
//  Copyright © 2017-2018 ArkPhone LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class LocalRadioAppSettings;
@class HTTPWebServerController;
@class HTTPSWebServerController;
@class SDRController;
@class IcecastController;
@class IcecastSourceController;
@class SoxController;
@class SQLiteController;
@class WebViewDelegate;
@class UDPStatusListenerController;
@class FCCMapController;
@class CustomTaskController;
@class LocalRadioAPI;
@class TLSManager;

#define kListenModeIdle 0
#define kListenModeFrequency 1
#define kListenModeScan 2
#define kListenModeDevice 3

@interface AppDelegate : NSObject <NSApplicationDelegate, NSStreamDelegate, NSTabViewDelegate>

//NS_ASSUME_NONNULL_BEGIN

@property (weak) IBOutlet NSWindow *window;

@property (weak) IBOutlet WebViewDelegate * webViewDelegate;

// These object are instantiated and inter-connected in Inteface Builder
@property (strong) IBOutlet LocalRadioAppSettings * localRadioAppSettings;
@property (strong) IBOutlet SQLiteController * sqliteController;
@property (strong) IBOutlet HTTPWebServerController * httpWebServerController;
@property (strong) IBOutlet HTTPSWebServerController * httpsWebServerController;
@property (strong) IBOutlet SDRController * sdrController;
@property (strong) IBOutlet IcecastController * icecastController;
@property (strong) IBOutlet IcecastSourceController * icecastSourceController;
@property (strong) IBOutlet SoxController * soxController;
@property (strong) IBOutlet UDPStatusListenerController * udpStatusListenerController;
@property (strong) IBOutlet FCCMapController * fccMapController;
@property (strong) IBOutlet CustomTaskController * customTaskController;
@property (strong) IBOutlet LocalRadioAPI * localRadioAPI;
@property (strong) IBOutlet TLSManager * tlsManager;

// Main window elements

@property (weak) IBOutlet NSTextField * localRadioHTTPSURLTextField;
@property (weak) IBOutlet NSTextField * localRadioHTTPURLTextField;

@property (weak) IBOutlet NSTextField * statusIcecastServerTextField;
@property (weak) IBOutlet NSTextField * statusIcecastSourceTextField;
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
@property (weak) IBOutlet NSTextField * statusAudioOutputFilterTextField;
@property (weak) IBOutlet NSTextField * statusSignalLevelTextField;
@property (weak) IBOutlet NSTextField * statusSquelchLevelTextField;
@property (weak) IBOutlet NSTextField * statusRtlsdrOptionsTextField;
@property (weak) IBOutlet NSTextField * statusIcecastURLTextField;

@property (strong) IBOutlet NSTextView * statusCurrentTasksTextView;

@property (weak) IBOutlet NSButton * statusOpenIcecastWebPage;

@property (weak) IBOutlet NSTextField * localRadioHTTPServerPortTextField;
@property (weak) IBOutlet NSTextField * localRadioHTTPSServerPortTextField;

@property (weak) IBOutlet NSTextField * icecastServerHostTextField;
@property (weak) IBOutlet NSTextField * icecastServerHTTPPortTextField;
@property (weak) IBOutlet NSTextField * icecastServerHTTPSPortTextField;
@property (weak) IBOutlet NSTextField * icecastServerMountNameTextField;
@property (weak) IBOutlet NSTextField * icecastServerSourcePasswordTextField;
@property (weak) IBOutlet NSTextField * icecastServerWebURLTextField;
@property (weak) IBOutlet NSButton * openIcecastWebPageButton;

@property (weak) IBOutlet NSTextField * statusPortTextField;
@property (weak) IBOutlet NSTextField * controlPortTextField;
@property (weak) IBOutlet NSTextField * audioPortTextField;

@property (weak) IBOutlet NSTextField * aacSettingsBitrateTextField;

@property (weak) IBOutlet NSButton * useWebViewAudioPlayerCheckbox;
@property (weak) IBOutlet NSButton * useAutoPlayCheckbox;
@property (weak) IBOutlet NSButton * logAllStderrMessagesCheckbox;


@property (weak) IBOutlet NSTextField * editLocalRadioHTTPServerPortTextField;
@property (weak) IBOutlet NSTextField * editLocalRadioHTTPSServerPortTextField;

@property (weak) IBOutlet NSTextField * editIcecastServerHostTextField;
@property (weak) IBOutlet NSTextField * editIcecastServerHTTPPortTextField;
@property (weak) IBOutlet NSTextField * editIcecastServerHTTPSPortTextField;
@property (weak) IBOutlet NSTextField * editIcecastServerMountNameTextField;
@property (weak) IBOutlet NSTextField * editIcecastServerSourcePasswordTextField;
@property (weak) IBOutlet NSTextField * editIcecastServerWebURLTextField;

@property (weak) IBOutlet NSTextField * editStatusPortTextField;
@property (weak) IBOutlet NSTextField * editControlPortTextField;
@property (weak) IBOutlet NSTextField * editAudioPortTextField;

@property (weak) IBOutlet NSPopUpButton * editAACSettingsBitratePopUpButton;

@property (weak) IBOutlet NSButton * editUseWebViewAudioPlayerCheckbox;
@property (weak) IBOutlet NSButton * editLogAllStderrMessagesCheckbox;

@property (weak) IBOutlet NSButton * editSaveButton;
@property (weak) IBOutlet NSButton * editCancelButton;
@property (weak) IBOutlet NSButton * editSetDefaultsButton;

@property (weak) IBOutlet NSWindow * editConfigurationSheetWindow;

@property (weak) IBOutlet NSWindow * generatingKeysAndCertificatesSheetWindow;
@property (weak) IBOutlet NSProgressIndicator * generatingKeysAndCertificatesProgressIndicator;

@property (weak) IBOutlet NSButton * showConfigurationFilesButton;
@property (weak) IBOutlet NSButton * changeConfigurationButton;

@property (strong) NSTimer * periodicUpdateTimer;

@property (strong) NSString * aacBitrate;
@property (strong) NSString * icecastServerMountName;

@property (assign) BOOL useWebViewAudioPlayer;
@property (assign) BOOL useAutoPlay;
@property (assign) BOOL logAllStderrMessages;
@property (assign) NSUInteger icecastServerHTTPPort;
@property (assign) NSUInteger icecastServerHTTPSPort;
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

- (NSString *)httpWebServerControllerURLString;


- (IBAction)openLocalRadioHTTPSServerWebPage:(id)sender;
- (IBAction)openLocalRadioHTTPServerWebPage:(id)sender;
- (IBAction)openIcecastServerWebPage:(id)sender;
- (IBAction)showConfigurationFilesButtonAction:(id)sender;
- (IBAction)changeConfigurationButtonAction:(id)sender;

- (IBAction)editSaveButtonAction:(id)sender;
- (IBAction)editCancelButtonAction:(id)sender;
- (IBAction)editSetDefaultsButtonAction:(id)sender;

- (IBAction)updateCurrentTasksText:(id)sender;

- (IBAction)reloadWebView:(id)sender;

- (NSString *)localHostString;
- (NSString *)httpWebServerPortString;
- (NSString *)httpsWebServerPortString;

- (int) processIDForProcessName:(NSString *)processName;

- (void)showInformationSheetWithMessage:(NSString *)message informativeText:(NSString *)informativeText;

- (NSString *)shortHertzString:(NSString *)hertzNumericString;
- (NSInteger)hertzWithString:(NSString *)hertzString;
- (void)setStatusFrequencyString:(NSString *)value;
- (void)setStatusNameString:(NSString *)value;
- (void)setStatusFrequencyIDString:(NSString *)value;

- (NSString *)localHostString;
- (NSString *)localHostIPString;

@end


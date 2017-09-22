//
//  SDRController.h
//  LocalRadio
//
//  Created by Douglas Ward on 5/29/17.
//  Copyright © 2017 ArkPhone LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
//#import "GCDAsyncUdpSocket.h"
//#import "GCDAsyncSocket.h"

@class AppDelegate;

//@interface SDRController : NSObject <GCDAsyncSocketDelegate, GCDAsyncUdpSocketDelegate>
@interface SDRController : NSObject
{
}

//@property(strong) GCDAsyncUdpSocket *udpSocket;
//@property(strong) GCDAsyncSocket * currentInfoSocket;   // TCP socket to rtl_fm_localradio

@property(strong) IBOutlet AppDelegate * appDelegate;

@property (strong) NSString * rtlsdrTaskMode;   // "frequency", "scan", or "stopped"
@property (strong) NSMutableDictionary * rtlsdrCategoryDictionary;

@property (strong) NSTask * rtlfmTask; // output to soxTask
@property (strong) NSPipe * rtlfmTaskStandardErrorPipe;

@property (strong) NSTask * audioMonitorTask;   // output to Sox via stdin and optionally to current Mac audio device
@property (strong) NSPipe * rtlsdrAudioMonitorPipe;
@property (strong) NSPipe * audioMonitorTaskStandardErrorPipe;

@property (strong) NSPipe * audioMonitorSoxPipe;

@property (strong) NSTask * soxTask;    // for resampling to 48K to UDPSender, or directing radio data to CoreAudio for decoding via external app
@property (strong) NSPipe * soxTaskStandardErrorPipe;

@property (strong) NSPipe * soxUDPSenderPipe;

@property (strong) NSTask * udpSenderTask;  // for sending to UDPListener (then EZStream and Icecast), also echos to stdout
@property (strong) NSPipe * udpSenderTaskStandardErrorPipe;

@property (strong) NSArray * rtlsdrTaskFrequenciesArray;
@property (assign) NSInteger udpTag;

@property (strong) NSString * quotedRtlfmPath;
@property (strong) NSString * quotedAudioMonitorPath;
@property (strong) NSString * quotedSoxPath;
@property (strong) NSString * quotedUDPSenderPath;

@property (strong) NSString * rtlfmTaskArgsString;
@property (strong) NSString * audioMonitorTaskArgsString;
@property (strong) NSString * soxTaskArgsString;
@property (strong) NSString * udpSenderTaskArgsString;

@property (assign) int rtlfmTaskProcessID;
@property (assign) int audioMonitorTaskProcessID;
@property (assign) int soxTaskProcessID;
@property (assign) int udpSenderTaskProcessID;


- (void)terminateTasks;

- (void)startRtlsdrTasksForFrequency:(NSDictionary *)frequencyDictionary;
- (void)startRtlsdrTasksForFrequencies:(NSArray *)frequenciesArray category:(NSMutableDictionary *)categoryDictionary;

//- (NSString *)frequencyNumberString:(NSString *)mhzString;
//- (NSString *)megahertzString:(NSString *)mhzNumericString;

@end

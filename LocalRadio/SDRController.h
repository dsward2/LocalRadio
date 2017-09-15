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

@property (strong) NSTask * rtlsdrTask; // output to soxTask
@property (strong) NSPipe * rtlsdrTaskStandardErrorPipe;

@property (strong) NSTask * audioMonitorTask;
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



- (void)terminateTasks;

- (void)startRtlsdrTaskForFrequency:(NSDictionary *)frequencyDictionary;
- (void)startRtlsdrTaskForFrequencies:(NSArray *)frequenciesArray category:(NSDictionary *)categoryDictionary;

//- (NSString *)frequencyNumberString:(NSString *)mhzString;
//- (NSString *)megahertzString:(NSString *)mhzNumericString;

@end

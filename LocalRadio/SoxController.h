//
//  SoxController.h
//  LocalRadio
//
//  Created by Douglas Ward on 7/19/17.
//  Copyright © 2017 ArkPhone LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AppDelegate;

@interface SoxController : NSObject

@property (weak) IBOutlet AppDelegate * appDelegate;

@property (strong) NSTask * soxTask;
@property (strong) NSPipe * soxTaskStandardErrorPipe;

@property (strong) NSTask * udpSenderTask;
@property (strong) NSPipe * udpSenderTaskStandardErrorPipe;

@property (strong) NSPipe * soxUDPSenderPipe;

@property (strong) NSString * soxTaskArgsString;
@property (strong) NSString * udpSenderTaskArgsString;

@property (strong) NSString * quotedSoxPath;
@property (strong) NSString * quotedUDPSenderPath;

@property (assign) int soxTaskProcessID;
@property (assign) int udpSenderTaskProcessID;

- (void)startSecondaryStreamForFrequencies:(NSArray *)frequenciesArray category:(NSDictionary *)categoryDictionary;

- (void)terminateTasks;

@end

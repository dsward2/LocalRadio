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
@property (strong) NSString * udpSenderArgsString;

- (void)startSecondaryStreamForFrequencies:(NSArray *)frequenciesArray category:(NSDictionary *)categoryDictionary;

- (void)terminateTasks;

@end

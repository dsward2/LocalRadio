//
//  WebServerConnection.h
//  LocalRadio
//
//  Created by Douglas Ward on 5/26/17.
//  Copyright © 2017-2020 ArkPhone LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "HTTPConnection.h"
#import "SDRController.h"

@class AppDelegate;
@class SQLiteController;

@interface HTTPWebServerConnection : HTTPConnection

@property(strong) IBOutlet AppDelegate * appDelegate;
@property(strong) IBOutlet SQLiteController * sqliteController;
@property(strong) IBOutlet SDRController * sdrController;

@property(strong) NSMutableData * bodyData;

@property (strong) NSString * previousPath;

@property(strong) NSMutableDictionary * constructFrequencyDictionary;

- (void)listenButtonClickedForFrequencyID:(NSString *)frequencyIDString;
- (void)listenButtonClickedForFrequency:(NSMutableDictionary *)favoriteDictionary;

- (NSData *)requestBody;
- (NSData *)requestMessageData;

@end

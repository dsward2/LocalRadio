//
//  WebServerConnection.h
//  LocalRadio
//
//  Created by Douglas Ward on 5/26/17.
//  Copyright © 2017 ArkPhone LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "HTTPConnection.h"
#import "IcecastController.h"
#import "EZStreamController.h"
#import "SDRController.h"

@class AppDelegate;
@class SQLiteController;

@interface WebServerConnection : HTTPConnection

@property(strong) IBOutlet AppDelegate * appDelegate;
@property(strong) IBOutlet SQLiteController * sqliteController;
@property(strong) IBOutlet IcecastController * icecastController;
@property(strong) IBOutlet EZStreamController * ezStreamController;
@property(strong) IBOutlet SDRController * sdrController;

@property(strong) NSMutableData * bodyData;

@property (strong) NSString * previousPath;

@property(strong) NSMutableDictionary * constructFrequencyDictionary;

- (void)listenButtonClickedForFrequencyID:(NSString *)frequencyIDString;
- (void)listenButtonClickedForFrequency:(NSMutableDictionary *)favoriteDictionary;


@end

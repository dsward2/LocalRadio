//
//  LocalRadioAppSettings.h
//  LocalRadio
//
//  Created by Douglas Ward on 8/27/17.
//  Copyright © 2017-2020 ArkPhone LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SQLiteController;
@class AppDelegate;

@interface LocalRadioAppSettings : NSObject

@property (strong) IBOutlet AppDelegate * appDelegate;
@property (strong) IBOutlet SQLiteController * sqliteController;

- (void) registerDefaultSettings;
- (void) setDefaultSettings;

- (NSNumber *) integerNumberForKey:(NSString *)key;
- (void) setInteger:(NSInteger)aInteger forKey:(NSString *)key;

- (NSString *) valueForKey:(NSString *)key;
- (void) setValue:(NSString *)aString forKey:(NSString *)key;

@end

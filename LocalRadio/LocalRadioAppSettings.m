//
//  LocalRadioAppSettings.m
//  LocalRadio
//
//  Created by Douglas Ward on 8/27/17.
//  Copyright © 2017 ArkPhone LLC. All rights reserved.
//

#import "LocalRadioAppSettings.h"
#import "SQLiteController.h"

@implementation LocalRadioAppSettings


- (void) registerDefaultSettings
{
    // set default key-store values in local_radio_config SQLite table
    
    [self setDefaultInteger:0 forKey:@"LocalRadioConfigVersion"];   // version 0 did not contain LocalRadioConfigVersion, version 1 does
    
    // these are all valid for versions 0 and 1
    [self setDefaultInteger:17002 forKey:@"HTTPServerPort"];
    [self setDefaultInteger:17003 forKey:@"IcecastServerPort"];
    [self setDefaultInteger:17004 forKey:@"StatusPort"];
    [self setDefaultInteger:17005 forKey:@"ControlPort"];
    [self setDefaultInteger:17006 forKey:@"AudioPort"];

    [self setDefaultInteger:0 forKey:@"IcecastServerMode"];

    [self setDefaultValue:@"127.0.0.1" forKey:@"IcecastServerHost"];
    [self setDefaultValue:@"localradio" forKey:@"IcecastServerMountName"];
    
    [self setDefaultValue:@"vol 10 dither -s" forKey:@"SecondStageSoxFilter"];
    [self setDefaultValue:@"-4.2" forKey:@"MP3Settings"];

    //[self setDefaultValue:@"myPassword123" forKey:@"IcecastServerSourcePassword"];
    NSString * randomPassword = [self generateRandomPassword];
    [self setDefaultValue:randomPassword forKey:@"IcecastServerSourcePassword"];
    [self setValue:randomPassword forKey:@"IcecastServerSourcePassword"];
}


- (NSString *)generateRandomPassword
{
    NSMutableString * randomPassword = [NSMutableString string];
    
    NSString * randomCharacters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";

    for (NSInteger i = 0; i < 20; i++)
    {
        uint32_t randomCharactersLength = (uint32_t)randomCharacters.length;
        NSInteger randomIndex = arc4random_uniform(randomCharactersLength);
        unichar randomCharacter = [randomCharacters characterAtIndex:randomIndex];
        [randomPassword appendFormat: @"%C", randomCharacter];
    }
    
    return randomPassword;
}


- (BOOL) valueExistsForKey:(NSString *)key
{
    BOOL result = NO;
    
    id existingRecord = [self.sqliteController localRadioAppSettingsValueForKey:key];
    if (existingRecord != NULL)
    {
        result = YES;
    }
    
    return result;
}



- (NSNumber *) integerForKey:(NSString *)key
{
    NSNumber * result = NULL;

    id existingValue = [self.sqliteController localRadioAppSettingsValueForKey:key];
    if ([existingValue isKindOfClass:[NSNumber class]] == YES)
    {
        result = existingValue;
    }
    else if ([existingValue isKindOfClass:[NSString class]] == YES)
    {
        NSString * existingValueString = existingValue;
        NSInteger existingValueInteger = existingValueString.integerValue;
        result = [NSNumber numberWithInteger:existingValueInteger];
    }
    
    return result;
}



- (void) setInteger:(NSInteger)aInteger forKey:(NSString *)key
{
    NSNumber * integerNumber = [NSNumber numberWithInteger:aInteger];
    
    [self.sqliteController storeLocalRadioAppSettingsValue:integerNumber ForKey:key];
}



- (void) setDefaultInteger:(NSInteger)aInteger forKey:(NSString *)key
{
    if ([self valueExistsForKey:key] == NO)
    {
        [self setInteger:aInteger forKey:key];
    }
}


- (NSString *) valueForKey:(NSString *)key
{
    NSString * result = NULL;

    id existingValue = [self.sqliteController localRadioAppSettingsValueForKey:key];
    if ([existingValue isKindOfClass:[NSString class]] == YES)
    {
        result = existingValue;
    }
    
    return result;
}


- (void) setValue:(NSString *)aString forKey:(NSString *)key
{
    [self.sqliteController storeLocalRadioAppSettingsValue:aString ForKey:key];
}



- (void) setDefaultValue:(NSString *)aString forKey:(NSString *)key
{
    if ([self valueExistsForKey:key] == NO)
    {
        [self setValue:aString forKey:key];
    }
}




@end

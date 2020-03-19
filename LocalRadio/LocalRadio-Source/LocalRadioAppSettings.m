//
//  LocalRadioAppSettings.m
//  LocalRadio
//
//  Created by Douglas Ward on 8/27/17.
//  Copyright © 2017-2020 ArkPhone LLC. All rights reserved.
//

#import "LocalRadioAppSettings.h"
#import "SQLiteController.h"

@implementation LocalRadioAppSettings


- (void) registerDefaultSettings
{
    // set default key-store values in local_radio_config SQLite table
    
    [self setDefaultInteger:kCurrentLocalRadioConfigVersion forKey:@"LocalRadioConfigVersion"];
    
    [self setDefaultInteger:17002 forKey:@"LocalRadioServerHTTPPort"];
    [self setDefaultInteger:17004 forKey:@"StreamingServerHTTPPort"];
    [self setDefaultInteger:17006 forKey:@"StatusPort"];
    [self setDefaultInteger:17007 forKey:@"ControlPort"];
    [self setDefaultInteger:17008 forKey:@"AudioPort"];

    [self setDefaultInteger:1 forKey:@"CaptureStderr"];

    [self setDefaultValue:@"128000" forKey:@"AACBitrate"];
}

- (void) setDefaultSettings
{
    // set default key-store values in local_radio_config SQLite table
    
    [self setInteger:kCurrentLocalRadioConfigVersion forKey:@"LocalRadioConfigVersion"];
    
    [self setInteger:17002 forKey:@"LocalRadioServerHTTPPort"];
    [self setInteger:17004 forKey:@"StreamingServerHTTPPort"];
    [self setInteger:17006 forKey:@"StatusPort"];
    [self setInteger:17007 forKey:@"ControlPort"];
    [self setInteger:17008 forKey:@"AudioPort"];

    [self setInteger:1 forKey:@"CaptureStderr"];
    
    [self setValue:@"128000" forKey:@"AACBitrate"];
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



- (NSNumber *) integerNumberForKey:(NSString *)key
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
    
    [self.sqliteController storeLocalRadioAppSettingsValue:integerNumber forKey:key];
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
    [self.sqliteController storeLocalRadioAppSettingsValue:aString forKey:key];
}



- (void) setDefaultValue:(NSString *)aString forKey:(NSString *)key
{
    if ([self valueExistsForKey:key] == NO)
    {
        [self setValue:aString forKey:key];
    }
}




@end

//
//  SQLiteController.m
//  LocalRadio
//
//  Created by Douglas Ward on 6/18/17.
//  Copyright © 2017-2020 ArkPhone LLC. All rights reserved.
//

#import "SQLiteController.h"
#import "SQLiteLibrary.h"
#import "NSFileManager+DirectoryLocations.h"

@implementation SQLiteController

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.sqliteIsRunning = NO;
    }
    return self;
}

//==================================================================================
//    startSQLiteConnection
//==================================================================================

- (void)startSQLiteConnection
{
    //
    // IMPORTANT: When the LocalRadio  database schema is changed,
    // the "data_skeleton.sqlite3" file should be updated to reflect the change.
    // Also, test LocalRadio for new users where the SQLite database is created for first time.
    //

    if (self.sqliteIsRunning == NO)
    {
        NSString * applicationSupportDirectoryPath = [[NSFileManager defaultManager] applicationSupportDirectory];
        
        NSString * databasePathString = [applicationSupportDirectoryPath stringByAppendingPathComponent:@"LocalRadio-V5.sqlite3"];
        
        BOOL existingLocalRadioV5Found = [[NSFileManager defaultManager] fileExistsAtPath:databasePathString];
        
        NSMutableDictionary * databaseUpgradeDictionary = NULL;
        
        if (existingLocalRadioV5Found == NO)
        {
            //check for earlier database versions, and migrate data if found
            if ([databaseUpgradeDictionary count] == 0)
            {
                databaseUpgradeDictionary = [self getDatabaseV4Data];
            }

            if ([databaseUpgradeDictionary count] == 0)
            {
                databaseUpgradeDictionary = [self getDatabaseV3Data];
            }

            if ([databaseUpgradeDictionary count] == 0)
            {
                databaseUpgradeDictionary = [self getDatabaseV2Data];
            }

            if ([databaseUpgradeDictionary count] == 0)
            {
                databaseUpgradeDictionary = [self getDatabaseV1Data];
            }
        }

        //NSLog(@"databasePathString = %@", databasePathString);

        [SQLiteLibrary setDatabaseFile:databasePathString]; // open LocalRadio-V5.sqlite3
        [SQLiteLibrary setupDatabaseAndForceReset:NO];
        self.sqliteIsRunning = [SQLiteLibrary begin];

        if (databaseUpgradeDictionary != NULL)
        {
            [self emptyTable:@"custom_task"];
            [self emptyTable:@"freq_cat"];
            [self emptyTable:@"frequency"];
            [self emptyTable:@"category"];
            [self emptyTable:@"local_radio_config"];

            [self importPreviousVersionData:databaseUpgradeDictionary];
        }

        //NSLog(@"startSQLiteConnection sqliteIsRunning = %d", self.sqliteIsRunning);
    }
}

//==================================================================================
//    importPreviousVersionData:
//==================================================================================

- (void)importPreviousVersionData:(NSMutableDictionary *)databaseUpgradeDictionary
{
    NSArray * allKeys = databaseUpgradeDictionary.allKeys;
    
    for (NSString * tableName in allKeys)
    {
        NSArray * tableInfoArray = [self getTableInfo:tableName];

        NSArray * recordsArray = [databaseUpgradeDictionary objectForKey:tableName];
        
        // first update existing records
        for (NSDictionary * aRecordDictionary in recordsArray)
        {
            NSNumber * recordIDNumber = [aRecordDictionary objectForKey:@"id"];
            NSInteger recordID = recordIDNumber.integerValue;
            if (recordID != 0)
            {
                tableInfoArray = [self importRecord:aRecordDictionary table:tableName tableInfoArray:tableInfoArray];
            }
        }
        
        // then insert new records
        for (NSDictionary * aRecordDictionary in recordsArray)
        {
            NSNumber * recordIDNumber = [aRecordDictionary objectForKey:@"id"];
            NSInteger recordID = recordIDNumber.integerValue;
            if (recordID == 0)
            {
                tableInfoArray = [self importRecord:aRecordDictionary table:tableName tableInfoArray:tableInfoArray];
            }
        }
    }
}

//==================================================================================
//    getDatabaseV1Data
//==================================================================================

- (NSMutableDictionary *)getDatabaseV1Data
{
    // If current version database is missing, attempt to access a V1 database and copy the data for deferred import.
    NSMutableDictionary * databaseUpgradeDictionary = [NSMutableDictionary dictionary];

    NSString * applicationSupportDirectoryPath = [[NSFileManager defaultManager] applicationSupportDirectory];
    NSString * databaseV1PathString = [applicationSupportDirectoryPath stringByAppendingPathComponent:@"LocalRadio.sqlite3"];
    BOOL localRadioV1Found = [[NSFileManager defaultManager] fileExistsAtPath:databaseV1PathString];
    
    if (localRadioV1Found == YES)
    {
        [SQLiteLibrary setDatabaseFile:databaseV1PathString];
        [SQLiteLibrary setupDatabaseAndForceReset:NO];
        BOOL sqliteIsRunning = [SQLiteLibrary begin];
        #pragma unused(sqliteIsRunning)

        NSString * queryString = @"SELECT id, station_name, frequency_mode, frequency, frequency_scan_end, frequency_scan_interval, tuner_gain, tuner_agc, sampling_mode, sample_rate, oversampling, modulation, squelch_level, options, fir_size, atan_math, audio_output_filter, stereo_flag, usb_device_string, bias_t_flag FROM frequency ORDER BY id;";
        NSArray * allFrequencyRecords = [SQLiteLibrary performQueryAndGetResultList:queryString];

        NSArray * allCategoryRecords = [self allCategoryRecords];
        NSArray * allFreqCatRecords = [self allFreqCatRecords];
        //NSArray * allCustomTaskRecords = [self allCustomTaskRecords];
        NSArray * allLocalRadioConfigRecords = [self allLocalRadioConfigRecords];         // no changes to this table

        if (allFrequencyRecords != NULL)
        {
            [databaseUpgradeDictionary setObject:allFrequencyRecords forKey:@"frequency"];
        }
        
        if (allCategoryRecords != NULL)
        {
            [databaseUpgradeDictionary setObject:allCategoryRecords forKey:@"category"];
        }
        
        if (allFreqCatRecords != NULL)
        {
            [databaseUpgradeDictionary setObject:allFreqCatRecords forKey:@"freq_cat"];
        }
        
        if (allLocalRadioConfigRecords != NULL)
        {
            [databaseUpgradeDictionary setObject:allLocalRadioConfigRecords forKey:@"local_radio_config"];
        }
    }
    
    return databaseUpgradeDictionary;
}

//==================================================================================
//    getDatabaseV2Data
//==================================================================================

- (NSMutableDictionary *)getDatabaseV2Data
{
    // If current version database is missing, attempt to access a V2 database and copy the data for deferred import.
    NSMutableDictionary * databaseUpgradeDictionary = [NSMutableDictionary dictionary];

    NSString * applicationSupportDirectoryPath = [[NSFileManager defaultManager] applicationSupportDirectory];
    NSString * databaseV2PathString = [applicationSupportDirectoryPath stringByAppendingPathComponent:@"LocalRadio-V2.sqlite3"];
    BOOL localRadioV2Found = [[NSFileManager defaultManager] fileExistsAtPath:databaseV2PathString];
    
    if (localRadioV2Found == YES)
    {
        [SQLiteLibrary setDatabaseFile:databaseV2PathString];
        [SQLiteLibrary setupDatabaseAndForceReset:NO];
        BOOL sqliteIsRunning = [SQLiteLibrary begin];
        #pragma unused(sqliteIsRunning)

        NSArray * allFrequencyRecords = [self allFrequencyRecords];     // no changes to this table
        NSArray * allCategoryRecords = [self allCategoryRecords];       // no changes to this table
        NSArray * allFreqCatRecords = [self allFreqCatRecords];         // no changes to this table
        NSArray * allLocalRadioConfigRecords = [self allLocalRadioConfigRecords];         // no changes to this table

        // custom_task in V3 adds columns, so select only valid columns for V2
        //NSArray * allCustomTaskRecords = [self allCustomTaskRecords];
        NSString * queryString = @"SELECT id, task_name, task_json, sample_rate, channels FROM custom_task ORDER BY id;";
        NSArray * allCustomTaskRecords = [SQLiteLibrary performQueryAndGetResultList:queryString];

        if (allFrequencyRecords != NULL)
        {
            [databaseUpgradeDictionary setObject:allFrequencyRecords forKey:@"frequency"];
        }
        
        if (allCategoryRecords != NULL)
        {
            [databaseUpgradeDictionary setObject:allCategoryRecords forKey:@"category"];
        }
        
        if (allFreqCatRecords != NULL)
        {
            [databaseUpgradeDictionary setObject:allFreqCatRecords forKey:@"freq_cat"];
        }
        
        if (allCustomTaskRecords != NULL)
        {
            [databaseUpgradeDictionary setObject:allCustomTaskRecords forKey:@"custom_task"];
        }

        if (allLocalRadioConfigRecords != NULL)
        {
            [databaseUpgradeDictionary setObject:allLocalRadioConfigRecords forKey:@"local_radio_config"];
        }
    }
    
    return databaseUpgradeDictionary;
}

//==================================================================================
//    setConfigRecordInArray:integer:forKey:
//==================================================================================

- (void)setConfigRecordInArray:(NSMutableArray *)allLocalRadioConfigRecords integer:(NSInteger)value forKey:(NSString *)key
{
    BOOL existingKeyFound = NO;

    for (NSDictionary * configItemDictionary in allLocalRadioConfigRecords)
    {
        NSString * existingKey = [configItemDictionary objectForKey:@"config_key"];
        if ([existingKey isEqualToString:key] == YES)
        {
            existingKeyFound = YES;
            NSNumber * itemIDNumber = [configItemDictionary objectForKey:@"id"];
            
            NSNumber * newValueNumber = [NSNumber numberWithInteger:value];
            
            NSDictionary * replacementDictionary = [NSDictionary dictionaryWithObjectsAndKeys:itemIDNumber, @"id", newValueNumber, @"config_value", key, @"config_key", nil];
            
            NSInteger index = [allLocalRadioConfigRecords indexOfObject:configItemDictionary];
            [allLocalRadioConfigRecords replaceObjectAtIndex:index withObject:replacementDictionary];
            
            break;
        }
    }
    
    if (existingKeyFound == NO)
    {
        NSNumber * newValueNumber = [NSNumber numberWithInteger:value];
        NSNumber * zeroNumber = [NSNumber numberWithInteger:0];
        NSDictionary * newDictionary = [NSDictionary dictionaryWithObjectsAndKeys:zeroNumber, @"id", newValueNumber, @"config_value", key, @"config_key", nil];
        [allLocalRadioConfigRecords addObject:newDictionary];
    }
}

//==================================================================================
//    getDatabaseV3Data
//==================================================================================

- (NSMutableDictionary *)getDatabaseV3Data
{
    // If current version database is missing, attempt to access a V2 database and copy the data for deferred import.
    NSMutableDictionary * databaseUpgradeDictionary = [NSMutableDictionary dictionary];

    NSString * applicationSupportDirectoryPath = [[NSFileManager defaultManager] applicationSupportDirectory];
    NSString * databaseV3PathString = [applicationSupportDirectoryPath stringByAppendingPathComponent:@"LocalRadio-V3.sqlite3"];
    BOOL localRadioV3Found = [[NSFileManager defaultManager] fileExistsAtPath:databaseV3PathString];
    
    if (localRadioV3Found == YES)
    {
        [SQLiteLibrary setDatabaseFile:databaseV3PathString];
        [SQLiteLibrary setupDatabaseAndForceReset:NO];
        BOOL sqliteIsRunning = [SQLiteLibrary begin];
        #pragma unused(sqliteIsRunning)

        NSArray * allFrequencyRecords = [self allFrequencyRecords];     // no changes to this table
        NSArray * allCategoryRecords = [self allCategoryRecords];       // no changes to this table
        NSArray * allFreqCatRecords = [self allFreqCatRecords];         // no changes to this table
        NSArray * allCustomTaskRecords = [self allCustomTaskRecords];   // no changes to this table
        
        NSMutableArray * allLocalRadioConfigRecords = [[self allLocalRadioConfigRecords] mutableCopy];
        
        [self setConfigRecordInArray:allLocalRadioConfigRecords integer:4 forKey:@"LocalRadioConfigVersion"];

        [self setConfigRecordInArray:allLocalRadioConfigRecords integer:17002 forKey:@"LocalRadioServerHTTPPort"];
        [self setConfigRecordInArray:allLocalRadioConfigRecords integer:17003 forKey:@"LocalRadioServerHTTPSPort"];
        [self setConfigRecordInArray:allLocalRadioConfigRecords integer:17004 forKey:@"StreamingServerHTTPPort"];
        [self setConfigRecordInArray:allLocalRadioConfigRecords integer:17006 forKey:@"StatusPort"];
        [self setConfigRecordInArray:allLocalRadioConfigRecords integer:17007 forKey:@"ControlPort"];
        [self setConfigRecordInArray:allLocalRadioConfigRecords integer:17008 forKey:@"AudioPort"];

        if (allFrequencyRecords != NULL)
        {
            [databaseUpgradeDictionary setObject:allFrequencyRecords forKey:@"frequency"];
        }
        
        if (allCategoryRecords != NULL)
        {
            [databaseUpgradeDictionary setObject:allCategoryRecords forKey:@"category"];
        }
        
        if (allFreqCatRecords != NULL)
        {
            [databaseUpgradeDictionary setObject:allFreqCatRecords forKey:@"freq_cat"];
        }
        
        if (allCustomTaskRecords != NULL)
        {
            [databaseUpgradeDictionary setObject:allCustomTaskRecords forKey:@"custom_task"];
        }
        
        if (allLocalRadioConfigRecords != NULL)
        {
            [databaseUpgradeDictionary setObject:allLocalRadioConfigRecords forKey:@"local_radio_config"];
        }
    }
    
    return databaseUpgradeDictionary;
}

//==================================================================================
//    getDatabaseV4Data
//==================================================================================

- (NSMutableDictionary *)getDatabaseV4Data
{
    // If current version database is missing, attempt to access a V2 database and copy the data for deferred import.
    NSMutableDictionary * databaseUpgradeDictionary = [NSMutableDictionary dictionary];

    NSString * applicationSupportDirectoryPath = [[NSFileManager defaultManager] applicationSupportDirectory];
    NSString * databaseV4PathString = [applicationSupportDirectoryPath stringByAppendingPathComponent:@"LocalRadio-V4.sqlite3"];
    BOOL localRadioV4Found = [[NSFileManager defaultManager] fileExistsAtPath:databaseV4PathString];
    
    if (localRadioV4Found == YES)
    {
        [SQLiteLibrary setDatabaseFile:databaseV4PathString];
        [SQLiteLibrary setupDatabaseAndForceReset:NO];
        BOOL sqliteIsRunning = [SQLiteLibrary begin];
        #pragma unused(sqliteIsRunning)

        // Add "bias_t_flag" and "usb_device_string" columns to frequency table

        //NSArray * oldAllFrequencyRecords = [self allFrequencyRecords];
        NSString * allFrequenciesQueryString = @"SELECT id, station_name, frequency_mode, frequency, frequency_scan_end, frequency_scan_interval, tuner_gain, tuner_agc, sampling_mode, sample_rate, oversampling, modulation, squelch_level, options, fir_size, atan_math, audio_output_filter, stereo_flag FROM frequency ORDER BY frequency;";
        NSArray * oldAllFrequencyRecords = [SQLiteLibrary performQueryAndGetResultList:allFrequenciesQueryString];

        NSMutableArray * allFrequencyRecords = [NSMutableArray array];
        for (NSDictionary * frequencyDictionary in oldAllFrequencyRecords)
        {
            NSMutableDictionary * mutableFrequencyDictionary = [frequencyDictionary mutableCopy];
            [mutableFrequencyDictionary setObject:[NSNumber numberWithBool:NO] forKey:@"bias_t_flag"];
            [mutableFrequencyDictionary setObject:@"0" forKey:@"usb_device_string"];
            [allFrequencyRecords addObject:mutableFrequencyDictionary];
        }

        // Add "scan_bias_t_flag" and "scan_usb_device_string" columns to category table
        
        //NSArray * oldAllCategoryRecords = [self allCategoryRecords];
        NSString * allCategoriesQueryString = @"SELECT id, category_name, category_scanning_enabled, scan_tuner_gain, scan_tuner_agc, scan_sampling_mode, scan_sample_rate, scan_oversampling, scan_modulation, scan_squelch_level, scan_squelch_delay, scan_options, scan_fir_size, scan_atan_math, scan_audio_output_filter FROM category ORDER BY category_name;";
        NSArray * oldAllCategoryRecords = [SQLiteLibrary performQueryAndGetResultList:allCategoriesQueryString];

        NSMutableArray * allCategoryRecords = [NSMutableArray array];
        for (NSDictionary * categoryDictionary in oldAllCategoryRecords)
        {
            NSMutableDictionary * mutableCategoryDictionary = [categoryDictionary mutableCopy];
            [mutableCategoryDictionary setObject:[NSNumber numberWithBool:NO] forKey:@"scan_bias_t_flag"];
            [mutableCategoryDictionary setObject:@"0"  forKey:@"scan_usb_device_string"];
            [allCategoryRecords addObject:mutableCategoryDictionary];
        }
        
        NSArray * allFreqCatRecords = [self allFreqCatRecords];         // no changes to this table
        NSArray * allCustomTaskRecords = [self allCustomTaskRecords];   // no changes to this table
        
        NSMutableArray * allLocalRadioConfigRecords = [[self allLocalRadioConfigRecords] mutableCopy];
        
        [self setConfigRecordInArray:allLocalRadioConfigRecords integer:5 forKey:@"LocalRadioConfigVersion"];

        if (allFrequencyRecords != NULL)
        {
            [databaseUpgradeDictionary setObject:allFrequencyRecords forKey:@"frequency"];
        }
        
        if (allCategoryRecords != NULL)
        {
            [databaseUpgradeDictionary setObject:allCategoryRecords forKey:@"category"];
        }
        
        if (allFreqCatRecords != NULL)
        {
            [databaseUpgradeDictionary setObject:allFreqCatRecords forKey:@"freq_cat"];
        }
        
        if (allCustomTaskRecords != NULL)
        {
            [databaseUpgradeDictionary setObject:allCustomTaskRecords forKey:@"custom_task"];
        }
        
        if (allLocalRadioConfigRecords != NULL)
        {
            [databaseUpgradeDictionary setObject:allLocalRadioConfigRecords forKey:@"local_radio_config"];
        }
    }
    
    return databaseUpgradeDictionary;
}

//==================================================================================
//    localRadioAppSettingsValueForKey:
//==================================================================================

- (id)localRadioAppSettingsValueForKey:(NSString *)aKey
{
    // This retrieves from the app's general-purpose key-store database for the settings and preferences
    id resultObject = NULL;
    
    if (self.sqliteIsRunning == NO)
    {
        [self startSQLiteConnection];
    }
    
    NSString * queryString = [NSString stringWithFormat:@"SELECT id, config_key, config_value FROM local_radio_config WHERE config_key='%@';", aKey];
    
    NSArray * queryResultArray = [SQLiteLibrary performQueryAndGetResultList:queryString];
    
    if (queryResultArray.count > 0)
    {
        NSDictionary * resultDictionary = queryResultArray.firstObject;
        resultObject = [resultDictionary objectForKey:@"config_value"];
    }
    
    return resultObject;
}

//==================================================================================
//	storeLocalRadioAppSettingsValueForKey:
//==================================================================================

- (void)storeLocalRadioAppSettingsValue:(id)aValue ForKey:(NSString *)aKey
{
    // This stores to the app's general-purpose key-store database for the settings and preferences

    id existingValue = [self localRadioAppSettingsValueForKey:aKey];

    int64_t queryResult = 0;
    
    if (existingValue != NULL)
    {
        // update existing record
        
        NSString * updateString = [NSString stringWithFormat:@"UPDATE local_radio_config SET config_value='%@' WHERE config_key='%@'",
                aValue, aKey];

        BOOL beginResult = [SQLiteLibrary begin];
        
        queryResult = [SQLiteLibrary performQuery:updateString block:nil];

        BOOL commitResult = [SQLiteLibrary commit];
    }
    else
    {
        // insert new record

        BOOL beginResult = [SQLiteLibrary begin];

        NSString * insertString = [NSString stringWithFormat:@"INSERT INTO local_radio_config (config_key, config_value) VALUES('%@', '%@')",
                aKey, aValue];

        queryResult = [SQLiteLibrary performQuery:insertString block:nil];

        BOOL commitResult = [SQLiteLibrary commit];
    }
}

//==================================================================================
//	frequencyRecordForID:
//==================================================================================

- (NSDictionary *)frequencyRecordForID:(NSString *)frequencyIDString
{
    NSDictionary * resultDictionary = NULL;

    NSInteger frequencyID = [frequencyIDString integerValue];

    NSString * queryString = [NSString stringWithFormat:@"SELECT id, station_name, frequency_mode, frequency, frequency_scan_end, frequency_scan_interval, tuner_gain, tuner_agc, sampling_mode, sample_rate, oversampling, modulation, squelch_level, options, fir_size, atan_math, audio_output_filter, stereo_flag, usb_device_string, bias_t_flag FROM frequency WHERE id='%ld';", frequencyID];
    
    //NSLog(@"frequencyRecordForID queryString = %@", queryString);
    
    NSArray * queryResultArray = [SQLiteLibrary performQueryAndGetResultList:queryString];

    //NSLog(@"frequencyRecordForID queryResultArray.count=%ld", queryResultArray.count);;
    
    if (queryResultArray.count > 0)
    {
        resultDictionary = queryResultArray.firstObject;
    }
    
    return resultDictionary;
}

//==================================================================================
//	frequencyRecordForFrequency:
//==================================================================================

- (NSDictionary *)frequencyRecordForFrequency:(NSString *)frequencyString
{
    NSDictionary * resultDictionary = NULL;
    
    NSInteger frequency = [frequencyString integerValue];

    NSString * queryString = [NSString stringWithFormat:@"SELECT id, station_name, frequency_mode, frequency, frequency_scan_end, frequency_scan_interval, tuner_gain, tuner_agc, sampling_mode, sample_rate, oversampling, modulation, squelch_level, options, fir_size, atan_math, audio_output_filter, stereo_flag, usb_device_string, bias_t_flag FROM frequency WHERE frequency='%ld';", frequency];
    
    //NSLog(@"frequencyRecordForID queryString = %@", queryString);
    
    NSArray * queryResultArray = [SQLiteLibrary performQueryAndGetResultList:queryString];

    //NSLog(@"frequencyRecordForID queryResultArray.count=%ld", queryResultArray.count);;
    
    if (queryResultArray.count > 0)
    {
        resultDictionary = queryResultArray.firstObject;
    }
    
    return resultDictionary;
}


//==================================================================================
//	allFrequencyRecords
//==================================================================================

- (NSArray *)allFrequencyRecords
{
    NSString * queryString = @"SELECT id, station_name, frequency_mode, frequency, frequency_scan_end, frequency_scan_interval, tuner_gain, tuner_agc, sampling_mode, sample_rate, oversampling, modulation, squelch_level, options, fir_size, atan_math, audio_output_filter, stereo_flag, usb_device_string, bias_t_flag FROM frequency ORDER BY frequency;";
    NSArray * queryResultArray = [SQLiteLibrary performQueryAndGetResultList:queryString];

    return queryResultArray;
}

//==================================================================================
//	allFrequencyRecordsForCategoryID:
//==================================================================================

- (NSArray *)allFrequencyRecordsForCategoryID:(NSString *)categoryIDString
{
    NSInteger categoryID = [categoryIDString integerValue];
    
    NSMutableArray * resultArray = [NSMutableArray array];

    NSString * freqCatQueryString = [NSString stringWithFormat:@"SELECT id, freq_id, cat_id FROM freq_cat WHERE cat_id=%ld;", categoryID];

    NSArray * freqCatQueryResultArray = [SQLiteLibrary performQueryAndGetResultList:freqCatQueryString];

    for (NSDictionary * freqCatDictionary in freqCatQueryResultArray)
    {
        //NSNumber * freqCatIDNumber = [freqCatDictionary objectForKey:@"id"];
        //NSString * freqCatIDString = [freqCatIDNumber stringValue];
        
        NSNumber * freqIDNumber = [freqCatDictionary objectForKey:@"freq_id"];
        //NSString * freqIDString = [freqIDNumber stringValue];

        //NSNumber * catIDNumber = [freqCatDictionary objectForKey:@"cat_id"];
        //NSString * catIDString = [catIDNumber stringValue];

        NSString * freqQueryString = [NSString stringWithFormat:@"SELECT id, station_name, frequency_mode, frequency, frequency_scan_end, frequency_scan_interval, tuner_gain, tuner_agc, sampling_mode, sample_rate, oversampling, modulation, squelch_level, options, fir_size, atan_math, audio_output_filter, stereo_flag, usb_device_string, bias_t_flag FROM frequency WHERE id='%@';", freqIDNumber];
        NSArray * frequencyResultArray = [SQLiteLibrary performQueryAndGetResultList:freqQueryString];
        if (frequencyResultArray.count > 0)
        {
            [resultArray addObject:frequencyResultArray.firstObject];
        }
    }

    NSArray * sortedResultArray = [resultArray sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
        NSNumber * first = [(NSDictionary *)a objectForKey:@"frequency"];
        NSNumber * second = [(NSDictionary *)b objectForKey:@"frequency"];
        return [first compare:second];
    }];
    
    resultArray = sortedResultArray.mutableCopy;

    return resultArray;
}

//==================================================================================
//    allCategoryRecords
//==================================================================================

- (NSArray *)allCategoryRecords
{
    NSString * queryString = @"SELECT id, category_name, category_scanning_enabled, scan_tuner_gain, scan_tuner_agc, scan_sampling_mode, scan_sample_rate, scan_oversampling, scan_modulation, scan_squelch_level, scan_squelch_delay, scan_options, scan_fir_size, scan_atan_math, scan_audio_output_filter, scan_bias_t_flag, scan_usb_device_string FROM category ORDER BY category_name;";
    
    NSArray * queryResultArray = [SQLiteLibrary performQueryAndGetResultList:queryString];

    return queryResultArray;
}

//==================================================================================
//	categoryRecordForID:
//==================================================================================

- (NSDictionary *)categoryRecordForID:(NSString *)categoryIDString
{
    NSInteger categoryID = [categoryIDString integerValue];
    
    NSString * queryString = [NSString stringWithFormat:@"SELECT id, category_name, category_scanning_enabled, scan_tuner_gain, scan_tuner_agc, scan_sample_rate, scan_oversampling, scan_sampling_mode, scan_modulation, scan_squelch_level, scan_squelch_delay, scan_options, scan_fir_size, scan_atan_math, scan_audio_output_filter, scan_bias_t_flag, scan_usb_device_string FROM category WHERE id='%ld' LIMIT 1;", categoryID];
    NSArray * queryResultArray = [SQLiteLibrary performQueryAndGetResultList:queryString];
    
    NSDictionary * categoryDictionary = queryResultArray.firstObject;
    
    return categoryDictionary;
}

//==================================================================================
//	categoryRecordForName:
//==================================================================================

- (NSDictionary *)categoryRecordForName:(NSString *)categoryNameString
{
    NSString * queryString = [NSString stringWithFormat:@"SELECT id, category_name, category_scanning_enabled, scan_tuner_gain, scan_tuner_agc, scan_sampling_mode, scan_sample_rate, scan_oversampling, scan_modulation, scan_squelch_level, scan_squelch_delay, scan_options, scan_fir_size, scan_atan_math, scan_audio_output_filter, scan_bias_t_flag, scan_usb_device_string FROM category WHERE category_name='%@' LIMIT 1;", categoryNameString];
    NSArray * queryResultArray = [SQLiteLibrary performQueryAndGetResultList:queryString];
    
    NSDictionary * categoryDictionary = queryResultArray.firstObject;
    
    return categoryDictionary;
}

//==================================================================================
//    allFreqCatRecords
//==================================================================================

- (NSArray *)allFreqCatRecords
{
    NSString * queryString = @"SELECT id, freq_id, cat_id FROM freq_cat ORDER BY id;";
    
    NSArray * queryResultArray = [SQLiteLibrary performQueryAndGetResultList:queryString];

    return queryResultArray;
}

//==================================================================================
//    sortedFreqCatRecordsWithCategoriesArray:frequenciesArray:
//==================================================================================

- (NSArray *)sortedFreqCatRecordsWithCategoriesArray:(NSArray *)categoriesArray frequenciesArray:(NSArray *) frequenciesArray
{
    NSString * queryString = @"SELECT id, freq_id, cat_id FROM freq_cat ORDER BY id;";
    
    NSArray * freqCatResultArray = [SQLiteLibrary performQueryAndGetResultList:queryString];
    
    NSMutableDictionary * freqCatSortDictionary = [NSMutableDictionary dictionary];
    for (NSDictionary * freqCatDictionary in freqCatResultArray)
    {
        NSNumber * catIDNumber = [freqCatDictionary objectForKey:@"cat_id"];
        NSNumber * freqIDNumber = [freqCatDictionary objectForKey:@"freq_id"];
        NSString * catFreqKey = [NSString stringWithFormat:@"%@:%@", catIDNumber, freqIDNumber];
        [freqCatSortDictionary setObject:freqCatDictionary forKey:catFreqKey];
    }
    
    NSMutableArray * queryResultArray = [NSMutableArray array];
    
    for (NSDictionary * categoryDictionary in categoriesArray)
    {
        NSNumber * catIDNumber = [categoryDictionary objectForKey:@"id"];
        for (NSDictionary * frequencyDictionary in frequenciesArray)
        {
            NSNumber * freqIDNumber = [frequencyDictionary objectForKey:@"id"];
            
            NSString * catFreqKey = [NSString stringWithFormat:@"%@:%@", catIDNumber, freqIDNumber];
            
            NSDictionary * matchFreqCatDictionary = [freqCatSortDictionary objectForKey:catFreqKey];
            if (matchFreqCatDictionary != NULL)
            {
                [queryResultArray addObject:matchFreqCatDictionary];
            }
        }
    }

    return queryResultArray;
}

//==================================================================================
//	freqCatRecordsForCategoryID:
//==================================================================================

- (NSArray *)freqCatRecordsForCategoryID:(NSString *)categoryIDString
{
    NSInteger categoryID = [categoryIDString integerValue];

    NSString * freqCatQueryString = [NSString stringWithFormat:@"SELECT id, freq_id, cat_id FROM freq_cat WHERE cat_id='%ld';", categoryID];
    NSArray * freqCatQueryResultArray = [SQLiteLibrary performQueryAndGetResultList:freqCatQueryString];

    return freqCatQueryResultArray;
}

//==================================================================================
//	freqCatRecordForFrequencyID:categoryID:
//==================================================================================

- (NSDictionary *)freqCatRecordForFrequencyID:(NSInteger)frequencyID categoryID:(NSInteger)categoryID
{
    NSDictionary * result = NULL;
    
    NSString * freqCatQueryString = [NSString stringWithFormat:@"SELECT id, freq_id, cat_id FROM freq_cat WHERE cat_id='%ld' AND freq_id='%ld';", categoryID, frequencyID];
    NSArray * freqCatQueryResultArray = [SQLiteLibrary performQueryAndGetResultList:freqCatQueryString];
    
    if (freqCatQueryResultArray.count > 0)
    {
        result = freqCatQueryResultArray.firstObject;
    }
    
    return result;
}

//==================================================================================
//	freqCatRecordExistsForFrequencyID:categoryID:
//==================================================================================

- (BOOL)freqCatRecordExistsForFrequencyID:(NSInteger)frequencyID categoryID:(NSInteger)categoryID
{
    BOOL result = NO;
    
    NSString * freqCatQueryString = [NSString stringWithFormat:@"SELECT id, freq_id, cat_id FROM freq_cat WHERE freq_id='%ld' AND cat_id='%ld';", frequencyID, categoryID];
    NSArray * freqCatQueryResultArray = [SQLiteLibrary performQueryAndGetResultList:freqCatQueryString];
    
    if (freqCatQueryResultArray.count > 0)
    {
        result = YES;
    }
    
    return result;
}

//==================================================================================
//	insertFreqCatRecordForFrequencyID:categoryID:
//==================================================================================

- (void)insertFreqCatRecordForFrequencyID:(NSInteger)frequencyID categoryID:(NSInteger)categoryID
{
    NSString * freqCatInsertQueryString = [NSString stringWithFormat:@"INSERT INTO freq_cat (freq_id, cat_id) VALUES ('%ld', '%ld');", frequencyID, categoryID];
    
    //NSArray * freqCatInsertQueryResultArray = [SQLiteLibrary performQueryAndGetResultList:freqCatInsertQueryString];
    
    NSNumber * freqIDNumber = [NSNumber numberWithInteger:frequencyID];
    NSNumber * catIDNumber = [NSNumber numberWithInteger:categoryID];
    
    NSDictionary * freqCatDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
            freqIDNumber, @"freq_id",
            catIDNumber, @"cat_id",
            NULL];
    
    BOOL beginResult = [SQLiteLibrary begin];
    int64_t result = [SQLiteLibrary performInsertQueryInTable:@"freq_cat" data:freqCatDictionary];
    BOOL commitResult = [SQLiteLibrary commit];

    //NSLog(@"insertFreqCatRecordForFrequencyID:categoryID: %@", freqCatInsertQueryResultArray);
}

//==================================================================================
//	deleteFreqCatRecordForFrequencyID:categoryID:
//==================================================================================

- (void)deleteFreqCatRecordForFrequencyID:(NSInteger)frequencyID categoryID:(NSInteger)categoryID
{
    NSString * freqCatDeleteQueryString = [NSString stringWithFormat:@"DELETE FROM freq_cat WHERE freq_id='%ld' AND cat_id='%ld';", frequencyID, categoryID];
    
    BOOL beginResult = [SQLiteLibrary begin];
    NSArray * freqCatDeleteQueryResultArray = [SQLiteLibrary performQueryAndGetResultList:freqCatDeleteQueryString];
    NSLog(@"editCategory freqCatDeleteQueryString %@", freqCatDeleteQueryResultArray);
    BOOL commitResult = [SQLiteLibrary commit];
}








//==================================================================================
//    allCustomTaskRecords
//==================================================================================

- (NSArray *)allCustomTaskRecords
{
    NSString * queryString = @"SELECT id, task_name, task_json, sample_rate, channels, input_buffer_size, audioconverter_buffer_size, audioqueue_buffer_size FROM custom_task ORDER BY id;";
    
    NSArray * queryResultArray = [SQLiteLibrary performQueryAndGetResultList:queryString];

    return queryResultArray;
}


//==================================================================================
//    allLocalRadioConfigRecords
//==================================================================================

- (NSArray *)allLocalRadioConfigRecords
{
    NSString * queryString = @"SELECT id, config_key, config_value FROM local_radio_config ORDER BY id;";

    NSArray * queryResultArray = [SQLiteLibrary performQueryAndGetResultList:queryString];

    return queryResultArray;
}

//==================================================================================
//    customTaskForID:
//==================================================================================

- (NSDictionary *)customTaskForID:(NSString *)customTaskIDString
{
    NSInteger customTaskID = [customTaskIDString integerValue];

    NSString * customTaskQueryString = [NSString stringWithFormat:@"SELECT id, task_name, task_json, sample_rate, channels, input_buffer_size, audioconverter_buffer_size, audioqueue_buffer_size FROM custom_task WHERE id='%ld';", customTaskID];
    NSArray * customTaskQueryResultArray = [SQLiteLibrary performQueryAndGetResultList:customTaskQueryString];
    
    NSDictionary * customTaskQueryResult = customTaskQueryResultArray.firstObject;

    return customTaskQueryResult;
}

//==================================================================================
//    insertCustomTaskRecord:json:sampleRate:channels:
//==================================================================================

- (void)insertCustomTaskRecord:(NSString *)customTaskName json:(NSString *)customTaskJSON sampleRate:(NSInteger)sampleRate channels:(NSInteger)channels inputBufferSize:(NSInteger)inputBufferSize audioConverterBufferSize:(NSInteger)audioConverterBufferSize audioQueueBufferSize:(NSInteger)audioQueueBufferSize
{
    //NSString * customTaskInsertQueryString = [NSString stringWithFormat:@"INSERT INTO custom_task (task_name, task_json) VALUES ('%@', '%@');", customTaskName, customTaskJSON];
    
    //NSArray * customTaskInsertQueryResultArray = [SQLiteLibrary performQueryAndGetResultList:customTaskInsertQueryString];
    
    NSNumber * sampleRateNumber = [NSNumber numberWithInteger:sampleRate];
    NSNumber * channelsNumber = [NSNumber numberWithInteger:channels];
    NSNumber * inputBufferSizeNumber = [NSNumber numberWithInteger:inputBufferSize];
    NSNumber * audioConverterBufferSizeNumber = [NSNumber numberWithInteger:audioConverterBufferSize];
    NSNumber * audioQueueBufferSizeNumber = [NSNumber numberWithInteger:audioQueueBufferSize];

    NSDictionary * customTaskDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
            customTaskName, @"task_name",
            customTaskJSON, @"task_json",
            sampleRateNumber, @"sample_rate",
            channelsNumber, @"channels",
            inputBufferSizeNumber, @"input_buffer_size",
            audioConverterBufferSizeNumber, @"audioconverter_buffer_size",
            audioQueueBufferSizeNumber, @"audioqueue_buffer_size",
            NULL];
    
    BOOL beginResult = [SQLiteLibrary begin];
    int64_t result = [SQLiteLibrary performInsertQueryInTable:@"custom_task" data:customTaskDictionary];
    BOOL commitResult = [SQLiteLibrary commit];

    //NSLog(@"insertCustomTaskRecord: %@", customTaskInsertQueryString);
}

//==================================================================================
//    updateCustomTaskRecordForID:name:json:sampleRate:channels:
//==================================================================================

- (void)updateCustomTaskRecordForID:(NSString *)customTaskID name:(NSString *)customTaskName json:(NSString *)customTaskJSON sampleRate:(NSInteger)sampleRate channels:(NSInteger)channels inputBufferSize:(NSInteger)inputBufferSize audioConverterBufferSize:(NSInteger)audioConverterBufferSize audioQueueBufferSize:(NSInteger)audioQueueBufferSize
{
    NSString * updateQueryString = [NSString stringWithFormat:@"UPDATE custom_task SET task_name='%@', task_json='%@', sample_rate='%ld', channels='%ld', input_buffer_size='%ld', audioconverter_buffer_size='%ld', audioqueue_buffer_size='%ld' WHERE id=%@",
            customTaskName, customTaskJSON, sampleRate, channels, inputBufferSize, audioConverterBufferSize, audioQueueBufferSize, customTaskID];

    BOOL beginResult = [SQLiteLibrary begin];

    int64_t queryResult = [SQLiteLibrary performQuery:updateQueryString block:nil];

    BOOL commitResult = [SQLiteLibrary commit];

    NSLog(@"updated custom task record: %@", updateQueryString);
}




//==================================================================================
//    deleteCustomTaskRecordForID:
//==================================================================================

- (void)deleteCustomTaskRecordForID:(NSString *)customTaskIDString;
{
    NSString * customTaskDeleteQueryString = [NSString stringWithFormat:@"DELETE FROM custom_task WHERE id='%@';", customTaskIDString];
    
    BOOL beginResult = [SQLiteLibrary begin];
    NSArray * customTaskDeleteQueryResultArray = [SQLiteLibrary performQueryAndGetResultList:customTaskDeleteQueryString];
    BOOL commitResult = [SQLiteLibrary commit];

    //NSLog(@"deleteCustomTaskRecordForID %@", customTaskDeleteQueryResultArray);
}


//==================================================================================
//	storeRecord:table:
//==================================================================================

- (int64_t)storeRecord:(NSDictionary *)recordDictionary table:(NSString *)tableName
{
    NSString * idString = [recordDictionary objectForKey:@"id"];
    NSInteger idInteger = idString.integerValue;
    
    int64_t queryResult = 0;
    
    if (idInteger > 0)
    {
        // update existing record
        
        NSMutableString * valuesString = [NSMutableString string];
        
        NSArray * allRecordKeys = [recordDictionary allKeys];
        
        for (NSString * aRecordKey in allRecordKeys)
        {
            if ([aRecordKey isEqualToString:@"id"] == NO)
            {
                id valueObject = [recordDictionary objectForKey:aRecordKey];
                
                if (valuesString.length > 0)
                {
                    [valuesString appendString:@","];
                }
                
                [valuesString appendFormat:@"%@=\"%@\"", aRecordKey, valueObject];
            }
        }

        NSString * updateString = [NSString stringWithFormat:@"UPDATE %@ SET %@ WHERE id=%ld",
                tableName, valuesString, idInteger];

        BOOL beginResult = [SQLiteLibrary begin];
        
        queryResult = [SQLiteLibrary performQuery:updateString block:nil];

        BOOL commitResult = [SQLiteLibrary commit];
    }
    else
    {
        // insert new record

        NSMutableString * columnsString = [NSMutableString string];
        NSMutableString * valuesString = [NSMutableString string];

        NSArray * allRecordKeys = [recordDictionary allKeys];
        
        for (NSString * aRecordKey in allRecordKeys)
        {
            if ([aRecordKey isEqualToString:@"id"] == NO)
            {
                id valueObject = [recordDictionary objectForKey:aRecordKey];
                
                if (columnsString.length > 0)
                {
                    [columnsString appendString:@","];
                }
                [columnsString appendString:aRecordKey];
                
                if (valuesString.length > 0)
                {
                    [valuesString appendString:@","];
                }
                [valuesString appendFormat:@"\"%@\"", valueObject];
            }
        }

        BOOL beginResult = [SQLiteLibrary begin];

        NSString * insertString = [NSString stringWithFormat:@"INSERT INTO %@ (%@) VALUES(%@)",
                tableName, columnsString, valuesString];

        queryResult = [SQLiteLibrary performQuery:insertString block:nil];

        BOOL commitResult = [SQLiteLibrary commit];
    }
    
    return queryResult;
}

//==================================================================================
//    importRecord:table:
//==================================================================================

- (NSArray *)importRecord:(NSDictionary *)recordDictionary table:(NSString *)tableName tableInfoArray:(NSArray *)tableInfoArray
{
    NSArray * currentTableInfoArray = tableInfoArray;

    NSString * idString = [recordDictionary objectForKey:@"id"];
    NSInteger idInteger = idString.integerValue;
    
    int64_t queryResult = 0;
    
    if (idInteger > 0)
    {
        // check for existing record
        NSString * existingQueryString = [NSString stringWithFormat:@"SELECT id FROM %@ WHERE id='%ld' LIMIT 1;", tableName, idInteger];
        NSArray * existingQueryResultArray = [SQLiteLibrary performQueryAndGetResultList:existingQueryString];
        
        if (existingQueryResultArray.count == 0)
        {
            // insert new record
            
            NSMutableString * columnsString = [NSMutableString string];
            NSMutableString * valuesString = [NSMutableString string];

            NSArray * allRecordKeys = [recordDictionary allKeys];
            
            for (NSString * aRecordKey in allRecordKeys)
            {
                id valueObject = [recordDictionary objectForKey:aRecordKey];

                NSString * valueKind = @"STRING";
                NSString * defaultValue = @"";
                if ([valueObject isKindOfClass:[NSString class]] == YES)
                {
                    valueKind = @"STRING";
                    defaultValue = @"''";
                }
                else if ([valueObject isKindOfClass:[NSNumber class]] == YES)
                {
                    valueKind = @"INTEGER";
                    defaultValue = @"0";
                }
                else
                {
                    valueKind = @"STRING";
                    defaultValue = @"''";
                }

                // if column does not exist, create it
                BOOL columnFound = NO;
                for (NSDictionary * columnDictionary in currentTableInfoArray)
                {
                    NSString * existingColumnName = [columnDictionary objectForKey:@"name"];
                    if ([aRecordKey isEqualToString:existingColumnName] == YES)
                    {
                        columnFound = YES;
                        break;
                    }
                }
                
                if (columnFound == NO)
                {
                    NSLog(@"SQLiteController - importRecord:table:tableInfoArray add column: %@", aRecordKey);
                    NSString * addColumnString = [NSString stringWithFormat:@"ALTER TABLE '%@' ADD COLUMN '%@' %@ NOT NULL DEFAULT(%@)", tableName, aRecordKey, valueKind, defaultValue];
                    queryResult = [SQLiteLibrary performQuery:addColumnString block:nil];

                    BOOL commitResult = [SQLiteLibrary commit];
                    
                    currentTableInfoArray = [self getTableInfo:tableName];
                }
            
                
                if (columnsString.length > 0)
                {
                    [columnsString appendString:@","];
                }
                [columnsString appendString:aRecordKey];
                
                if (valuesString.length > 0)
                {
                    [valuesString appendString:@","];
                }
                [valuesString appendFormat:@"'%@'", valueObject];
            }

            BOOL beginResult = [SQLiteLibrary begin];

            NSString * insertString = [NSString stringWithFormat:@"INSERT INTO %@ (%@) VALUES(%@)",
                    tableName, columnsString, valuesString];

            queryResult = [SQLiteLibrary performQuery:insertString block:nil];

            BOOL commitResult = [SQLiteLibrary commit];
        }
        else
        {
            // update existing record
            
            NSMutableString * valuesString = [NSMutableString string];
            
            NSArray * allRecordKeys = [recordDictionary allKeys];
            
            for (NSString * aRecordKey in allRecordKeys)
            {
                if ([aRecordKey isEqualToString:@"id"] == NO)
                {
                    id valueObject = [recordDictionary objectForKey:aRecordKey];
                    
                    if (valuesString.length > 0)
                    {
                        [valuesString appendString:@","];
                    }
                    
                    [valuesString appendFormat:@"%@=\"%@\"", aRecordKey, valueObject];
                }
            }

            NSString * updateString = [NSString stringWithFormat:@"UPDATE %@ SET %@ WHERE id=%ld",
                    tableName, valuesString, idInteger];

            BOOL beginResult = [SQLiteLibrary begin];
            
            queryResult = [SQLiteLibrary performQuery:updateString block:nil];

            BOOL commitResult = [SQLiteLibrary commit];
        }
    }
    
    return currentTableInfoArray;   // return tableInfoArray to caller, modified if columns added
}

//==================================================================================
//	lastInsertID
//==================================================================================

- (NSInteger)lastInsertID
{
    NSInteger lastInsertID = -1;
    NSString * lastInsertIDString = @"SELECT last_insert_rowid();";
    NSArray * lastInsertIDArray = [SQLiteLibrary performQueryAndGetResultList:lastInsertIDString];
    
    if (lastInsertIDArray.count == 1)
    {
        NSDictionary * lastInsertIDDictionary = [lastInsertIDArray firstObject];
        NSNumber * lastInsertIDNumber = [lastInsertIDDictionary objectForKey:@"last_insert_rowid()"];
        if (lastInsertIDNumber != NULL)
        {
            lastInsertID = [lastInsertIDNumber integerValue];
        }
    }
    
    return lastInsertID;
}

//==================================================================================
//	getTableInfo:
//==================================================================================

- (NSArray *)getTableInfo:(NSString *)tableName
{
    NSString * tableInfoQueryString = [NSString stringWithFormat:@"PRAGMA table_info(%@);", tableName];
    NSArray * tableInfoArray = [SQLiteLibrary performQueryAndGetResultList:tableInfoQueryString];

    return tableInfoArray;
}

//==================================================================================
//	makePrototypeDictionaryForTable:
//==================================================================================

- (NSMutableDictionary *)makePrototypeDictionaryForTable:(NSString *)tableName
{
    NSMutableDictionary * resultDictionary = [NSMutableDictionary dictionary];

    NSArray * tableInfoArray = [self getTableInfo:tableName];
    
    NSCharacterSet * singleQuoteCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"'"];
    
    for (NSDictionary * columnDictionary in tableInfoArray)
    {
        NSString * columnName = [columnDictionary objectForKey:@"name"];
        NSString * columnType = [columnDictionary objectForKey:@"type"];
        NSString * columnDefault = [columnDictionary objectForKey:@"dflt_value"];
        //NSString * columnNotNull = [columnDictionary objectForKey:@"notnull"];
        //NSString * columnPrimaryKey = [columnDictionary objectForKey:@"pk"];
        
        id newValue = columnDefault;
        
        if ([columnType isEqualToString:@"INTEGER"] == YES)
        {
            NSInteger defaultInteger = [columnDefault integerValue];
            newValue = [NSNumber numberWithInteger:defaultInteger];
        }
        else if ([columnType isEqualToString:@"DOUBLE"] == YES)
        {
            double defaultDouble = [columnDefault doubleValue];
            newValue = [NSNumber numberWithDouble:defaultDouble];
        }
        else if ([columnType isEqualToString:@"VARCHAR"] == YES)
        {
            NSString * trimmedValue = [columnDefault stringByTrimmingCharactersInSet:singleQuoteCharacterSet];
            newValue = trimmedValue;
        }
        else if ([columnType isEqualToString:@"BOOLEAN"] == YES)
        {
            NSInteger defaultInteger = [columnDefault integerValue];
            newValue = [NSNumber numberWithInteger:defaultInteger];
        }
        else if ([columnType isEqualToString:@"STRING"] == YES)
        {
            newValue = columnDefault;
        }
        else
        {
            NSLog(@"SQLiteController - makePrototypeDictionaryForTable - using unknown type for table %@ column %@ type %@", tableName, columnName, columnType);
        }
        
        [resultDictionary setObject:newValue forKey:columnName];
    }
    
    return resultDictionary;
}

//==================================================================================
//	deleteFrequencyRecordForID:
//==================================================================================

- (void)deleteFrequencyRecordForID:(NSString *)frequencyIDString
{
    NSInteger frequencyID = [frequencyIDString integerValue];

    NSString * freqCatDeleteQueryString = [NSString stringWithFormat:@"DELETE FROM freq_cat WHERE freq_id='%ld';", frequencyID];
    NSString * freqDeleteQueryString = [NSString stringWithFormat:@"DELETE FROM frequency WHERE id='%ld';", frequencyID];
    
    BOOL beginResult = [SQLiteLibrary begin];
    
    NSArray * freqCatDeleteQueryResultArray = [SQLiteLibrary performQueryAndGetResultList:freqCatDeleteQueryString];
    NSLog(@"SQLiteController - deleteFreqCatRecordForID %@", freqCatDeleteQueryResultArray);
    
    NSArray * freqDeleteQueryResultArray = [SQLiteLibrary performQueryAndGetResultList:freqDeleteQueryString];
    NSLog(@"SQLiteController - deleteFrequencyRecordForID %@", freqDeleteQueryResultArray);
    
    BOOL commitResult = [SQLiteLibrary commit];
}

//==================================================================================
//	deleteCategoryRecordForID:
//==================================================================================

- (void)deleteCategoryRecordForID:(NSString *)categoryIDString
{
    NSInteger categoryID = [categoryIDString integerValue];

    NSString * freqCatDeleteQueryString = [NSString stringWithFormat:@"DELETE FROM freq_cat WHERE cat_id='%ld';", categoryID];
    NSString * categoryDeleteQueryString = [NSString stringWithFormat:@"DELETE FROM category WHERE id='%ld';", categoryID];
    
    BOOL beginResult = [SQLiteLibrary begin];
    
    NSArray * freqCatDeleteQueryResultArray = [SQLiteLibrary performQueryAndGetResultList:freqCatDeleteQueryString];
    NSLog(@"SQLiteController - deleteFreqCatRecordForID %@", freqCatDeleteQueryResultArray);
    
    NSArray * categoryDeleteQueryResultArray = [SQLiteLibrary performQueryAndGetResultList:categoryDeleteQueryString];
    NSLog(@"SQLiteController - deleteCategoryRecordForID %@", categoryDeleteQueryResultArray);
    
    BOOL commitResult = [SQLiteLibrary commit];
}

//==================================================================================
//    emptyTable:
//==================================================================================

- (void)emptyTable:(NSString *)tableName
{
    BOOL beginResult = [SQLiteLibrary begin];
    
    NSString * emptyQueryString = [NSString stringWithFormat:@"DELETE FROM %@;", tableName];
    NSArray * emptyQueryResultArray = [SQLiteLibrary performQueryAndGetResultList:emptyQueryString];
    NSLog(@"SQLiteController - emptyQueryResultArray %@", emptyQueryResultArray);

    NSString * resetQueryString = [NSString stringWithFormat:@"UPDATE SQLITE_SEQUENCE SET SEQ=0 WHERE NAME='%@'", tableName];
    NSArray * resetQueryResultArray = [SQLiteLibrary performQueryAndGetResultList:resetQueryString];
    NSLog(@"SQLiteController - resetQueryResultArray %@", resetQueryResultArray);

    BOOL commitResult = [SQLiteLibrary commit];
}



@end

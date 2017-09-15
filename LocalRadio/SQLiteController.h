//
//  SQLiteController.h
//  LocalRadio
//
//  Created by Douglas Ward on 6/18/17.
//  Copyright © 2017 ArkPhone LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SQLiteController : NSObject

@property (assign) BOOL sqliteIsRunning;

- (void)startSQLiteConnection;

- (id)localRadioAppSettingsValueForKey:(NSString *)aKey;
- (void)storeLocalRadioAppSettingsValue:(id)aValue ForKey:(NSString *)aKey;

- (NSArray *)allFrequencyRecords;
- (NSDictionary *)frequencyRecordForID:(NSString *)frequencyIDString;
- (NSDictionary *)frequencyRecordForFrequency:(NSString *)frequencyString;
- (NSArray *)allFrequencyRecordsForCategoryID:(NSString *)categoryIDString;
- (void)deleteFrequencyRecordForID:(NSString *)frequencyIDString;

- (NSArray *)allCategoryRecords;
- (NSDictionary *)categoryRecordForID:(NSString *)idString;
- (NSDictionary *)categoryRecordForName:(NSString *)idString;
- (void)deleteCategoryRecordForID:(NSString *)categoryIDString;

- (NSArray *)freqCatRecordsForCategoryID:(NSString *)categoryIDString;
- (BOOL)freqCatRecordExistsForFrequencyID:(NSInteger)frequencyID categoryID:(NSInteger)categoryID;
- (NSDictionary *)freqCatRecordForFrequencyID:(NSInteger)frequencyID categoryID:(NSInteger)categoryID;

- (void)insertFreqCatRecordForFrequencyID:(NSInteger)frequencyID categoryID:(NSInteger)categoryID;
- (void)deleteFreqCatRecordForFrequencyID:(NSInteger)frequencyID categoryID:(NSInteger)categoryID;

- (int64_t)storeRecord:(NSDictionary *)recordDictionary table:(NSString *)tableName;   // insert or update, depending on recordDictionary=>'id'

- (NSArray *)getTableInfo:(NSString *)tableName;
- (NSMutableDictionary *)makePrototypeDictionaryForTable:(NSString *)tableName;

- (NSInteger)lastInsertID;

@end

/*
 * Copyright 2012 Dmitri Fedortchenko
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
#import <Foundation/Foundation.h>
#import <sqlite3.h>

#define sqlite_now_epoch @"strftime('%s','now')"
#ifdef __cplusplus
extern "C" {
#endif

    NSString* sqlite3_column_nsstring(sqlite3_stmt* statement, int column);

#ifdef __cplusplus
}
#endif

typedef void (^SQLiteBlock)(sqlite3_stmt *compiledStatement);

@interface SQLiteLibrary : NSObject
{
	sqlite3 *database;
	NSRecursiveLock *lock;
}
+ (SQLiteLibrary *)singleton;

/**
* Sets the database file name that will be used for the remainder of the singleton lifetime
* The database file will be looked for in the default documents folder.
* This (or any of the other setDatabase... methods) must be the first method run before anything can be done with the library.
*
* @param dbFilePath Absolute path to the database file
*/
+ (void)setDatabaseFile:(NSString *)dbFilePath;

/**
* Sets the database file name that will be used for the remainder of the singleton lifetime
* The database file will be looked for in the default documents folder.
* This (or any of the other setDatabase... methods) must be the first method run before anything can be done with the library.
*
* @param dbFilename path to the database file relative to DOCUMENTS folder
*/
+ (void)setDatabaseFileInDocuments:(NSString *)dbFilename;

/**
* Sets the database file name that will be used for the remainder of the singleton lifetime.
* The database file will be looked for in the default cache folder.
* This (or any of the other setDatabase... methods) must be the first method run before anything can be done with the library.
*
* @param dbFilename path to the database file relative to CACHE folder
*/
+ (void)setDatabaseFileInCache:(NSString *)dbFilename;

/**
* Return a dictionary for the sqlite statement.
* The keys are column names. When using joins and custom columns, make sure to use "AS" to specify unique column names.
*
* @param statement sqlite3 statement object for one row.
*/
+ (NSDictionary *)dictionaryForRowData:(sqlite3_stmt *)statement;

+ (BOOL)isId:(id)value columnName:(NSString *)columnName inTable:(NSString *)tableName;

/**
* Return a dictionary with the result of the provided SQL select query.
* The keys are column names. When using joins and custom columns, make sure to use "AS" to specify unique column names.
*
* @param query SELECT query
*/

+ (NSArray*)performQueryAndGetResultList:(NSString*)query;

- (NSArray *)performQueryAndGetResultList:(NSString *)query;

- (BOOL)verifyDatabaseFile;

/**
* Verify integrity of the database file.
*/
+ (BOOL)verifyDatabaseFile;

/** Perform an INSERT.
* If no transaction has been started, the method will start a new transaction and auto-commit at the end of the query.
*
* @param tableName SQL query
* @param data Dictionary with table column names as keys and data as values.
* @return returns the id of the last inserted row
* */

+ (int64_t)performInsertQueryInTable:(NSString *)tableName data:(NSDictionary *)data;

/** Perform an INSERT OR REPLACE.
* If any unique constraint fails, the row will be replaced (see SQLite docs on INSERT OR REPLACE).
* If no transaction has been started, the method will start a new transaction and auto-commit at the end of the query.
*
* @param tableName SQL query
* @param data Dictionary with table column names as keys and data as values.
* @return returns the id of the last inserted row
* */
+ (int64_t)performReplaceQueryInTable:(NSString *)tableName data:(NSDictionary *)data;

+ (int64_t)performUpdateQueryInTable:(NSString *)tableName data:(NSDictionary *)data idColumn:(NSString *)idColumn;

/**
* See +performQuery:block:
*/
- (int64_t)performQueryInTransaction:(NSString *)query block:(SQLiteBlock)block;

/** Perform an SQL query. Works with any SQL query. (singleton edition)
* If no transaction has been started, the method will start a new transaction and auto-commit at the end of the query.
*
* @param query SQL query
* @param block Block with SQL result
* @return Returns different values depending on query: INSERT returns the id of the inserted row, UPDATE returns the number of affected rows, SELECT returns number of found rows
* */
+ (int64_t)performQuery:(NSString *)query block:(SQLiteBlock)block;

/**
* Copy database skeleton to user's documents directory.
* @param forceReset if True, overwrite existing database file
*/
+ (void)setupDatabaseAndForceReset:(BOOL)forceReset;

/**
* Begin transaction (singleton edition)
*/
+ (BOOL)begin;

/**
* Commit transaction (singleton edition)
*/
+ (BOOL)commit;

/**
* Begin transaction
*/
- (BOOL)begin;


/**
* Commit transaction
*/
- (BOOL)commit;


@end

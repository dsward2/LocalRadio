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
#import "SQLiteLibrary.h"

#define ODBsprintf(format, ...) [NSString stringWithFormat:format, ## __VA_ARGS__]
#define make_nil_if_null(__string__) (__string__==nil||[__string__ isEqualToString:@"(null)"])?nil:__string__

#ifdef __cplusplus
extern "C" {
#endif

#define DEBUG_LOG 1

NSString* escape_string(id value)
{
    if ([value isKindOfClass:[NSString class]])
        return ODBsprintf(@"\"%@\"",[value stringByReplacingOccurrencesOfString:@"\"" withString:@"\"\""]);
    else
        return value;
}

NSString* sqlite3_column_nsstring(sqlite3_stmt* statement, int column)
{
    char* data = (char *)sqlite3_column_text(statement, column);
    if (data)
    {
        return make_nil_if_null([NSString stringWithUTF8String:data]);
    }
    else
    {
        return nil;
    }
}

#ifdef __cplusplus
}
#endif

@implementation SQLiteLibrary
{
    NSString* dbFilePath_;
}

static SQLiteLibrary* _instance;

+ (void)initialize
{
    [super initialize];
    _instance = [[self alloc] init];
}

+ (SQLiteLibrary *)singleton
{
	return _instance;
}

+ (void)setDatabaseFileInCache:(NSString *)dbFilename
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *directory = [paths objectAtIndex:0];
    NSString* appFile = [directory stringByAppendingPathComponent:dbFilename];
    [self setDatabaseFile:appFile];

}
+ (void)setDatabaseFileInDocuments:(NSString *)dbFilename
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *directory = [paths objectAtIndex:0];
    NSString* appFile = [directory stringByAppendingPathComponent:dbFilename];
    [self setDatabaseFile:appFile];
}
+ (void)setDatabaseFile:(NSString *)dbFilePath
{
    SQLiteLibrary * me = [self singleton];
    @synchronized (self)
    {
#if !__has_feature(objc_arc)
        [me->dbFilePath_ release];
#endif
        me->dbFilePath_ = nil;

        me->dbFilePath_ = [dbFilePath copy];
    }
}

- (id)init
{
	self = [super init];
	if (self)
	{
		database = nil;
		lock = [[NSRecursiveLock alloc]init];
	}

	return self;

}

#if !__has_feature(objc_arc)
- (void)dealloc
{
    [lock release];
    [super dealloc];
}
#endif

+ (BOOL)begin
{
	return [[self singleton] begin];
}

+ (BOOL)verifyDatabaseFile
{
    return [[self singleton]verifyDatabaseFile];
}
- (BOOL)verifyDatabaseFile
{
	NSString*dbPath = dbFilePath_;
    NSAssert(dbPath!=nil, @"Database file not set, perhaps you need to run `setDatabaseFileIn[Cache|Documents]:`");

#if DEBUG_LOG>=1
	NSLog(@"Using sqlite database at path %@", dbPath);
#endif
	NSAssert(database==nil, @"Attempted to start transaction while another is in progress.");
	
#if DEBUG_LOG>=2
    NSLog(@"Begin db verification...");
#endif
    
    if (![[NSFileManager defaultManager] isReadableFileAtPath:dbFilePath_])
    {
#if DEBUG_LOG>=2
        NSLog(@"DB File not found: %@", dbPath);
#endif

        return NO;
    }
    
	if(sqlite3_open([dbPath UTF8String], &database) == SQLITE_OK)
    {
        sqlite3_exec(database, "PRAGMA quick_check;", NULL, NULL, NULL);
        if (sqlite3_errcode(database) != SQLITE_DONE && sqlite3_errcode(database)>0)
		{
#if DEBUG_LOG>=1
			NSLog(@"!!!!!!> SQLITE ERROR ===============> %d - %@", sqlite3_errcode(database), [NSString stringWithCString:sqlite3_errmsg(database) encoding:NSUTF8StringEncoding]);
#endif
			return NO;
		}
		return YES;
	}
#if DEBUG_LOG>=1
	NSLog(@"!!!!!!> SQLITE ERROR ===============> Failed to open SQLite database %@;", dbPath);
#endif
    return NO;
}

- (BOOL)begin
{
    [lock lock];
    if (database!=nil)
    {
        [self commit];
        [lock lock];
    }

    NSAssert(dbFilePath_!=nil, @"dbFilePath must be set!");

	NSString*dbPath = dbFilePath_;
#if DEBUG_LOG>=2
	NSLog(@"Using sqlite database at path %@", dbPath);
#endif
	NSAssert([[NSFileManager defaultManager] isReadableFileAtPath:dbPath], ODBsprintf(@"Database file does not exist %@", dbPath));

	NSAssert(database==nil, @"Attempted to start transaction while another is in progress.");
	
	if(sqlite3_open([dbPath UTF8String], &database) == SQLITE_OK) {
#if DEBUG_LOG>=2
		NSLog(@"TRANSACTION BEGIN");
#endif
		sqlite3_exec(database, "BEGIN;", NULL, NULL, NULL);
		if (sqlite3_errcode(database) != SQLITE_DONE && sqlite3_errcode(database)>0)
		{
#if DEBUG_LOG>=1
			NSLog(@"!!!!!!> SQLITE ERROR ===============> %d - %@", sqlite3_errcode(database), [NSString stringWithCString:sqlite3_errmsg(database) encoding:NSUTF8StringEncoding]);
#endif
			return NO;
		}
        [lock unlock];      // dsward
		return YES;
	}
#if DEBUG_LOG>=1
	NSLog(@"!!!!!!> SQLITE ERROR ===============> Failed to open SQLite database %@;", dbPath);
#endif
    [lock unlock];      // dsward
	return NO;
}


+ (NSDictionary *)dictionaryForRowData:(sqlite3_stmt *)statement {

    int columns = sqlite3_column_count(statement);
    NSMutableDictionary *result = [[NSMutableDictionary alloc] initWithCapacity:columns];

    for (int i = 0; i<columns; i++) {
        const char *name = sqlite3_column_name(statement, i);

        NSString *columnName = [NSString stringWithCString:name encoding:NSUTF8StringEncoding];

        int type = sqlite3_column_type(statement, i);

        switch (type) {
            case SQLITE_INTEGER:
            {
                int value = sqlite3_column_int(statement, i);
                [result setObject:[NSNumber numberWithInt:value] forKey:columnName];
                break;
            }
            case SQLITE_FLOAT:
            {
                float value = (float)sqlite3_column_double(statement, i);
                [result setObject:[NSNumber numberWithFloat:value] forKey:columnName];
                break;
            }
            case SQLITE_TEXT:
            {
                const char *value = (const char*)sqlite3_column_text(statement, i);
                [result setObject:[NSString stringWithCString:value encoding:NSUTF8StringEncoding] forKey:columnName];
                break;
            }

            case SQLITE_BLOB:
                break;
            case SQLITE_NULL:
                //[result setObject:[NSNull null] forKey:columnName];
                break;

            default:
            {
                const char *value = (const char *)sqlite3_column_text(statement, i);
                [result setObject:[NSString stringWithCString:value encoding:NSUTF8StringEncoding] forKey:columnName];
                break;
            }

        } //end switch
    }
#if __has_feature(objc_arc)
    return result;
#else
    return [result autorelease];
#endif
}

+ (BOOL)isId:(id)value columnName:(NSString*)columnName inTable:(NSString*)tableName
{
    return [[self singleton] isId:value columnName:columnName inTable:tableName];
}
- (BOOL)isId:(id)value columnName:(NSString*)columnName inTable:(NSString*)tableName
{
    NSString* query = ODBsprintf(@"SELECT count(%@) as count FROM %@ WHERE %@ = %@", columnName, tableName, columnName, escape_string(value));
    NSArray *results = [SQLiteLibrary performQueryAndGetResultList:query];

    return ([results count] && [results[0][@"count"]intValue]>0);
}
+ (NSArray *)performQueryAndGetResultList:(NSString *)query
{
    return [[self singleton] performQueryAndGetResultList:query];
}

- (NSArray *)performQueryAndGetResultList:(NSString *)query
{
	[lock lock];

	BOOL shouldCommit = NO;
	if (database == nil)
	{
#if DEBUG_LOG>=2
		NSLog(@"======> SQLITE INFO ===============> No transaction started, forcing autocommit");
#endif
        shouldCommit=YES;
		[self begin];
	}
	NSAssert(database!=nil, @"Must begin a transaction first.");
    if (database == nil)
    	return nil;

#if DEBUG_LOG>=2
	NSLog(@"Performing query:\n\t%@", query);
#endif
	// Setup the SQL Statement and compile it for faster access
	sqlite3_stmt *compiledStatement;
    NSMutableArray* returnData = [NSMutableArray array];

	if(sqlite3_prepare_v2(database, [query UTF8String], -1, &compiledStatement, NULL) == SQLITE_OK)
    {
		// Loop through the results and add them to the feeds array
        /*
        while(sqlite3_step(compiledStatement) == SQLITE_ROW)
        {
            [returnData addObject:[SQLiteLibrary dictionaryForRowData:compiledStatement]];
        }
        */
        
        int stepResult = SQLITE_ROW;
        while (stepResult == SQLITE_ROW)
        {
            stepResult = sqlite3_step(compiledStatement);
            
            if (stepResult == SQLITE_ROW)
            {
                [returnData addObject:[SQLiteLibrary dictionaryForRowData:compiledStatement]];
            }
        }

#if DEBUG_LOG>=2
		if (sqlite3_errcode(database) != SQLITE_DONE && sqlite3_errcode(database)>0)
		{
			NSLog(@"!!!!!!> SQLITE ERROR ===============> %d - %@", sqlite3_errcode(database), [NSString stringWithCString:sqlite3_errmsg(database) encoding:NSUTF8StringEncoding]);
		}
#endif

	}
#if DEBUG_LOG>=1
	else
	{
		NSLog(@"!!!!!!> SQLITE ERROR ===============> %d - %@", sqlite3_errcode(database), [NSString stringWithCString:sqlite3_errmsg(database) encoding:NSUTF8StringEncoding]);
	}
#endif
	// Release the compiled statement from memory
	sqlite3_finalize(compiledStatement);
	if (shouldCommit)
		[self commit];

	[lock unlock];
	return returnData;
}

- (int64_t)performQueryInTransaction:(NSString *)query block:(SQLiteBlock)block
{
	[lock lock];

	BOOL shouldCommit = NO;
	if (database == nil)
	{
#if DEBUG_LOG>=2
		NSLog(@"======> SQLITE INFO ===============> No transaction started, forcing autocommit");
#endif
        shouldCommit=YES;
		[self begin];
	}
	NSAssert(database!=nil, @"Must begin a transaction first.");
	if (database == nil)
		return -1;

	int returnValue = -1;

#if DEBUG_LOG>=2
	NSLog(@"Performing query:\n\t%@", query);
#endif
	// Setup the SQL Statement and compile it for faster access
	sqlite3_stmt *compiledStatement;
	if(sqlite3_prepare_v2(database, [query UTF8String], -1, &compiledStatement, NULL) == SQLITE_OK) {
		// Loop through the results and add them to the feeds array
#if !__has_feature(objc_arc)
		[block retain];
#endif
		int resultCount = 0;
		while(sqlite3_step(compiledStatement) == SQLITE_ROW) {
			// Read the data from the result row
			resultCount ++;
			if (block!=nil)
				block(compiledStatement);
		}

#if DEBUG_LOG>=2
		if (sqlite3_errcode(database) != SQLITE_DONE && sqlite3_errcode(database)>0)
		{
			NSLog(@"!!!!!!> SQLITE ERROR ===============> %d - %@", sqlite3_errcode(database), [NSString stringWithCString:sqlite3_errmsg(database) encoding:NSUTF8StringEncoding]);
		}
#endif
		if ([[query uppercaseString] hasPrefix:@"INSERT"])
			returnValue = (int)sqlite3_last_insert_rowid(database);
		else if ([[query uppercaseString] hasPrefix:@"SELECT"])
			returnValue = resultCount;
		else
			returnValue = sqlite3_changes(database);
#if !__has_feature(objc_arc)
		[block release];
#endif
	}
#if DEBUG_LOG>=1
	else
	{
		NSLog(@"!!!!!!> SQLITE ERROR ===============> %d - %@", sqlite3_errcode(database), [NSString stringWithCString:sqlite3_errmsg(database) encoding:NSUTF8StringEncoding]);
	}
#endif
	// Release the compiled statement from memory
	sqlite3_finalize(compiledStatement);
	if (shouldCommit)
		[self commit];

	[lock unlock];
	return returnValue;
}

+ (BOOL)commit
{
	return [[self singleton] commit];
}

- (BOOL)commit
{
    [lock lock];

    if (database == nil)
    {
        [lock unlock];
        return NO;
    }

	sqlite3_exec(database, "COMMIT;", NULL, NULL, NULL);
	BOOL success = YES;
	if (sqlite3_errcode(database) != SQLITE_DONE && sqlite3_errcode(database)>0)
	{
#if DEBUG_LOG>=1
		NSLog(@"!!!!!!> SQLITE ERROR ===============> %d - %@", sqlite3_errcode(database), [NSString stringWithCString:sqlite3_errmsg(database) encoding:NSUTF8StringEncoding]);
#endif
        success=NO;
	}
#if DEBUG_LOG>=2
	NSLog(@"TRANSACTION COMMIT");
#endif
	sqlite3_close(database);
	database = nil;

    [lock unlock];
    [lock unlock];
	return success;
}

+ (int64_t)performInsertQueryInTable:(NSString*)tableName  data:(NSDictionary*)data
{
    return [[self singleton] performInsertQueryInTable:tableName data:data];
}
- (int64_t)performInsertQueryInTable:(NSString*)tableName  data:(NSDictionary*)data
{
    return [self performInsertQueryInTable:tableName data:data allowReplace:NO];
}

+ (int64_t)performReplaceQueryInTable:(NSString*)tableName  data:(NSDictionary*)data
{
    return [[self singleton] performReplaceQueryInTable:tableName data:data];
}

- (int64_t)performReplaceQueryInTable:(NSString*)tableName  data:(NSDictionary*)data
{
    return [self performInsertQueryInTable:tableName data:data allowReplace:YES];
}

+ (int64_t)performUpdateQueryInTable:(NSString*)tableName data:(NSDictionary*)data idColumn:(NSString*)idColumn
{
    return [[self singleton] performUpdateQueryInTable:tableName data:data idColumn:idColumn];
}

- (int64_t)performUpdateQueryInTable:(NSString*)tableName data:(NSDictionary*)data idColumn:(NSString*)idColumn
{
    NSMutableArray* values = [NSMutableArray arrayWithCapacity:[data count]];
    id idValue = nil;
    for (NSString*columnKey in [data allKeys])
    {
        id value = data[columnKey];
        id fixedValue = nil;
        if ([value isKindOfClass:[NSString class]])
            fixedValue = [escape_string(value) copy];
        else if (value==[NSNull null])
            fixedValue = @"NULL";
        else
            fixedValue = [value copy];

        if ([columnKey isEqualToString:idColumn])
        {
            idValue = [fixedValue copy];
        }
        else
        {
            [values addObject:ODBsprintf(@"%@ = %@", columnKey, fixedValue)];
        }
    }

    NSString* queryString = ODBsprintf(
    @"UPDATE %@ SET %@ WHERE %@ = %@",
    tableName,
    [values componentsJoinedByString:@","],
    idColumn,
    idValue
    );

    return [self performQueryInTransaction:queryString block:nil];

}

- (int64_t)performInsertQueryInTable:(NSString*)tableName  data:(NSDictionary*)data allowReplace:(BOOL)allowReplace
{
    NSMutableDictionary * queryData = [NSMutableDictionary dictionaryWithCapacity:[data count]];
    for (NSString* key in [data allKeys])
    {
        id value = data[key];
        if ([value isKindOfClass:[NSString class]])
            queryData[key] = escape_string(value);
        else if (value==[NSNull null])
            queryData[key] = @"NULL";
        else
            queryData[key] = value;
    }
    NSString* orReplace = @"";
    if (allowReplace) orReplace = @"OR REPLACE";

    NSString* queryString = ODBsprintf(
    @"INSERT %@ INTO %@ (%@) VALUES(%@)",
        orReplace,
        tableName,
        [[queryData allKeys] componentsJoinedByString:@","],
        [[queryData allValues] componentsJoinedByString:@","]
    );

    return [self performQueryInTransaction:queryString block:nil];

}

+ (int64_t)performQuery:(NSString *)query block:(SQLiteBlock)block
{
	return [[self singleton] performQueryInTransaction:query block:block];
}

- (void)setupDatabaseAndForceReset:(BOOL)forceReset
{
    NSAssert(dbFilePath_!=nil, @"dbFilePath must be set!");

#if DEBUG_LOG>=1
	NSLog(@"Using sqlite database at path %@", dbFilePath_);
#endif

    NSString* defaultDB = [[NSBundle mainBundle]pathForResource:@"data_skeleton" ofType:@"sqlite3"];
    NSString* appFile = dbFilePath_;
    BOOL exists = [[NSFileManager defaultManager]fileExistsAtPath:appFile];
    if (exists && forceReset)
        [[NSFileManager defaultManager] removeItemAtPath:appFile error:nil];

    if (!exists || forceReset)
        [[NSFileManager defaultManager]copyItemAtPath:defaultDB toPath:appFile error:nil];
}

+ (void)setupDatabaseAndForceReset:(BOOL)forceReset
{
    [[self singleton] setupDatabaseAndForceReset:forceReset];
}

@end

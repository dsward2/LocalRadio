## Bugfix 2012-08-16: Removed a dependency to a custom library.

# Info

This is a very simple *thread safe* SQLite wrapper for Mac OS X and iOS development.

It is a singleton, so it allows for a single database connection. That being said, the library is thread
safe and if multiple threads attempt to do SQL operations, they will be queued up until the current
thread is done (i.e. the database transaction is committed).

It has support for transactions and uses blocks.

## Data skeleton and data locations

Before using the library you have to set the name of your preferred database file and it's location.

```objc
# Store database data in the cache
[SQLiteLibrary setDatabaseFileInCache:@"dbstuff.sqlite"];
 
# Store database data in the persistent documents folder
[SQLiteLibrary setDatabaseFileInDocuments:@"dbstuff.sqlite"];
```

After setting the file name, the code below will copy the file **data_skeleton.sqlite3** to the file you specified above.
Note that this will **NOT** override the file, **UNLESS** you specify `YES` as the `ForceReset` parameter.

```objc
[SQLiteLibrary setupDatabaseAndForceReset:NO];
```

### setDatabaseFileInCache 

The *cache* location will store the database in a cache folder and this folder can be deleted at any time
when the application is not running. It is also not backed up.

Use this for databases that store temporary data that you will not need to store between application launches.

### setDatabaseFileInDocuments

The *documents* location will store the database in the user's Documents folder. This folder is persistent
and will not be deleted unless the user uninstalls the iOS application or manually deletes the file on Mac.

Use this for databases that store persistent data such as user profiles or game highscores.

## Logging

Log messages are output based on your setting of `DEBUG_LOG` preprocessor macro.

* `DEBUG_LOG=1` - outputs basic messages and errors
* `DEBUG_LOG=2` - outputs every query and lots of other data

## Typical usage scenario

```objc
[SQLiteLibrary setDatabaseFileInCache:@"dbstuff.sqlite"];
[SQLiteLibrary setupDatabaseAndForceReset:NO];
[SQLiteLibrary begin];

# Insert query
[SQLiteLibrary performQuery:@"INSERT INTO tablename (bar, foo) VALUES(2,3)" block:nil];

# Select query
# The block will be called once for every row returned from the query
[SQLiteLibrary performQuery:@"SELECT foo, bar FROM tablename" block:^(sqlite3_stmt *rowData) {
    NSString* stringValue = sqlite3_column_nsstring(rowData, 0);
    int intValue = sqlite3_column_int(rowData, 1);
}];
```

The `performQuery:` method returns different integer values depending on the query:

* **INSERT** returns the id of the *last* inserted row
* **UPDATE** returns the number of affected rows
* **SELECT** returns number of found rows

## Using transactions

By default every query is performed in it's own transaction, however if you are performing lots
of insert queries using transactions increases performance quite a bit.

```objc
[SQLiteLibrary begin];
[SQLiteLibrary performQuery:@"INSERT INTO tablename (bar, foo) VALUES(22,3)" block:nil];
[SQLiteLibrary performQuery:@"INSERT INTO tablename (bar, foo) VALUES(252,234542)" block:nil];
[SQLiteLibrary performQuery:@"INSERT INTO tablename (bar, foo) VALUES(252,5253)" block:nil];
[SQLiteLibrary performQuery:@"INSERT INTO tablename (bar, foo) VALUES(2222,2523)" block:nil];
[SQLiteLibrary performQuery:@"INSERT INTO tablename (bar, foo) VALUES(512,352)" block:nil];
[SQLiteLibrary commit];
```

### Threads

Calling `begin` initiates a thread lock, and the lock is only released only when `commit` is called.

So once an SQL transaction is started, all other database access will be put on hold until the thread
that begun the transaction calls `commit`.

Note: A single query outside a transaction calls `begin` and `commit`, and thus follows the above principle.

### Rollback

There is currently no rollback support.

## sqlite3\_column\_nsstring

For `NSString` support I wrote a custom function `sqlite3_column_nsstring`, it behaves like other sqlite3 functions but returns an `NSString` instead of a C string.

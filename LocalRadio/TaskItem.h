//
//  TaskItem.h
//  LocalRadio
//
//  Created by Douglas Ward on 12/21/17.
//  Copyright © 2017-2018 ArkPhone LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TaskItem : NSObject

@property (strong) NSTask * task;
@property (strong) NSString * path;
@property (strong) NSString * functionName;
@property (strong) NSMutableArray * argsArray;

@property (strong) NSPipe * stderrPipe;

- (void) addArgument:(NSString *)argItem;

- (NSString *) quotedPath;
- (NSString *) argsString;

- (NSError *) createTask;
- (NSError *) startTask;
- (NSError *) terminateTask;

- (NSString *) taskInfoString;

@end

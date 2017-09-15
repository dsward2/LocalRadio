//
//  EZStreamController.h
//  LocalRadio
//
//  Created by Douglas Ward on 7/7/17.
//  Copyright © 2017 ArkPhone LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AppDelegate;

@interface EZStreamController : NSObject

@property(strong) IBOutlet AppDelegate * appDelegate;

@property (strong) NSTask * ezStreamTask;
@property (strong) NSPipe * ezStreamTaskStandardErrorPipe;

- (void)terminateTasks;

- (void)startEZStreamServer;
- (void)stopEZStreamServer;

@end

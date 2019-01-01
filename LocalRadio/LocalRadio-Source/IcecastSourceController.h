//
//  IcecastSourceController.h
//  LocalRadio
//
//  Created by Douglas Ward on 9/28/18.
//  Copyright © 2018 ArkPhone LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AppDelegate;
@class TaskPipelineManager;

NS_ASSUME_NONNULL_BEGIN

@interface IcecastSourceController : NSObject

@property(strong) IBOutlet AppDelegate * appDelegate;

@property (strong) TaskPipelineManager * icecastSourceTaskPipelineManager;

@property (strong) NSString * audioFormat;

- (void)terminateTasks;

- (void)startIcecastSource;
//- (void)stopIcecastSource;

@end

NS_ASSUME_NONNULL_END

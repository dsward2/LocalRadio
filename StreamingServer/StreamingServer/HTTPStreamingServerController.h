//
//  HTTPStreamingServerController.h
//  StreamingServer
//
//  Created by Douglas Ward on 2/25/20.
//  Copyright © 2020 ArkPhone LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class HTTPStreamingServer;

NS_ASSUME_NONNULL_BEGIN

@interface HTTPStreamingServerController : NSObject

@property(strong) HTTPStreamingServer * _Nullable httpStreamingServer;

- (BOOL)startProcessingWithPort:(int)port;
- (void)addAudioDataToConnections:(NSMutableData *)audioData;

@end

NS_ASSUME_NONNULL_END

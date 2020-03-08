//
//  HTTPStreamingServerConnection.h
//  StreamingServer
//
//  Created by Douglas Ward on 2/25/20.
//  Copyright © 2020 ArkPhone LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "HTTPConnection.h"

NS_ASSUME_NONNULL_BEGIN

@interface HTTPStreamingServerConnection : HTTPConnection

- (void)addAudioData:(NSMutableData *)audioData;

@end

NS_ASSUME_NONNULL_END

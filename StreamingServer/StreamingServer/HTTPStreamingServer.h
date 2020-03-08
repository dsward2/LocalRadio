//
//  HTTPStreamingServer.h
//  StreamingServer
//
//  Created by Douglas Ward on 3/5/20.
//  Copyright © 2020 ArkPhone LLC. All rights reserved.
//

#import "HTTPServer.h"

NS_ASSUME_NONNULL_BEGIN

@interface HTTPStreamingServer : HTTPServer

- (NSMutableArray *)connections; // dsward

@end

NS_ASSUME_NONNULL_END

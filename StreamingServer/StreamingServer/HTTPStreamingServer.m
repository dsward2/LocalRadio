//
//  HTTPStreamingServer.m
//  StreamingServer
//
//  Created by Douglas Ward on 3/5/20.
//  Copyright © 2020 ArkPhone LLC. All rights reserved.
//

#import "HTTPStreamingServer.h"

@implementation HTTPStreamingServer

// dsward - added connections method
- (NSMutableArray *)connections
{
    __block NSMutableArray * result;
    
    dispatch_sync(serverQueue, ^{
        result = self->connections;
    });
    
    return result;
}

@end

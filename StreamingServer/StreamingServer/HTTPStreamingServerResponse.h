//
//  HTTPStreamingServerResponse.h
//  StreamingServer
//
//  Created by Douglas Ward on 3/7/20.
//  Copyright © 2020 ArkPhone LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "HTTPResponse.h"
#import "HTTPStreamingServerConnection.h"

NS_ASSUME_NONNULL_BEGIN

@interface HTTPStreamingServerResponse : NSObject <HTTPResponse>

@property (strong) NSMutableArray * _Nullable audioDataArray;     // array of NSMutableData containing ADTS AAC audio data packets

- (id)initWithConnection:(HTTPStreamingServerConnection *)parent;
- (void)addAudioData:(NSMutableData *)audioData;

@end

NS_ASSUME_NONNULL_END

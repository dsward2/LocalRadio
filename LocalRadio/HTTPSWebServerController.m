//
//  HTTPSWebServerController.m
//  LocalRadio
//
//  Created by Douglas Ward on 12/16/18.
//  Copyright © 2018 ArkPhone LLC. All rights reserved.
//

#import "HTTPSWebServerController.h"
#import "HTTPSWebServerConnection.h"

@implementation HTTPSWebServerController

//==================================================================================
//    connectionClassForScheme
//==================================================================================

- (Class)connectionClassForScheme
{
     return [HTTPSWebServerConnection class];  // override for http/https
}

//==================================================================================
//    serverClassPortKey
//==================================================================================

- (NSString *)serverClassPortKey
{
    return @"LocalRadioServerHTTPSPort";
}

//==================================================================================
//    serviceName
//==================================================================================

- (NSString *)serviceName
{
    return @"LocalRadioSecure";
}

@end

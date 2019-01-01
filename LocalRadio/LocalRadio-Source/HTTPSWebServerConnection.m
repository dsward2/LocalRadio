//
//  HTTPSWebServerConnection.m
//  LocalRadio
//
//  Created by Douglas Ward on 12/16/18.
//  Copyright © 2018 ArkPhone LLC. All rights reserved.
//

#import "HTTPSWebServerConnection.h"
#import "DDKeychain_LocalRadio.h"
#import "HTTPLogging.h"

@implementation HTTPSWebServerConnection

//==================================================================================
//    httpScheme
//==================================================================================

- (NSString *)httpScheme
{
    return @"https";     // override to return http or https
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark HTTPS
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Returns whether or not the server is configured to be a secure server.
 * In other words, all connections to this server are immediately secured, thus only secure connections are allowed.
 * This is the equivalent of having an https server, where it is assumed that all connections must be secure.
 * If this is the case, then unsecure connections will not be allowed on this server, and a separate unsecure server
 * would need to be run on a separate port in order to support unsecure connections.
 *
 * Note: In order to support secure connections, the sslIdentityAndCertificates method must be implemented.
**/
- (BOOL)isSecureServer
{
    // Create an HTTPS server (all connections will be secured via SSL/TLS)
    return YES;
}



/**
 * This method is expected to returns an array appropriate for use in kCFStreamSSLCertificates SSL Settings.
 * It should be an array of SecCertificateRefs except for the first element in the array, which is a SecIdentityRef.
**/
- (NSArray *)sslIdentityAndCertificates
{
    NSArray *result = [DDKeychain_LocalRadio SSLIdentityAndCertificates];
    if([result count] == 0)
    {
        //HTTPLogInfo(@"sslIdentityAndCertificates: Creating New Identity...");
        [DDKeychain_LocalRadio createNewIdentity];
        return [DDKeychain_LocalRadio SSLIdentityAndCertificates];
    }

    return result;
}

@end

//
//  WebServerController.h
//  LocalRadio
//
//  Created by Douglas Ward on 4/22/17.
//  Copyright © 2017-2018 ArkPhone LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class HTTPServer;
@class AppDelegate;

@interface HTTPWebServerController : NSObject 
{
}

@property(strong) IBOutlet AppDelegate * appDelegate;

@property(strong) HTTPServer * httpServer;

- (NSNumber *)serverClassPortNumber;

- (void)startHTTPServer;
- (void)stopHTTPServer;

@end

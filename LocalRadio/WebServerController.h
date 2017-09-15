//
//  WebServerController.h
//  LocalRadio
//
//  Created by Douglas Ward on 4/22/17.
//  Copyright © 2017 ArkPhone LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class HTTPServer;
@class AppDelegate;

@interface WebServerController : NSObject 
{
}

@property(strong) IBOutlet AppDelegate * appDelegate;


@property(strong) HTTPServer * httpServer;
@property(assign) NSUInteger webServerPort;

- (void)startHTTPServer;
- (void)stopHTTPServer;

//- (void)startProcessing;
//- (void)stopProcessing;

@end

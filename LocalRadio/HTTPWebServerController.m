//
//  WebServerController.m
//  LocalRadio
//
//  Created by Douglas Ward on 4/22/17.
//  Copyright © 2017-2018 ArkPhone LLC. All rights reserved.
//

#import "HTTPWebServerController.h"
#import <WebKit/WebKit.h>

// CocoaHTTPServer
#import "HTTPServer.h"
#import "DDLog.h"
#import "DDTTYLogger.h"
#import "HTTPDynamicFileResponse.h"
#import "HTTPLogging.h"
#import "HTTPConnection.h"

#import "LocalRadioAppSettings.h"
#import "HTTPWebServerConnection.h"
#import "AppDelegate.h"


// Log levels: off, error, warn, info, verbose
static const int ddLogLevel = LOG_LEVEL_VERBOSE;


@interface HTTPWebServerController (PrivateMethods)
@property (readonly, copy) NSString *applicationSupportFolder;
@end

@implementation HTTPWebServerController

//==================================================================================
//	dealloc
//==================================================================================

- (void)dealloc
{
    if (self.httpServer != NULL)
    {
        [self stopProcessing];
    }
}

//==================================================================================
//	init
//==================================================================================

- (instancetype)init
{
    self = [super init];
    if (self) {
        //[self startProcessing];   // don't start immediately, but call startHTTPServer from AppDelegate
    }
    return self;
}

//==================================================================================
//	startHTTPServer
//==================================================================================

- (void)startHTTPServer
{
    /*
    [self.webServerController stopProcessing];
    self.webServerController = NULL;

    NSLog(@"Starting HTTP server");
 
    self.webServerController = [[WebServerController alloc] init];
    */
    
    [self startProcessing];
}

//==================================================================================
//	stopHTTPServer
//==================================================================================

- (void)stopHTTPServer
{
    [self stopProcessing];
}

//==================================================================================
//	startProcessing
//==================================================================================

- (void)startProcessing
{
    if (self.httpServer == NULL)
    {
        NSNumber * localRadioServerHTTPPort = [self.appDelegate.localRadioAppSettings integerForKey:@"LocalRadioServerHTTPPort"];
        if (localRadioServerHTTPPort.integerValue <= 0)
        {
            localRadioServerHTTPPort = [NSNumber numberWithInteger:17002];
        }
        self.webServerPort = localRadioServerHTTPPort.integerValue;

        // For CocoaHTTPServer
        // Configure our logging framework.
        // To keep things simple and fast, we're just going to log to the Xcode console.
        [DDLog addLogger:[DDTTYLogger sharedInstance]];
        
        // Initalize our http server
        self.httpServer = [[HTTPServer alloc] init];
        
        // Tell server to use our custom HTTPConnection class.
        //[self.httpServer setConnectionClass:[HTTPConnection class]];
        [self.httpServer setConnectionClass:[HTTPWebServerConnection class]];  // custom class for dynamic response
        
        // Tell the server to broadcast its presence via Bonjour.
        // This allows browsers such as Safari to automatically discover our service.
        [self.httpServer setType:@"_http._tcp."];

		NSString * computerName = [[NSHost currentHost] localizedName];
        NSString * bonjourServiceName = [NSString stringWithFormat:@"LocalRadio.%@", computerName];

        [self.httpServer setName:bonjourServiceName];
        
        // Normally there's no need to run our server on any specific port.
        // Technologies like Bonjour allow clients to dynamically discover the server's port at runtime.
        // However, for easy testing you may want force a certain port so you can just hit the refresh button.
        [self.httpServer setPort:self.webServerPort];
        
        // Serve files from our embedded Web folder
        NSString * webPath = [[NSBundle mainBundle].resourcePath stringByAppendingPathComponent:@"Web"];
        //DDLogVerbose(@"Setting document root: %@", webPath);
        
        [self.httpServer setDocumentRoot:webPath];
        
        // Start the server (and check for problems)
        
        NSError *error;
        BOOL success = [self.httpServer start:&error];
        
        if(!success)
        {
            DDLogError(@"Error starting HTTP Server: %@", error);
        }
    }
}

//==================================================================================
//	stopProcessing
//==================================================================================

- (void)stopProcessing
{
    [self.httpServer stop];
    
    self.httpServer = NULL;
}

@end

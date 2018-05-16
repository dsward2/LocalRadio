//
//  WebServerController.m
//  LocalRadio
//
//  Created by Douglas Ward on 4/22/17.
//  Copyright © 2017-2018 ArkPhone LLC. All rights reserved.
//

#import "WebServerController.h"
#import <WebKit/WebKit.h>

// CocoaHTTPServer
#import "HTTPServer.h"
#import "DDLog.h"
#import "DDTTYLogger.h"
#import "HTTPDynamicFileResponse.h"
#import "HTTPLogging.h"
#import "HTTPConnection.h"

#import "LocalRadioAppSettings.h"
#import "WebServerConnection.h"
#import "AppDelegate.h"


// Log levels: off, error, warn, info, verbose
static const int ddLogLevel = LOG_LEVEL_VERBOSE;


@interface WebServerController (PrivateMethods)
@property (readonly, copy) NSString *applicationSupportFolder;
@end

@implementation WebServerController

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
        [self startProcessing];
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
        NSNumber * httpServerPortNumber = [self.appDelegate.localRadioAppSettings integerForKey:@"HTTPServerPort"];
        if (httpServerPortNumber.integerValue <= 0)
        {
            httpServerPortNumber = [NSNumber numberWithInteger:17002];
        }
        self.webServerPort = httpServerPortNumber.integerValue;;

        // For CocoaHTTPServer
        // Configure our logging framework.
        // To keep things simple and fast, we're just going to log to the Xcode console.
        [DDLog addLogger:[DDTTYLogger sharedInstance]];
        
        // Initalize our http server
        self.httpServer = [[HTTPServer alloc] init];
        
        // Tell server to use our custom HTTPConnection class.
        //[self.httpServer setConnectionClass:[HTTPConnection class]];
        [self.httpServer setConnectionClass:[WebServerConnection class]];  // custom class for dynamic response
        
        // Tell the server to broadcast its presence via Bonjour.
        // This allows browsers such as Safari to automatically discover our service.
        [self.httpServer setType:@"_http._tcp."];

		NSString * computerName = [[NSHost currentHost] localizedName];
        NSString * bonjourName = [NSString stringWithFormat:@"LocalRadio.%@", computerName];

        [self.httpServer setName:bonjourName];
        
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

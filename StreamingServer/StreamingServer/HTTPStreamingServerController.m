//
//  StreamingServerController.m
//  StreamingServer
//
//  Created by Douglas Ward on 2/25/20.
//  Copyright © 2020 ArkPhone LLC. All rights reserved.
//

#import "HTTPStreamingServerController.h"

// CocoaHTTPServer
#import "HTTPStreamingServer.h"
#import "DDLog.h"
#import "DDTTYLogger.h"
#import "HTTPAsyncFileResponse.h"
#import "HTTPLogging.h"
#import "HTTPConnection.h"

#import "HTTPStreamingServerConnection.h"



// Log levels: off, error, warn, info, verbose
static const int ddLogLevel = LOG_LEVEL_VERBOSE;

@interface HTTPStreamingServerController (PrivateMethods)
@property (readonly, copy) NSString * applicationSupportFolder;
@end

@implementation HTTPStreamingServerController

//==================================================================================
//    dealloc
//==================================================================================

- (void)dealloc
{
    if (self.httpStreamingServer != NULL)
    {
        [self stopProcessing];
    }
}

//==================================================================================
//    init
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
//    startHTTPStreamingServer
//==================================================================================

/*
- (void)startHTTPStreamingServer
{
    //[self.webServerController stopProcessing];
    //self.webServerController = NULL;

    //NSLog(@"Starting HTTP server");
 
    //self.webServerController = [[WebServerController alloc] init];
    
    [self startProcessing];
}
*/

//==================================================================================
//    stopHTTPStreamingServer
//==================================================================================

- (void)stopHTTPStreamingServer
{
    [self stopProcessing];
}

//==================================================================================
//    connectionClassForScheme
//==================================================================================

- (Class)connectionClassForScheme
{
     return [HTTPStreamingServerConnection class];  // override for http/https
}

//==================================================================================
//    serverClassPortKey
//==================================================================================

- (NSString *)serverClassPortKey
{
    return @"StreamingServerHTTPPort";
}

//==================================================================================
//    serviceName
//==================================================================================

- (NSString *)serviceName
{
    return @"LocalRadioStreamingServer";
}

//==================================================================================
//    serverClassPortNumber
//==================================================================================
/*
- (NSNumber *)serverClassPortNumber
{
    //NSString * serverClassPortKey = [self serverClassPortKey];
    //NSNumber * serverClassPortNumber = [self.appDelegate.localRadioAppSettings integerNumberForKey:serverClassPortKey];
    return serverClassPortNumber;
}
*/

//==================================================================================
//    startProcessingWithPort:
//==================================================================================

- (BOOL)startProcessingWithPort:(int32_t)port
{
    BOOL success = NO;
    if (self.httpStreamingServer == NULL)
    {
        // port number result depends on http or https

        self.streamingServerPort = port;
        NSNumber * serverClassPortNumber = [NSNumber numberWithInt:port];
        
        if (serverClassPortNumber.integerValue <= 0)
        {
            DDLogError(@"HTTPWebServerController - startProcessing - invalid localRadioServerHTTPPort");
            self.streamingServerPort = 17004;
            serverClassPortNumber = [NSNumber numberWithInteger:17004];
        }

        // For CocoaHTTPServer
        // Configure our logging framework.
        // To keep things simple and fast, we're just going to log to the Xcode console.
        [DDLog addLogger:[DDTTYLogger sharedInstance]];
        
        // Initalize our http server
        self.httpStreamingServer = [[HTTPStreamingServer alloc] init];
        
        // Tell server to use our custom HTTPConnection class.
        //[self.httpServer setConnectionClass:[HTTPWebServerConnection class]];  // custom class for dynamic response
        [self.httpStreamingServer setConnectionClass:[self connectionClassForScheme]];  // override for http/https

        // Tell the server to broadcast its presence via Bonjour.
        // This allows browsers such as Safari to automatically discover our service.
        [self.httpStreamingServer setType:@"_http._tcp."];

        NSString * serviceName = [self serviceName];
        
        NSString * computerName = [[NSHost currentHost] localizedName];
        NSString * bonjourServiceName = [NSString stringWithFormat:@"%@.%@", serviceName, computerName];

        [self.httpStreamingServer setName:bonjourServiceName];
        
        // Normally there's no need to run our server on any specific port.
        // Technologies like Bonjour allow clients to dynamically discover the server's port at runtime.
        // However, for easy testing you may want force a certain port so you can just hit the refresh button.
        [self.httpStreamingServer setPort:serverClassPortNumber.integerValue];

        // Serve files from our embedded Web folder
        NSString * webPath = [[NSBundle mainBundle].resourcePath stringByAppendingPathComponent:@"Web"];
        //DDLogVerbose(@"Setting document root: %@", webPath);
        
        [self.httpStreamingServer setDocumentRoot:webPath];
        
        // Start the server (and check for problems)
        
        NSError *error;
        BOOL success = [self.httpStreamingServer start:&error];
        
        if(!success)
        {
            DDLogError(@"HTTPWebServerController - startProcessing - Error starting HTTP Streaming Server: %@", error);
        }
        
    }
    return success;
}

//==================================================================================
//    stopProcessing
//==================================================================================

- (void)stopProcessing
{
    [self.httpStreamingServer stop];
    
    self.httpStreamingServer = NULL;
}

//==================================================================================
//    addAudioDataToConnections
//==================================================================================

- (void)addAudioDataToConnections:(NSMutableData *)audioData;
{
    NSMutableArray * connectionsArray = [self.httpStreamingServer connections];
    
    for (HTTPConnection * aHTTPConnection in connectionsArray)
    {
        if ([aHTTPConnection isKindOfClass:[HTTPStreamingServerConnection class]] == YES)
        {
            HTTPStreamingServerConnection * streamingServerConnection = (HTTPStreamingServerConnection *)aHTTPConnection;
            
            [streamingServerConnection addAudioData:audioData];
        }
    }
}

@end

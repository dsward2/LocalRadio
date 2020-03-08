//
//  HTTPStreamingServerConnection.m
//  StreamingServer
//
//  Created by Douglas Ward on 2/25/20.
//  Copyright © 2020 ArkPhone LLC. All rights reserved.
//

#import "HTTPStreamingServerConnection.h"
#import "HTTPLogging.h"
#import "HTTPMessage.h"
#import "GCDAsyncSocket.h"
#import "HTTPStreamingServerResponse.h"

/**
 * Important notice to those implementing custom asynchronous and/or chunked responses:
 *
 * HTTPConnection supports asynchronous responses.  All you have to do in your custom response class is
 * asynchronously generate the response, and invoke HTTPConnection's responseHasAvailableData method.
 * You don't have to wait until you have all of the response ready to invoke this method.  For example, if you
 * generate the response in incremental chunks, you could call responseHasAvailableData after generating
 * each chunk.  Please see the HTTPAsyncFileResponse class for an example of how to do this.
 *
 * The normal flow of events for an HTTPConnection while responding to a request is like this:
 *  - Send http resopnse headers
 *  - Get data from response via readDataOfLength method.
 *  - Add data to asyncSocket's write queue.
 *  - Wait for asyncSocket to notify it that the data has been sent.
 *  - Get more data from response via readDataOfLength method.
 *  - ... continue this cycle until the entire response has been sent.
 *
 * With an asynchronous response, the flow is a little different.
 *
 * First the HTTPResponse is given the opportunity to postpone sending the HTTP response headers.
 * This allows the response to asynchronously execute any code needed to calculate a part of the header.
 * An example might be the response needs to generate some custom header fields,
 * or perhaps the response needs to look for a resource on network-attached storage.
 * Since the network-attached storage may be slow, the response doesn't know whether to send a 200 or 404 yet.
 * In situations such as this, the HTTPResponse simply implements the delayResponseHeaders method and returns YES.
 * After returning YES from this method, the HTTPConnection will wait until the response invokes its
 * responseHasAvailableData method. After this occurs, the HTTPConnection will again query the delayResponseHeaders
 * method to see if the response is ready to send the headers.
 * This cycle will continue until the delayResponseHeaders method returns NO.
 *
 * You should only delay sending the response headers until you have everything you need concerning just the headers.
 * Asynchronously generating the body of the response is not an excuse to delay sending the headers.
 *
 * After the response headers have been sent, the HTTPConnection calls your readDataOfLength method.
 * You may or may not have any available data at this point. If you don't, then simply return nil.
 * You should later invoke HTTPConnection's responseHasAvailableData when you have data to send.
 *
 * You don't have to keep track of when you return nil in the readDataOfLength method, or how many times you've invoked
 * responseHasAvailableData. Just simply call responseHasAvailableData whenever you've generated new data, and
 * return nil in your readDataOfLength whenever you don't have any available data in the requested range.
 * HTTPConnection will automatically detect when it should be requesting new data and will act appropriately.
 *
 * It's important that you also keep in mind that the HTTP server supports range requests.
 * The setOffset method is mandatory, and should not be ignored.
 * Make sure you take into account the offset within the readDataOfLength method.
 * You should also be aware that the HTTPConnection automatically sorts any range requests.
 * So if your setOffset method is called with a value of 100, then you can safely release bytes 0-99.
 *
 * HTTPConnection can also help you keep your memory footprint small.
 * Imagine you're dynamically generating a 10 MB response.  You probably don't want to load all this data into
 * RAM, and sit around waiting for HTTPConnection to slowly send it out over the network.  All you need to do
 * is pay attention to when HTTPConnection requests more data via readDataOfLength.  This is because HTTPConnection
 * will never allow asyncSocket's write queue to get much bigger than READ_CHUNKSIZE bytes.  You should
 * consider how you might be able to take advantage of this fact to generate your asynchronous response on demand,
 * while at the same time keeping your memory footprint small, and your application lightning fast.
 *
 * If you don't know the content-length in advanced, you should also implement the isChunked method.
 * This means the response will not include a Content-Length header, and will instead use "Transfer-Encoding: chunked".
 * There's a good chance that if your response is asynchronous and dynamic, it's also chunked.
 * If your response is chunked, you don't need to worry about range requests.
**/


// Log levels: off, error, warn, info, verbose
// Other flags: trace
static const int httpLogLevel = HTTP_LOG_LEVEL_WARN; // | HTTP_LOG_FLAG_TRACE;

@implementation HTTPStreamingServerConnection

//==================================================================================
//    initWithAsyncSocket:configuration:
//==================================================================================

- (id)initWithAsyncSocket:(GCDAsyncSocket *)newSocket configuration:(HTTPConfig *)aConfig
{
    if ((self = [super initWithAsyncSocket:newSocket configuration:aConfig]))
    {
    }
    
    return self;
}

//==================================================================================
//    addAudioData:
//==================================================================================

- (void)addAudioData:(NSMutableData *)audioData
{
    HTTPStreamingServerResponse * response = (HTTPStreamingServerResponse *)self->httpResponse;

    [response addAudioData:audioData];
    
    [self responseHasAvailableData:response];
}

//==================================================================================
//    httpScheme
//==================================================================================

- (NSString *)httpScheme
{
    return @"http";     // override to return http or https
}

//==================================================================================
//    supportsMethod:atPath:
//==================================================================================

- (BOOL)supportsMethod:(NSString *)method atPath:(NSString *)path
{
    //HTTPLogTrace();
    
    // Add support for POST
    
    if ([method isEqualToString:@"GET"])
    {
        // add subpaths for supported pages here to fix HTTP Error 405 - Method Not Allowed error response
    
        if ([path isEqualToString:@"/localradio.aac"])
        {
            return YES;
        }
    }
    
    if ([method isEqualToString:@"POST"])
    {
        return NO;
    }
    
    return [super supportsMethod:method atPath:path];
}

//==================================================================================
//    expectsRequestBodyFromMethod:atPath:
//==================================================================================

- (BOOL)expectsRequestBodyFromMethod:(NSString *)method atPath:(NSString *)path
{
    //HTTPLogTrace();
    
    // Inform HTTP server that we expect a body to accompany a POST request
    //if([method isEqualToString:@"POST"])
    //    return YES;
    
    //return [super expectsRequestBodyFromMethod:method atPath:path];

    return NO;
}


//==================================================================================
//    httpResponseForMethod:URI:
//==================================================================================

- (NSObject<HTTPResponse> *)httpResponseForMethod:(NSString *)method URI:(NSString *)path
{
    //HTTPLogTrace();
    
    // Override me to provide custom responses.
    
    NSString *filePath = [self filePathForURI:path allowDirectory:NO];
    
    BOOL isDir = NO;
    
    if (filePath && [[NSFileManager defaultManager] fileExistsAtPath:filePath isDirectory:&isDir] && !isDir)
    {
        HTTPStreamingServerResponse * response = [[HTTPStreamingServerResponse alloc] initWithConnection:self];
        return response;
    }
    
    return nil;
}


- (NSData *)preprocessResponse:(HTTPMessage *)response
{
    [response setHeaderField:@"Content-Type" value:@"audio/aac"];

    NSData * resultData = [super preprocessResponse:response];
    return resultData;
}

@end

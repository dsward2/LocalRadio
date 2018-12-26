//
//  LocalRadioAPI.m
//  LocalRadio
//
//  Created by Douglas Ward on 10/28/18.
//  Copyright © 2018 ArkPhone LLC. All rights reserved.
//

#import "LocalRadioAPI.h"
#import "AppDelegate.h"
#import "HTTPWebServerConnection.h"
#import "HTTPMessage.h"
#import "UDPStatusListenerController.h"
#import "SQLiteController.h"

@implementation LocalRadioAPI

- (NSString *)httpResponseForMethod:(NSString *)method URI:(NSString *)path webServerConnection:(HTTPWebServerConnection *)webServerConnection
{
    NSDictionary * responseDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
            @"error", @"result",
            @"Invalid Request", @"error_message", nil];
    
    NSString * messageString = nil;
    NSString * postString = nil;

    NSData * messageData = [webServerConnection requestMessageData];
    if (messageData)
    {
        messageString = [[NSString alloc] initWithData:messageData encoding:NSUTF8StringEncoding];
    }

    NSData * postData = [webServerConnection requestBody];
    
    if (postData.length > 0)
    {
        // extract POST data from HTTP request, get api-request-name and json
        postString = [[NSString alloc] initWithData:postData encoding:NSUTF8StringEncoding];

        NSURLComponents * urlComponents = [[NSURLComponents alloc] init];
        urlComponents.query = postString;
        NSArray * queryItems = urlComponents.queryItems;
        
        NSMutableDictionary * postDictionary = [NSMutableDictionary dictionary];
        
        for (NSURLQueryItem * aURLQueryItem in queryItems)
        {
            NSString * queryItemName = aURLQueryItem.name;
            NSString * queryItemValue = aURLQueryItem.value;
            
            [postDictionary setObject:queryItemValue forKey:queryItemName];
        }
        
        NSString * postRequestName = [postDictionary objectForKey:@"api-request-name"];
        
        NSString * postJSONString = [postDictionary objectForKey:@"json"];
        if (postJSONString == NULL)
        {
            postJSONString = [NSString string];
        }
        NSString * decodedJSONString = [postJSONString stringByRemovingPercentEncoding];
        NSData * jsonData = [decodedJSONString dataUsingEncoding:NSUTF8StringEncoding];

        NSDictionary * jsonDictionary = NULL;

        NSError * jsonError = nil;
        id object = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&jsonError];

        if ([object isKindOfClass:[NSDictionary class]] == YES)
        {
            jsonDictionary = object;
        }
        
        if ([postRequestName isEqualToString:@"get-audio-url"] == YES)
        {
            //NSString * audioURLString = [NSString stringWithFormat:@"https://%@:%lu/%@", self.appDelegate.localHostString, self.appDelegate.icecastServerHTTPSPort, self.appDelegate.icecastServerMountName];
            NSString * audioURLString = [NSString stringWithFormat:@"http://%@:%lu/%@", self.appDelegate.localHostIPString, self.appDelegate.icecastServerHTTPPort, self.appDelegate.icecastServerMountName];
            responseDictionary = [NSDictionary dictionaryWithObjectsAndKeys:audioURLString, @"audio-url", nil];
        }
        else if ([postRequestName isEqualToString:@"get-now-playing"] == YES)
        {
            responseDictionary = self.appDelegate.udpStatusListenerController.nowPlayingDictionary;
            
            if (responseDictionary == NULL)
            {
                responseDictionary = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"Not Playing", @"station_name", nil];
            }
        }
        else if ([postRequestName isEqualToString:@"get-all-categories"] == YES)
        {
            NSArray * allCategoriesArray = self.sqliteController.allCategoryRecords;
            responseDictionary = [NSDictionary dictionaryWithObjectsAndKeys:allCategoriesArray, @"all-categories", nil];
        }
        else if ([postRequestName isEqualToString:@"get-all-frequencies"] == YES)
        {
            NSArray * allFrequenciesArray = self.sqliteController.allFrequencyRecords;
            responseDictionary = [NSDictionary dictionaryWithObjectsAndKeys:allFrequenciesArray, @"all-frequencies", nil];
        }
        else if ([postRequestName isEqualToString:@"get-all-freq-cat"] == YES)
        {
            NSArray * allFreqCatArray = self.sqliteController.allFreqCatRecords;
            responseDictionary = [NSDictionary dictionaryWithObjectsAndKeys:allFreqCatArray, @"all-freq-cat", nil];
        }
        else if ([postRequestName isEqualToString:@"get-all-custom-tasks"] == YES)
        {
            NSArray * allFreqCatArray = self.sqliteController.allFreqCatRecords;
            responseDictionary = [NSDictionary dictionaryWithObjectsAndKeys:allFreqCatArray, @"all-custom-tasks", nil];
        }
    }

    NSError * jsonError = NULL;
    NSData * responseData = [NSJSONSerialization dataWithJSONObject:responseDictionary options:NSJSONWritingPrettyPrinted error:&jsonError];
    NSString * responseString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];

    return responseString;
}



@end

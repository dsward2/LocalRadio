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
        // for LocalRadioAPI, extract POST data from HTTP request, get api-request-name and json
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
        
        NSData * decodedBase64Data = [[NSData alloc] initWithBase64EncodedString:decodedJSONString options:0];
        NSString * decodedBase64String = [[NSString alloc] initWithData:decodedBase64Data encoding:NSUTF8StringEncoding];
        
        //NSData * jsonData = [decodedJSONString dataUsingEncoding:NSUTF8StringEncoding];
        NSData * jsonData = [decodedBase64String dataUsingEncoding:NSUTF8StringEncoding];

        NSDictionary * jsonDictionary = NULL;

        NSError * jsonError = nil;
        id object = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&jsonError];

        if ([object isKindOfClass:[NSDictionary class]] == YES)
        {
            jsonDictionary = object;
        }
        
        if ([postRequestName isEqualToString:@"get-audio-url"] == YES)
        {
            NSString * audioURLString = [NSString stringWithFormat:@"http://%@:%lu", self.appDelegate.localHostIPString, self.appDelegate.streamingServerHTTPPort];
            responseDictionary = [NSDictionary dictionaryWithObjectsAndKeys:audioURLString, @"audio-url", nil];
        }
        else if ([postRequestName isEqualToString:@"get-now-playing"] == YES)
        {
            responseDictionary = self.appDelegate.udpStatusListenerController.nowPlayingDictionary;
            
            if (responseDictionary == NULL)
            {
                responseDictionary = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"now-playing", @"station_name", nil];
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
            //NSArray * allFreqCatArray = self.sqliteController.allFreqCatRecords;
            NSArray * allCategoriesArray = self.sqliteController.allCategoryRecords;
            NSArray * allFrequenciesArray = self.sqliteController.allFrequencyRecords;
            NSArray * allFreqCatArray = [self.sqliteController sortedFreqCatRecordsWithCategoriesArray:allCategoriesArray frequenciesArray:allFrequenciesArray];
            responseDictionary = [NSDictionary dictionaryWithObjectsAndKeys:allFreqCatArray, @"all-freq-cat", nil];
        }
        else if ([postRequestName isEqualToString:@"get-all-custom-tasks"] == YES)
        {
            NSArray * allkCustomTasksArray = self.sqliteController.allCustomTaskRecords;
            responseDictionary = [NSDictionary dictionaryWithObjectsAndKeys:allkCustomTasksArray, @"all-custom-tasks", nil];
        }
        else if ([postRequestName isEqualToString:@"set-new-frequency"] == YES)
        {        
            NSNumber * frequencyIDNumber = [jsonDictionary objectForKey:@"frequency_id"];
            
            NSString * frequencyIDString = [NSString stringWithFormat:@"%@", frequencyIDNumber];
            
            if (frequencyIDString != NULL)
            {
                NSMutableDictionary * frequencyDictionary = [[self.sqliteController frequencyRecordForID:frequencyIDString] mutableCopy];
                
                [self.sdrController startRtlsdrTasksForFrequency:frequencyDictionary];
            }
            
            NSDictionary * nowPlayingDictionary = self.appDelegate.udpStatusListenerController.nowPlayingDictionary;

            if (nowPlayingDictionary == NULL)
            {
                responseDictionary = [NSMutableDictionary dictionaryWithObjectsAndKeys:nowPlayingDictionary, @"set-new-frequency-result", nil];
            }
        }
        else if ([postRequestName isEqualToString:@"set-new-custom-task"] == YES)
        {
            NSNumber * customTaskIDNumber = [jsonDictionary objectForKey:@"custom_task_id"];
            
            NSString * customTaskIDString = [NSString stringWithFormat:@"%@", customTaskIDNumber];

            if (customTaskIDString != NULL)
            {
                [self.sdrController startTasksForCustomTaskID: customTaskIDString];
            }
            
            NSDictionary * nowPlayingDictionary = self.appDelegate.udpStatusListenerController.nowPlayingDictionary;

            if (nowPlayingDictionary == NULL)
            {
                responseDictionary = [NSMutableDictionary dictionaryWithObjectsAndKeys:nowPlayingDictionary, @"set-new-frequency-result", nil];
            }
        }
    }

    NSError * jsonError = NULL;
    NSData * responseData = [NSJSONSerialization dataWithJSONObject:responseDictionary options:NSJSONWritingPrettyPrinted error:&jsonError];
    NSString * responseString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];

    return responseString;
}



@end

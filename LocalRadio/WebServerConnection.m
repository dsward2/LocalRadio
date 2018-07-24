//
//  WebServerConnection.m
//  LocalRadio
//
//  Created by Douglas Ward on 5/26/17.
//  Copyright © 2017-2018 ArkPhone LLC. All rights reserved.
//

#import "LocalRadioAppSettings.h"
#import "WebServerConnection.h"
#import "HTTPDynamicFileResponse.h"
#import "HTTPLogging.h"
#import "AppDelegate.h"
#import "SQLiteController.h"
#import "SDRController.h"
#import "IcecastController.h"
#import "NSFileManager+DirectoryLocations.h"
#import "HTTPMessage.h"
#import "UDPStatusListenerController.h"

#import <AudioToolbox/AudioServices.h>

// 	const int r82xx_gains[] = { 0, 9, 14, 27, 37, 77, 87, 125, 144, 157,
//				     166, 197, 207, 229, 254, 280, 297, 328,
//				     338, 364, 372, 386, 402, 421, 434, 439,
//				     445, 480, 496 };


// Log levels: off, error, warn, info, verbose
// Other flags: trace
static const int httpLogLevel = HTTP_LOG_LEVEL_WARN; // | HTTP_LOG_FLAG_TRACE;

@implementation WebServerConnection

//==================================================================================
//	initWithAsyncSocket:configuration:
//==================================================================================

- (id)initWithAsyncSocket:(GCDAsyncSocket *)newSocket configuration:(HTTPConfig *)aConfig
{
	if ((self = [super initWithAsyncSocket:newSocket configuration:aConfig]))
	{
        self.appDelegate = (AppDelegate *)[NSApp delegate];
        self.sqliteController = self.appDelegate.sqliteController;
        self.icecastController = self.appDelegate.icecastController;
        self.ezStreamController = self.appDelegate.ezStreamController;
        self.sdrController = self.appDelegate.sdrController;
    }
    
    return self;
}

//==================================================================================
//	supportsMethod:atPath:
//==================================================================================

- (BOOL)supportsMethod:(NSString *)method atPath:(NSString *)path
{
	HTTPLogTrace();
	
	// Add support for POST
	
	if ([method isEqualToString:@"POST"])
	{
        // add subpaths for supported pages here to fix HTTP Error 405 - Method Not Allowed error response
    
		if ([path isEqualToString:@"/storefrequency.html"])
		{
			// Let's be extra cautious, and make sure the upload isn't 5 gigs
			
			return requestContentLength < 4096;
		}
		else if ([path isEqualToString:@"/deletefrequency.html"])
		{
			// Let's be extra cautious, and make sure the upload isn't 5 gigs
			
			return requestContentLength < 4096;
		}
		else if ([path isEqualToString:@"/deletecategory.html"])
		{
			// Let's be extra cautious, and make sure the upload isn't 5 gigs
			
			return requestContentLength < 4096;
		}
		else if ([path isEqualToString:@"/insertnewfrequency.html"])
		{
			// Let's be extra cautious, and make sure the upload isn't 5 gigs
			
			return requestContentLength < 4096;
		}
		else if ([path isEqualToString:@"/storecategory.html"])
		{
			// Let's be extra cautious, and make sure the upload isn't 5 gigs
			
			return requestContentLength < 4096;
		}
		else if ([path isEqualToString:@"/addcategory.html"])
		{
			// Let's be extra cautious, and make sure the upload isn't 5 gigs
			
			return requestContentLength < 4096;
		}
		else if ([path isEqualToString:@"/listenbuttonclicked.html"])
		{
			// Let's be extra cautious, and make sure the upload isn't 5 gigs
			
			return requestContentLength < 4096;
		}
        else if ([path isEqualToString:@"/frequencylistenbuttonclicked.html"])
        {
            // Let's be extra cautious, and make sure the upload isn't 5 gigs
            
            return requestContentLength < 4096;
        }
        else if ([path isEqualToString:@"/devicelistenbuttonclicked.html"])
        {
            // Let's be extra cautious, and make sure the upload isn't 5 gigs
            
            return requestContentLength < 4096;
        }
		else if ([path isEqualToString:@"/nowplayingstatus.html"])
		{
			// Let's be extra cautious, and make sure the upload isn't 5 gigs
			
			return requestContentLength < 4096;
		}
		else if ([path isEqualToString:@"/scannerlistenbuttonclicked.html"])
		{
			// Let's be extra cautious, and make sure the upload isn't 5 gigs
			
			return requestContentLength < 4096;
		}
		else if ([path isEqualToString:@"/applymp3settings.html"])
		{
			// Let's be extra cautious, and make sure the upload isn't 5 gigs
			
			return requestContentLength < 4096;
		}
	}
	
	return [super supportsMethod:method atPath:path];
}

//==================================================================================
//	expectsRequestBodyFromMethod:atPath:
//==================================================================================

/*
- (BOOL)expectsRequestBodyFromMethod:(NSString *)method atPath:(NSString *)path
{
	HTTPLogTrace();
	
	// Inform HTTP server that we expect a body to accompany a POST request
	
	if([method isEqualToString:@"POST"])
		return YES;
	
	return [super expectsRequestBodyFromMethod:method atPath:path];
}
*/

//==================================================================================
//	httpResponseForMethod:URI:
//==================================================================================

- (NSObject<HTTPResponse> *)httpResponseForMethod:(NSString *)method URI:(NSString *)path
{
	// Use HTTPConnection's filePathForURI method.
	// This method takes the given path (which comes directly from the HTTP request),
	// and converts it to a full path by combining it with the configured document root.
	// 
	// It also does cool things for us like support for converting "/" to "/index.html",
	// and security restrictions (ensuring we don't serve documents outside configured document root folder).
    
	NSString *filePath = [self filePathForURI:path];
    
    NSURL * pathURL = [NSURL URLWithString:path];

    // TODO: remove this instrumentation, which logs the page request
    NSString * pathURLPath = [pathURL path];
    NSString * pathExtension = pathURLPath.pathExtension;
    if ([pathExtension isEqualToString:@"html"] == YES)
    {
        if ([path isEqualToString:@"/nowplayingstatus.html"] == NO)
        {
            NSLog(@"WebServerConnection httpResponseForMethod:%@ URI:%@", method, path);
        }
        else if ([self.previousPath isEqualToString:@"/nowplayingstatus.html"] == NO)
        {
            // only log the first consecutive request for /nowplayingstatus.html, which is requested several times per second
            NSLog(@"WebServerConnection httpResponseForMethod:%@ URI:%@", method, path);
        }
    }
    else
    {
        NSLog(@"WebServerConnection httpResponseForMethod:%@ URI:%@", method, path);
    }
    self.previousPath = path;

    NSURLComponents *urlComponents = [NSURLComponents componentsWithURL:pathURL
            resolvingAgainstBaseURL:NO];
    NSArray * queryItems = urlComponents.queryItems;
	
	// Convert to relative path
	
	NSString *documentRoot = [config documentRoot];
	
	if (![filePath hasPrefix:documentRoot])
	{
		// Uh oh.
		// HTTPConnection's filePathForURI was supposed to take care of this for us.
		return nil;
	}
	
	NSString * relativePath = [filePath substringFromIndex:[documentRoot length]];
    
    BOOL processDynamicPage = NO;
	
    NSString * fileExtension = [relativePath pathExtension];
    
    if ([fileExtension isEqualToString:@"html"] == YES)
    {
        processDynamicPage = YES;
    }
    
    //NSDictionary * allHeaderFields = [request allHeaderFields];
    //NSLog(@"allHeaderFields = %@", allHeaderFields);

    // allHeaderFields = {
    //     Accept = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8";
    //     "Accept-Encoding" = "gzip, deflate";
    //     "Accept-Language" = "en-us";
    //     Connection = "keep-alive";
    //     Host = "192.168.10.8:17002";
    //     Referer = "http://192.168.10.8:17002/";
    //     "User-Agent" = "LocalRadio/0.5";
    // }

    NSString * userAgentString = [request headerField:@"User-Agent"];
    
    BOOL userAgentIsLocalRadioApp = NO;
    NSRange userAgentRange = [userAgentString rangeOfString:@"LocalRadio"];
    if (userAgentRange.location != NSNotFound)
    {
        userAgentIsLocalRadioApp = YES;
    }
    
    if (processDynamicPage == YES)
    {
		HTTPLogVerbose(@"%@[%p]: Serving up dynamic content", THIS_FILE, self);
		
		// The index.html file contains several dynamic fields that need to be completed.
		// For example:
		// 
		// Computer name: %%COMPUTER_NAME%%
		// 
		// We need to replace "%%COMPUTER_NAME%%" with whatever the computer name is.
		// We can accomplish this easily with the HTTPDynamicFileResponse class,
		// which takes a dictionary of replacement key-value pairs,
		// and performs replacements on the fly as it uploads the file.

		NSMutableDictionary *replacementDict = [NSMutableDictionary dictionaryWithCapacity:5];
		
		NSString *computerName = [[NSHost currentHost] localizedName];
		[replacementDict setObject:computerName forKey:@"COMPUTER_NAME"];

		NSString *currentTime = [[NSDate date] description];
		[replacementDict setObject:currentTime  forKey:@"TIME"];

		NSString * navBarString = [self generateNavBar];
		[replacementDict setObject:navBarString  forKey:@"NAV_BAR"];

        #pragma mark relativePath=index.html
        if ([relativePath isEqualToString:@"/index.html"])
        {
            NSString * audioPlayerString = [self generateAudioPlayerString:userAgentIsLocalRadioApp];
            [replacementDict setObject:audioPlayerString forKey:@"AUDIO_PLAYER"];
        }
        #pragma mark relativePath=index2.html
        else if ([relativePath isEqualToString:@"/index2.html"])
        {
            NSString * currentTunerString = [self generateCurrentTunerString];
            [replacementDict setObject:currentTunerString forKey:@"CURRENT_TUNER"];

            NSString * favoritesIconSVGString = [self getSVGWithFileName:@"favorites.svg"];
            [replacementDict setObject:favoritesIconSVGString forKey:@"FAVORITES_ICON"];

            NSString * categoriesIconSVGString = [self getSVGWithFileName:@"categories.svg"];
            [replacementDict setObject:categoriesIconSVGString forKey:@"CATEGORIES_ICON"];

            NSString * tunerIconSVGString = [self getSVGWithFileName:@"tuner.svg"];
            [replacementDict setObject:tunerIconSVGString forKey:@"TUNER_ICON"];

            NSString * deviceIconSVGString = [self getSVGWithFileName:@"devices.svg"];
            [replacementDict setObject:deviceIconSVGString forKey:@"DEVICE_ICON"];

            NSString * settingsIconSVGString = [self getSVGWithFileName:@"gear.svg"];
            [replacementDict setObject:settingsIconSVGString forKey:@"GEAR_ICON"];

            NSString * infoIconSVGString = [self getSVGWithFileName:@"info.svg"];
            [replacementDict setObject:infoIconSVGString forKey:@"INFO_ICON"];
        }
        #pragma mark relativePath=favorites.html
        else if ([relativePath isEqualToString:@"/favorites.html"])
        {
            NSString * favoritesString = [self generateFavoritesString];
            [replacementDict setObject:favoritesString forKey:@"FAVORITES_TABLE"];
        }
        #pragma mark relativePath=viewfavorite.html
        else if ([relativePath isEqualToString:@"/viewfavorite.html"])
        {
            NSString * freqIDString = [self valueForKey:@"id" fromQueryItems:queryItems];

            NSDictionary * frequencyDictionary = [self.sqliteController frequencyRecordForID:freqIDString];
            NSString * stationNameString = [frequencyDictionary objectForKey:@"station_name"];
            [replacementDict setObject:stationNameString forKey:@"VIEW_FAVORITE_NAME"];

            NSString * viewFavoriteItemString = [self generateViewFavoriteItemStringForID:freqIDString];
            [replacementDict setObject:viewFavoriteItemString forKey:@"VIEW_FAVORITE_ITEM"];
        }
 
        
        
        
        
        
        
        
        #pragma mark relativePath=applymp3settings.html
        else if ([relativePath isEqualToString:@"/applymp3settings.html"])
        {
            // this action is for the Listen button for Favorites frequencies (not the Listen button for the full record HTML form)

            NSString * postString = nil;
            NSString * messageString = nil;
            
            NSData * postData = [request body];
            if (postData)
            {
                postString = [[NSString alloc] initWithData:postData encoding:NSUTF8StringEncoding];
            }

            NSData * messageData = [request messageData];
            if (messageData)
            {
                messageString = [[NSString alloc] initWithData:messageData encoding:NSUTF8StringEncoding];
            }
            
            NSError *error = nil;
            id object = [NSJSONSerialization
                      JSONObjectWithData:postData
                      options:0
                      error:&error];
            
            if ([object isKindOfClass:[NSDictionary class]] == YES)
            {
                NSDictionary * settingsDictionary = object;
                
                [self applyMP3Settings:settingsDictionary];
            }
            
            [replacementDict setObject:@"OK" forKey:@"APPLY_MP3_SETTINGS_BUTTON_CLICKED_RESULT"];
        }





        #pragma mark relativePath=listenbuttonclicked.html
        else if ([relativePath isEqualToString:@"/listenbuttonclicked.html"])
        {
            // this action is for the Listen button for Favorites frequencies (not the Listen button for the full record HTML form)

            NSString * postString = nil;
            NSString * messageString = nil;
            
            NSData * postData = [request body];
            if (postData)
            {
                postString = [[NSString alloc] initWithData:postData encoding:NSUTF8StringEncoding];
            }

            NSData * messageData = [request messageData];
            if (messageData)
            {
                messageString = [[NSString alloc] initWithData:messageData encoding:NSUTF8StringEncoding];
            }
            
            NSError *error = nil;
            id object = [NSJSONSerialization
                      JSONObjectWithData:postData
                      options:0
                      error:&error];
            
            if ([object isKindOfClass:[NSArray class]] == YES)
            {
                NSArray * dataArray = object;
                
                NSMutableDictionary * frequencyDictionary = [self.sqliteController makePrototypeDictionaryForTable:@"frequency"];

                NSCharacterSet * whitespaceCharacterSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
                
                for (NSDictionary * aDataDictionary in dataArray)
                {
                    NSString * dataName = [aDataDictionary objectForKey:@"name"];
                    NSString * dataValue = [aDataDictionary objectForKey:@"value"];

                    dataName = [dataName stringByTrimmingCharactersInSet:whitespaceCharacterSet];
                    dataValue = [dataValue stringByTrimmingCharactersInSet:whitespaceCharacterSet];
                    
                    id validColumnObject = [frequencyDictionary objectForKey:dataName];
                    if (validColumnObject != NULL)
                    {
                        [frequencyDictionary setObject:dataValue forKey:dataName];
                    }
                }
                
                NSString * freqIDString = [frequencyDictionary objectForKey:@"id"]; // frequencyDictionary.id normally NSNumber, but NSString here
                NSInteger freqID = freqIDString.integerValue;
                if (freqID > 0)
                {
                    [self listenButtonClickedForFrequencyID:freqIDString];
                }
                else
                {
                    [self convertNumericFieldsInFrequencyDictionary:frequencyDictionary];

                    [self listenButtonClickedForFrequency:frequencyDictionary];
                }
            }
            
            [replacementDict setObject:@"OK" forKey:@"LISTEN_BUTTON_CLICKED_RESULT"];
            
            self.appDelegate.listenMode = kListenModeFrequency;
        }
        #pragma mark relativePath=frequencylistenbuttonclicked.html
        else if ([relativePath isEqualToString:@"/frequencylistenbuttonclicked.html"])
        {
            NSString * postString = nil;
            NSString * messageString = nil;
            
            NSData * postData = [request body];
            if (postData)
            {
                postString = [[NSString alloc] initWithData:postData encoding:NSUTF8StringEncoding];
            }

            NSData * messageData = [request messageData];
            if (messageData)
            {
                messageString = [[NSString alloc] initWithData:messageData encoding:NSUTF8StringEncoding];
            }
            
            NSError *error = nil;
            id object = [NSJSONSerialization
                      JSONObjectWithData:postData
                      options:0
                      error:&error];
            
            if ([object isKindOfClass:[NSDictionary class]] == YES)
            {
                NSDictionary * listenDictionary = object;
                
                NSString * freqString = [listenDictionary objectForKey:@"frequency"];
                NSInteger freqValue = [freqString integerValue];
                NSNumber * freqNumber = [NSNumber numberWithInteger:freqValue];
                
                NSString * sampleRateString = [listenDictionary objectForKey:@"sample_rate"];
                NSInteger sampleRateValue = [sampleRateString integerValue];
                NSNumber * sampleRateNumber = [NSNumber numberWithInteger:sampleRateValue];
                
                NSString * tunerGainString = [listenDictionary objectForKey:@"tuner_gain"];
                CGFloat tunerGainValue = [tunerGainString floatValue];
                NSNumber * tunerGainNumber = [NSNumber numberWithFloat:tunerGainValue];
                
                //NSMutableDictionary * frequencyDictionary = [self.sqliteController makePrototypeDictionaryForTable:@"frequency"];
                
                NSMutableDictionary * frequencyDictionary = self.constructFrequencyDictionary;
                
                if (frequencyDictionary == NULL)
                {
                    frequencyDictionary = [self.sqliteController makePrototypeDictionaryForTable:@"frequency"];
                }
                
                [frequencyDictionary setObject:freqNumber forKey:@"frequency"];
                [frequencyDictionary setObject:sampleRateNumber forKey:@"sample_rate"];
                [frequencyDictionary setObject:tunerGainNumber forKey:@"tuner_gain"];

                [self listenButtonClickedForFrequency:frequencyDictionary];
            }
            
            [replacementDict setObject:@"OK" forKey:@"LISTEN_BUTTON_CLICKED_RESULT"];

            self.appDelegate.listenMode = kListenModeFrequency;
        }
        #pragma mark relativePath=devicelistenbuttonclicked.html
        else if ([relativePath isEqualToString:@"/devicelistenbuttonclicked.html"])
        {
            NSString * postString = nil;
            NSString * messageString = nil;
            
            NSData * postData = [request body];
            if (postData)
            {
                postString = [[NSString alloc] initWithData:postData encoding:NSUTF8StringEncoding];
            }

            NSData * messageData = [request messageData];
            if (messageData)
            {
                messageString = [[NSString alloc] initWithData:messageData encoding:NSUTF8StringEncoding];
            }
            
            NSError *error = nil;
            id object = [NSJSONSerialization
                      JSONObjectWithData:postData
                      options:0
                      error:&error];
            
            if ([object isKindOfClass:[NSArray class]] == YES)
            {
                NSArray * deviceArray = object;
                
                if (deviceArray.count == 1)
                {
                    id deviceArrayObject = deviceArray.firstObject;
                    if ([deviceArrayObject isKindOfClass:[NSDictionary class]] == YES)
                    {
                        NSMutableDictionary * deviceDictionary = [deviceArrayObject mutableCopy];
                        
                        NSString * settingName = [deviceDictionary objectForKey:@"name"];
                        if ([settingName isEqualToString:@"audio_output"] == YES)
                        {
                            NSString * deviceName = [deviceDictionary objectForKey:@"value"];
                        
                            [self listenButtonClickedForDevice:deviceName];
                        }
                    }
                }
            }
            
            [replacementDict setObject:@"OK" forKey:@"DEVICE_LISTEN_BUTTON_CLICKED_RESULT"];

            self.appDelegate.listenMode = kListenModeDevice;
        }
        #pragma mark relativePath=nowplaying.html
        else if ([relativePath isEqualToString:@"/nowplaying.html"])
        {
            //NSString * nowPlayingNameString = self.appDelegate.statusFunctionTextField.stringValue;
            NSString * nowPlayingNameString = self.sdrController.statusFunctionString;
            if (nowPlayingNameString == NULL)
            {
                nowPlayingNameString = @"";
            }
            [replacementDict setObject:nowPlayingNameString forKey:@"NOW_PLAYING_NAME"];
            
            //NSString * frequencyString = self.appDelegate.statusFrequencyTextField.stringValue;
            //NSString * modulationString = self.appDelegate.statusModulationTextField.stringValue;
            //NSString * sampleRateString = self.appDelegate.statusSamplingRateTextField.stringValue;

            NSString * frequencyString = self.appDelegate.statusFrequency;
            NSString * modulationString = self.appDelegate.statusModulation;
            NSString * sampleRateString = self.appDelegate.statusSamplingRate;

            NSString * nowPlayingDetailsString = [NSString stringWithFormat:@"<br><br>frequency: %@<br>modulation: %@<br>sample rate: %@<br><br>", frequencyString, modulationString, sampleRateString];

            [replacementDict setObject:nowPlayingDetailsString forKey:@"NOW_PLAYING_DETAILS"];
            
            NSString * openAudioPlayerPageButtonString = [self generateOpenAudioPlayerPageButtonString];
            
            [replacementDict setObject:openAudioPlayerPageButtonString forKey:@"OPEN_AUDIO_PLAYER_PAGE_BUTTON"];
        }
        #pragma mark relativePath=nowplayingstatus.html
        else if ([relativePath isEqualToString:@"/nowplayingstatus.html"])
        {
            NSString * nowPlayingStatusString = [self generateNowPlayingStatusString];

            [replacementDict setObject:nowPlayingStatusString forKey:@"NOW_PLAYING_STATUS_RESULT"];
        }
        #pragma mark relativePath=editfavorite.html
        else if ([relativePath isEqualToString:@"/editfavorite.html"])
        {
            NSString * freqIDString = [self valueForKey:@"id" fromQueryItems:queryItems];
            
            NSDictionary * frequencyDictionary = [self.sqliteController frequencyRecordForID:freqIDString];
            NSString * stationNameString = [frequencyDictionary objectForKey:@"station_name"];
            [replacementDict setObject:stationNameString forKey:@"EDIT_FAVORITE_NAME"];

            NSString * viewListenItemString = [self generateEditFrequencyFormStringForID:freqIDString];
            [replacementDict setObject:viewListenItemString forKey:@"EDIT_FAVORITE"];
        }
        #pragma mark relativePath=storecategory.html
        //else if ([method isEqualToString:@"POST"] && [relativePath isEqualToString:@"/storecategory.html"])
        else if ([relativePath isEqualToString:@"/storecategory.html"])
        {
            NSString * postString = nil;
            NSString * messageString = nil;
            
            NSData * postData = [request body];
            if (postData)
            {
                postString = [[NSString alloc] initWithData:postData encoding:NSUTF8StringEncoding];
            }

            NSData * messageData = [request messageData];
            if (messageData)
            {
                messageString = [[NSString alloc] initWithData:messageData encoding:NSUTF8StringEncoding];
            }
            
            NSError *error = nil;
            id object = [NSJSONSerialization
                      JSONObjectWithData:postData
                      options:0
                      error:&error];
            
            if ([object isKindOfClass:[NSArray class]] == YES)
            {
                NSArray * dataArray = object;
                
                NSMutableDictionary * categoryDictionary = [NSMutableDictionary dictionary];

                NSCharacterSet * whitespaceCharacterSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
                
                for (NSDictionary * aDataDictionary in dataArray)
                {
                    NSString * dataName = [aDataDictionary objectForKey:@"name"];
                    NSString * dataValue = [aDataDictionary objectForKey:@"value"];

                    dataName = [dataName stringByTrimmingCharactersInSet:whitespaceCharacterSet];
                    dataValue = [dataValue stringByTrimmingCharactersInSet:whitespaceCharacterSet];
                    
                    if ([dataName isEqualToString:@"scan_audio_output"] == YES)
                    {
                        if ([dataValue isEqualToString:@"Built-in Icecast Server"] == YES)
                        {
                            dataValue = @"icecast";
                        }
                    }

                    if ([dataName isEqualToString:@"scan_sampling_mode"] == YES)
                    {
                        if ([dataValue isEqualToString:@"sampling_mode_standard"] == YES)
                        {
                            dataValue = @"0";
                        }
                        else if ([dataValue isEqualToString:@"sampling_mode_direct"] == YES)
                        {
                            dataValue = @"2";
                        }
                    }

                    if ([dataName isEqualToString:@"scan_tuner_agc"] == YES)
                    {
                        if ([dataValue isEqualToString:@"agc_mode_off"] == YES)
                        {
                            dataValue = @"0";
                        }
                        else if ([dataValue isEqualToString:@"agc_mode_on"] == YES)
                        {
                            dataValue = @"1";
                        }
                    }
                    
                    [categoryDictionary setObject:dataValue forKey:dataName];
                }
                
                [self.sqliteController storeRecord:categoryDictionary table:@"category"];

                //NSLog(@"categoryDictionary = %@", categoryDictionary);

                if (self.appDelegate.listenMode == kListenModeScan)
                {
                    NSNumber * categoryIDNumber = [categoryDictionary objectForKey:@"id"];
                    if (categoryIDNumber != NULL)
                    {
                        NSInteger categoryID = categoryIDNumber.integerValue;
                        
                        if (categoryID != 0)
                        {
                            dispatch_sync(dispatch_get_main_queue(), ^{
                                NSInteger nowScanningCategoryID = self.appDelegate.statusFrequencyIDTextField.integerValue;
                            
                                if (categoryID == nowScanningCategoryID)
                                {
                                    NSString * categoryIDString = [NSString stringWithFormat:@"%ld", categoryID];
                                    [self scannerListenButtonClickedForCategoryID:categoryIDString];
                                }
                            });
                        }
                    }
                }
            }


            [replacementDict setObject:@"OK" forKey:@"STORE_CATEGORY_RESULT"];
        }
        #pragma mark relativePath=addcategory.html
        else if ([relativePath isEqualToString:@"/addcategory.html"])
        {
            NSString * postString = nil;
            NSString * messageString = nil;
            
            NSData * postData = [request body];
            if (postData)
            {
                postString = [[NSString alloc] initWithData:postData encoding:NSUTF8StringEncoding];
            }

            NSData * messageData = [request messageData];
            if (messageData)
            {
                messageString = [[NSString alloc] initWithData:messageData encoding:NSUTF8StringEncoding];
            }
            
            NSError *error = nil;
            id object = [NSJSONSerialization
                      JSONObjectWithData:postData
                      options:0
                      error:&error];
            
            if ([object isKindOfClass:[NSArray class]] == YES)
            {
                NSArray * dataArray = object;
                
                NSMutableDictionary * categoryDictionary = [self.sqliteController makePrototypeDictionaryForTable:@"category"];

                NSCharacterSet * whitespaceCharacterSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
                
                for (NSDictionary * aDataDictionary in dataArray)
                {
                    NSString * dataName = [aDataDictionary objectForKey:@"name"];
                    NSString * dataValue = [aDataDictionary objectForKey:@"value"];

                    dataName = [dataName stringByTrimmingCharactersInSet:whitespaceCharacterSet];
                    dataValue = [dataValue stringByTrimmingCharactersInSet:whitespaceCharacterSet];
                    
                    [categoryDictionary setObject:dataValue forKey:dataName];
                }
                
                [categoryDictionary removeObjectForKey:@"id"];
                
                NSString * newCategoryName = [categoryDictionary objectForKey:@"category_name"];
                
                // check for existing category name
                NSDictionary * existingCategoryDictionary = [self.sqliteController categoryRecordForName:newCategoryName];
                
                if (existingCategoryDictionary == NULL)
                {
                    // no existing category found for name, so create new category record
                    [self.sqliteController storeRecord:categoryDictionary table:@"category"];
                }
                //NSLog(@"categoryDictionary = %@", categoryDictionary);
            }


            [replacementDict setObject:@"OK" forKey:@"ADD_CATEGORY_RESULT"];
        }
        #pragma mark relativePath=addcategoryform.html
        else if ([relativePath isEqualToString:@"/addcategoryform.html"])
        {
        }
        #pragma mark relativePath=storefrequency.html
        //else if ([method isEqualToString:@"POST"] && [relativePath isEqualToString:@"/storefrequency.html"])
        else if ([relativePath isEqualToString:@"/storefrequency.html"])
        {
            NSString * postString = nil;
            NSString * messageString = nil;
            
            NSData * postData = [request body];
            if (postData)
            {
                postString = [[NSString alloc] initWithData:postData encoding:NSUTF8StringEncoding];
            }

            NSData * messageData = [request messageData];
            if (messageData)
            {
                messageString = [[NSString alloc] initWithData:messageData encoding:NSUTF8StringEncoding];
            }
            
            NSError *error = nil;
            id object = [NSJSONSerialization
                      JSONObjectWithData:postData
                      options:0
                      error:&error];
            
            if ([object isKindOfClass:[NSArray class]] == YES)
            {
                NSArray * dataArray = object;
                
                NSMutableDictionary * prototypeDictionary = [self.sqliteController makePrototypeDictionaryForTable:@"frequency"];
                
                NSMutableDictionary * frequencyDictionary = [NSMutableDictionary dictionary];

                NSCharacterSet * whitespaceCharacterSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
                
                for (NSDictionary * aDataDictionary in dataArray)
                {
                    NSString * dataName = [aDataDictionary objectForKey:@"name"];
                    NSString * dataValue = [aDataDictionary objectForKey:@"value"];

                    dataName = [dataName stringByTrimmingCharactersInSet:whitespaceCharacterSet];
                    dataValue = [dataValue stringByTrimmingCharactersInSet:whitespaceCharacterSet];
                    
                    id validColumn = [prototypeDictionary objectForKey:dataName];
                    if (validColumn != NULL)
                    {
                        if ([dataName isEqualToString:@"audio_output"] == YES)
                        {
                            if ([dataValue isEqualToString:@"Built-in Icecast Server"] == YES)
                            {
                                dataValue = @"icecast";
                            }
                        }
                        
                        if ([dataName isEqualToString:@"frequency_mode"] == YES)
                        {
                            if ([dataValue isEqualToString:@"frequency_mode_single"] == YES)
                            {
                                dataValue = @"0";
                            }
                            else if ([dataValue isEqualToString:@"frequency_mode_range"] == YES)
                            {
                                dataValue = @"1";
                            }
                        }

                        if ([dataName isEqualToString:@"sampling_mode"] == YES)
                        {
                            if ([dataValue isEqualToString:@"sampling_mode_standard"] == YES)
                            {
                                dataValue = @"0";
                            }
                            else if ([dataValue isEqualToString:@"sampling_mode_direct"] == YES)
                            {
                                dataValue = @"2";
                            }
                        }
                        
                        if ([dataName isEqualToString:@"tuner_agc"] == YES)
                        {
                            if ([dataValue isEqualToString:@"agc_mode_off"] == YES)
                            {
                                dataValue = @"0";
                            }
                            else if ([dataValue isEqualToString:@"agc_mode_on"] == YES)
                            {
                                dataValue = @"1";
                            }
                        }
                        
                        [frequencyDictionary setObject:dataValue forKey:dataName];
                    }
                }

                /*
                NSString * frequencyMegahertzString = [frequencyDictionary objectForKey:@"frequency"];
                NSInteger frequencyInteger = [self.appDelegate hertzWithString:frequencyMegahertzString];
                NSNumber * frequencyNumber = [NSNumber numberWithInteger:frequencyInteger];
                [frequencyDictionary setObject:frequencyNumber forKey:@"frequency"];
                
                NSString * frequencyScanEndMegahertzString = [frequencyDictionary objectForKey:@"frequency_scan_end"];
                NSInteger frequencyScanEndInteger = [self.appDelegate hertzWithString:frequencyScanEndMegahertzString];
                NSNumber * frequencyScanEndNumber = [NSNumber numberWithInteger:frequencyScanEndInteger];
                [frequencyDictionary setObject:frequencyScanEndNumber forKey:@"frequency_scan_end"];
                
                NSString * frequencyScanIntervalMegahertzString = [frequencyDictionary objectForKey:@"frequency_scan_interval"];
                //NSInteger frequencyScanIntervalInteger = [self.appDelegate hertzWithString:frequencyScanIntervalMegahertzString];
                NSInteger frequencyScanIntervalInteger = [frequencyScanIntervalMegahertzString integerValue];
                NSNumber * frequencyScanIntervalNumber = [NSNumber numberWithInteger:frequencyScanIntervalInteger];
                [frequencyDictionary setObject:frequencyScanIntervalNumber forKey:@"frequency_scan_interval"];
                */
                
                [self convertNumericFieldsInFrequencyDictionary:frequencyDictionary];
                
                [self.sqliteController storeRecord:frequencyDictionary table:@"frequency"];

                //NSLog(@"storeRecord frequencyDictionary = %@", frequencyDictionary);
                
                // if the stored record is the currently playing audio, restart rtl_fm_localradio with new parameters for this record
                
                if (self.appDelegate.listenMode == kListenModeFrequency)
                {
                    NSNumber * frequencyIDNumber = [frequencyDictionary objectForKey:@"id"];
                    if (frequencyIDNumber != NULL)
                    {
                        NSInteger frequencyID = frequencyIDNumber.integerValue;
                        
                        if (frequencyID != 0)
                        {
                            dispatch_sync(dispatch_get_main_queue(), ^{
                                NSInteger nowPlayingFrequencyID = self.appDelegate.statusFrequencyIDTextField.integerValue;
                            
                                if (frequencyID == nowPlayingFrequencyID)
                                {
                                    NSString * frequencyIDString = [NSString stringWithFormat:@"%ld", frequencyID];
                                    [self listenButtonClickedForFrequencyID:frequencyIDString];
                                }
                            });
                        }
                    }
                }
            }


            [replacementDict setObject:@"OK" forKey:@"STORE_FREQUENCY_RESULT"];
        }
        #pragma mark relativePath=deletefrequency.html
        else if ([relativePath isEqualToString:@"/deletefrequency.html"])
        {
            NSString * postString = nil;
            NSString * messageString = nil;
            
            NSData * postData = [request body];
            if (postData)
            {
                postString = [[NSString alloc] initWithData:postData encoding:NSUTF8StringEncoding];
            }

            NSData * messageData = [request messageData];
            if (messageData)
            {
                messageString = [[NSString alloc] initWithData:messageData encoding:NSUTF8StringEncoding];
            }
            
            NSError *error = nil;
            id object = [NSJSONSerialization
                      JSONObjectWithData:postData
                      options:0
                      error:&error];
            
            if ([object isKindOfClass:[NSArray class]] == YES)
            {
                NSArray * dataArray = object;
                
                NSMutableDictionary * frequencyDictionary = [NSMutableDictionary dictionary];

                NSCharacterSet * whitespaceCharacterSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
                
                for (NSDictionary * aDataDictionary in dataArray)
                {
                    NSString * dataName = [aDataDictionary objectForKey:@"name"];
                    NSString * dataValue = [aDataDictionary objectForKey:@"value"];

                    dataName = [dataName stringByTrimmingCharactersInSet:whitespaceCharacterSet];
                    dataValue = [dataValue stringByTrimmingCharactersInSet:whitespaceCharacterSet];
                    
                    [frequencyDictionary setObject:dataValue forKey:dataName];
                }

                NSString * frequencyIDString = [frequencyDictionary objectForKey:@"frequency_id"];
                
                [self.sqliteController deleteFrequencyRecordForID:frequencyIDString];

                NSLog(@"frequencyDictionary = %@", frequencyDictionary);
            }

            [replacementDict setObject:@"OK" forKey:@"DELETE_FREQUENCY_RESULT"];
        }
        #pragma mark relativePath=deletecategory.html
        else if ([relativePath isEqualToString:@"/deletecategory.html"])
        {
            NSString * postString = nil;
            NSString * messageString = nil;
            
            NSData * postData = [request body];
            if (postData)
            {
                postString = [[NSString alloc] initWithData:postData encoding:NSUTF8StringEncoding];
            }

            NSData * messageData = [request messageData];
            if (messageData)
            {
                messageString = [[NSString alloc] initWithData:messageData encoding:NSUTF8StringEncoding];
            }
            
            NSError *error = nil;
            id object = [NSJSONSerialization
                      JSONObjectWithData:postData
                      options:0
                      error:&error];
            
            if ([object isKindOfClass:[NSArray class]] == YES)
            {
                NSArray * dataArray = object;
                
                NSMutableDictionary * categoryDictionary = [NSMutableDictionary dictionary];

                NSCharacterSet * whitespaceCharacterSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
                
                for (NSDictionary * aDataDictionary in dataArray)
                {
                    NSString * dataName = [aDataDictionary objectForKey:@"name"];
                    NSString * dataValue = [aDataDictionary objectForKey:@"value"];

                    dataName = [dataName stringByTrimmingCharactersInSet:whitespaceCharacterSet];
                    dataValue = [dataValue stringByTrimmingCharactersInSet:whitespaceCharacterSet];
                    
                    [categoryDictionary setObject:dataValue forKey:dataName];
                }

                NSString * categoryIDString = [categoryDictionary objectForKey:@"category_id"];
                
                [self.sqliteController deleteCategoryRecordForID:categoryIDString];

                //NSLog(@"categoryDictionary = %@", categoryDictionary);
            }

            [replacementDict setObject:@"OK" forKey:@"DELETE_CATEGORY_RESULT"];
        }
        #pragma mark relativePath=editcategorysettings.html
        else if ([relativePath isEqualToString:@"/editcategorysettings.html"])
        {
            NSString * categoryIDString = [self valueForKey:@"id" fromQueryItems:queryItems];
            
            NSDictionary * categoryDictionary = [self.sqliteController categoryRecordForID:categoryIDString];
            NSString * categoryNameString = [categoryDictionary objectForKey:@"category_name"];
            [replacementDict setObject:categoryNameString forKey:@"EDIT_CATEGORY_NAME"];

            NSString * editCategoryItemString = [self generateEditCategorySettingsStringForID:categoryIDString];
            [replacementDict setObject:editCategoryItemString forKey:@"EDIT_CATEGORY_SETTINGS"];
        }
        #pragma mark relativePath=categories.html
        else if ([relativePath isEqualToString:@"/categories.html"])
        {
            NSString * categoriesString = [self generateCategoriesString];
            [replacementDict setObject:categoriesString forKey:@"CATEGORIES_TABLE"];
        }
        #pragma mark relativePath=editcategory.html
        else if ([relativePath isEqualToString:@"/editcategory.html"])
        {
            NSString * categoryIDString = [self valueForKey:@"id" fromQueryItems:queryItems];

            NSDictionary * categoryDictionary = [self.sqliteController categoryRecordForID:categoryIDString];
            NSString * categoryNameString = [categoryDictionary objectForKey:@"category_name"];
            [replacementDict setObject:categoryNameString forKey:@"EDIT_CATEGORY_NAME"];
        
            NSString * editCategoryString = [self generateEditCategoryString:categoryIDString];
            [replacementDict setObject:editCategoryString forKey:@"EDIT_CATEGORY_TABLE"];

            NSString * deleteCategoryButtonString = [self generateDeleteCategoryButtonStringForID:categoryIDString name:categoryNameString];

            [replacementDict setObject:deleteCategoryButtonString forKey:@"DELETE_CATEGORY_BUTTON"];
        }
        #pragma mark relativePath=editcategoryitem.html
        else if ([relativePath isEqualToString:@"/editcategoryitem.html"])
        {
            // this is a web service call, no page required in response
            NSString * catIDString = [self valueForKey:@"cat_id" fromQueryItems:queryItems];
            NSString * freqIDString = [self valueForKey:@"freq_id" fromQueryItems:queryItems];
            NSString * isMemberString = [self valueForKey:@"is_member" fromQueryItems:queryItems];
            
            NSInteger catID = catIDString.integerValue;
            NSInteger freqID = freqIDString.integerValue;
            BOOL isMember = NO;
            if ([isMemberString isEqualToString:@"true"])
            {
                isMember = YES;
            }
            
            [self editCategoryID:catID frequencyID:freqID isMember:isMember];

            [replacementDict setObject:@"OK" forKey:@"EDIT_CATEGORY_ITEM_RESULT"];
            
        }
        #pragma mark relativePath=category.html
        else if ([relativePath isEqualToString:@"/category.html"])
        {
            NSString * idString = [self valueForKey:@"id" fromQueryItems:queryItems];
            NSDictionary * categoryDictionary = [self.sqliteController categoryRecordForID:idString];

            NSMutableString * scanCategoryButtonString = [NSMutableString string];
            NSNumber * categoryScanningEnabled = [categoryDictionary objectForKey:@"category_scanning_enabled"];
            if ([categoryScanningEnabled integerValue] == 1)
            {
                [scanCategoryButtonString appendString:@"<form id='scannerlistenForm' action='#'>"];
                
                NSString * idInputString = [NSString stringWithFormat:@"<input type='hidden' name='id' value='%@'>", idString];
                [scanCategoryButtonString appendString:idInputString];

                NSString * listenButtonString = @"<br><input class='twelve columns button button-primary' type='button' value='Scan All Frequencies' onclick=\"var listenForm=getElementById('listenForm'); scannerListenButtonClicked(scannerlistenForm);\">";
                [scanCategoryButtonString appendString:listenButtonString];

                [scanCategoryButtonString appendString:@"</form><br>&nbsp;<br>\n"];
            }
            [replacementDict setObject:scanCategoryButtonString forKey:@"SCAN_CATEGORY_BUTTON"];

            NSString * scannerSettingsButtonString = [NSString stringWithFormat:@"<form action='javascript:loadContent(\"editcategorysettings.html?id=%@\")'><input class='button twelve columns' type='submit' value='Category Settings'><input type='hidden' name='id' value='%@'></form><br>&nbsp;<br>\n", idString, idString];
            [replacementDict setObject:scannerSettingsButtonString forKey:@"CATEGORY_SETTINGS_BUTTON"];

            NSString * editCategoryButtonString = [NSString stringWithFormat:@"<form action='javascript:loadContent(\"editcategory.html?id=%@\")'><input class='button twelve columns' type='submit' value='Edit Frequencies List'><input type='hidden' name='id' value='%@'></form><br>&nbsp;<br>\n", idString, idString];
            [replacementDict setObject:editCategoryButtonString forKey:@"EDIT_CATEGORY_LIST_BUTTON"];

            NSString * categoryName = [categoryDictionary objectForKey:@"category_name"];
            [replacementDict setObject:categoryName forKey:@"CATEGORY_NAME"];

            NSString * categoryString = [self generateCategoryFavoritesString:idString];
            [replacementDict setObject:categoryString forKey:@"CATEGORY_TABLE"];

        }
        #pragma mark relativePath=tuner.html
        else if ([relativePath isEqualToString:@"/tuner.html"])
        {
            
        }
        #pragma mark relativePath=credits.html
        else if ([relativePath isEqualToString:@"/credits.html"])
        {
            
        }
        #pragma mark relativePath=settings.html
        else if ([relativePath isEqualToString:@"/settings.html"])
        {
            NSString * bitrateSelectString = [self generateMP3BitrateSelectString];
            [replacementDict setObject:bitrateSelectString forKey:@"MP3_BITRATE_SELECT"];
            
            NSString * encodingQualitySelectString = [self generateMP3EncodingQualitySelectString];
            [replacementDict setObject:encodingQualitySelectString forKey:@"MP3_ENCODING_QUALITY_SELECT"];
        }
        #pragma mark relativePath=info.html
        else if ([relativePath isEqualToString:@"/info.html"])
        {
            NSString * settingsIconSVGString = [self getSVGWithFileName:@"LocalRadio-animation.svg"];
            [replacementDict setObject:settingsIconSVGString forKey:@"LOCALRADIO_ANIMATION"];
        }
        #pragma mark relativePath=tuner_wbfm.html
        else if ([relativePath isEqualToString:@"/tuner_wbfm.html"])
        {
            self.constructFrequencyDictionary = [self.sqliteController makePrototypeDictionaryForTable:@"frequency"];
            
            // set custom values for wbfm properties not shown on the UI
            [self.constructFrequencyDictionary setObject:@"Untitled FM Station" forKey:@"station_name"];
            [self.constructFrequencyDictionary setObject:[NSNumber numberWithInteger:2] forKey:@"oversampling"];
            [self.constructFrequencyDictionary setObject:@"vol 1 deemph dither -s" forKey:@"audio_output_filter"];

            NSString * categorySelectString = [self generateCategorySelectOptions];
            [replacementDict setObject:categorySelectString forKey:@"CATEGORY_SELECT"];

        }
        #pragma mark relativePath=tuner_general.html
        else if ([relativePath isEqualToString:@"/tuner_general.html"])
        {
            self.constructFrequencyDictionary = [self.sqliteController makePrototypeDictionaryForTable:@"frequency"];

            // set custom values for fm properties not shown on the UI
            [self.constructFrequencyDictionary setObject:@"Untitled FM Frequency" forKey:@"station_name"];
            [self.constructFrequencyDictionary setObject:[NSNumber numberWithInteger:4] forKey:@"oversampling"];
            [self.constructFrequencyDictionary setObject:@"vol 1 deemph dither -s" forKey:@"audio_output_filter"];


            NSString * categorySelectString = [self generateCategorySelectOptions];
            [replacementDict setObject:categorySelectString forKey:@"CATEGORY_SELECT"];
        }
        #pragma mark relativePath=tuner_am.html
        else if ([relativePath isEqualToString:@"/tuner_am.html"])
        {
            self.constructFrequencyDictionary = [self.sqliteController makePrototypeDictionaryForTable:@"frequency"];

            // set custom values for wbfm properties not shown on the UI
            [self.constructFrequencyDictionary setObject:@"Untitled AM Frequency" forKey:@"station_name"];
            [self.constructFrequencyDictionary setObject:@"am" forKey:@"modulation"];
            [self.constructFrequencyDictionary setObject:[NSNumber numberWithInteger:4] forKey:@"oversampling"];
            [self.constructFrequencyDictionary setObject:[NSNumber numberWithInteger:10000] forKey:@"sample_rate"];
            [self.constructFrequencyDictionary setObject:[NSNumber numberWithInteger:2] forKey:@"sampling_mode"];
            [self.constructFrequencyDictionary setObject:@"swagc" forKey:@"options"];
            [self.constructFrequencyDictionary setObject:@"vol 4" forKey:@"audio_output_filter"];

            NSString * categorySelectString = [self generateCategorySelectOptions];
            [replacementDict setObject:categorySelectString forKey:@"CATEGORY_SELECT"];
        }
        #pragma mark relativePath=tuner_aviation.html
        else if ([relativePath isEqualToString:@"/tuner_aviation.html"])
        {
            self.constructFrequencyDictionary = [self.sqliteController makePrototypeDictionaryForTable:@"frequency"];

            // set custom values for aviation properties not shown on the UI
            [self.constructFrequencyDictionary setObject:@"Untitled Airband Frequency" forKey:@"station_name"];
            [self.constructFrequencyDictionary setObject:@"am" forKey:@"modulation"];
            [self.constructFrequencyDictionary setObject:[NSNumber numberWithInteger:4] forKey:@"oversampling"];
            [self.constructFrequencyDictionary setObject:[NSNumber numberWithInteger:5000] forKey:@"sample_rate"];
            //[self.constructFrequencyDictionary setObject:@"swagc" forKey:@"options"];
            [self.constructFrequencyDictionary setObject:@"vol 4" forKey:@"audio_output_filter"];
            [self.constructFrequencyDictionary setObject:[NSNumber numberWithInteger:0] forKey:@"squelch_level"];

            NSString * categorySelectString = [self generateCategorySelectOptions];
            [replacementDict setObject:categorySelectString forKey:@"CATEGORY_SELECT"];
        }
        #pragma mark relativePath=tuner_advanced.html
        else if ([relativePath isEqualToString:@"/tuner_advanced.html"])
        {
            self.constructFrequencyDictionary = [self.sqliteController makePrototypeDictionaryForTable:@"frequency"];

            // set custom values for wbfm properties not shown on the UI
            [self.constructFrequencyDictionary setObject:@"Untitled Frequency" forKey:@"station_name"];

            NSString * tunerFormString = [self generateEditFrequencyFormStringForFrequency:self.constructFrequencyDictionary];
            [replacementDict setObject:tunerFormString forKey:@"TUNER_FORM"];

            //NSString * categorySelectString = [self generateCategorySelectOptions];
            //[replacementDict setObject:categorySelectString forKey:@"CATEGORY_SELECT"];
        }
        #pragma mark relativePath=devices.html
        else if ([relativePath isEqualToString:@"/devices.html"])
        {
            self.constructFrequencyDictionary = [self.sqliteController makePrototypeDictionaryForTable:@"frequency"];

            // set custom values for wbfm properties not shown on the UI
            [self.constructFrequencyDictionary setObject:@"Audio Device" forKey:@"station_name"];

            NSString * devicesFormString = [self generateDevicesFormString];
            [replacementDict setObject:devicesFormString forKey:@"DEVICES_FORM"];
        }
        #pragma mark relativePath=insertnewfrequency.html
        else if ([relativePath isEqualToString:@"/insertnewfrequency.html"])
        {
            NSString * postString = nil;
            NSString * messageString = nil;
            
            NSData * postData = [request body];
            if (postData)
            {
                postString = [[NSString alloc] initWithData:postData encoding:NSUTF8StringEncoding];
            }

            NSData * messageData = [request messageData];
            if (messageData)
            {
                messageString = [[NSString alloc] initWithData:messageData encoding:NSUTF8StringEncoding];
            }
            
            NSError *error = nil;
            id object = [NSJSONSerialization
                      JSONObjectWithData:postData
                      options:0
                      error:&error];
            
            if ([object isKindOfClass:[NSArray class]] == YES)
            {
                NSArray * dataArray = object;
                
                NSMutableDictionary * frequencyDictionary = [self.sqliteController makePrototypeDictionaryForTable:@"frequency"];
                //NSMutableDictionary * frequencyDictionary = self.constructFrequencyDictionary;
                
                [frequencyDictionary removeObjectForKey:@"id"];

                NSCharacterSet * whitespaceCharacterSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
                
                NSString * categoryIDString = NULL;
                
                for (NSDictionary * aDataDictionary in dataArray)
                {
                    NSString * dataName = [aDataDictionary objectForKey:@"name"];
                    NSString * dataValue = [aDataDictionary objectForKey:@"value"];

                    dataName = [dataName stringByTrimmingCharactersInSet:whitespaceCharacterSet];
                    dataValue = [dataValue stringByTrimmingCharactersInSet:whitespaceCharacterSet];

                    id validField = [frequencyDictionary objectForKey:dataName];
                    if (validField != NULL)
                    {
                        if ([dataName isEqualToString:@"audio_output"] == YES)
                        {
                            if ([dataValue isEqualToString:@"Built-in Icecast Server"] == YES)
                            {
                                dataValue = @"icecast";
                            }
                        }
                        
                        if ([dataName isEqualToString:@"frequency_mode"] == YES)
                        {
                            if ([dataValue isEqualToString:@"frequency_mode_single"] == YES)
                            {
                                dataValue = @"0";
                            }
                            else if ([dataValue isEqualToString:@"frequency_mode_range"] == YES)
                            {
                                dataValue = @"1";
                            }
                        }

                        if ([dataName isEqualToString:@"sampling_mode"] == YES)
                        {
                            if ([dataValue isEqualToString:@"sampling_mode_standard"] == YES)
                            {
                                dataValue = @"0";
                            }
                            else if ([dataValue isEqualToString:@"sampling_mode_direct"] == YES)
                            {
                                dataValue = @"2";
                            }
                        }
                        
                        if ([dataName isEqualToString:@"tuner_agc"] == YES)
                        {
                            if ([dataValue isEqualToString:@"agc_mode_off"] == YES)
                            {
                                dataValue = @"0";
                            }
                            else if ([dataValue isEqualToString:@"agc_mode_on"] == YES)
                            {
                                dataValue = @"1";
                            }
                        }
                    
                        [frequencyDictionary setObject:dataValue forKey:dataName];
                    }
                    else
                    {
                        if ([dataName isEqualToString:@"categories_select"] == YES)
                        {
                            categoryIDString = dataValue;
                        }
                    }
                }

                /*
                id frequencyMegahertzObject = [frequencyDictionary objectForKey:@"frequency"];
                if ([frequencyMegahertzObject isKindOfClass:[NSString class]] == YES)
                {
                    NSInteger frequencyInteger = [self.appDelegate hertzWithString:frequencyMegahertzObject];
                    NSNumber * frequencyNumber = [NSNumber numberWithInteger:frequencyInteger];
                    [frequencyDictionary setObject:frequencyNumber forKey:@"frequency"];
                }
                
                id frequencyScanEndMegahertzObject = [frequencyDictionary objectForKey:@"frequency_scan_end"];
                if ([frequencyScanEndMegahertzObject isKindOfClass:[NSString class]] == YES)
                {
                    NSInteger frequencyScanEndInteger = [self.appDelegate hertzWithString:frequencyScanEndMegahertzObject];
                    NSNumber * frequencyScanEndNumber = [NSNumber numberWithInteger:frequencyScanEndInteger];
                    [frequencyDictionary setObject:frequencyScanEndNumber forKey:@"frequency_scan_end"];
                }
                
                id frequencyScanIntervalMegahertzObject = [frequencyDictionary objectForKey:@"frequency_scan_interval"];
                if ([frequencyScanIntervalMegahertzObject isKindOfClass:[NSString class]] == YES)
                {
                    //NSInteger frequencyScanIntervalInteger = [self.appDelegate hertzWithString:frequencyScanIntervalMegahertzObject];
                    NSString * frequencyScanIntervalMegahertzString = frequencyScanIntervalMegahertzObject;
                    NSInteger frequencyScanIntervalInteger = [frequencyScanIntervalMegahertzString integerValue];
                    NSNumber * frequencyScanIntervalNumber = [NSNumber numberWithInteger:frequencyScanIntervalInteger];
                    [frequencyDictionary setObject:frequencyScanIntervalNumber forKey:@"frequency_scan_interval"];
                }
                */
                
                [self convertNumericFieldsInFrequencyDictionary:frequencyDictionary];

                int64_t queryResult = [self.sqliteController storeRecord:frequencyDictionary table:@"frequency"];
                
                if (queryResult > 0)
                {
                    if (categoryIDString != NULL)
                    {
                        NSInteger lastInsertFrequencyID = queryResult;
                        
                        NSInteger categoryID = [categoryIDString integerValue];
                        NSNumber * categoryIDNumber = [NSNumber numberWithInteger:categoryID];
                        NSNumber * lastInsertFrequencyIDNumber = [NSNumber numberWithInteger:lastInsertFrequencyID];
                    
                        NSMutableDictionary * freqCatDictionary = [NSMutableDictionary dictionary];
                        [freqCatDictionary setObject:categoryIDNumber forKey:@"cat_id"];
                        [freqCatDictionary setObject:lastInsertFrequencyIDNumber forKey:@"freq_id"];

                        [self.sqliteController storeRecord:freqCatDictionary table:@"freq_cat"];
                    }
                }

                
                //NSLog(@"frequencyDictionary = %@", frequencyDictionary);
            }

            [replacementDict setObject:@"OK" forKey:@"INSERT_NEW_FREQUENCY_RESULT"];
        }
        #pragma mark relativePath=scannerlistenbuttonclicked.html
        else if ([relativePath isEqualToString:@"/scannerlistenbuttonclicked.html"])
        {
            NSString * postString = nil;
            NSString * messageString = nil;
            
            NSData * postData = [request body];
            if (postData)
            {
                postString = [[NSString alloc] initWithData:postData encoding:NSUTF8StringEncoding];
            }

            NSData * messageData = [request messageData];
            if (messageData)
            {
                messageString = [[NSString alloc] initWithData:messageData encoding:NSUTF8StringEncoding];
            }
            
            NSError *error = nil;
            id object = [NSJSONSerialization
                      JSONObjectWithData:postData
                      options:0
                      error:&error];
            
            if ([object isKindOfClass:[NSArray class]] == YES)
            {
                NSArray * dataArray = object;
                
                NSMutableDictionary * scannerListenButtonDictionary = [NSMutableDictionary dictionary];

                NSCharacterSet * whitespaceCharacterSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
                
                for (NSDictionary * aDataDictionary in dataArray)
                {
                    NSString * dataName = [aDataDictionary objectForKey:@"name"];
                    NSString * dataValue = [aDataDictionary objectForKey:@"value"];

                    dataName = [dataName stringByTrimmingCharactersInSet:whitespaceCharacterSet];
                    dataValue = [dataValue stringByTrimmingCharactersInSet:whitespaceCharacterSet];
                    
                    [scannerListenButtonDictionary setObject:dataValue forKey:dataName];
                }
                
                NSString * categoryIDString = [scannerListenButtonDictionary objectForKey:@"id"];

                [self scannerListenButtonClickedForCategoryID:categoryIDString];  // calls startRtlsdrTaskForFrequenciesWithDictionary
            }
            
            [replacementDict setObject:@"OK" forKey:@"SCANNER_LISTEN_BUTTON_CLICKED_RESULT"];
            
            self.appDelegate.listenMode = kListenModeScan;
        }
        #pragma mark relativePath=
        else
        {
            NSString * pathExtension = [relativePath pathExtension];
            if ([pathExtension isEqualToString:@"html"] == YES)
            {
                NSLog(@"WebServerConnection - a handler was not found for %@", relativePath);
            }
        }
        
		HTTPLogVerbose(@"%@[%p]: replacementDict = \n%@", THIS_FILE, self, replacementDict);

        if ([path isEqualToString:@"/nowplayingstatus.html"] == NO)
        {
            NSLog(@"WebServerConnection - downloading dynamic file: %@", path);
        }

		return [[HTTPDynamicFileResponse alloc] initWithFilePath:[self filePathForURI:path]
                forConnection:self
                separator:@"%%"
                replacementDictionary:replacementDict];
	}
    
    /*
	else if ([relativePath isEqualToString:@"/unittest.html"])
	{
		HTTPLogVerbose(@"%@[%p]: Serving up HTTPResponseTest (unit testing)", THIS_FILE, self);
		
		return [[HTTPResponseTest alloc] initWithConnection:self];
	}
    */
    
    NSLog(@"WebServerConnection - downloading static file: %@", path);
	
	return [super httpResponseForMethod:method URI:path];
}

//==================================================================================
//	getSVGWithFileName:
//==================================================================================

- (NSString *)getSVGWithFileName:(NSString *)svgFileName
{
	NSString * webPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Web"];
    NSString * imagesPath = [webPath stringByAppendingString:@"/images/"];
    NSString * filePath = [imagesPath stringByAppendingString:svgFileName];
    
    NSError * fileError = NULL;
    NSString * svgString = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:&fileError];
    
    NSError * xmlError = NULL;
    NSXMLDocument * xmlDocument = [[NSXMLDocument alloc] initWithXMLString:svgString options:NSXMLNodeOptionsNone error:&xmlError];
    
    xmlDocument.standalone = YES;        // omit DTD
    
    NSString * xmlString = [xmlDocument XMLString];
    
    xmlString = [xmlString stringByReplacingOccurrencesOfString:@"<?xml version=\"1.0\" encoding=\"utf-8\" standalone=\"yes\"?>" withString:@""];
    
    return xmlString;
}

//==================================================================================
//	convertNumericFieldsInFrequencyDictionary:
//==================================================================================

- (void)convertNumericFieldsInFrequencyDictionary:(NSMutableDictionary *)frequencyDictionary
{
    // for dictionaries constructed from web forms, convert strings to NSNumber object to match the database fields
    id frequencyModeObject = [frequencyDictionary objectForKey:@"frequency_mode"];
    if ([frequencyModeObject isKindOfClass:[NSString class]] == YES)
    {
        NSString * frequencyModeString = frequencyModeObject;
        NSInteger frequencyModeInteger = frequencyModeString.integerValue;
        NSNumber * frequencyModeNumber = [NSNumber numberWithInteger:frequencyModeInteger];
        [frequencyDictionary setObject:frequencyModeNumber forKey:@"frequency_mode"];
    }

    id frequencyMegahertzObject = [frequencyDictionary objectForKey:@"frequency"];
    if ([frequencyMegahertzObject isKindOfClass:[NSString class]] == YES)
    {
        NSInteger frequencyInteger = [self.appDelegate hertzWithString:frequencyMegahertzObject];
        NSNumber * frequencyNumber = [NSNumber numberWithInteger:frequencyInteger];
        [frequencyDictionary setObject:frequencyNumber forKey:@"frequency"];
    }
    
    id frequencyScanEndMegahertzObject = [frequencyDictionary objectForKey:@"frequency_scan_end"];
    if ([frequencyScanEndMegahertzObject isKindOfClass:[NSString class]] == YES)
    {
        NSInteger frequencyScanEndInteger = [self.appDelegate hertzWithString:frequencyScanEndMegahertzObject];
        NSNumber * frequencyScanEndNumber = [NSNumber numberWithInteger:frequencyScanEndInteger];
        [frequencyDictionary setObject:frequencyScanEndNumber forKey:@"frequency_scan_end"];
    }
    
    id frequencyScanIntervalMegahertzObject = [frequencyDictionary objectForKey:@"frequency_scan_interval"];
    if ([frequencyScanIntervalMegahertzObject isKindOfClass:[NSString class]] == YES)
    {
        NSString * frequencyScanIntervalMegahertzString = frequencyScanIntervalMegahertzObject;
        NSInteger frequencyScanIntervalInteger = [frequencyScanIntervalMegahertzString integerValue];
        NSNumber * frequencyScanIntervalNumber = [NSNumber numberWithInteger:frequencyScanIntervalInteger];
        [frequencyDictionary setObject:frequencyScanIntervalNumber forKey:@"frequency_scan_interval"];
    }
    
    id tunerGainObject = [frequencyDictionary objectForKey:@"tuner_gain"];
    if ([tunerGainObject isKindOfClass:[NSString class]] == YES)
    {
        NSString * tunerGainString = tunerGainObject;
        double tunerGainDouble = tunerGainString.doubleValue;
        NSNumber * tunerGainNumber = [NSNumber numberWithDouble:tunerGainDouble];
        [frequencyDictionary setObject:tunerGainNumber forKey:@"tuner_gain"];
    }

    id tunerAGCObject = [frequencyDictionary objectForKey:@"tuner_agc"];
    if ([tunerAGCObject isKindOfClass:[NSString class]] == YES)
    {
        NSString * tunerGainString = tunerAGCObject;
        NSInteger tunerGainInteger = tunerGainString.integerValue;
        NSNumber * tunerGainNumber = [NSNumber numberWithInteger:tunerGainInteger];
        [frequencyDictionary setObject:tunerGainNumber forKey:@"tuner_agc"];
    }
    
    id samplingModeObject = [frequencyDictionary objectForKey:@"sampling_mode"];
    if ([samplingModeObject isKindOfClass:[NSString class]] == YES)
    {
        NSString * samplingModeString = samplingModeObject;
        NSInteger samplingModeInteger = samplingModeString.integerValue;
        NSNumber * samplingModeNumber = [NSNumber numberWithInteger:samplingModeInteger];
        [frequencyDictionary setObject:samplingModeNumber forKey:@"sampling_mode"];
    }
    
    id sampleRateObject = [frequencyDictionary objectForKey:@"sample_rate"];
    if ([sampleRateObject isKindOfClass:[NSString class]] == YES)
    {
        NSString * sampleRateString = sampleRateObject;
        NSInteger sampleRateInteger = sampleRateString.integerValue;
        NSNumber * sampleRateNumber = [NSNumber numberWithInteger:sampleRateInteger];
        [frequencyDictionary setObject:sampleRateNumber forKey:@"sample_rate"];
    }
    
    id oversamplingObject = [frequencyDictionary objectForKey:@"oversampling"];
    if ([oversamplingObject isKindOfClass:[NSString class]] == YES)
    {
        NSString * oversamplingString = oversamplingObject;
        NSInteger oversamplingInteger = oversamplingString.integerValue;
        NSNumber * oversamplingNumber = [NSNumber numberWithInteger:oversamplingInteger];
        [frequencyDictionary setObject:oversamplingNumber forKey:@"oversampling"];
    }
    
    id squelchLevelObject = [frequencyDictionary objectForKey:@"squelch_level"];
    if ([squelchLevelObject isKindOfClass:[NSString class]] == YES)
    {
        NSString * squelchLevelString = squelchLevelObject;
        double squelchLevelDouble = squelchLevelString.doubleValue;
        NSNumber * squelchLevelNumber = [NSNumber numberWithDouble:squelchLevelDouble];
        [frequencyDictionary setObject:squelchLevelNumber forKey:@"squelch_level"];
    }
    
    id firSizeObject = [frequencyDictionary objectForKey:@"fir_size"];
    if ([firSizeObject isKindOfClass:[NSString class]] == YES)
    {
        NSString * firSizeString = firSizeObject;
        NSInteger firSizeInteger = firSizeString.integerValue;
        NSNumber * firSizeNumber = [NSNumber numberWithInteger:firSizeInteger];
        [frequencyDictionary setObject:firSizeNumber forKey:@"fir_size"];
    }
}


//==================================================================================
//	processBodyData:
//==================================================================================

- (void)processBodyData:(NSData *)postDataChunk
{
	HTTPLogTrace();
    // append data to the parser. It will invoke callbacks to let us handle
    // parsed data.
	
	// Remember: In order to support LARGE POST uploads, the data is read in chunks.
	// This prevents a 50 MB upload from being stored in RAM.
	// The size of the chunks are limited by the POST_CHUNKSIZE definition.
	// Therefore, this method may be called multiple times for the same POST request.
	
	BOOL result = [request appendData:postDataChunk];
	if (!result)
	{
		HTTPLogError(@"%@[%p]: %@ - Couldn't append bytes!", THIS_FILE, self, THIS_METHOD);
	}
}

//==================================================================================
//	valueForKey:fromQueryItems:
//==================================================================================

- (NSString *)valueForKey:(NSString *)key
           fromQueryItems:(NSArray *)queryItems
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name=%@", key];
    NSURLQueryItem *queryItem = [[queryItems filteredArrayUsingPredicate:predicate] firstObject];
    return queryItem.value;
}

//==================================================================================
//	generateNavBar
//==================================================================================

 - (NSString *)generateNavBar
{
    NSString * navBarString =
@"   <div class=\"navbar-spacer\"></div>\n"
@"   <nav class=\"navbar\">\n"
@"      <div class=\"container\">\n"
@"        <ul class=\"navbar-list\">\n"
@"          <li class=\"navbar-item\"><a class=\"navbar-link\" href=\"#\" onclick=\"backButtonClicked(self);\" title=\"Click the Back button to return to the previous page in the web interface\">Back</a></li>\n"
@"          <li class=\"navbar-item\"><a class=\"navbar-link\" href=\"#\" onclick=\"loadContent('index2.html');\"  title=\"Click the Top button to reload the LocalRadio web interface.\">Top</a></li>\n"
@"          <li class=\"navbar-item\"><a class=\"navbar-link\" id=\"nowPlayingNavBarLink\" href=\"#\" onclick=\"loadContent('nowplaying.html');\"   title=\"Click the Now Playing button to see the current activity on the radio, including the live Signal Level, which can be helpful for setting the correct Squelch Level.  Note that the Now Playing page will generate more network traffic, and consume more energy on mobile devices.\">Now Playing</a></li>\n"
@"        </ul>\n"
@"      </div>\n"
@"    </nav>\n";

   return navBarString;
}

//==================================================================================
//	generateViewFavoriteItemStringForID:
//==================================================================================

- (NSString *)generateViewFavoriteItemStringForID:(NSString *)idString
{
    NSMutableString * resultString = [NSMutableString string];

    NSDictionary * favoriteDictionary = [self.sqliteController frequencyRecordForID:idString];
    
    if (favoriteDictionary != NULL)
    {
        NSNumber * idNumber = [favoriteDictionary objectForKey:@"id"];
        NSString * idString = [idNumber stringValue];
        
        NSNumber * frequencyNumber = [favoriteDictionary objectForKey:@"frequency"];
        NSString * frequencyNumericString = [frequencyNumber stringValue];
        NSString * frequencyString = [self.appDelegate shortHertzString:frequencyNumericString];
        
        NSNumber * frequencyScanEndNumber = [favoriteDictionary objectForKey:@"frequency_scan_end"];
        NSString * frequencyScanEndNumericString = [frequencyScanEndNumber stringValue];
        NSString * frequencyScanEndString = [self.appDelegate shortHertzString:frequencyScanEndNumericString];
        
        NSNumber * frequencyScanIntervalNumber = [favoriteDictionary objectForKey:@"frequency_scan_interval"];
        NSString * frequencyScanIntervalNumericString = [frequencyScanIntervalNumber stringValue];
        NSString * frequencyScanIntervalString = [self.appDelegate shortHertzString:frequencyScanIntervalNumericString];
        
        NSString * stationNameString = [favoriteDictionary objectForKey:@"station_name"];
        
        NSString * modulationString = [favoriteDictionary objectForKey:@"modulation"];
        
        NSNumber * sampleRateNumber = [favoriteDictionary objectForKey:@"sample_rate"];
        NSString * sampleRateString = [sampleRateNumber stringValue];

        NSMutableString * formString = [NSMutableString string];



        
        //[formString appendString:@"<form action='listen.html'>"];
        [formString appendString:@"<form id='listenForm' action='#'>"];
        
        NSString * idInputString = [NSString stringWithFormat:@"<input type='hidden' name='id' value='%@'>", idString];
        [formString appendString:idInputString];

        //NSString * listenButtonString = @"<br><input class='twelve columns button button-primary' type='submit' value='Listen'>";
        //[formString appendString:listenButtonString];

        NSString * listenButtonString = @"<br><br><input class='twelve columns button button-primary' type='button' value='Listen' onclick=\"var listenForm=getElementById('listenForm'); listenButtonClicked(listenForm);\"  title=\"Click the Listen button to tune the RTL-SDR radio to the frequency shown above.  You may also need to click on the Play button in the audio controls below.\">";
        [formString appendString:listenButtonString];

        [formString appendString:@"</form>"];
        
        //NSString * listenButtonString = @"<br><button class='button button-primary twelve columns' type='button' onclick=\"listenButtonClicked();\">Listen</button>";
        //[formString appendString:listenButtonString];
        
        



        [formString appendFormat:@"<br><form action='javascript:loadContent(\"editfavorite.html?id=%@\")'>", idString];

        NSString * editButtonString = @"<br><input class='twelve columns button' type='submit' value='Edit'>";
        [formString appendString:editButtonString];

        //[formString appendString:idInputString];
        
        [formString appendString:@"</form>"];

        //[resultString appendFormat:@"id: %@<br>frequency: %@<br>name: %@<br>modulation: %@<br>bandwidth: %@<br><br>%@", idString, frequencyString, stationNameString, modulationString, bandwidthString, formString];

        [resultString appendFormat:@"%@<br><br>frequency: %@<br>modulation: %@<br>sample rate: %@<br><br>", formString, frequencyString, modulationString, sampleRateString];
    }
    else
    {
        [resultString appendFormat:@"Error getting favorite id = %@", idString];
    }

    return resultString;
}

//==================================================================================
//	generateNowPlayingStatusString
//==================================================================================

- (NSString *)generateNowPlayingStatusString
{
    NSString * nowPlayingStatusString = @"";

    NSMutableDictionary * nowPlayingDictionary = self.appDelegate.udpStatusListenerController.nowPlayingDictionary;
    
    if (nowPlayingDictionary != NULL)
    {
        nowPlayingDictionary = [nowPlayingDictionary mutableCopy];
    
        NSNumber * frequencyIDNumber = [nowPlayingDictionary objectForKey:@"id"];
        if (frequencyIDNumber != NULL)
        {
            [nowPlayingDictionary removeObjectForKey:frequencyIDNumber];
        }
        else
        {
            frequencyIDNumber = [NSNumber numberWithInteger:0];
        }
        [nowPlayingDictionary setObject:frequencyIDNumber forKey:@"frequency_id"];
        
        NSNumber * frequencyNumber = [nowPlayingDictionary objectForKey:@"frequency"];
        NSString * frequencyString = frequencyNumber.stringValue;
        NSString * hertzString = [self.appDelegate shortHertzString:frequencyString];
        [nowPlayingDictionary setObject:hertzString forKey:@"short_frequency"];
        
        NSString * rtlsdrTaskMode = self.appDelegate.sdrController.rtlsdrTaskMode;

        // merge category record data with the frequency data
        if ([rtlsdrTaskMode isEqualToString:@"scan"] == YES)
        {
            NSMutableDictionary * rtlsdrCategoryDictionary = self.appDelegate.sdrController.rtlsdrCategoryDictionary;
            NSArray * allKeys = [rtlsdrCategoryDictionary allKeys];
            for (NSString * aKey in allKeys)
            {
                NSString * value = [rtlsdrCategoryDictionary objectForKey:aKey];
                
                NSString * newKey = aKey;
                
                if ([aKey isEqualToString:@"id"] == YES)
                {
                    newKey = @"category_id";
                }
                
                [nowPlayingDictionary setObject:value forKey:newKey];
            }
        }
        
        id tunerGainValue = [nowPlayingDictionary objectForKey:@"tuner_gain"];
        if (tunerGainValue != NULL)
        {
            if ([tunerGainValue isKindOfClass:[NSNumber class]] == YES)
            {
                NSString * tunerGainString = [NSString stringWithFormat:@"%.1f", [tunerGainValue floatValue]];
                
                [nowPlayingDictionary setObject:tunerGainString forKey:@"tuner_gain"];
            }
        }

        NSError *error = nil;
        NSData * nowPlayingData = [NSJSONSerialization
                  dataWithJSONObject:nowPlayingDictionary
                  options:0
                  error:&error];
        
        if (nowPlayingData != NULL)
        {
            NSString * nowPlayingDataString = [[NSString alloc] initWithData:nowPlayingData encoding:NSUTF8StringEncoding];
            if (nowPlayingDataString.length > 1)
            {
                nowPlayingStatusString = nowPlayingDataString;
            }
        }
    }

    return nowPlayingStatusString;
}

//==================================================================================
//	generateCurrentTunerString
//==================================================================================

- (NSString *)generateCurrentTunerString
{
    NSMutableString * resultString = [NSMutableString string];
    
    NSDictionary * icecastStatusDictionary = [self.icecastController icecastStatusDictionary];
    
    if (icecastStatusDictionary != NULL)
    {
        //NSString * sourcesString = [icecastStatusDictionary objectForKey:@"sources"];
        
        NSArray * sourcesArray = [icecastStatusDictionary objectForKey:@"sources_list"];
        
        NSInteger streamIndex = 1;
        
        for (NSDictionary * aSourceDictionary in sourcesArray)
        {
            NSString * serverDescription = [aSourceDictionary objectForKey:@"server_description"];
            
            if ([serverDescription isEqualToString:@"Unknown"] == NO)
            {
                NSString * rowPrototypeString =
@"                <div class=\"six columns value-prop\">\n"
@"                    <embed class=\"value-img\" type=\"image/svg+xml\" src=\"images/favorites.svg\" />\n"
@"                    <div class=\"value-prop\">\n"
@"                        <a class=\"button button-primary\" onclick=\"loadContent('favorites.html');\">%@</a>\n"
@"                    </div>\n"
@"                    %@\n"
@"                </div>\n";

                NSString * majorLabel = [NSString stringWithFormat:@"Stream %ld", streamIndex];

                NSString * rowString = [NSString stringWithFormat:rowPrototypeString, majorLabel, serverDescription];
            
                [resultString appendString:rowString];

                streamIndex++;
            }
        }
    }

    return resultString;
}

//==================================================================================
//	generateMP3BitrateSelectString
//==================================================================================

- (NSString *)generateMP3BitrateSelectString
{
    NSMutableString * resultString = [NSMutableString string];
    
    NSString * currentMP3Setting = self.appDelegate.mp3SettingsTextField.stringValue;
    
    NSArray * currentMP3SettingArray = [currentMP3Setting componentsSeparatedByString:@"."];
    
    NSString * currentBitrate = @"16000";
    if (currentMP3SettingArray.count > 0)
    {
        currentBitrate = currentMP3SettingArray.firstObject;
    }
    
    NSMutableDictionary * bitrateDictionary = [NSMutableDictionary dictionaryWithObjectsAndKeys:
            @"", @"8000",
            @"", @"16000",
            @"", @"24000",
            @"", @"32000",
            @"", @"48000",
            @"", @"64000",
            @"", @"80000",
            @"", @"96000",
            @"", @"112000",
            @"", @"128000",
            @"", @"160000",
            @"", @"192000",
            @"", @"224000",
            @"", @"256000",
            @"", @"320000",
            NULL];
    
    [bitrateDictionary setObject:@" selected=\"\"" forKey:currentBitrate];
    
    // note from LAME:
    // <bitrate> (bitrate in kbit/s) must be chosen from the following values: 8, 16, 24, 32, 40, 48, 64, 80, 96, 112, 128, 160, 192, 224, 256, or 320.

    [resultString appendFormat:@"<option value=\"8000\" %@>8000 bps</option>", [bitrateDictionary objectForKey:@"8000"]];
    [resultString appendFormat:@"<option value=\"16000\" %@>16000 bps</option>", [bitrateDictionary objectForKey:@"16000"]];
    [resultString appendFormat:@"<option value=\"24000\" %@>24000 bps</option>", [bitrateDictionary objectForKey:@"24000"]];
    [resultString appendFormat:@"<option value=\"32000\" %@>32000 bps</option>", [bitrateDictionary objectForKey:@"32000"]];
    [resultString appendFormat:@"<option value=\"40000\" %@>40000 bps</option>", [bitrateDictionary objectForKey:@"40000"]];
    [resultString appendFormat:@"<option value=\"48000\" %@>48000 bps</option>", [bitrateDictionary objectForKey:@"48000"]];
    [resultString appendFormat:@"<option value=\"64000\" %@>64000 bps</option>", [bitrateDictionary objectForKey:@"64000"]];
    [resultString appendFormat:@"<option value=\"80000\" %@>80000 bps</option>", [bitrateDictionary objectForKey:@"80000"]];
    [resultString appendFormat:@"<option value=\"96000\" %@>96000 bps</option>", [bitrateDictionary objectForKey:@"96000"]];
    [resultString appendFormat:@"<option value=\"112000\" %@>112000 bps</option>", [bitrateDictionary objectForKey:@"112000"]];
    [resultString appendFormat:@"<option value=\"128000\" %@>128000 bps</option>", [bitrateDictionary objectForKey:@"128000"]];
    [resultString appendFormat:@"<option value=\"160000\" %@>160000 bps</option>", [bitrateDictionary objectForKey:@"160000"]];
    [resultString appendFormat:@"<option value=\"192000\" %@>192000 bps</option>", [bitrateDictionary objectForKey:@"192000"]];
    [resultString appendFormat:@"<option value=\"224000\" %@>224000 bps</option>", [bitrateDictionary objectForKey:@"224000"]];
    [resultString appendFormat:@"<option value=\"256000\" %@>256000 bps</option>", [bitrateDictionary objectForKey:@"256000"]];
    [resultString appendFormat:@"<option value=\"320000\" %@>320000 bps</option>", [bitrateDictionary objectForKey:@"320000"]];
    
    return resultString;
}

//==================================================================================
//	generateMP3EncodingQualitySelectString
//==================================================================================

- (NSString *)generateMP3EncodingQualitySelectString
{
    NSMutableString * resultString = [NSMutableString string];
    
    NSString * currentMP3Setting = self.appDelegate.mp3SettingsTextField.stringValue;
    
    NSArray * currentMP3SettingArray = [currentMP3Setting componentsSeparatedByString:@"."];

    NSString * currentEncodingQuality = @"2";
    if (currentMP3SettingArray.count > 1)
    {
        currentEncodingQuality = [currentMP3SettingArray objectAtIndex:1];
    }

    NSMutableDictionary * encodingQualityDictionary = [NSMutableDictionary dictionaryWithObjectsAndKeys:
            @"", @"0",
            @"", @"1",
            @"", @"2",
            @"", @"3",
            @"", @"4",
            @"", @"5",
            @"", @"6",
            @"", @"7",
            @"", @"8",
            @"", @"9",
            NULL];
    
    [encodingQualityDictionary setObject:@" selected=\"\"" forKey:currentEncodingQuality];

    [resultString appendFormat:@"<option value=\"0\" %@ >0 - Higher Quality, Slower</option>", [encodingQualityDictionary objectForKey:@"0"]];
    [resultString appendFormat:@"<option value=\"1\" %@ >1</option>", [encodingQualityDictionary objectForKey:@"1"]];
    [resultString appendFormat:@"<option value=\"2\" %@ >2 - Default</option>", [encodingQualityDictionary objectForKey:@"2"]];
    [resultString appendFormat:@"<option value=\"3\" %@ >3</option>", [encodingQualityDictionary objectForKey:@"3"]];
    [resultString appendFormat:@"<option value=\"4\" %@ >4</option>", [encodingQualityDictionary objectForKey:@"4"]];
    [resultString appendFormat:@"<option value=\"5\" %@ >5</option>", [encodingQualityDictionary objectForKey:@"5"]];
    [resultString appendFormat:@"<option value=\"6\" %@ >6</option>", [encodingQualityDictionary objectForKey:@"6"]];
    [resultString appendFormat:@"<option value=\"7\" %@ >7</option>", [encodingQualityDictionary objectForKey:@"7"]];
    [resultString appendFormat:@"<option value=\"8\" %@ >8</option>", [encodingQualityDictionary objectForKey:@"8"]];
    [resultString appendFormat:@"<option value=\"9\" %@ >9 - Lower Quality, Faster</option>", [encodingQualityDictionary objectForKey:@"9"]];
    
    return resultString;
}

//==================================================================================
//	generateFavoritesString
//==================================================================================

- (NSString *)generateFavoritesString
{
    NSArray * allFrequencyRecordsArray = [self.sqliteController allFrequencyRecords];
    
    NSMutableString * tableString = [NSMutableString string];
    
    [tableString appendString:@"<table class='u-full-width'>"];
    [tableString appendString:@"<thead>"];
    [tableString appendString:@"<tr>"];
    //[tableString appendString:@"<th>ID</th>"];
    [tableString appendString:@"<th>Frequency</th>"];
    [tableString appendString:@"<th>Name</th>"];
    //[tableString appendString:@"<th>Modulation</th>"];
    //[tableString appendString:@"<th>Bandwidth</th>"];
    [tableString appendString:@"</tr>"];
    [tableString appendString:@"</thead>"];
    [tableString appendString:@"<tbody>"];
    
    for (NSDictionary * favoriteDictionary in allFrequencyRecordsArray)
    {
        NSNumber * idNumber = [favoriteDictionary objectForKey:@"id"];
        NSString * idString = [idNumber stringValue];
        
        NSNumber * frequencyNumber = [favoriteDictionary objectForKey:@"frequency"];
        NSString * frequencyNumericString = [frequencyNumber stringValue];
        NSString * frequencyString = [self.appDelegate shortHertzString:frequencyNumericString];

        NSNumber * frequencyScanEndNumber = [favoriteDictionary objectForKey:@"frequency_scan_end"];
        NSString * frequencyScanEndNumericString = [frequencyScanEndNumber stringValue];
        NSString * frequencyScanEndString = [self.appDelegate shortHertzString:frequencyScanEndNumericString];
        
        NSNumber * frequencyScanIntervalNumber = [favoriteDictionary objectForKey:@"frequency_scan_interval"];
        NSString * frequencyScanIntervalNumericString = [frequencyScanIntervalNumber stringValue];
        NSString * frequencyScanIntervalString = [self.appDelegate shortHertzString:frequencyScanIntervalNumericString];
        
        NSString * stationNameString = [favoriteDictionary objectForKey:@"station_name"];
        
        [tableString appendString:@"<tr>"];
        
        [tableString appendString:@"<td>"];
        
        NSString * titleString = [NSString stringWithFormat:@"Show %@ at %@", stationNameString, frequencyString];

        NSString * buttonString = [NSString stringWithFormat:@"<a class='button button-primary two columns' type='submit' onclick=\"loadContent('viewfavorite.html?id=%@');\" title='%@'>%@</a>", idString, titleString, frequencyString];
        
        [tableString appendString:buttonString];
        
        [tableString appendString:@"</td>"];
        
        //[tableString appendString:@"<td>"];
        //[tableString appendString:frequencyString];
        //[tableString appendString:@"</td>"];
        
        [tableString appendString:@"<td>"];
        [tableString appendString:stationNameString];
        [tableString appendString:@"</td>"];
        
        [tableString appendString:@"</tr>"];
    }

    [tableString appendString:@"</tbody>"];
    [tableString appendString:@"</table>"];
    
    return tableString;
}

//==================================================================================
//	generateAudioDeviceList:
//==================================================================================

- (NSArray *)generateAudioDeviceList
{
    NSMutableArray * resultArray = [NSMutableArray array];

    AudioObjectPropertyAddress  propertyAddress;
    AudioObjectID               *deviceIDs;
    UInt32                      propertySize;
    NSInteger                   numDevices;
    
    propertyAddress.mSelector = kAudioHardwarePropertyDevices;
    propertyAddress.mScope = kAudioObjectPropertyScopeGlobal;
    propertyAddress.mElement = kAudioObjectPropertyElementMaster;
    if (AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &propertyAddress, 0, NULL, &propertySize) == noErr)
    {
        numDevices = propertySize / sizeof(AudioDeviceID);
        deviceIDs = (AudioDeviceID *)calloc(numDevices, sizeof(AudioDeviceID));

        if (AudioObjectGetPropertyData(kAudioObjectSystemObject, &propertyAddress, 0, NULL, &propertySize, deviceIDs) == noErr)
        {
            for (NSInteger idx=0; idx<numDevices; idx++)
            {
                AudioObjectPropertyAddress      deviceAddress;

                char deviceName[64];
                propertySize = sizeof(deviceName);
                deviceAddress.mSelector = kAudioDevicePropertyDeviceName;
                deviceAddress.mScope = kAudioObjectPropertyScopeGlobal;
                deviceAddress.mElement = kAudioObjectPropertyElementMaster;
                if (AudioObjectGetPropertyData(deviceIDs[idx], &deviceAddress, 0, NULL, &propertySize, deviceName) == noErr)
                {
                }
                
                char manufacturerName[64];
                propertySize = sizeof(manufacturerName);
                deviceAddress.mSelector = kAudioDevicePropertyDeviceManufacturer;
                deviceAddress.mScope = kAudioObjectPropertyScopeGlobal;
                deviceAddress.mElement = kAudioObjectPropertyElementMaster;
                if (AudioObjectGetPropertyData(deviceIDs[idx], &deviceAddress, 0, NULL, &propertySize, manufacturerName) == noErr)
                {
                }
                
                CFStringRef uidString;
                propertySize = sizeof(uidString);
                deviceAddress.mSelector = kAudioDevicePropertyDeviceUID;
                deviceAddress.mScope = kAudioObjectPropertyScopeGlobal;
                deviceAddress.mElement = kAudioObjectPropertyElementMaster;
                if (AudioObjectGetPropertyData(deviceIDs[idx], &deviceAddress, 0, NULL, &propertySize, &uidString) == noErr)
                {
                }
 
                NSInteger inputChannelCount = 0;
                deviceAddress.mSelector = kAudioDevicePropertyStreamConfiguration;
                deviceAddress.mScope = kAudioDevicePropertyScopeInput;
                deviceAddress.mElement = kAudioObjectPropertyElementMaster;
                OSStatus err = AudioObjectGetPropertyDataSize(deviceIDs[idx], &deviceAddress, 0, NULL, &propertySize);
                if (err == 0)
                {
                    AudioBufferList * buflist = (AudioBufferList *)malloc(propertySize);
                    err = AudioObjectGetPropertyData(deviceIDs[idx], &deviceAddress, 0, NULL, &propertySize, buflist);
                    if (!err) {
                        for (UInt32 i = 0; i < buflist->mNumberBuffers; ++i)
                        {
                            inputChannelCount += buflist->mBuffers[i].mNumberChannels;
                        }
                    }
                    free(buflist);
                }


                NSInteger outputChannelCount = 0;
                deviceAddress.mSelector = kAudioDevicePropertyStreamConfiguration;
                deviceAddress.mScope = kAudioDevicePropertyScopeOutput;
                deviceAddress.mElement = kAudioObjectPropertyElementMaster;
                err = AudioObjectGetPropertyDataSize(deviceIDs[idx], &deviceAddress, 0, NULL, &propertySize);
                if (err == 0)
                {
                    AudioBufferList * buflist = (AudioBufferList *)malloc(propertySize);
                    err = AudioObjectGetPropertyData(deviceIDs[idx], &deviceAddress, 0, NULL, &propertySize, buflist);
                    if (!err) {
                        for (UInt32 i = 0; i < buflist->mNumberBuffers; ++i)
                        {
                            outputChannelCount += buflist->mBuffers[i].mNumberChannels;
                        }
                    }
                    free(buflist);
                }

 
                //NSLog(@"device %s by %s id %@", deviceName, manufacturerName, uidString);
                
                NSString * deviceNameString = [NSString stringWithCString:deviceName encoding:NSUTF8StringEncoding];
                NSString * manufacturerNameString = [NSString stringWithCString:manufacturerName encoding:NSUTF8StringEncoding];
                
                NSNumber * inputChannelCountNumber = [NSNumber numberWithInteger:inputChannelCount];
                NSNumber * outputChannelCountNumber = [NSNumber numberWithInteger:outputChannelCount];
                
                if ([deviceNameString isEqualToString:@"Built-in Line Input"] == YES)
                {
                    deviceNameString = @"Built-in Line In";
                }
                if ([deviceNameString isEqualToString:@"Built-in Digital Input"] == YES)
                {
                    deviceNameString = @"Built-in Digital In";
                }
                if ([deviceNameString isEqualToString:@"Built-in Line Output"] == YES)
                {
                    deviceNameString = @"Built-in Line Out";
                }
                if ([deviceNameString isEqualToString:@"Built-in Digital Output"] == YES)
                {
                    deviceNameString = @"Built-in Digital Out";
                }
                
                NSDictionary * deviceDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                        deviceNameString, @"deviceName",
                        manufacturerNameString, @"manufacturerName",
                        inputChannelCountNumber, @"inputChannelCount",
                        outputChannelCountNumber, @"outputChannelCount",
                        nil];
                
                [resultArray addObject:deviceDictionary];

                CFRelease(uidString);
            }
        }

        free(deviceIDs);
    }
    
    return resultArray;
}

//==================================================================================
//	generateAudioPlayerString
//==================================================================================

- (NSString *)generateAudioPlayerString:(BOOL)userAgentIsLocalRadioApp
{
    NSMutableString * resultString = [NSMutableString string];
    
    BOOL useMacSystemAudio = NO;
    
    if (userAgentIsLocalRadioApp == YES)
    {
        //if (self.appDelegate.useWebViewAudioPlayerCheckbox.state == NO)
        if (self.appDelegate.useWebViewAudioPlayer == NO)
        {
            useMacSystemAudio = YES;
        }
    }
    
    if (useMacSystemAudio == NO)
    {
        NSString * icecastServerMountName = [self.appDelegate.localRadioAppSettings valueForKey:@"IcecastServerMountName"];

        NSString * applicationSupportDirectoryPath = [[NSFileManager defaultManager] applicationSupportDirectory];
        NSString * icecastConfigPath = [applicationSupportDirectoryPath stringByAppendingPathComponent:@"icecast.xml"];

        NSError * fileError = NULL;
        NSString * icecastXMLString = [NSString stringWithContentsOfFile:icecastConfigPath encoding:NSUTF8StringEncoding error:&fileError];

        NSError * xmlError = NULL;
        NSXMLDocument * xmlDocument = [[NSXMLDocument alloc] initWithXMLString:icecastXMLString options:0 error:&xmlError];

        NSXMLElement * rootElement = [xmlDocument rootElement];
        
        NSString * hostnameQuery = @"hostname";
        NSError * error = NULL;
        NSArray * hostnameResultArray = [rootElement nodesForXPath:hostnameQuery error:&error];
        if (hostnameResultArray.count == 1)
        {
            NSXMLElement * hostnameElement = hostnameResultArray.firstObject;
            NSString * hostname = hostnameElement.stringValue;
            
            NSString * portQuery = @"listen-socket/port";
            NSArray * portResultArray = [rootElement nodesForXPath:portQuery error:&error];
            if (portResultArray.count == 1)
            {
                NSXMLElement * portElement = portResultArray.firstObject;
                NSString * portString = portElement.stringValue;
                
                //NSString * randomQuery = [self randomQuery];    // TODO: TEST: add random query to URL to force fresh stream
                //NSString * mp3URLString = [NSString stringWithFormat:@"http://%@:%@/%@?%@", hostname, portString, icecastServerMountName, randomQuery];

                NSString * mp3URLString = [NSString stringWithFormat:@"http://%@:%@/%@", hostname, portString, icecastServerMountName];
                
                NSString * autoplayFlag = @"";
                NSString * audioPlayerJS = @"";
                
                BOOL addAutoplayAttributes = NO;
                
                if (userAgentIsLocalRadioApp == YES)
                {
                    //addAutoplayAttributes = self.appDelegate.useAutoPlayCheckbox.state;
                    addAutoplayAttributes = self.appDelegate.useAutoPlay;
                }
                
                if (addAutoplayAttributes == YES)
                {
                    autoplayFlag = @"autoplay";
                }

                audioPlayerJS =
                        @" onabort='audioPlayerAbort(this);' "
                        @" oncanplay='audioPlayerCanPlay(this);' "
                        @" oncanplaythrough='audioPlayerCanPlaythrough(this);' "
                        @" ondurationchange='audioPlayerDurationChange(this);' "
                        @" onemptied='audioPlayerEmptied(this);' "
                        @" onended='audioPlayerEnded(this);' "
                        @" onerror='audioPlayerError(this, error);' "
                        @" onloadeddata='audioPlayerLoadedData(this);' "
                        @" onloadedmetadata='audioPlayerLoadedMetadata(this);' "
                        @" onloadstart='audioPlayerLoadStart(this);' "
                        @" onpause='audioPlayerPaused(this);' "
                        @" onplay='audioPlayerPlay(this);' "
                        @" onplaying='audioPlayerPlaying(this);' "
                        @" onprogress='audioPlayerProgress(this);' "
                        @" onratechange='audioPlayerRateChange(this);' "
                        @" onseeked='audioPlayerSeeked(this);' "
                        @" onseeking='audioPlayerSeeking(this);' "
                        @" onstalled='audioPlayerStalled(this);' "
                        @" onplay='audioPlayerStarted(this);' "
                        @" onsuspend='audioPlayerSuspend(this);' "
                        @" ontimeupdate='audioPlayerTimeUpdate(this);' "
                        @" onwaiting='audioPlayerWaiting(this);' ";
                
                [resultString appendFormat:@"<audio id='audio_element' controls %@ preload=\"none\" src='%@' type='audio/mpeg' %@ title='LocalRadio audio player.'>Your browser does not support the audio element.</audio>\n", autoplayFlag, mp3URLString, audioPlayerJS];
            }
        }
    }
    else
    {
        [resultString appendString:@"Using Mac system audio"];
    }

    return resultString;
}

//==================================================================================
//	randomQuery
//==================================================================================

 - (NSString *)randomQuery
{
    NSMutableString * randomQuery = [NSMutableString string];

    NSString * randomCharacters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";

    for (NSInteger i = 0; i < 8; i++)
    {
        uint32_t randomCharactersLength = (uint32_t)randomCharacters.length;
        NSInteger randomIndex = arc4random_uniform(randomCharactersLength);
        unichar randomCharacter = [randomCharacters characterAtIndex:randomIndex];
        [randomQuery appendFormat: @"%C", randomCharacter];
    }
    
    return randomQuery;
}

//==================================================================================
//	applyMP3Settings:
//==================================================================================

 - (void)applyMP3Settings:(NSDictionary *)settingsDictionary
 {
    NSString * bitrate = [settingsDictionary objectForKey:@"bitrate"];
    NSString * encoding_quality = [settingsDictionary objectForKey:@"encoding_quality"];
    
    NSInteger bitrateInt = bitrate.integerValue;
    
    NSInteger bitrateK = bitrateInt / 1000;
    
    //NSString * mp3Setting = [NSString stringWithFormat:@"%@.%@", bitrate, encoding_quality];
    NSString * mp3Setting = [NSString stringWithFormat:@"%ld.%@", bitrateK, encoding_quality];
    
    [self performSelectorOnMainThread:@selector(setMP3SettingsTextField:) withObject:mp3Setting waitUntilDone:YES];

    [self.appDelegate.localRadioAppSettings setValue:mp3Setting forKey:@"MP3Settings"];
    
    [self.appDelegate restartServices];
 }

//==================================================================================
//	setMP3SettingsTextField:
//==================================================================================

 - (void)setMP3SettingsTextField:(NSString *)mp3SettingString
 {
    self.appDelegate.mp3SettingsTextField.stringValue = mp3SettingString;
 }

//==================================================================================
//	listenButtonClickedForFrequencyID:
//==================================================================================

- (void)listenButtonClickedForFrequencyID:(NSString *)frequencyIDString
{
    NSMutableDictionary * frequencyDictionary = [[self.sqliteController frequencyRecordForID:frequencyIDString] mutableCopy];
    
    [self listenButtonClickedForFrequency:frequencyDictionary];
}

//==================================================================================
//    listenButtonClickedForFrequency:
//==================================================================================

- (void)listenButtonClickedForFrequency:(NSMutableDictionary *)favoriteDictionary
{
    if (favoriteDictionary != NULL)
    {
        [self.sdrController startRtlsdrTasksForFrequency:favoriteDictionary];
    }
}

//==================================================================================
//    listenButtonClickedForDevice:
//==================================================================================

- (void)listenButtonClickedForDevice:(NSString *)deviceName
{
    if (deviceName != NULL)
    {
        [self.sdrController startTasksForDevice:deviceName];
    }
}

//==================================================================================
//	scannerListenButtonClickedForCategoryID:
//==================================================================================

- (void)scannerListenButtonClickedForCategoryID:(NSString *)categoryIDString
{
    NSMutableString * resultString = [NSMutableString string];

    NSDictionary * categoryDictionary = [self.sqliteController categoryRecordForID:categoryIDString];

    NSArray * freqCatQueryResultArray = [self.sqliteController freqCatRecordsForCategoryID:categoryIDString];
    
    NSMutableArray * frequenciesArray = [NSMutableArray array];
    
    for (NSDictionary * freqCatDictionary in freqCatQueryResultArray)
    {
        //NSNumber * freqCatIDNumber = [freqCatDictionary objectForKey:@"id"];
        //NSString * freqCatIDString = [freqCatIDNumber stringValue];
        
        NSNumber * freqIDNumber = [freqCatDictionary objectForKey:@"freq_id"];
        NSString * freqIDString = [freqIDNumber stringValue];

        //NSNumber * catIDNumber = [freqCatDictionary objectForKey:@"cat_id"];
        //NSString * catIDString = [catIDNumber stringValue];

        NSDictionary * favoriteDictionary = [self.sqliteController frequencyRecordForID:freqIDString];
        if (favoriteDictionary != NULL)
        {
            [frequenciesArray addObject:favoriteDictionary];
        }
        else
        {
            [resultString appendFormat:@"Error getting categoryIDString = %@", categoryIDString];
        }
    }

    //[self.sdrController startRtlsdrTaskForFrequencies:frequenciesArray category:categoryDictionary];
    
    id categoryRef = categoryDictionary;
    if (categoryRef == NULL)
    {
        categoryRef = [NSNull null];
    }
    NSDictionary * freqCatDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
            frequenciesArray, @"frequencies",
            categoryRef, @"category",
            nil];
    [self performSelectorInBackground:@selector(startRtlsdrTaskForFrequenciesWithDictionary:) withObject:freqCatDictionary];
}

//==================================================================================
//	tunerGainsArray
//==================================================================================

- (NSArray *)tunerGainsArray
{
    NSArray * tunerGainsArray = [NSArray arrayWithObjects:
        @"0.0",
        @"0.9",
        @"1.4",
        @"2.7",
        @"3.7",
        @"7.7",
        @"8.7",
        @"12.5",
        @"14.4",
        @"15.7",
        @"16.6",
        @"19.7",
        @"20.7",
        @"22.9",
        @"25.4",
        @"28.0",
        @"29.7",
        @"32.8",
        @"33.8",
        @"36.4",
        @"37.2",
        @"38.6",
        @"40.2",
        @"42.1",
        @"43.4",
        @"43.9",
        @"44.5",
        @"48.0",
        @"49.6",
        NULL
    ];
    
    return tunerGainsArray;
}

//==================================================================================
//	oversamplingArray
//==================================================================================

- (NSArray *)oversamplingArray
{
    NSArray * oversamplingArray = [NSArray arrayWithObjects:
        @"0",
        @"1",
        @"2",
        @"4",
        @"8",
        @"16",
        NULL
    ];
    
    return oversamplingArray;
}

//==================================================================================
//	generateEditCategorySettingsStringForID:
//==================================================================================

- (NSString *)generateEditCategorySettingsStringForID:(NSString *)idString
{
    NSDictionary * categoryDictionary = [self.sqliteController categoryRecordForID:idString];

    NSMutableString * resultString = [NSMutableString string];
    
    if (categoryDictionary != NULL)
    {
        NSNumber * idNumber = [categoryDictionary objectForKey:@"id"];
        NSString * idString = [idNumber stringValue];

        NSString * categoryNameString = [categoryDictionary objectForKey:@"category_name"];

        NSNumber * categoryScanningEnabledNumber = [categoryDictionary objectForKey:@"category_scanning_enabled"];
        
        
        NSNumber * scanSamplingModeNumber = [categoryDictionary objectForKey:@"scan_sampling_mode"];
        //NSString * scanSamplingModeString = [scanSamplingModeNumber stringValue];

        NSNumber * scanTunerGainNumber = [categoryDictionary objectForKey:@"scan_tuner_gain"];
        NSString * scanTunerGainString = [scanTunerGainNumber stringValue];

        NSNumber * scanTunerAGCNumber = [categoryDictionary objectForKey:@"scan_tuner_agc"];
        //NSString * scanTunerAGCString = [scanTunerAGCNumber stringValue];

        NSNumber * scanSampleRateNumber = [categoryDictionary objectForKey:@"scan_sample_rate"];
        NSString * scanSampleRateString = [scanSampleRateNumber stringValue];

        NSNumber * scanOversamplingNumber = [categoryDictionary objectForKey:@"scan_oversampling"];
        NSString * scanOversamplingString = [scanOversamplingNumber stringValue];

        NSString * scanModulationString = [categoryDictionary objectForKey:@"scan_modulation"];

        NSNumber * scanSquelchLevelNumber = [categoryDictionary objectForKey:@"scan_squelch_level"];
        NSString * scanSquelchLevelString = [scanSquelchLevelNumber stringValue];

        NSNumber * scanSquelchDelayNumber = [categoryDictionary objectForKey:@"scan_squelch_delay"];
        NSString * scanSquelchDelayString = [scanSquelchDelayNumber stringValue];

        NSString * rtlfmOptionsString = [categoryDictionary objectForKey:@"scan_options"];

        NSNumber * scanFirSizeNumber = [categoryDictionary objectForKey:@"scan_fir_size"];
        NSString * scanFirSizeString = [scanFirSizeNumber stringValue];

        NSString * scanAtanMathString = [categoryDictionary objectForKey:@"scan_atan_math"];

        NSString * scanAudioOutputFilterString = [categoryDictionary objectForKey:@"scan_audio_output_filter"];

        NSString * scanAudioOutputString = [categoryDictionary objectForKey:@"scan_audio_output"];
        
        NSString * scanStreamSourceString = [categoryDictionary objectForKey:@"scan_stream_source"];
        
        NSMutableString * formString = [NSMutableString string];
        [formString appendString:@"<form class='editcategorysettings' id='editcategorysettings' onsubmit='event.preventDefault(); return storeCategoryRecord(this);' method='POST'>"];
        
        NSString * formNameString = [NSString stringWithFormat:@"<label for='category_name'>Name:</label><input class='twelve columns value-prop' type='text' id='category_name' name='category_name' value='%@'>", categoryNameString];
        [formString appendString:formNameString];



        [formString appendString:@"<label for='category_scanning_enabled'>Enable Category Scanning:</label>"];
        [formString appendString:@"<select class='twelve columns value-prop' name='category_scanning_enabled'>"];
        NSInteger categoryScanning = [categoryScanningEnabledNumber integerValue];
        NSString * categoryScanningDisabledSelectedString = @"";
        if (categoryScanning == 0)
        {
            categoryScanningDisabledSelectedString = @"selected=\"\"";
        }
        NSString * categoryScanningEnabledSelectedString = @"";
        if (categoryScanning == 1)
        {
            categoryScanningEnabledSelectedString = @"selected=\"\"";
        }
        [formString appendFormat:@"<option value='0' %@>Disabled</option>", categoryScanningDisabledSelectedString];
        [formString appendFormat:@"<option value='1' %@>Enabled</option>", categoryScanningEnabledSelectedString];
        [formString appendString:@"</select>"];



        
        NSArray * tunerGainsArray = [self tunerGainsArray];
        NSString * closestTunerGain = @"49.6";
        CGFloat selectedTunerGainFloat = scanTunerGainString.floatValue;
        for (NSString * aTunerGain in tunerGainsArray)
        {
            CGFloat aTunerGainFloat = aTunerGain.floatValue;
            if (selectedTunerGainFloat <= aTunerGainFloat)
            {
                closestTunerGain = aTunerGain;
                break;
            }
        }
        
        
        [formString appendString:@"<label for='scan_tuner_gain'>Tuner Gain:</label>"];
        [formString appendString:@"<select class='twelve columns value-prop' name='scan_tuner_gain'>"];
        for (NSString * aTunerGain in tunerGainsArray)
        {
            NSString * selectedString = @"";
            if ([aTunerGain isEqualToString:closestTunerGain] == YES)
            {
                selectedString = @" selected";
            }
            [formString appendFormat:@"<option value='%@' %@>%@</option>", aTunerGain, selectedString, aTunerGain];
        }
        [formString appendString:@"</select>"];

        [formString appendString:@"<label for='scan_tuner_agc'>Tuner AGC:</label>"];
        [formString appendString:@"<select class='twelve columns value-prop' name='scan_tuner_agc'>"];
        NSString * agcOffSelectedString = @"";
        NSInteger agcMode = [scanTunerAGCNumber integerValue];
        if (agcMode == 0)
        {
            agcOffSelectedString = @"selected";
        }
        NSString * agcOnSelectedString = @"";
        if (agcMode == 1)
        {
            agcOnSelectedString = @"selected";
        }
        [formString appendFormat:@"<option value='agc_mode_off' %@>Off</option>", agcOffSelectedString];
        [formString appendFormat:@"<option value='agc_mode_on' %@>On</option>", agcOnSelectedString];
        [formString appendString:@"</select>"];

        NSString * formSampleRateString = [NSString stringWithFormat:@"<label for='frequency'>Sample Rate:</label><input class='twelve columns value-prop' type='number' id='scan_sample_rate' name='scan_sample_rate' value='%@'>", scanSampleRateString];
        [formString appendString:formSampleRateString];

        [formString appendString:@"<span style='display: inline;'>"];

        [formString appendString:@"<input class='sample-rate-button' type='button' onclick='setScanSampleRateInput(5000);' value='5k'>"];
        [formString appendString:@"<input class='sample-rate-button' type='button' onclick='setScanSampleRateInput(7000);' value='7k'>"];
        [formString appendString:@"<input class='sample-rate-button' type='button' onclick='setScanSampleRateInput(10000);' value='10k'>"];
        [formString appendString:@"<input class='sample-rate-button' type='button' onclick='setScanSampleRateInput(85000);' value='85k'>"];
        [formString appendString:@"<input class='sample-rate-button' type='button' onclick='setScanSampleRateInput(170000);' value='170k'>"];

        [formString appendString:@"</span>"];

        [formString appendString:@"<br><br>"];
        

        [formString appendString:@"<label for='scan_sampling_mode'>Sampling Mode:</label>"];
        [formString appendString:@"<select class='twelve columns value-prop' name='scan_sampling_mode'>"];
        NSString * samplingModeStandardSelectedString = @"";
        NSInteger samplingMode = [scanSamplingModeNumber integerValue];
        if (samplingMode == 0)
        {
            samplingModeStandardSelectedString = @"selected";
        }
        NSString * samplingModeDirectSelectedString = @"";
        if (samplingMode == 2)
        {
            samplingModeDirectSelectedString = @"selected";
        }
        [formString appendFormat:@"<option value='sampling_mode_standard' %@>Standard</option>", samplingModeStandardSelectedString];
        [formString appendFormat:@"<option value='sampling_mode_direct' %@>Direct Q-Branch</option>", samplingModeDirectSelectedString];
        [formString appendString:@"</select>"];

        NSArray * oversamplingArray = [self oversamplingArray];
        NSString * closestOversampling = @"0";
        NSInteger selectedOversampling = scanOversamplingString.integerValue;
        for (NSString * aOversamplingString in oversamplingArray)
        {
            NSInteger aOversampling = aOversamplingString.integerValue;
            if (selectedOversampling <= aOversampling)
            {
                closestOversampling = aOversamplingString;
                break;
            }
        }
        [formString appendString:@"<label for='scan_oversampling'>Oversampling:</label>"];
        [formString appendString:@"<select class='twelve columns value-prop' name='scan_oversampling'>"];
        for (NSString * aOversamplingString in oversamplingArray)
        {
            NSString * selectedString = @"";
            if ([aOversamplingString isEqualToString:closestOversampling] == YES)
            {
                selectedString = @" selected";
            }
            [formString appendFormat:@"<option value='%@' %@>%@</option>", aOversamplingString, selectedString, aOversamplingString];
        }
        [formString appendString:@"</select>"];

        NSArray * modulationsArray = [self modulationsArray];
        [formString appendString:@"<label for='scan_modulation'>Modulation:</label>"];
        [formString appendString:@"<select class='twelve columns value-prop' name='scan_modulation'>"];
        for (NSDictionary * modulationDictionary in modulationsArray)
        {
            NSString * aLabelString = [modulationDictionary objectForKey:@"label"];
            NSString * aModulationString = [modulationDictionary objectForKey:@"modulation"];
            NSString * selectedString = @"";
            if ([scanModulationString isEqualToString:aModulationString] == YES)
            {
                selectedString = @"selected";
            }
            NSString * optionString = [NSString stringWithFormat:@"<option value='%@' %@>%@</option>", aModulationString, selectedString, aLabelString];
            [formString appendString:optionString];
        }
        [formString appendString:@"</select>"];

        NSString * formSquelchLevelString = [NSString stringWithFormat:@"<label for='scan_squelch_level'>Squelch Level:</label><input class='twelve columns value-prop' type='number' id='scan_squelch_level' name='scan_squelch_level' value='%@'>", scanSquelchLevelString];
        [formString appendString:formSquelchLevelString];

        NSString * formSquelchDelayString = [NSString stringWithFormat:@"<label for='scan_squelch_delay'>Squelch Delay:</label><input class='twelve columns value-prop' type='number' id='scan_squelch_delay' name='scan_squelch_delay' value='%@'>", scanSquelchDelayString];
        [formString appendString:formSquelchDelayString];

        NSString * formRtlfmOptionsString = [NSString stringWithFormat:@"<label for='scan_options'>RTL-FM Options:</label><input class='twelve columns value-prop' type='text' id='scan_options' name='scan_options' value='%@'>", rtlfmOptionsString];
        [formString appendString:formRtlfmOptionsString];

        NSString * firSize0Selected = @"";
        if ([scanFirSizeString isEqualToString:@"0"] == YES)
        {
            firSize0Selected = @" selected";
        }
        NSString * firSize1Selected = @"";
        if ([scanFirSizeString isEqualToString:@"1"] == YES)
        {
            firSize1Selected = @" selected";
        }
        NSString * firSize9Selected = @"";
        if ([scanFirSizeString isEqualToString:@"9"] == YES)
        {
            firSize9Selected = @" selected";
        }
        [formString appendString:@"<label for='scan_fir_size'>FIR Size:</label>"];
        [formString appendString:@"<select class='twelve columns value-prop' name='scan_fir_size'>"];
        [formString appendFormat:@"<option value='0' %@>0</option>", firSize0Selected];
        [formString appendFormat:@"<option value='1' %@>1</option>", firSize1Selected];
        [formString appendFormat:@"<option value='9' %@>9</option>", firSize9Selected];
        [formString appendString:@"</select>"];

        NSString * atanMathStdSelected = @"";
        if ([scanAtanMathString isEqualToString:@"std"] == YES)
        {
            atanMathStdSelected = @" selected";
        }
        NSString * atanMathFastSelected = @"";
        if ([scanAtanMathString isEqualToString:@"fast"] == YES)
        {
            atanMathFastSelected = @" selected";
        }
        NSString * atanMathLUTSelected = @"";
        if ([scanAtanMathString isEqualToString:@"lut"] == YES)
        {
            atanMathLUTSelected = @" selected";
        }
        NSString * atanMathAleSelected = @"";
        if ([scanAtanMathString isEqualToString:@"ale"] == YES)
        {
            atanMathAleSelected = @" selected";
        }
        [formString appendString:@"<label for='atan_math'>atan Math:</label>"];
        [formString appendString:@"<select class='twelve columns value-prop' name='scan_atan_math'>"];
        [formString appendFormat:@"<option value='std' %@>std</option>", atanMathStdSelected];
        [formString appendFormat:@"<option value='fast' %@>fast</option>", atanMathFastSelected];
        [formString appendFormat:@"<option value='lut' %@>lut</option>", atanMathLUTSelected];
        [formString appendFormat:@"<option value='ale' %@>ale</option>", atanMathAleSelected];
        [formString appendString:@"</select>"];

        NSString * formAudioOutputFilterString = [NSString stringWithFormat:@"<label for='frequency'>Sox Audio Output Filter:</label><input class='twelve columns value-prop' type='text' id='scan_audio_output_filter' name='scan_audio_output_filter' value='%@'>", scanAudioOutputFilterString];
        [formString appendString:formAudioOutputFilterString];



        NSArray * audioDeviceArray = [self generateAudioDeviceList];
        
        [formString appendString:@"<label for='scan_audio_output'>Audio Output</label>"];
        [formString appendString:@"<select name='scan_audio_output' class='twelve columns value-prop'>"];
        
        NSString * icecastOutputSelectedString = @"";
        if ([scanAudioOutputString isEqualToString:@"icecast"] == YES)
        {
            icecastOutputSelectedString = @"selected";
        }
        [formString appendFormat:@"<option value='icecast' %@>Built-in Icecast Server</option>", icecastOutputSelectedString];

        for (NSDictionary * deviceDictionary in audioDeviceArray)
        {
            NSNumber * outputChannelCountNumber = [deviceDictionary objectForKey:@"outputChannelCount"];
            NSInteger outputChannelCount = outputChannelCountNumber.integerValue;
            if (outputChannelCount > 0)
            {
                NSString * deviceName = [deviceDictionary objectForKey:@"deviceName"];
                
                NSCharacterSet * whitespaceCharacterSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
                deviceName = [deviceName stringByTrimmingCharactersInSet:whitespaceCharacterSet];
                
                //deviceName = [@" " stringByAppendingString:deviceName];
                
                NSString * optionSelectedString = @"";
                if ([scanAudioOutputString isEqualToString:deviceName] == YES)
                {
                    optionSelectedString = @"selected";
                }
                
                [formString appendFormat:@"<option value='%@' %@>%@</option><br>", deviceName, optionSelectedString, deviceName];
            }
        }
        [formString appendString:@"</select>"];


        [formString appendString:@"<label for='scan_stream_source'>Stream Source</label>"];
        [formString appendString:@"<select name='scan_stream_source' class='twelve columns value-prop'>"];

        NSString * icecastStreamSelectedString = @"";
        if ([scanStreamSourceString isEqualToString:@"icecast"] == YES)
        {
            icecastStreamSelectedString = @"selected";
        }
        [formString appendFormat:@"<option value='icecast' %@>Built-in Icecast Server</option>", icecastStreamSelectedString];

        for (NSDictionary * deviceDictionary in audioDeviceArray)
        {
            NSNumber * outputChannelCountNumber = [deviceDictionary objectForKey:@"outputChannelCount"];
            NSInteger outputChannelCount = outputChannelCountNumber.integerValue;
            if (outputChannelCount > 0)
            {
                NSString * deviceName = [deviceDictionary objectForKey:@"deviceName"];

                NSCharacterSet * whitespaceCharacterSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
                deviceName = [deviceName stringByTrimmingCharactersInSet:whitespaceCharacterSet];

                //deviceName = [@" " stringByAppendingString:deviceName];
                
                NSString * optionSelectedString = @"";
                if ([scanStreamSourceString isEqualToString:deviceName] == YES)
                {
                    optionSelectedString = @"selected";
                }
                
                [formString appendFormat:@"<option value='%@' %@>%@</option><br>", deviceName, optionSelectedString, deviceName];
            }
        }
        [formString appendString:@"</select>"];


        
        NSString * idInputString = [NSString stringWithFormat:@"<input type='hidden' name='id' value='%@'>", idString];
        [formString appendString:idInputString];

        NSString * saveButtonString = @"<br>&nbsp;<br>&nbsp;<br><input class='twelve columns button button-primary' type='submit' value='Save Changes'>";
        [formString appendString:saveButtonString];
        
        [formString appendString:@"</form><br>&nbsp;<br>&nbsp;"];

        [resultString appendString:formString];
    }
    else
    {
        [resultString appendFormat:@"Error getting favorite id = %@", idString];
    }

    return resultString;
}

//==================================================================================
//	generateEditFrequencyFormStringForID:
//==================================================================================

- (NSString *)generateEditFrequencyFormStringForID:(NSString *)idString
{
    NSDictionary * favoriteDictionary = [self.sqliteController frequencyRecordForID:idString];

    NSString * resultString = [self generateEditFrequencyFormStringForFrequency:favoriteDictionary];
    
    return resultString;
}

//==================================================================================
//	generateDevicesFormString
//==================================================================================

- (NSString *)generateDevicesFormString
{
    NSMutableString * resultString = [NSMutableString string];

    NSMutableString * formString = [NSMutableString string];

    NSString * formAction = @"deviceSelect";

    [formString appendFormat:@"<form class='device_form' id='deviceForm' onsubmit='event.preventDefault(); return %@(this);' method='POST'>\n", formAction];

    NSArray * audioDeviceArray = [self generateAudioDeviceList];
    
    [formString appendString:@"<label for='audio_output'>Select Audio Input</label>\n"];
    [formString appendString:@"<select name='audio_output' class='twelve columns value-prop' title='The Audio Input setting selects a Core Audio device, like \"Built-in Input\".'>\n"];
    
    for (NSDictionary * deviceDictionary in audioDeviceArray)
    {
        NSNumber * inputChannelCountNumber = [deviceDictionary objectForKey:@"inputChannelCount"];
        NSInteger inputChannelCount = inputChannelCountNumber.integerValue;
        if (inputChannelCount > 0)
        {
            NSString * deviceName = [deviceDictionary objectForKey:@"deviceName"];

            NSCharacterSet * whitespaceCharacterSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
            deviceName = [deviceName stringByTrimmingCharactersInSet:whitespaceCharacterSet];
            
            NSString * optionSelectedString = @"";
            /*
            if ([audioOutputString isEqualToString:deviceName] == YES)
            {
                optionSelectedString = @"selected";
            }
            */
            
            [formString appendFormat:@"<option value='%@' %@>%@</option><br>\n", deviceName, optionSelectedString, deviceName];
        }
    }
    [formString appendString:@"</select>\n"];

    NSString * listenButtonString = @"<br><br><input class='twelve columns button button-primary' type='button' value='Listen' onclick=\"var deviceForm=getElementById('deviceForm'); deviceListenButtonClicked(deviceForm);\"  title=\"Click the Listen button for the selected device.  You may also need to click on the Play button in the audio controls below.\">";
    [formString appendString:listenButtonString];

    [formString appendString:@"</form>\n<br>&nbsp;<br>\n"];

    [resultString appendString:formString];

    return resultString;
}

//==================================================================================
//	generateEditFrequencyFormStringForFrequency:
//==================================================================================

- (NSString *)generateEditFrequencyFormStringForFrequency:(NSDictionary *)favoriteDictionary
{
    //NSDictionary * favoriteDictionary = [self.sqliteController frequencyRecordForID:idString];

    NSMutableString * resultString = [NSMutableString string];
    
    if (favoriteDictionary != NULL)
    {
        NSNumber * idNumber = [favoriteDictionary objectForKey:@"id"];
        NSInteger idInteger = [idNumber integerValue];
        //NSString * idString = [idNumber stringValue];

        NSString * stationNameString = [favoriteDictionary objectForKey:@"station_name"];
        
        NSNumber * frequencyModeNumber = [favoriteDictionary objectForKey:@"frequency_mode"];
        NSInteger frequencyMode = [frequencyModeNumber integerValue];
        
        NSNumber * frequencyNumber = [favoriteDictionary objectForKey:@"frequency"];
        NSString * frequencyNumericString = [frequencyNumber stringValue];
        NSString * frequencyString = [self.appDelegate shortHertzString:frequencyNumericString];

        NSNumber * frequencyScanEndNumber = [favoriteDictionary objectForKey:@"frequency_scan_end"];
        NSString * frequencyScanEndNumericString = [frequencyScanEndNumber stringValue];
        NSString * frequencyScanEndString = [self.appDelegate shortHertzString:frequencyScanEndNumericString];
        
        NSNumber * frequencyScanIntervalNumber = [favoriteDictionary objectForKey:@"frequency_scan_interval"];
        //NSString * frequencyScanIntervalNumericString = [frequencyScanIntervalNumber stringValue];
        //NSString * frequencyScanIntervalString = [self.appDelegate shortHertzString:frequencyScanIntervalNumericString];
        NSString * frequencyScanIntervalString = [frequencyScanIntervalNumber stringValue];

        NSNumber * tunerGainNumber = [favoriteDictionary objectForKey:@"tuner_gain"];
        NSString * tunerGainString = [tunerGainNumber stringValue];

        NSNumber * tunerAGCNumber = [favoriteDictionary objectForKey:@"tuner_agc"];
        //NSString * tunerAGCString = [tunerAGCNumber stringValue];

        NSNumber * samplingModeNumber = [favoriteDictionary objectForKey:@"sampling_mode"];
        //NSString * samplingModeString = [samplingModeNumber stringValue];

        NSNumber * sampleRateNumber = [favoriteDictionary objectForKey:@"sample_rate"];
        NSString * sampleRateString = [sampleRateNumber stringValue];

        NSNumber * oversamplingNumber = [favoriteDictionary objectForKey:@"oversampling"];
        NSString * oversamplingString = [oversamplingNumber stringValue];

        NSString * modulationString = [favoriteDictionary objectForKey:@"modulation"];

        NSNumber * squelchLevelNumber = [favoriteDictionary objectForKey:@"squelch_level"];
        NSString * squelchLevelString = [squelchLevelNumber stringValue];

        NSString * rtlfmOptionsString = [favoriteDictionary objectForKey:@"options"];

        NSNumber * firSizeNumber = [favoriteDictionary objectForKey:@"fir_size"];
        NSString * firSizeString = [firSizeNumber stringValue];

        NSString * atanMathString = [favoriteDictionary objectForKey:@"atan_math"];

        NSString * audioOutputFilterString = [favoriteDictionary objectForKey:@"audio_output_filter"];

        NSString * audioOutputString = [favoriteDictionary objectForKey:@"audio_output"];
        
        NSString * streamSourceString = [favoriteDictionary objectForKey:@"stream_source"];
        
        NSMutableString * formString = [NSMutableString string];
        
        NSString * formAction = @"storeFrequencyRecord";
        if (idInteger == 0)
        {
            formAction = @"insertNewFrequencyRecord";
        }
        
        [formString appendFormat:@"<form class='editfavorite' id='editfavorite' onsubmit='event.preventDefault(); return %@(this);' method='POST'>\n", formAction];

        NSString * formNameString = [NSString stringWithFormat:@"<label for='station_name'>Name:</label>\n<input class='twelve columns value-prop' type='text' id='station_name' name='station_name' value='%@' title='The Name field is used to save the name of the radio frequency in the database.  The Name could be the callsign of a radio station, for example.'>\n", stationNameString];
        [formString appendString:formNameString];
        




        [formString appendString:@"<label for='frequency_mode'>Frequency Mode:</label>\n"];
        [formString appendString:@"<select class='twelve columns value-prop' name='frequency_mode' title='Set the Frequency Mode to \"Frequency\" for a single radio frequeny, or to \"Frequency Range\" to scan a range of frequencies.'>\n"];
        NSString * frequencyModeSelectedString = @"";
        if (frequencyMode == 0)
        {
            frequencyModeSelectedString = @"selected";
        }
        NSString * frequencyRangeModeSelectedString = @"";
        if (frequencyMode == 1)
        {
            frequencyRangeModeSelectedString = @"selected";
        }
        [formString appendFormat:@"<option value='frequency_mode_single' %@>Frequency</option>\n", frequencyModeSelectedString];
        [formString appendFormat:@"<option value='frequency_mode_range' %@>Frequency Range</option>\n", frequencyRangeModeSelectedString];
        [formString appendString:@"</select>\n"];



        
        
        
        NSString * formFrequencyString = [NSString stringWithFormat:@"<label for='frequency'>Frequency or Scan Range Start Frequency:</label>\n<input class='twelve columns value-prop' type='text' id='frequency' name='frequency' value='%@' title='The Frequency field should contain a radio frequency, either a numeric value like \"89100000\", or \"89.1 MHz\" for the same frequency.  In Frequency Range mode, this frequency starts the scanning range.'>\n", frequencyString];
        [formString appendString:formFrequencyString];
        




        NSString * formFrequencyScanEndString = [NSString stringWithFormat:@"<label for='frequency_scan_end'>Scan Range End Frequency:</label>\n<input class='twelve columns value-prop' type='text' id='frequency_scan_end' name='frequency_scan_end' value='%@' title='In Frequency Range mode, this frequency ends the scanning range.'>\n", frequencyScanEndString];
        [formString appendString:formFrequencyScanEndString];
        
        NSString * formFrequencyScanIntervalString = [NSString stringWithFormat:@"<label for='frequency_scan_interval'>Scan Frequency Interval:</label>\n<input class='twelve columns value-prop' type='text' id='frequency_scan_interval' name='frequency_scan_interval' value='%@' title='In Frequency Range mode, this is the amount of separation between channels for scanning the frequency range.'>\n", frequencyScanIntervalString];
        [formString appendString:formFrequencyScanIntervalString];
        






        NSArray * tunerGainsArray = [self tunerGainsArray];
        NSString * closestTunerGain = @"49.6";
        CGFloat selectedTunerGainFloat = tunerGainString.floatValue;
        for (NSString * aTunerGain in tunerGainsArray)
        {
            CGFloat aTunerGainFloat = aTunerGain.floatValue;
            if (selectedTunerGainFloat <= aTunerGainFloat)
            {
                closestTunerGain = aTunerGain;
                break;
            }
        }
        [formString appendString:@"<label for='tuner_gain'>Tuner Gain:</label>\n"];
        [formString appendString:@"<select class='twelve columns value-prop' name='tuner_gain' title='Set the Tuner Gain to a larger value to increase the signal amplification, or a smaller value to decrease it.  Adjust the Tuner Gain and Bandwidth to get the best signal.'>\n"];
        for (NSString * aTunerGain in tunerGainsArray)
        {
            NSString * selectedString = @"";
            if ([aTunerGain isEqualToString:closestTunerGain] == YES)
            {
                selectedString = @" selected";
            }
            [formString appendFormat:@"<option value='%@' %@>%@</option>\n", aTunerGain, selectedString, aTunerGain];
        }
        [formString appendString:@"</select>\n"];





        [formString appendString:@"<label for='tuner_agc'>Tuner AGC:</label>\n"];
        [formString appendString:@"<select class='twelve columns value-prop' name='tuner_agc' title='The Tuner AGC setting controls the automatic gain control circuit in the radio.'>\n"];
        NSString * agcOffSelectedString = @"";
        NSInteger agcMode = [tunerAGCNumber integerValue];
        if (agcMode == 0)
        {
            agcOffSelectedString = @"selected";
        }
        NSString * agcOnSelectedString = @"";
        if (agcMode == 1)
        {
            agcOnSelectedString = @"selected";
        }
        [formString appendFormat:@"<option value='agc_mode_off' %@>Off</option>\n", agcOffSelectedString];
        [formString appendFormat:@"<option value='agc_mode_on' %@>On</option>\n", agcOnSelectedString];
        [formString appendString:@"</select>\n"];





        NSString * formSampleRateString = [NSString stringWithFormat:@"<label for='frequency'>Sample Rate:</label>\n<input class='twelve columns value-prop' type='number' id='sample_rate' name='sample_rate' value='%@' title='The Sample Rate is usually set to 170000 or 85000 for FM radio stations, and to 5000, 7000 or 10000 for other radio signals.'>\n", sampleRateString];
        [formString appendString:formSampleRateString];

        [formString appendString:@"<span style='display: inline;'>"];

        [formString appendString:@"<input class='sample-rate-button' type='button' onclick='setSampleRateInput(5000);' value='5k'>"];
        [formString appendString:@"<input class='sample-rate-button' type='button' onclick='setSampleRateInput(7000);' value='7k'>"];
        [formString appendString:@"<input class='sample-rate-button' type='button' onclick='setSampleRateInput(10000);' value='10k'>"];
        [formString appendString:@"<input class='sample-rate-button' type='button' onclick='setSampleRateInput(85000);' value='85k'>"];
        [formString appendString:@"<input class='sample-rate-button' type='button' onclick='setSampleRateInput(170000);' value='170k'>"];

        [formString appendString:@"</span>"];

        [formString appendString:@"<br><br>"];
  
    
        
        [formString appendString:@"<label for='scan_sampling_mode'>Sampling Mode:</label>\n"];
        [formString appendString:@"<select class='twelve columns value-prop' name='sampling_mode' title='The Sampling Mode is usually set to Standard mode, but for frequencies below 24 MHz, use Direct Q-Branch mode.'>\n"];
        NSString * samplingModeStandardSelectedString = @"";
        NSInteger samplingMode = [samplingModeNumber integerValue];
        if (samplingMode == 0)
        {
            samplingModeStandardSelectedString = @"selected";
        }
        NSString * samplingModeDirectSelectedString = @"";
        if (samplingMode == 2)
        {
            samplingModeDirectSelectedString = @"selected";
        }
        [formString appendFormat:@"<option value='sampling_mode_standard' %@>Standard</option>\n", samplingModeStandardSelectedString];
        [formString appendFormat:@"<option value='sampling_mode_direct' %@>Direct Q-Branch</option>\n", samplingModeDirectSelectedString];
        [formString appendString:@"</select>\n"];



        NSArray * oversamplingArray = [self oversamplingArray];
        NSString * closestOversampling = @"0";
        NSInteger selectedOversampling = oversamplingString.integerValue;
        for (NSString * aOversamplingString in oversamplingArray)
        {
            NSInteger aOversampling = aOversamplingString.integerValue;
            if (selectedOversampling <= aOversampling)
            {
                closestOversampling = aOversamplingString;
                break;
            }
        }

        [formString appendString:@"<label for='oversampling'>Oversampling:</label>\n"];
        [formString appendString:@"<select class='twelve columns value-prop' name='oversampling' title='The Oversampling setting can improve the quality of the audio'>\n"];
        for (NSString * aOversamplingString in oversamplingArray)
        {
            NSString * selectedString = @"";
            if ([aOversamplingString isEqualToString:closestOversampling] == YES)
            {
                selectedString = @" selected";
            }
            [formString appendFormat:@"<option value='%@' %@>%@</option>\n", aOversamplingString, selectedString, aOversamplingString];
        }
        [formString appendString:@"</select>\n"];

        NSArray * modulationsArray = [self modulationsArray];
        [formString appendString:@"<label for='modulation'>Modulation:</label>\n"];
        [formString appendString:@"<select class='twelve columns value-prop' name='modulation' title='The Modulation is usually set to FM, but should be set to AM for AM broadcast stations, shortwave stations, and aviation frequencies.'>\n"];
        for (NSDictionary * modulationDictionary in modulationsArray)
        {
            NSString * aLabelString = [modulationDictionary objectForKey:@"label"];
            NSString * aModulationString = [modulationDictionary objectForKey:@"modulation"];
            NSString * selectedString = @"";
            if ([modulationString isEqualToString:aModulationString] == YES)
            {
                selectedString = @"selected";
            }
            NSString * optionString = [NSString stringWithFormat:@"<option value='%@' %@>%@</option>\n", aModulationString, selectedString, aLabelString];
            [formString appendString:optionString];
        }
        [formString appendString:@"</select>\n"];

        NSString * formSquelchLevelString = [NSString stringWithFormat:@"<label for='squelch_level'>Squelch Level:</label>\n<input class='twelve columns value-prop' type='number' id='squelch_level' name='squelch_level' value='%@' title='The Squelch setting is used to silence radio static when a signal is too weak or not present to receive.  The static will be automatically silenced when the radio's Signal Level value is less that the Squelch value.  If the radio is not in scanning mode, the Squelch Level can be set to 0 to disable squelch.  In scanning modes, the Squelch Level must be greater than zero.'>\n", squelchLevelString];
        [formString appendString:formSquelchLevelString];

        NSString * formRtlfmOptionsString = [NSString stringWithFormat:@"<label for='options'>RTL-FM Options:</label>\n<input class='twelve columns value-prop' type='text' id='options' name='options' value='%@' title='The RTL-FM Options can be used to set custom options for the  rtl_fm tool.  The RTL-FM Options field should usually be empty.' >\n", rtlfmOptionsString];
        [formString appendString:formRtlfmOptionsString];

        NSString * firSize0Selected = @"";
        if ([firSizeString isEqualToString:@"0"] == YES)
        {
            firSize0Selected = @" selected";
        }
        NSString * firSize1Selected = @"";
        if ([firSizeString isEqualToString:@"1"] == YES)
        {
            firSize1Selected = @" selected";
        }
        NSString * firSize9Selected = @"";
        if ([firSizeString isEqualToString:@"9"] == YES)
        {
            firSize9Selected = @" selected";
        }
        [formString appendString:@"<label for='fir_size'>FIR Size:</label>\n"];
        [formString appendString:@"<select class='twelve columns value-prop' name='fir_size' The FIR Size field enables a low-leakage downsample filter, and the value can be 0 or 9.  0 has bad roll off.' >\n"];
        [formString appendFormat:@"<option value='0' %@>0</option>\n", firSize0Selected];
        [formString appendFormat:@"<option value='1' %@>1</option>\n", firSize1Selected];
        [formString appendFormat:@"<option value='9' %@>9</option>\n", firSize9Selected];
        [formString appendString:@"</select>\n"];

        NSString * atanMathStdSelected = @"";
        if ([atanMathString isEqualToString:@"std"] == YES)
        {
            atanMathStdSelected = @" selected";
        }
        NSString * atanMathFastSelected = @"";
        if ([atanMathString isEqualToString:@"fast"] == YES)
        {
            atanMathFastSelected = @" selected";
        }
        NSString * atanMathLUTSelected = @"";
        if ([atanMathString isEqualToString:@"lut"] == YES)
        {
            atanMathLUTSelected = @" selected";
        }
        NSString * atanMathAleSelected = @"";
        if ([atanMathString isEqualToString:@"ale"] == YES)
        {
            atanMathAleSelected = @" selected";
        }
        [formString appendString:@"<label for='atan_math'>atan Math:</label>\n"];
        [formString appendString:@"<select class='twelve columns value-prop' name='atan_math' title='The atan Math menu is set in the menu, and the default setting is \"std\".'>\n"];
        [formString appendFormat:@"<option value='std' %@>std</option>\n", atanMathStdSelected];
        [formString appendFormat:@"<option value='fast' %@>fast</option>\n", atanMathFastSelected];
        [formString appendFormat:@"<option value='lut' %@>lut</option>\n", atanMathLUTSelected];
        [formString appendFormat:@"<option value='ale' %@>ale</option>", atanMathAleSelected];
        [formString appendString:@"</select>\n"];

        NSString * formAudioOutputFilterString = [NSString stringWithFormat:@"<label for='frequency'>Sox Audio Output Filter:</label>\n<input class='twelve columns value-prop' type='text' id='audio_output_filter' name='audio_output_filter' value='%@' title='The Audio Output Filter is used by the Sox audio tool for several purposes.  This filter is for the final Sox output.  The default value is \"vol 1\".  Do not set a \"rate\" command here, LocalRadio automatically sets the sample rate to 48000.'>\n", audioOutputFilterString];
        [formString appendString:formAudioOutputFilterString];



        NSArray * audioDeviceArray = [self generateAudioDeviceList];
        
        [formString appendString:@"<label for='audio_output'>Audio Output</label>\n"];
        [formString appendString:@"<select name='audio_output' class='twelve columns value-prop' title='The Audio Output setting controls the destination of audio from the radio and final Sox filters.  The default setting is \"Built-in Icecast Server\" for normal usage.'>\n"];
        
        NSString * icecastOutputSelectedString = @"";
        if ([audioOutputString isEqualToString:@"icecast"] == YES)
        {
            icecastOutputSelectedString = @"selected";
        }
        [formString appendFormat:@"<option value='icecast' %@>Built-in Icecast Server</option>\n", icecastOutputSelectedString];

        for (NSDictionary * deviceDictionary in audioDeviceArray)
        {
            NSNumber * outputChannelCountNumber = [deviceDictionary objectForKey:@"outputChannelCount"];
            NSInteger outputChannelCount = outputChannelCountNumber.integerValue;
            if (outputChannelCount > 0)
            {
                NSString * deviceName = [deviceDictionary objectForKey:@"deviceName"];

                NSCharacterSet * whitespaceCharacterSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
                deviceName = [deviceName stringByTrimmingCharactersInSet:whitespaceCharacterSet];

                //deviceName = [@" " stringByAppendingString:deviceName];
                
                NSString * optionSelectedString = @"";
                if ([audioOutputString isEqualToString:deviceName] == YES)
                {
                    optionSelectedString = @"selected";
                }
                
                [formString appendFormat:@"<option value='%@' %@>%@</option><br>\n", deviceName, optionSelectedString, deviceName];
            }
        }
        [formString appendString:@"</select>\n"];


        [formString appendString:@"<label for='stream_source'>Stream Source</label>\n"];
        [formString appendString:@"<select name='stream_source' class='twelve columns value-prop' title='The Stream Source controls the input to the Icecast server for streaming audio.  The default setting is \"Built-in Icecast Server\" for normal usage.'>\n"];

        NSString * icecastStreamSelectedString = @"";
        if ([streamSourceString isEqualToString:@"icecast"] == YES)
        {
            icecastStreamSelectedString = @"selected";
        }
        [formString appendFormat:@"<option value='icecast' %@>Built-in Icecast Server</option>\n", icecastStreamSelectedString];

        for (NSDictionary * deviceDictionary in audioDeviceArray)
        {
            NSNumber * outputChannelCountNumber = [deviceDictionary objectForKey:@"outputChannelCount"];
            NSInteger outputChannelCount = outputChannelCountNumber.integerValue;
            if (outputChannelCount > 0)
            {
                NSString * deviceName = [deviceDictionary objectForKey:@"deviceName"];

                NSCharacterSet * whitespaceCharacterSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
                deviceName = [deviceName stringByTrimmingCharactersInSet:whitespaceCharacterSet];

                //deviceName = [@" " stringByAppendingString:deviceName];
                
                NSString * optionSelectedString = @"";
                if ([streamSourceString isEqualToString:deviceName] == YES)
                {
                    optionSelectedString = @"selected";
                }
                
                [formString appendFormat:@"<option value='%@' %@>%@</option>\n<br>\n", deviceName, optionSelectedString, deviceName];
            }
        }
        [formString appendString:@"</select>\n"];


        [formString appendString:@"&nbsp;<br>\n"];
        
        
        

        if (idInteger == 0)
        {
            NSString * categorySelectString = [self generateCategorySelectOptions];
            [formString appendString:categorySelectString];
            
            [formString appendString:@"<br>&nbsp;<br>&nbsp;<br>\n"];
        }


        [formString appendString:@"<input class='twelve columns button button-primary' type='button' value='Listen' onclick='var frequencyForm=getElementById(\"editfavorite\"); listenButtonClicked(frequencyForm);'  title='Click the Listen button to tune the RTL-SDR radio to the frequency shown above.  You may also need to click on the Play button in the audio controls below.'>"];
        
        NSString * idInputString = [NSString stringWithFormat:@"<input type='hidden' name='id' value='%@'>", idNumber];
        [formString appendString:idInputString];

        // display a button to add new record, or save changes to existing record
        NSString * saveButtonValue = @"Save Changes";
        if (idInteger == 0)
        {
            saveButtonValue = @"Add New Favorite Frequency";
        }

        NSString * saveButtonString = [NSString stringWithFormat:@"<br>&nbsp;<br>&nbsp;<br>\n<input id='save-button' class='twelve columns button button-primary' type='submit' value='%@' title='Click the %@ button to store this record in the Favorites frequency database.'>", saveButtonValue, saveButtonValue];
        [formString appendString:saveButtonString];
        
        [formString appendString:@"<br>&nbsp;<br>&nbsp;<br>\n"];

        [formString appendString:@"</form><br>&nbsp;\n"];

        [resultString appendString:formString];



        if (idInteger != 0)
        {
            // display a Delete button for an existing record
            [formString appendString:@"&nbsp;<br>\n"];

            NSMutableString * formDeleteString = [NSMutableString string];
            [formDeleteString appendString:@"<form class='delete-favorite-form' id='delete-favorite-form' onsubmit='event.preventDefault(); return deleteFrequencyRecord(this);' method='POST'>\n"];

            NSString * truncateStationNameString = [NSString stringWithString:stationNameString];
            if (truncateStationNameString.length > 25)
            {
                truncateStationNameString = [truncateStationNameString substringToIndex:25];
                truncateStationNameString = [truncateStationNameString stringByAppendingString:@"..."];
            }

            NSString * deleteButtonString = [NSString stringWithFormat:@"&nbsp;<br>\n<input id='delete-button' class='twelve columns button button-primary' type='submit' value='Delete %@' title='Click the Delete button to delete this record from the Favorites frequency database.'>\n", truncateStationNameString];
            [formDeleteString appendString:deleteButtonString];

            NSString * frequencyIDString = [NSString stringWithFormat:@"<input type='hidden' id='frequency_id' name='frequency_id' value='%@'>\n", idNumber];
            [formDeleteString appendString:frequencyIDString];

            NSString * frequencyNameString = [NSString stringWithFormat:@"<input type='hidden' id='frequency_name' name='frequency_name' value='%@'>\n", stationNameString];
            [formDeleteString appendString:frequencyNameString];
            
            [formDeleteString appendString:@"</form>\n<br>&nbsp;<br>\n"];

            [resultString appendString:formDeleteString];
        }
    }
    else
    {
        NSNumber * idNumber = [favoriteDictionary objectForKey:@"id"];
        NSString * idString = [idNumber stringValue];
    
        [resultString appendFormat:@"Error getting favorite id = %@", idString];
    }

    return resultString;
}


//==================================================================================
//	generateDeleteCategoryButtonStringForID:name:
//==================================================================================

-(NSString *)generateDeleteCategoryButtonStringForID:(NSString *)categoryIDString name:(NSString *)categoryNameString
{
    NSMutableString * resultString = [NSMutableString string];

    NSMutableString * formDeleteString = [NSMutableString string];
    [formDeleteString appendString:@"<form class='delete-favorite-form' id='delete-favorite-form' onsubmit='event.preventDefault(); return deleteCategoryRecord(this);' method='POST'>\n"];

    NSString * truncateStationNameString = [NSString stringWithString:categoryNameString];
    if (truncateStationNameString.length > 25)
    {
        truncateStationNameString = [truncateStationNameString substringToIndex:25];
        truncateStationNameString = [truncateStationNameString stringByAppendingString:@"..."];
    }

    NSString * deleteButtonString = [NSString stringWithFormat:@"<br>&nbsp;<br>&nbsp;<br>\n<input id='delete-category-button' class='twelve columns button button-primary' type='submit' value='Delete %@ Category'>\n", truncateStationNameString];
    [formDeleteString appendString:deleteButtonString];

    NSString * inputCategoryIDString = [NSString stringWithFormat:@"<input type='hidden' id='category_id' name='category_id' value='%@'>\n", categoryIDString];
    [formDeleteString appendString:inputCategoryIDString];
    
    NSString * inputCategoryNameString = [NSString stringWithFormat:@"<input type='hidden' id='category_name' name='category_name' value='%@'>\n", categoryNameString];
    [formDeleteString appendString:inputCategoryNameString];
    
    [formDeleteString appendString:@"</form>\n<br>&nbsp;<br>\n"];

    [resultString appendString:formDeleteString];

    return resultString;
}

//==================================================================================
//	modulationsArray
//==================================================================================

- (NSArray *)modulationsArray
{
    NSMutableArray * modulationsArray = [NSMutableArray array];
    
    NSDictionary * fmDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
            @"FM", @"label",
            @"fm", @"modulation",
            @"85000", @"bandwidth",
            nil];
    [modulationsArray addObject:fmDictionary];
    
    /*
    NSDictionary * wbfmDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
            @"Wide-band FM", @"label",
            @"wbfm", @"modulation",
            @"170000", @"bandwidth",
            nil];
    [modulationsArray addObject:wbfmDictionary];
    */
    
    NSDictionary * amDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
            @"AM", @"label",
            @"am", @"modulation",
            @"10000", @"bandwidth",
            nil];
    [modulationsArray addObject:amDictionary];
    
    NSDictionary * usbDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
            @"USB", @"label",
            @"usb", @"modulation",
            @"10000", @"bandwidth",
            nil];
    [modulationsArray addObject:usbDictionary];
    
    NSDictionary * lsbDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
            @"LSB", @"label",
            @"lsb", @"modulation",
            @"10000", @"bandwidth",
            nil];
    [modulationsArray addObject:lsbDictionary];
    
    NSDictionary * rawDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
            @"Raw", @"label",
            @"raw", @"modulation",
            @"10000", @"bandwidth",
            nil];
    [modulationsArray addObject:rawDictionary];
    
    return modulationsArray;
}

//==================================================================================
//	generateCategoryFavoritesString:
//==================================================================================

- (NSString *)generateCategoryFavoritesString:(NSString *)categoryIDString
{
    NSMutableString * resultString = [NSMutableString string];

    [resultString appendString:@"<table class='u-full-width'>"];
    [resultString appendString:@"<thead>"];
    [resultString appendString:@"<tr>"];
    //[resultString appendString:@"<th>ID</th>"];
    [resultString appendString:@"<th>Frequency</th>"];
    [resultString appendString:@"<th>Name</th>"];
    [resultString appendString:@"</tr>"];
    [resultString appendString:@"</thead>"];
    [resultString appendString:@"<tbody>"];

    NSArray * frequenciesForCategoryArray = [self.sqliteController allFrequencyRecordsForCategoryID:categoryIDString];

    for (NSDictionary * favoriteDictionary in frequenciesForCategoryArray)
    {
        NSNumber * idNumber = [favoriteDictionary objectForKey:@"id"];
        NSString * idString = [idNumber stringValue];

        NSString * stationNameString = [favoriteDictionary objectForKey:@"station_name"];
        
        NSNumber * frequencyNumber = [favoriteDictionary objectForKey:@"frequency"];
        NSString * frequencyNumericString = [frequencyNumber stringValue];
        NSString * frequencyString = [self.appDelegate shortHertzString:frequencyNumericString];

        NSNumber * frequencyScanEndNumber = [favoriteDictionary objectForKey:@"frequency_scan_end"];
        NSString * frequencyScanEndNumericString = [frequencyScanEndNumber stringValue];
        NSString * frequencyScanEndString = [self.appDelegate shortHertzString:frequencyScanEndNumericString];
        
        NSNumber * frequencyScanIntervalNumber = [favoriteDictionary objectForKey:@"frequency_scan_interval"];
        NSString * frequencyScanIntervalNumericString = [frequencyScanIntervalNumber stringValue];
        NSString * frequencyScanIntervalString = [self.appDelegate shortHertzString:frequencyScanIntervalNumericString];
        
        /*
        NSNumber * tunerGainNumber = [favoriteDictionary objectForKey:@"tuner_gain"];
        NSString * tunerGainString = [tunerGainNumber stringValue];

        NSNumber * tunerAGCNumber = [favoriteDictionary objectForKey:@"tuner_agc"];
        NSString * tunerAGCString = [tunerAGCNumber stringValue];

        NSNumber * samplingModeNumber = [favoriteDictionary objectForKey:@"sampling_mode"];
        NSString * samplingModeString = [samplingModeNumber stringValue];

        NSNumber * sampleRateNumber = [favoriteDictionary objectForKey:@"sample_rate"];
        NSString * sampleRateString = [sampleRateNumber stringValue];

        NSNumber * oversamplingNumber = [favoriteDictionary objectForKey:@"oversampling"];
        NSString * oversamplingString = [oversamplingNumber stringValue];

        NSString * modulationString = [favoriteDictionary objectForKey:@"modulation"];

        NSNumber * squelchLevelNumber = [favoriteDictionary objectForKey:@"squelch_level"];
        NSString * squelchLevelString = [squelchLevelNumber stringValue];

        NSString * optionsString = [favoriteDictionary objectForKey:@"options"];

        NSNumber * firSizeNumber = [favoriteDictionary objectForKey:@"fir_size"];
        NSString * firSizeString = [firSizeNumber stringValue];

        NSString * atanMathString = [favoriteDictionary objectForKey:@"atan_math"];

        NSString * audioOutputFilterString = [favoriteDictionary objectForKey:@"audio_output_filter"];

        NSString * audioOutputString = [favoriteDictionary objectForKey:@"audio_output"];
        
        NSString * streamSourceString = [favoriteDictionary objectForKey:@"stream_source"];
        */

        [resultString appendString:@"<tr>"];
        
        [resultString appendString:@"<td>"];

        NSString * buttonString = [NSString stringWithFormat:@"<a class='button button-primary two columns' type='submit' onclick=\"loadContent('viewfavorite.html?id=%@');\">%@</a>", idString, frequencyString];
        [resultString appendString:buttonString];
        
        [resultString appendString:@"</td>"];
        
        //[resultString appendString:@"<td>"];
        //[resultString appendString:frequencyString];
        //[resultString appendString:@"</td>"];
        
        [resultString appendString:@"<td>"];
        [resultString appendString:stationNameString];
        [resultString appendString:@"</td>"];
        
        [resultString appendString:@"</tr>"];
    }

    [resultString appendString:@"</tbody>"];
    [resultString appendString:@"</table>"];
    
    return resultString;
}

//==================================================================================
//	generateEditCategoryString:
//==================================================================================

- (NSString *)generateEditCategoryString:(NSString *)categoryIDString
{
    //NSArray * freqCatQueryResultArray = [self.sqliteController freqCatRecordsForCategoryID:categoryIDString];
    
    NSArray * allFrequenciesArray = [self.sqliteController allFrequencyRecords];
    
    NSMutableString * tableString = [NSMutableString string];
    
    [tableString appendString:@"<table class='u-full-width'>"];
    [tableString appendString:@"<thead>"];
    [tableString appendString:@"<tr>"];
    [tableString appendString:@"<th>ID</th>"];
    [tableString appendString:@"<th>Frequency</th>"];
    [tableString appendString:@"<th>Name</th>"];
    [tableString appendString:@"</tr>"];
    [tableString appendString:@"</thead>"];
    [tableString appendString:@"<tbody>"];
    
    for (NSDictionary * favoriteDictionary in allFrequenciesArray)
    {
        NSNumber * idNumber = [favoriteDictionary objectForKey:@"id"];
        //NSString * idString = [idNumber stringValue];
        
        NSNumber * frequencyNumber = [favoriteDictionary objectForKey:@"frequency"];
        NSString * frequencyNumericString = [frequencyNumber stringValue];
        NSString * frequencyString = [self.appDelegate shortHertzString:frequencyNumericString];

        NSNumber * frequencyScanEndNumber = [favoriteDictionary objectForKey:@"frequency_scan_end"];
        NSString * frequencyScanEndNumericString = [frequencyScanEndNumber stringValue];
        NSString * frequencyScanEndString = [self.appDelegate shortHertzString:frequencyScanEndNumericString];
        
        NSNumber * frequencyScanIntervalNumber = [favoriteDictionary objectForKey:@"frequency_scan_interval"];
        NSString * frequencyScanIntervalNumericString = [frequencyScanIntervalNumber stringValue];
        NSString * frequencyScanIntervalString = [self.appDelegate shortHertzString:frequencyScanIntervalNumericString];
        
        NSString * stationNameString = [favoriteDictionary objectForKey:@"station_name"];
        
        //NSString * modulationString = [favoriteDictionary objectForKey:@"modulation"];
        
        //NSNumber * bandwidthNumber = [favoriteDictionary objectForKey:@"bandwidth"];
        //NSString * bandwidthString = [bandwidthNumber stringValue];
    
        [tableString appendString:@"<tr>"];
        
        [tableString appendString:@"<td>"];
        
        //NSString * buttonString = [NSString stringWithFormat:@"<a class='twelve columns button button-primary' type='submit' href='viewfavorite.html?id=%@'>%@</a>", idString, idString];
        //[tableString appendString:buttonString];
        
        NSString * checkedFlagString = @"";
        NSInteger cat_id = categoryIDString.integerValue;
        NSInteger freq_id = idNumber.integerValue;
        
        BOOL freqCatRecordExists = [self.sqliteController freqCatRecordExistsForFrequencyID:freq_id categoryID:cat_id];
        
        if (freqCatRecordExists == YES)
        {
            checkedFlagString = @"checked";
        }
        
        //NSString * checkboxString = [NSString stringWithFormat:@"<input type='checkbox' class='checkbox' onclick='handleEditCategoryClick(this);' cat_id='%@' freq_id='%@' %@>&nbsp;%@</input>\n", categoryIDString, idNumber, checkedFlagString, idNumber];
        NSString * checkboxString = [NSString stringWithFormat:@"<input type='checkbox' class='checkbox' onclick='handleEditCategoryClick(this);' cat_id='%@' freq_id='%@' %@></input>\n", categoryIDString, idNumber, checkedFlagString];
        [tableString appendString:checkboxString];
        
        [tableString appendString:@"</td>"];
        
        [tableString appendString:@"<td>"];
        [tableString appendString:frequencyString];
        [tableString appendString:@"</td>"];
        
        [tableString appendString:@"<td>"];
        [tableString appendString:stationNameString];
        [tableString appendString:@"</td>"];
        
        [tableString appendString:@"</tr>"];
    }

    [tableString appendString:@"</tbody>"];
    [tableString appendString:@"</table>"];
    
    return tableString;
}


//==================================================================================
//	generateCategoriesString
//==================================================================================

- (NSString *)generateCategoriesString
{
    NSArray * allCategoriesArray = [self.sqliteController allCategoryRecords];
    
    NSMutableString * tableString = [NSMutableString string];
    
    [tableString appendString:@"<table class='u-full-width'>"];
    [tableString appendString:@"<thead>"];
    [tableString appendString:@"<tr>"];
    [tableString appendString:@"<th>ID</th>"];
    [tableString appendString:@"<th>Category</th>"];
    [tableString appendString:@"</tr>"];
    [tableString appendString:@"</thead>"];
    [tableString appendString:@"<tbody>"];
    
    for (NSDictionary * categoryDictionary in allCategoriesArray)
    {
        NSNumber * idNumber = [categoryDictionary objectForKey:@"id"];
        NSString * idString = [idNumber stringValue];
        
        NSString * categoryNameString = [categoryDictionary objectForKey:@"category_name"];
        
        [tableString appendString:@"<tr>"];
        
        [tableString appendString:@"<td>"];
        
        NSString * titleString = [NSString stringWithFormat:@"Show category %@", categoryNameString];

        NSString * buttonString = [NSString stringWithFormat:@"<a class='button button-primary' type='submit' onclick=\"loadContent('category.html?id=%@');\" title='%@'>%@</a>", idString, titleString, idString];
        [tableString appendString:buttonString];
        
        [tableString appendString:@"</td>"];
        
        [tableString appendString:@"<td>"];
        [tableString appendString:categoryNameString];
        [tableString appendString:@"</td>"];
        
        [tableString appendString:@"</tr>"];
    }

    [tableString appendString:@"</tbody>"];
    [tableString appendString:@"</table>"];
    
    
    NSMutableString * formNewCategoryString = [NSMutableString string];
    
    //[formNewCategoryString appendString:@"<form class='new-category-form' id='new-category-form' onsubmit='event.preventDefault(); return addCategory(this);' method='POST'>\n"];
    
    [formNewCategoryString appendString:@"<form class='new-category-form' id='new-category-form' action='javascript:loadContent(\"addcategoryform.html\")'"];

    NSString * newCategoryButtonString = [NSString stringWithFormat:@"<br>&nbsp;<br>&nbsp;<br>\n<input id='add-category-button' class='twelve columns button button-primary' type='submit' value='Add New Category'>\n"];
    [formNewCategoryString appendString:newCategoryButtonString];
    
    [formNewCategoryString appendString:@"</form>\n<br>&nbsp;<br>\n"];

    [tableString appendString:formNewCategoryString];
    
    return tableString;
}

//==================================================================================
//	editCategory:
//==================================================================================

- (void)editCategoryID:(NSInteger)cat_id frequencyID:(NSInteger)freq_id isMember:(BOOL)is_member
{
    BOOL relationExists = [self.sqliteController freqCatRecordExistsForFrequencyID:freq_id categoryID:cat_id];

    if (is_member == YES)
    {
        if (relationExists == NO)
        {
            [self.sqliteController insertFreqCatRecordForFrequencyID:freq_id categoryID:cat_id];
        }
    }
    else
    {
        if (relationExists == YES)
        {
            [self.sqliteController deleteFreqCatRecordForFrequencyID:freq_id categoryID:cat_id];
        }
    }
}

//==================================================================================
//	startRtlsdrTaskForFrequenciesWithDictionary:
//==================================================================================

- (void)startRtlsdrTaskForFrequenciesWithDictionary:(NSMutableDictionary *)freqCatDictionary
{
    NSArray * frequenciesArray = [freqCatDictionary objectForKey:@"frequencies"];
    
    NSMutableDictionary * categoryDictionary = NULL;
    id categoryDictionaryRef = [freqCatDictionary objectForKey:@"category"];
    if (categoryDictionaryRef != [NSNull null])
    {
        categoryDictionary = categoryDictionaryRef;
    }

    [self.sdrController startRtlsdrTasksForFrequencies:frequenciesArray category:categoryDictionary];
}


//==================================================================================
//	generateCategorySelectOptions
//==================================================================================

- (NSString *)generateCategorySelectOptions
{
    NSMutableString * selectOptionsString = [NSMutableString string];

    NSArray * categoriesArray = [self.sqliteController allCategoryRecords];

    [selectOptionsString appendString:@"<label for='categories_select'>Category:</label>"];
    [selectOptionsString appendString:@"<select class='twelve columns value-prop' name='categories_select' title='The Category pop-up button can be used when adding a new Favorites frequency record'>"];
    [selectOptionsString appendString:@"<option value='' selected></option>"];

    for (NSDictionary * categoryDictionary in categoriesArray)
    {
        NSNumber * categoryIDNumber = [categoryDictionary objectForKey:@"id"];
        NSString * categoryName = [categoryDictionary objectForKey:@"category_name"];
    
        [selectOptionsString appendFormat:@"<option value='%@'>%@</option>", categoryIDNumber, categoryName];
    }
    [selectOptionsString appendString:@"</select>"];
    
    return selectOptionsString;
}


//==================================================================================
//	generateOpenAudioPlayerPageButtonString
//==================================================================================

- (NSString *)generateOpenAudioPlayerPageButtonString
{
    NSString * hostString = self.appDelegate.localHostString;

    NSNumber * icecastServerPortNumber = [self.appDelegate.localRadioAppSettings integerForKey:@"IcecastServerPort"];
    NSString * icecastServerMountName = [self.appDelegate.localRadioAppSettings valueForKey:@"IcecastServerMountName"];

    //NSString * audioURLString = [NSString stringWithFormat:@"window.location='http://%@:%@/%@'", hostString, icecastServerPortNumber, icecastServerMountName];
    //NSString * audioURLString = [NSString stringWithFormat:@"location.href='http://%@:%@/%@'", hostString, icecastServerPortNumber, icecastServerMountName];
    NSString * audioURLString = [NSString stringWithFormat:@"http://%@:%@/%@", hostString, icecastServerPortNumber, icecastServerMountName];

    //NSString * listenButtonString = [NSString stringWithFormat:@"<button class='button button-primary twelve columns' type='button' onclick=\"%@\" target='_parent'>Open Audio Player Page</button>", audioURLString];

    NSString * listenButtonString = [NSString stringWithFormat:@"<a href='%@' target='_top'><button class='button button-primary twelve columns' type='button'>Open Audio Player Page</button></a>", audioURLString];

    return listenButtonString;
}

@end

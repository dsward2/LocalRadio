//
//  FCCMapController.m
//  LocalRadio
//
//  Created by Douglas Ward on 9/5/17.
//  Copyright © 2017-2018 ArkPhone LLC. All rights reserved.
//

#import "FCCSearchController.h"
#import "AppDelegate.h"
#import "SDRController.h"
#import "SQLiteController.h"

@implementation FCCSearchController

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.searchResultsArray = [NSMutableArray array];
        self.latitude = 0;
        self.longitude = 0;
        [self buildZipLatLongDictionary];
    }
    return self;
}



- (void)startStandardLocationServicesUpdates
{
    // Create the location manager if this object does not
    // already have one.
    
    if (self.locationManager == NULL)
    {
        self.locationManager = [[CLLocationManager alloc] init];
    }

    self.locationManager.delegate = self;
    self.locationManager.desiredAccuracy = kCLLocationAccuracyKilometer;
    self.locationManager.distanceFilter = kCLDistanceFilterNone; // meters

    if (![CLLocationManager locationServicesEnabled])
    {
        NSLog(@"Location services are not enabled, quitting.");
        NSBeep();
    }
    else if (([CLLocationManager authorizationStatus] == kCLAuthorizationStatusDenied) ||
             ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusRestricted))
    {
        NSLog(@"Location services are not authorized, quitting.");
        NSBeep();
    }
    else {
        [self.locationManager startUpdatingLocation];
    }

}




- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation
{
    // Filter out points before the last update
    /*
    NSTimeInterval timeSinceLastUpdate = [newLocation.timestamp timeIntervalSinceDate:dateOfLastUpdate];

    if (timeSinceLastUpdate > 0)
    {
        //Do stuff
    }
    */
}


- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    // Delegate method from the CLLocationManagerDelegate protocol.
    // If it's a relatively recent event, turn off updates to save power.
    CLLocation* location = [locations lastObject];
    NSDate* eventDate = location.timestamp;
    NSTimeInterval howRecent = [eventDate timeIntervalSinceNow];
    if (fabs(howRecent) < 15.0)
    {
        // If the event is recent, do something with it.
        NSLog(@"latitude %+.6f, longitude %+.6f\n",
              location.coordinate.latitude,
              location.coordinate.longitude);
        self.latitude = location.coordinate.latitude;
        self.longitude = location.coordinate.longitude;
    }
}




- (void)locationManager:(CLLocationManager *)manager locationManager:(CLAuthorizationStatus)status;
{
    NSLog(@"locationManager:locationManager: %d", status);
}




- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    NSLog(@"Location Error:%@", [error localizedDescription]);
}



- (void)buildZipLatLongDictionary
{
    NSBundle *thisBundle = [NSBundle bundleForClass:[self class]];
    NSString * filePath = [thisBundle pathForResource:@"zip_lat_long" ofType:@"txt"];

    self.zipLatLongDictionary = [NSMutableDictionary dictionary];
    
    FILE * file = fopen([filePath UTF8String], "r");
    char buffer[256];
    
    while (fgets((char *)&buffer, 256, file) != NULL)
    {
        NSString* result = [NSString stringWithUTF8String:buffer];
        //NSLog(@"%@",result);
        
        NSArray * lineComponents = [result componentsSeparatedByString:@","];
        
        if (lineComponents.count == 3)
        {
            NSString * zipCodeString = [lineComponents objectAtIndex:0];
            NSInteger zipCodeInteger = zipCodeString.integerValue;
            if (zipCodeInteger > 0)
            {
                NSNumber * zipCodeNumber = [NSNumber numberWithInteger:zipCodeInteger];
            
                NSString * latitudeString = [lineComponents objectAtIndex:1];
                NSString * longitudeString = [lineComponents objectAtIndex:2];
                
                double latitudeDouble = latitudeString.doubleValue;
                double longitudeDouble = longitudeString.doubleValue;
                
                NSNumber * latitudeNumber = [NSNumber numberWithDouble:latitudeDouble];
                NSNumber * longitudeNumber = [NSNumber numberWithDouble:longitudeDouble];
                
                NSDictionary * latLongDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                        latitudeNumber, @"lat",
                        longitudeNumber, @"long",
                        NULL];
                
                [self.zipLatLongDictionary setObject:latLongDictionary forKey:zipCodeNumber];
            }
        }
    }
    
    fclose(file);
}

- (IBAction)searchMethodPopUpButtonAction:(id)sender
{
    NSString * selectedMode = self.searchMethodPopUpButton.titleOfSelectedItem;
    
    if ([selectedMode isEqualToString:@"Search With 5-Digit ZIP Code"])
    {
        self.zipCodeTextField.hidden = NO;
    }
    else if ([selectedMode isEqualToString:@"Search With Current Location"])
    {
        self.zipCodeTextField.hidden = YES;
        
        if (self.locationManager == NULL)
        {
            [self startStandardLocationServicesUpdates];
        }
    }
}


- (IBAction)fccSearchButtonAction:(id)sender
{
    NSString * selectedMode = self.searchMethodPopUpButton.titleOfSelectedItem;
    
    if ([selectedMode isEqualToString:@"Search With 5-Digit ZIP Code"])
    {
        [self fccSearchByZIPCode];
    }
    else if ([selectedMode isEqualToString:@"Search With Current Location"])
    {
        [self fccSearchByCurrentLocation];
    }
}

- (void)fccSearchByZIPCode
{
    NSInteger zipCodeInteger = self.zipCodeTextField.integerValue;
    if ((zipCodeInteger >= 10000) && (zipCodeInteger <= 99999))
    {
        NSNumber * zipCodeNumber = [NSNumber numberWithInteger:zipCodeInteger];
        
        NSDictionary * zipCodeDictionary = [self.zipLatLongDictionary objectForKey:zipCodeNumber];
        if (zipCodeDictionary != NULL)
        {
            NSNumber * latitudeNumber = [zipCodeDictionary objectForKey:@"lat"];
            NSNumber * longitudeNumber = [zipCodeDictionary objectForKey:@"long"];
            
            double latitudeDouble = latitudeNumber.doubleValue;
            double longitudeDouble = longitudeNumber.doubleValue;

            int latSeconds = (int)(latitudeDouble * 3600);
            int latDegrees = latSeconds / 3600;
            latSeconds = ABS(latSeconds % 3600);
            int latMinutes = latSeconds / 60;
            latSeconds %= 60;

            int longSeconds = (int)(longitudeDouble * 3600);
            int longDegrees = longSeconds / 3600;
            longSeconds = ABS(longSeconds % 3600);
            int longMinutes = longSeconds / 60;
            longSeconds %= 60;

            char latLetter = (longitudeDouble < 0) ? 'N' : 'S';
            char longLetter = (latitudeDouble < 0) ? 'E' : 'W';
            
            NSLog(@"latitude = %d %d %d %c", latDegrees, latMinutes, latSeconds, latLetter);
            NSLog(@"longitude = %d %d %d %c", longDegrees, longMinutes, longSeconds, longLetter);
            
            NSString * radiusUnitsString = self.distanceModePopUpButton.titleOfSelectedItem;
            
            NSInteger radius = self.radiusTextField.integerValue;
            if ([radiusUnitsString isEqualToString:@"miles"])
            {
                radius = (float)radius * 1.60934f;
            }
            
            NSString * protoString = [NSString stringWithFormat:@"https://transition.fcc.gov/fcc-bin/fmq?call=&arn=&state=&city=&freq=0.0&fre2=107.9&serv=&vac=&facid=&asrn=&class=&list=4&dist=%ld&dlat2=%d&mlat2=%d&slat2=%d&NS=%c&dlon2=%d&mlon2=%d&slon2=%d&EW=%c&size=9&NextTab=Results+to+Next+Page%@Tab",
                    radius, latDegrees, latMinutes, latSeconds, latLetter,
                    longDegrees, longMinutes, longSeconds, longLetter, @"%2F"];
            
            NSLog(@"protoString = %@", protoString);
            
            //[self requestFCCData:protoString];
            [NSThread detachNewThreadSelector:@selector(requestFCCData:) toTarget:self withObject:protoString];
            
            [self.searchProgressIndicator startAnimation:self];
            [self.searchProgressIndicator setHidden:NO];
            [self.searchButton setEnabled:NO];
            [self.addToFavoritesButton setEnabled:NO];
            [self.listenButton setEnabled:NO];
        }
        else
        {
            NSBeep();

            [self.searchProgressIndicator stopAnimation:self];
            [self.searchProgressIndicator setHidden:YES];
            [self.searchButton setEnabled:YES];
            [self.addToFavoritesButton setEnabled:YES];
            [self.listenButton setEnabled:YES];
        }
    }
    else
    {
        NSBeep();

        [self.searchProgressIndicator stopAnimation:self];
        [self.searchProgressIndicator setHidden:YES];
        [self.searchButton setEnabled:YES];
        [self.addToFavoritesButton setEnabled:YES];
        [self.listenButton setEnabled:YES];
    }
}




- (void)fccSearchByCurrentLocation
{
    if (self.latitude != 0)
    {
        double latitudeDouble = self.latitude;
        double longitudeDouble = self.longitude;

        int latSeconds = (int)(latitudeDouble * 3600);
        int latDegrees = latSeconds / 3600;
        latSeconds = ABS(latSeconds % 3600);
        int latMinutes = latSeconds / 60;
        latSeconds %= 60;

        int longSeconds = (int)(longitudeDouble * 3600);
        int longDegrees = longSeconds / 3600;
        longSeconds = ABS(longSeconds % 3600);
        int longMinutes = longSeconds / 60;
        longSeconds %= 60;

        char latLetter = (longitudeDouble < 0) ? 'N' : 'S';
        char longLetter = (latitudeDouble < 0) ? 'E' : 'W';
        
        NSLog(@"latitude = %d %d %d %c", latDegrees, latMinutes, latSeconds, latLetter);
        NSLog(@"longitude = %d %d %d %c", longDegrees, longMinutes, longSeconds, longLetter);
        
        NSString * radiusUnitsString = self.distanceModePopUpButton.titleOfSelectedItem;
        
        NSInteger radius = self.radiusTextField.integerValue;
        if ([radiusUnitsString isEqualToString:@"miles"])
        {
            radius = (float)radius * 1.60934f;
        }
        
        NSString * protoString = [NSString stringWithFormat:@"https://transition.fcc.gov/fcc-bin/fmq?call=&arn=&state=&city=&freq=0.0&fre2=107.9&serv=&vac=&facid=&asrn=&class=&list=4&dist=%ld&dlat2=%d&mlat2=%d&slat2=%d&NS=%c&dlon2=%d&mlon2=%d&slon2=%d&EW=%c&size=9&NextTab=Results+to+Next+Page%@Tab",
                radius, latDegrees, latMinutes, latSeconds, latLetter,
                longDegrees, longMinutes, longSeconds, longLetter, @"%2F"];
        
        NSLog(@"protoString = %@", protoString);
        
        //[self requestFCCData:protoString];
        [NSThread detachNewThreadSelector:@selector(requestFCCData:) toTarget:self withObject:protoString];
        
        [self.searchProgressIndicator startAnimation:self];
        [self.searchProgressIndicator setHidden:NO];
        [self.searchButton setEnabled:NO];
        [self.addToFavoritesButton setEnabled:NO];
        [self.listenButton setEnabled:NO];
    }
    else
    {
        NSBeep();

        [self.searchProgressIndicator stopAnimation:self];
        [self.searchProgressIndicator setHidden:YES];
        [self.searchButton setEnabled:YES];
        [self.addToFavoritesButton setEnabled:YES];
        [self.listenButton setEnabled:YES];
    }
}

// |KABF        |88.3  MHz |FM |202 |ND  |-                   |C1 |-  |LIC    |LITTLE ROCK              |AR |US |BLED   -19900803KC  |91.    kW |91.    kW |237.0   |237.0   |2772       |N |34 |47 |31.00 |W |92  |28 |38.00 |ARKANSAS BROADCASTING FOUNDATION INC                                        |  18.74 km |  11.64 mi |285.67 deg |362.   m|362.0  m|-         |-       |-       |85.    m|151310    |


- (void) requestFCCData:(NSString *)urlString
{
    [self.searchResultsArray removeAllObjects];

    self.urlSession =[NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]
            delegate:self delegateQueue:[NSOperationQueue mainQueue]];

    NSURL *url = [NSURL URLWithString:urlString];
    NSURLSessionDataTask * dataTask =
    [self.urlSession dataTaskWithURL:url completionHandler:^(NSData *data,
            NSURLResponse *response, NSError *error)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
        
            if (error == NULL)
            {
            //nameLabel.text = @"yay!";
                NSString * dataString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                //NSLog(@"dataString = %@", dataString);
                
                NSCharacterSet * newlineCharacterSet = [NSCharacterSet newlineCharacterSet];
                NSCharacterSet * whitespaceCharacterSet = [NSCharacterSet whitespaceCharacterSet];
                NSArray * linesArray = [dataString componentsSeparatedByCharactersInSet:newlineCharacterSet];
                
                for (NSString * lineString in linesArray)
                {
                    NSArray * untrimmedFieldsArray = [lineString componentsSeparatedByString:@"|"];
                    
                    NSMutableArray * fieldsArray = [NSMutableArray array];
                    for (NSString * untrimmedFieldString in untrimmedFieldsArray)
                    {
                        NSString * trimmedFieldString = [untrimmedFieldString stringByTrimmingCharactersInSet:whitespaceCharacterSet];
                        
                        trimmedFieldString = [trimmedFieldString stringByReplacingOccurrencesOfString:@"    " withString:@" "];
                        trimmedFieldString = [trimmedFieldString stringByReplacingOccurrencesOfString:@"   " withString:@" "];
                        trimmedFieldString = [trimmedFieldString stringByReplacingOccurrencesOfString:@"  " withString:@" "];
                        trimmedFieldString = [trimmedFieldString stringByReplacingOccurrencesOfString:@". " withString:@" "];
                        
                        [fieldsArray addObject:trimmedFieldString];
                    }

                    if (fieldsArray.count == 39)
                    {
                        NSString * recordType = [fieldsArray objectAtIndex:3];
                        
                        if ([recordType isEqualToString:@"FM"] == YES)
                        {
                            [self.searchResultsArray addObject:fieldsArray];
                        }
                    }
                }
            }
            else
            {
                NSBeep();
            }
            
            [self.fccTableView reloadData];

            [self.searchProgressIndicator stopAnimation:self];
            [self.searchProgressIndicator setHidden:YES];
            [self.searchButton setEnabled:YES];
            [self.addToFavoritesButton setEnabled:YES];
            [self.listenButton setEnabled:YES];

        });
    }];
    
    [dataTask resume];
}








- (IBAction)fccListenButtonAction:(id)sender
{
    NSInteger row = self.fccTableView.selectedRow;

    if (row >= 0)
    {
        NSMutableArray * linesArray = [self.searchResultsArray objectAtIndex:row];
        NSString * stationNameString = [linesArray objectAtIndex:1];
        NSString * frequencyString = [linesArray objectAtIndex:2];
        NSString * recordTypeString = [linesArray objectAtIndex:3];
        NSString * cityString = [linesArray objectAtIndex:10];
        NSString * stateString = [linesArray objectAtIndex:11];
        NSString * erpString = [linesArray objectAtIndex:15];
        NSString * licenseeString = [linesArray objectAtIndex:27];
        NSString * distanceKmString = [linesArray objectAtIndex:28];
        NSString * distanceMilesString = [linesArray objectAtIndex:29];
        NSString * directionString = [linesArray objectAtIndex:30];
        
        NSInteger hertzFrequency = [self.appDelegate hertzWithString:frequencyString];
        if (hertzFrequency > 0)
        {
            NSMutableDictionary * frequencyDictionary = [self.appDelegate.sqliteController makePrototypeDictionaryForTable:@"frequency"];
            
            //NSMutableDictionary * frequencyDictionary = self.appDelegate.constructFrequencyDictionary;
            
            if (frequencyDictionary == NULL)
            {
                frequencyDictionary = [self.appDelegate.sqliteController makePrototypeDictionaryForTable:@"frequency"];
            }
            
            NSInteger sampleRate = self.sampleRatePopUpButton.titleOfSelectedItem.integerValue;
            double tunerGain = self.tunerGainPopUpButton.titleOfSelectedItem.doubleValue;
            
            NSNumber * freqNumber = [NSNumber numberWithInteger:hertzFrequency];
            NSNumber * sampleRateNumber = [NSNumber numberWithInteger:sampleRate];
            NSNumber * tunerGainNumber = [NSNumber numberWithDouble:tunerGain];
            
            [frequencyDictionary setObject:freqNumber forKey:@"frequency"];
            [frequencyDictionary setObject:sampleRateNumber forKey:@"sample_rate"];
            [frequencyDictionary setObject:tunerGainNumber forKey:@"tuner_gain"];

            [self.appDelegate.sdrController startRtlsdrTasksForFrequency:frequencyDictionary];
        }
        else
        {
            NSBeep();
        }
    }
    else
    {
        NSBeep();
    }
}

 
- (IBAction)fccImportButtonAction:(id)sender
{
    NSInteger row = self.fccTableView.selectedRow;

    if (row >= 0)
    {
        NSMutableArray * linesArray = [self.searchResultsArray objectAtIndex:row];
        NSString * stationNameString = [linesArray objectAtIndex:1];
        NSString * frequencyString = [linesArray objectAtIndex:2];
        NSString * recordTypeString = [linesArray objectAtIndex:3];
        NSString * cityString = [linesArray objectAtIndex:10];
        NSString * stateString = [linesArray objectAtIndex:11];
        NSString * erpString = [linesArray objectAtIndex:15];
        NSString * licenseeString = [linesArray objectAtIndex:27];
        NSString * distanceKmString = [linesArray objectAtIndex:28];
        NSString * distanceMilesString = [linesArray objectAtIndex:29];
        NSString * directionString = [linesArray objectAtIndex:30];
        
        NSInteger hertzFrequency = [self.appDelegate hertzWithString:frequencyString];
        if (hertzFrequency > 0)
        {
            NSString * hertzFrequencyString = [NSString stringWithFormat:@"%ld", hertzFrequency];
            NSMutableDictionary * existingFrequencyDictionary = [[self.appDelegate.sqliteController frequencyRecordForFrequency:hertzFrequencyString] mutableCopy];
            
            if (existingFrequencyDictionary != NULL)
            {
                // ask user how to resolve existing record
            
                NSAlert *alert = [[NSAlert alloc] init];
                [alert setMessageText:@"Existing record found for this frequency"];
                [alert setInformativeText:@"You can replace the existing frequency record, or add a new record with the same frequency, or cancel this operation."];
                [alert addButtonWithTitle:@"Replace Existing Record"];
                [alert addButtonWithTitle:@"Add New Record"];
                [alert addButtonWithTitle:@"Cancel"];
                [alert setAlertStyle:NSWarningAlertStyle];

                [alert beginSheetModalForWindow:self.fccSearchWindow completionHandler:^(NSModalResponse returnCode) {
                    if (returnCode == NSAlertThirdButtonReturn) {
                        // Cancel button
                        return;
                    }
                    if (returnCode == NSAlertSecondButtonReturn) {
                        // Add New Record button
                        [self addToFavorites];
                        return;
                    }
                    
                    // Replace Existing Record button clicked
                    
                    [self updateFavorite];
                }];
            }
            else
            {
                [self addToFavorites];
            }
        }
    }
}




- (void)updateFavorite
{
    NSInteger row = self.fccTableView.selectedRow;

    if (row >= 0)
    {
        NSMutableArray * linesArray = [self.searchResultsArray objectAtIndex:row];
        NSString * stationNameString = [linesArray objectAtIndex:1];
        NSString * frequencyString = [linesArray objectAtIndex:2];
        NSString * recordTypeString = [linesArray objectAtIndex:3];
        NSString * cityString = [linesArray objectAtIndex:10];
        NSString * stateString = [linesArray objectAtIndex:11];
        NSString * erpString = [linesArray objectAtIndex:15];
        NSString * licenseeString = [linesArray objectAtIndex:27];
        NSString * distanceKmString = [linesArray objectAtIndex:28];
        NSString * distanceMilesString = [linesArray objectAtIndex:29];
        NSString * directionString = [linesArray objectAtIndex:30];
        
        NSInteger hertzFrequency = [self.appDelegate hertzWithString:frequencyString];
        if (hertzFrequency > 0)
        {
            NSString * hertzFrequencyString = [NSString stringWithFormat:@"%ld", hertzFrequency];
            NSMutableDictionary * frequencyDictionary = [[self.appDelegate.sqliteController frequencyRecordForFrequency:hertzFrequencyString] mutableCopy];

            //NSMutableDictionary * frequencyDictionary = [self.appDelegate.sqliteController makePrototypeDictionaryForTable:@"frequency"];
            //NSMutableDictionary * frequencyDictionary = self.appDelegate.constructFrequencyDictionary;
            
            if (frequencyDictionary == NULL)
            {
                frequencyDictionary = [self.appDelegate.sqliteController makePrototypeDictionaryForTable:@"frequency"];
            }
            
            NSInteger sampleRate = self.sampleRatePopUpButton.titleOfSelectedItem.integerValue;
            double tunerGain = self.tunerGainPopUpButton.titleOfSelectedItem.doubleValue;
            
            NSString * stationAndCityName = [NSString stringWithFormat:@"%@ - %@", stationNameString, cityString];
            
            NSNumber * freqNumber = [NSNumber numberWithInteger:hertzFrequency];
            NSNumber * sampleRateNumber = [NSNumber numberWithInteger:sampleRate];
            NSNumber * tunerGainNumber = [NSNumber numberWithDouble:tunerGain];
            
            NSNumber * oversamplingNumber = [NSNumber numberWithInteger:4];
            if (sampleRate > 85000)
            {
                oversamplingNumber = [NSNumber numberWithInteger:2];
            }
            
            [frequencyDictionary setObject:stationAndCityName forKey:@"station_name"];
            [frequencyDictionary setObject:freqNumber forKey:@"frequency"];
            [frequencyDictionary setObject:sampleRateNumber forKey:@"sample_rate"];
            [frequencyDictionary setObject:tunerGainNumber forKey:@"tuner_gain"];
            [frequencyDictionary setObject:@"vol 1 deemph dither -s" forKey:@"audio_output_filter"];
            [frequencyDictionary setObject:oversamplingNumber forKey:@"oversampling"];
            
            [self.appDelegate.sqliteController storeRecord:frequencyDictionary table:@"frequency"];
        }
    }
}




- (void)addToFavorites
{
    NSInteger row = self.fccTableView.selectedRow;

    if (row >= 0)
    {
        NSMutableArray * linesArray = [self.searchResultsArray objectAtIndex:row];
        NSString * stationNameString = [linesArray objectAtIndex:1];
        NSString * frequencyString = [linesArray objectAtIndex:2];
        NSString * recordTypeString = [linesArray objectAtIndex:3];
        NSString * cityString = [linesArray objectAtIndex:10];
        NSString * stateString = [linesArray objectAtIndex:11];
        NSString * erpString = [linesArray objectAtIndex:15];
        NSString * licenseeString = [linesArray objectAtIndex:27];
        NSString * distanceKmString = [linesArray objectAtIndex:28];
        NSString * distanceMilesString = [linesArray objectAtIndex:29];
        NSString * directionString = [linesArray objectAtIndex:30];
        
        NSInteger hertzFrequency = [self.appDelegate hertzWithString:frequencyString];
        if (hertzFrequency > 0)
        {
            NSMutableDictionary * frequencyDictionary = [self.appDelegate.sqliteController makePrototypeDictionaryForTable:@"frequency"];
            
            //NSMutableDictionary * frequencyDictionary = self.appDelegate.constructFrequencyDictionary;
            
            if (frequencyDictionary == NULL)
            {
                frequencyDictionary = [self.appDelegate.sqliteController makePrototypeDictionaryForTable:@"frequency"];
            }
            
            NSInteger sampleRate = self.sampleRatePopUpButton.titleOfSelectedItem.integerValue;
            double tunerGain = self.tunerGainPopUpButton.titleOfSelectedItem.doubleValue;
            
            NSString * stationAndCityName = [NSString stringWithFormat:@"%@ - %@", stationNameString, cityString];
            
            NSNumber * freqNumber = [NSNumber numberWithInteger:hertzFrequency];
            NSNumber * sampleRateNumber = [NSNumber numberWithInteger:sampleRate];
            NSNumber * tunerGainNumber = [NSNumber numberWithDouble:tunerGain];
            
            NSNumber * oversamplingNumber = [NSNumber numberWithInteger:4];
            if (sampleRate > 85000)
            {
                oversamplingNumber = [NSNumber numberWithInteger:2];
            }
            
            [frequencyDictionary setObject:stationAndCityName forKey:@"station_name"];
            [frequencyDictionary setObject:freqNumber forKey:@"frequency"];
            [frequencyDictionary setObject:sampleRateNumber forKey:@"sample_rate"];
            [frequencyDictionary setObject:tunerGainNumber forKey:@"tuner_gain"];
            [frequencyDictionary setObject:@"vol 1 deemph dither -s" forKey:@"audio_output_filter"];
            [frequencyDictionary setObject:oversamplingNumber forKey:@"oversampling"];
            
            [self.appDelegate.sqliteController storeRecord:frequencyDictionary table:@"frequency"];
        }
    }
}


- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return self.searchResultsArray.count;
}


- (NSView *)tableView:(NSTableView *)tableView 
   viewForTableColumn:(NSTableColumn *)tableColumn 
                  row:(NSInteger)row
{
    NSTableCellView * cell = [self.fccTableView makeViewWithIdentifier:tableColumn.identifier owner: self];
    
    NSString * resultString = @"???";

    NSMutableArray * linesArray = [self.searchResultsArray objectAtIndex:row];
    NSString * stationNameString = [linesArray objectAtIndex:1];
    NSString * frequencyString = [linesArray objectAtIndex:2];
    NSString * recordTypeString = [linesArray objectAtIndex:3];
    NSString * cityString = [linesArray objectAtIndex:10];
    NSString * stateString = [linesArray objectAtIndex:11];
    NSString * erpString = [linesArray objectAtIndex:15];
    NSString * licenseeString = [linesArray objectAtIndex:27];
    NSString * distanceKmString = [linesArray objectAtIndex:28];
    NSString * distanceMilesString = [linesArray objectAtIndex:29];
    NSString * directionString = [linesArray objectAtIndex:30];

    if ([tableColumn.identifier isEqualToString:@"frequency"] == YES)
    {
        resultString = frequencyString;
    }
    else if ([tableColumn.identifier isEqualToString:@"station_name"] == YES)
    {
        resultString = stationNameString;
    }
    else if ([tableColumn.identifier isEqualToString:@"location"] == YES)
    {
        resultString = [NSString stringWithFormat:@"%@, %@ - %@", cityString, stateString, licenseeString];
    }
    else if ([tableColumn.identifier isEqualToString:@"distance"] == YES)
    {
        NSString * distanceString = @"???";
        NSString * radiusUnitsString = self.distanceModePopUpButton.titleOfSelectedItem;
        if ([radiusUnitsString isEqualToString:@"miles"])
        {
            NSInteger distance = distanceMilesString.integerValue;
            distanceString = [NSString stringWithFormat:@"%ld mi", distance];
        }
        else
        {
            NSInteger distance = distanceKmString.integerValue;
            distanceString = [NSString stringWithFormat:@"%ld km", distance];
        }
    
        resultString = distanceString;
    }
    else if ([tableColumn.identifier isEqualToString:@"direction"] == YES)
    {
        NSInteger directionPoint = directionString.integerValue / 22.5;
        NSString * directionPointString = @"???";
        switch (directionPoint % 16)
        {
            case 0:
                directionPointString = @"N";
                break;
            case 1:
                directionPointString = @"NE";
                break;
            case 2:
                directionPointString = @"NE";
                break;
            case 3:
                directionPointString = @"E";
                break;
            case 4:
                directionPointString = @"E";
                break;
            case 5:
                directionPointString = @"SE";
                break;
            case 6:
                directionPointString = @"SE";
                break;
            case 7:
                directionPointString = @"S";
                break;
            case 8:
                directionPointString = @"S";
                break;
            case 9:
                directionPointString = @"SW";
                break;
            case 10:
                directionPointString = @"SW";
                break;
            case 11:
                directionPointString = @"W";
                break;
            case 12:
                directionPointString = @"W";
                break;
            case 13:
                directionPointString = @"NW";
                break;
            case 14:
                directionPointString = @"NW";
                break;
            case 15:
                directionPointString = @"N";
                break;
        }
        
        resultString = directionPointString;
    }
    else if ([tableColumn.identifier isEqualToString:@"erp"] == YES)
    {
        resultString = erpString;
    }

    cell.textField.stringValue = resultString;
    return cell;
}

 
@end

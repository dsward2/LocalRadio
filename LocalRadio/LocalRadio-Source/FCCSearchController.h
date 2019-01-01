//
//  FCCMapController.h
//  LocalRadio
//
//  Created by Douglas Ward on 9/5/17.
//  Copyright © 2017-2018 ArkPhone LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <CoreLocation/CoreLocation.h>

@class AppDelegate;

@interface FCCSearchController : NSObject <NSTableViewDelegate, NSTableViewDataSource, NSURLSessionDelegate, CLLocationManagerDelegate>
{
}

@property (weak) IBOutlet NSWindow *  fccSearchWindow;
@property (weak) IBOutlet AppDelegate * appDelegate;
@property (weak) IBOutlet NSTableView * fccTableView;
@property (weak) IBOutlet NSTextField * zipCodeTextField;
@property (weak) IBOutlet NSTextField * radiusTextField;
@property (weak) IBOutlet NSPopUpButton * distanceModePopUpButton;
@property (weak) IBOutlet NSProgressIndicator * searchProgressIndicator;
@property (weak) IBOutlet NSButton * searchButton;
@property (weak) IBOutlet NSButton * listenButton;
@property (weak) IBOutlet NSButton * addToFavoritesButton;
@property (weak) IBOutlet NSPopUpButton * sampleRatePopUpButton;
@property (weak) IBOutlet NSPopUpButton * tunerGainPopUpButton;
@property (weak) IBOutlet NSPopUpButton * searchMethodPopUpButton;

@property (strong) CLLocationManager * locationManager;
@property (assign) CLLocationDegrees latitude;
@property (assign) CLLocationDegrees longitude;

@property (strong) NSMutableDictionary * zipLatLongDictionary;
@property (strong) NSURLSession * urlSession;
@property (strong) NSMutableArray * searchResultsArray;

- (IBAction)fccSearchButtonAction:(id)sender;
- (IBAction)fccImportButtonAction:(id)sender;
- (IBAction)fccListenButtonAction:(id)sender;
- (IBAction)searchMethodPopUpButtonAction:(id)sender;

@end

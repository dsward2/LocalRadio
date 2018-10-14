//
//  IcecastController.h
//  LocalRadio
//
//  Created by Douglas Ward on 6/18/17.
//  Copyright © 2017-2018 ArkPhone LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AppDelegate;

@interface IcecastController : NSObject  <NSXMLParserDelegate>

@property(strong) IBOutlet AppDelegate * appDelegate;

@property (strong) NSTask * icecastTask;
@property (strong) NSTask * ezStreamTask;

@property (strong) NSXMLParser * icecastStatusParser;
@property (strong) NSString * currentElementName;
@property (strong) NSMutableString * currentElementData;
@property (assign) BOOL inSourceElement;
@property (strong) NSMutableDictionary * parserOutputDictionary;
@property (strong) NSMutableDictionary * currentSourceDictionary;

@property (strong) NSArray * icecastTaskArgsArray;
@property (strong) NSString * icecastTaskArgsString;
@property (strong) NSString * quotedIcecastPath;

@property (strong) NSDictionary * lastIcecastStatusDictionary;
@property (assign) BOOL icecastStatusBusy;

@property (assign) int icecastTaskProcessID;

@property (strong) NSPipe * stderrPipe;

- (void)terminateTasks;

- (void)configureIcecast;
- (void)startIcecastServer;
- (void)stopIcecastServer;


- (NSDictionary *)icecastStatusDictionary;
- (NSString *)icecastWebServerURLString;

@end

//
//  LocalRadioAPI.h
//  LocalRadio
//
//  Created by Douglas Ward on 10/28/18.
//  Copyright © 2018 ArkPhone LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class AppDelegate;
@class HTTPWebServerConnection;
@class SQLiteController;
@class SDRController;

@interface LocalRadioAPI : NSObject

@property (weak) IBOutlet AppDelegate * appDelegate;
@property (weak) IBOutlet SQLiteController * sqliteController;
@property (weak) IBOutlet SDRController * sdrController;

- (NSString *)httpResponseForMethod:(NSString *)method URI:(NSString *)path webServerConnection:(HTTPWebServerConnection *)webServerConnection;

@end

NS_ASSUME_NONNULL_END

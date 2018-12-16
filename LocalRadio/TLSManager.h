//
//  TLSManager.h
//  LocalRadio
//
//  Created by Douglas Ward on 12/15/18.
//  Copyright © 2018 ArkPhone LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class AppDelegate;

@interface TLSManager : NSObject

@property(strong) IBOutlet AppDelegate * appDelegate;

- (void)configureCertificates;
- (NSString *)tlsDirectoryPath;

@end

NS_ASSUME_NONNULL_END

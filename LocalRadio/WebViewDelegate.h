//
//  WebViewDelegate.h
//  LocalRadio
//
//  Created by Douglas Ward on 7/15/17.
//  Copyright © 2017-2018 ArkPhone LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import "AppDelegate.h"

@interface WebViewDelegate : NSObject <WebUIDelegate, WebPolicyDelegate, WebDownloadDelegate, WebFrameLoadDelegate, WebResourceLoadDelegate>

@property (weak) IBOutlet AppDelegate * appDelegate;
@property (strong) IBOutlet WebView * webView;    // allocated in code
@property (weak) IBOutlet NSView * webViewParentView;
@property (weak) IBOutlet NSWindow * webViewWindow;

- (void)loadMainPage;

@end

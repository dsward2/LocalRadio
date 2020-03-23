//
//  WebViewDelegate.m
//  LocalRadio
//
//  Created by Douglas Ward on 7/15/17.
//  Copyright © 2017-2020 ArkPhone LLC. All rights reserved.
//

#import "WebViewDelegate.h"
#import "AppDelegate.h"

@implementation WebViewDelegate

- (void)loadMainPage
{
    [self performSelectorOnMainThread:@selector(loadMainPageOnMainThread) withObject:NULL waitUntilDone:NO];
}



-( void)loadMainPageOnMainThread
{
    if (self.webView == NULL)
    {
        NSRect webViewFrame = self.webViewParentView.bounds;
        self.webView = [[WKWebView alloc] initWithFrame:webViewFrame];
        [self.webViewParentView addSubview:self.webView];
        self.webView.UIDelegate = self;
        self.webView.navigationDelegate = self;
        
        self.webView.customUserAgent = @"LocalRadio/1.0";

        NSString * urlString = [self.appDelegate httpWebServerControllerURLString];
        NSURL * url = [NSURL URLWithString:urlString];
        NSURLRequest * urlRequest = [NSURLRequest requestWithURL:url];
        [self.webView loadRequest:urlRequest];
    }
}


- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(void))completionHandler
{
    [self.appDelegate showInformationSheetWithMessage:@"LocalRadio" informativeText:message];
}


- (void)webView:(WKWebView *)webView runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(BOOL result))completionHandler
{
    // this delegate method is called via JavaScript's confirm() function in localradio.js when a frequency or category record deletion is requested
    NSString * informativeText = @"Click OK button to delete the record.";

    NSAlert * alert = [[NSAlert alloc] init];
    [alert setMessageText:message];
    [alert setInformativeText:informativeText];
    [alert addButtonWithTitle:@"OK"];
    [alert addButtonWithTitle:@"Cancel"];
    [alert setAlertStyle:NSAlertStyleWarning];

    [alert beginSheetModalForWindow:self.webViewWindow completionHandler:^(NSModalResponse returnCode)
    {
        // return NSAlertFirstButtonReturn for OK button or
        // NSAlertSecondButtonReturn for Cancel button
        
        [[NSApplication sharedApplication] stopModalWithCode:returnCode];
        
        BOOL result = NO;
        if (returnCode == NSAlertFirstButtonReturn)
        {
            result = YES;
        }
        
        completionHandler(result);
    }];

    [NSApp runModalForWindow:self.webViewWindow];
}

@end

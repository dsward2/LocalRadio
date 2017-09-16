//
//  WebViewDelegate.m
//  LocalRadio
//
//  Created by Douglas Ward on 7/15/17.
//  Copyright © 2017 ArkPhone LLC. All rights reserved.
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
        self.webView = [[WebView alloc] initWithFrame:webViewFrame];
        [self.webViewParentView addSubview:self.webView];
        self.webView.UIDelegate = self;
        self.webView.policyDelegate = self;
        self.webView.downloadDelegate = self;
        self.webView.frameLoadDelegate = self;
        self.webView.resourceLoadDelegate = self;
        
        self.webView.customUserAgent = @"LocalRadio/1.0";

        NSString * urlString = [self.appDelegate webServerControllerURLString];
        NSURL * url = [NSURL URLWithString:urlString];
        NSURLRequest * urlRequest = [NSURLRequest requestWithURL:url];
        [[self.webView mainFrame] loadRequest:urlRequest];
    }
}



- (void)webView:(WebView *)sender runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WebFrame *)frame
{
    [self.appDelegate showInformationSheetWithMessage:@"LocalRadio" informativeText:message];
}



- (BOOL)webView:(WebView *)sender runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(id)frame
{
    BOOL result = NO;
    NSInteger resultInteger = -1;
    
    NSString * informativeText = @"Click OK button to delete the record.";

    NSAlert * alert = [[NSAlert alloc] init];
    [alert setMessageText:message];
    [alert setInformativeText:informativeText];
    [alert addButtonWithTitle:@"OK"];
    [alert addButtonWithTitle:@"Cancel"];
    [alert setAlertStyle:NSWarningAlertStyle];

    [alert beginSheetModalForWindow:self.webViewWindow modalDelegate:self
            didEndSelector:@selector(confirmPanelAlertDidEnd:returnCode:contextInfo:) contextInfo:&resultInteger];

    [NSApp runModalForWindow:self.webViewWindow];
    
    if (resultInteger == 1)
    {
        result = YES;
    }

    return result;
}


- (void)confirmPanelAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
    NSInteger * resultPtr = contextInfo;
    if (returnCode == NSAlertFirstButtonReturn) {
        *resultPtr = 1;
        [[NSApplication sharedApplication] stopModal];
    }
    else if (returnCode == NSAlertSecondButtonReturn) {
        *resultPtr = 0;
        [[NSApplication sharedApplication] stopModal];
    }
}




- (void)webView:(WebView *)webView decidePolicyForNewWindowAction:(NSDictionary *)actionInformation
        request:(NSURLRequest *)request newFrameName:(NSString *)frameName
        decisionListener:(id<WebPolicyDecisionListener>)listener
{
    [listener ignore];      // Ignore requests for new WebView window

    // handle URL request with default web browser
    NSString * urlString = request.URL.absoluteString;
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:urlString]];
}



@end

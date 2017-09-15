//
//  main.m
//  LocalRadio
//
//  Created by Douglas Ward on 4/22/17.
//  Copyright © 2017 ArkPhone LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

int main(int argc, const char * argv[])
{
    [[NSUserDefaults standardUserDefaults] setBool:TRUE forKey:@"WebKitDeveloperExtras"];
    [[NSUserDefaults standardUserDefaults] setBool:TRUE forKey:@"WebKitScriptDebugger"];
    [[NSUserDefaults standardUserDefaults] setBool:TRUE forKey:@"IncludeInternalDebugMenu"];
    [[NSUserDefaults standardUserDefaults] setBool:TRUE forKey:@"IncludeDebugMenu"];

    [[NSUserDefaults standardUserDefaults] synchronize];

    return NSApplicationMain(argc, argv);
}

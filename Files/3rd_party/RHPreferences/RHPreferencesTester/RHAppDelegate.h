//
//  RHAppDelegate.h
//  RHPreferencesTester
//
//  Created by Richard Heard on 23/05/12.
//  Copyright (c) 2012 Richard Heard. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <RHPreferences/RHPreferences.h>

@interface RHAppDelegate : NSObject <NSApplicationDelegate> {
    
    NSWindow *_window;
    RHPreferencesWindowController *_preferencesWindowController;
}

@property (assign) IBOutlet NSWindow *window;
@property (retain) RHPreferencesWindowController *preferencesWindowController;


#pragma mark - IBActions
-(IBAction)showPreferences:(id)sender;



@end

//
//  VeryTestWindow.m
//  Operations
//
//  Created by Michael G. Kazakov on 5/30/17.
//  Copyright © 2017 Michael G. Kazakov. All rights reserved.
//

#import "VeryTestWindow.h"

@interface VeryTestWindow ()

@end

@implementation VeryTestWindow

- (void)windowDidLoad {
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

@end

void ShowVeryTestWindow()
{
//- (instancetype)initWithWindowNibName:(NSString *)windowNibName;
    //VeryTestWindow *w = [[VeryTestWindow alloc] init];
    static VeryTestWindow *w;
    w = [[VeryTestWindow alloc] initWithWindowNibName:@"VeryTestWindow"];
//    w = [[VeryTestWindow alloc] init];
    NSWindow *ww = w.window;
    [w showWindow:nil];
    
    NSLog(@"%@", [NSBundle bundleForClass:VeryTestWindow.class].bundlePath);

}

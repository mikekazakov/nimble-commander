//
//  PreferencesWindowPanelsTab.m
//  Files
//
//  Created by Michael G. Kazakov on 13.07.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "PreferencesWindowPanelsTab.h"

@interface PreferencesWindowPanelsTab ()

@end

@implementation PreferencesWindowPanelsTab

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:NSStringFromClass(self.class) bundle:nibBundleOrNil];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

-(NSString*)identifier{
    return NSStringFromClass(self.class);
}
-(NSImage*)toolbarItemImage{
    return [NSImage imageNamed:NSImageNameGoRightTemplate];
}
-(NSString*)toolbarItemLabel{
    return @"Panels";
}

@end

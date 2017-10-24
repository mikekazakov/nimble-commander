//
//  RHWideViewController.m
//  RHPreferences
//
//  Created by Richard Heard on 23/05/12.
//  Copyright (c) 2012 Richard Heard. All rights reserved.
//

#import "RHWideViewController.h"

@interface RHWideViewController ()

@end

@implementation RHWideViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:@"RHWideViewController" bundle:nibBundleOrNil];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

#pragma mark - RHPreferencesViewControllerProtocol

-(NSString*)identifier{
    return NSStringFromClass(self.class);
}
-(NSImage*)toolbarItemImage{
    return [NSImage imageNamed:@"WidePreferences"];
}
-(NSString*)toolbarItemLabel{
    return NSLocalizedString(@"Resizing", @"WideToolbarItemLabel");
}

@end

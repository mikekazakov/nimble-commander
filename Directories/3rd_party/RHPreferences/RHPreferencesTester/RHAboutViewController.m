//
//  RHAboutViewController.m
//  RHPreferencesTester
//
//  Created by Richard Heard on 17/04/12.
//  Copyright (c) 2012 Richard Heard. All rights reserved.
//

#import "RHAboutViewController.h"

@interface RHAboutViewController ()

@end

@implementation RHAboutViewController
@synthesize emailTextField = _emailTextField;

-(id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil{
    self = [super initWithNibName:@"RHAboutViewController" bundle:nibBundleOrNil];
    if (self){
        // Initialization code here.
    }
    return self;
}


#pragma mark - RHPreferencesViewControllerProtocol

-(NSString*)identifier{
    return NSStringFromClass(self.class);
}
-(NSImage*)toolbarItemImage{
    return [NSImage imageNamed:@"AboutPreferences"];
}
-(NSString*)toolbarItemLabel{
    return NSLocalizedString(@"About", @"AboutToolbarItemLabel");
}

-(NSView*)initialKeyView{
    return self.emailTextField;
}

@end

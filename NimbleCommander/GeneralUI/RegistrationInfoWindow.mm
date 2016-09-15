//
//  RegistrationInfoWindow.m
//  NimbleCommander
//
//  Created by Michael G. Kazakov on 9/14/16.
//  Copyright © 2016 Michael G. Kazakov. All rights reserved.
//
#include "../../Files/GoogleAnalytics.h"
#include "../../Files/ActivationManager.h"
#include "RegistrationInfoWindow.h"

@interface RegistrationInfoWindow ()
@property (strong) IBOutlet NSTabView *tabView;
@property (strong) IBOutlet NSTextField *apProduct;
@property (strong) IBOutlet NSTextField *apName;
@property (strong) IBOutlet NSTextField *apEmail;
@property (strong) IBOutlet NSTextField *apCompany;
@end

@implementation RegistrationInfoWindow
{
    RegistrationInfoWindow *m_Self;
}

- (id) init
{
    self = [super initWithWindowNibName:NSStringFromClass(self.class)];
    if( self ) {
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    m_Self = self;
    
    if( ActivationManager::ForAppStore() ) {
        [self.tabView selectTabViewItemAtIndex:0];
    }
    else {
        if( ActivationManager::Instance().UserHadRegistered() ) {
            [self.tabView selectTabViewItemAtIndex:1];
            auto &info = ActivationManager::Instance().LicenseInformation();
            if( info.count("Company") )
                self.apCompany.stringValue = [NSString stringWithUTF8StdString:info.at("Company")];
            if( info.count("Email") )
                self.apEmail.stringValue = [NSString stringWithUTF8StdString:info.at("Email")];
            if( info.count("Name") )
                self.apName.stringValue = [NSString stringWithUTF8StdString:info.at("Name")];
            if( info.count("Product") )
                self.apProduct.stringValue = [NSString stringWithUTF8StdString:info.at("Product")];
        }
        else {
            [self.tabView selectTabViewItemAtIndex:2];
        }
    }
    GoogleAnalytics::Instance().PostScreenView("Registration Info Sheet");
}

- (IBAction)onOK:(id)sender
{
    [self.window.sheetParent endSheet:self.window returnCode:0];
    m_Self = nil;
}

@end

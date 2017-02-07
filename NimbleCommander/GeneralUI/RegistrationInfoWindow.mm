//
//  RegistrationInfoWindow.m
//  NimbleCommander
//
//  Created by Michael G. Kazakov on 9/14/16.
//  Copyright © 2016 Michael G. Kazakov. All rights reserved.
//

#include <NimbleCommander/Core/GoogleAnalytics.h>
#include <NimbleCommander/Core/Theming/CocoaAppearanceManager.h>
#include "../Bootstrap/ActivationManager.h"
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
    CocoaAppearanceManager::Instance().ManageWindowApperance(self.window);
    m_Self = self;
    
    if( ActivationManager::ForAppStore() ) { // MAS version
        [self.tabView selectTabViewItemAtIndex:0];
    }
    else { // standalone version
        if( ActivationManager::Instance().UserHadRegistered() ) {
            if( ActivationManager::Instance().UserHasProVersionInstalled() ) { // Pro version
                [self.tabView selectTabViewItemAtIndex:0];
            }
            else { // License
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
        }
        else { // Unregistered
            [self.tabView selectTabViewItemAtIndex:2];
        }
    }
    GA().PostScreenView("Registration Info Sheet");
}

- (IBAction)onOK:(id)sender
{
    [self.window.sheetParent endSheet:self.window returnCode:0];
    m_Self = nil;
}

@end

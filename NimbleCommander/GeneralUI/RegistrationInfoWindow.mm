// Copyright (C) 2016-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include <NimbleCommander/Core/GoogleAnalytics.h>
#include <Utility/CocoaAppearanceManager.h>
#include "../Bootstrap/ActivationManager.h"
#include "RegistrationInfoWindow.h"
#include <Utility/StringExtras.h>

@interface RegistrationInfoWindow ()
@property (nonatomic) IBOutlet NSTabView *tabView;
@property (nonatomic) IBOutlet NSTextField *apProduct;
@property (nonatomic) IBOutlet NSTextField *apName;
@property (nonatomic) IBOutlet NSTextField *apEmail;
@property (nonatomic) IBOutlet NSTextField *apCompany;
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
    nc::utility::CocoaAppearanceManager::Instance().ManageWindowApperance(self.window);
    m_Self = self;
    
    if( nc::bootstrap::ActivationManager::ForAppStore() ) { // MAS version
        [self.tabView selectTabViewItemAtIndex:0];
    }
    else { // standalone version
        if( nc::bootstrap::ActivationManager::Instance().UserHadRegistered() ) {
            if( nc::bootstrap::ActivationManager::Instance().UserHasProVersionInstalled() ) { // Pro version
                [self.tabView selectTabViewItemAtIndex:0];
            }
            else { // License
                [self.tabView selectTabViewItemAtIndex:1];
                auto &info = nc::bootstrap::ActivationManager::Instance().LicenseInformation();
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

- (IBAction)onOK:(id)[[maybe_unused]]_sender
{
    [self.window.sheetParent endSheet:self.window returnCode:0];
    m_Self = nil;
}

@end

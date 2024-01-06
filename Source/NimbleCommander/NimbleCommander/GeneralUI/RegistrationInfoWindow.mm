// Copyright (C) 2016-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#include "RegistrationInfoWindow.h"
#include "../Bootstrap/ActivationManager.h"
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
    nc::bootstrap::ActivationManager *m_ActivationManager;
}

- (instancetype) initWithActivationManager:(nc::bootstrap::ActivationManager&)_am
{
    self = [super initWithWindowNibName:NSStringFromClass(self.class)];
    if( self ) {
        m_ActivationManager = &_am;
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    m_Self = self;
    
    if( m_ActivationManager->ForAppStore() ) { // MAS version
        [self.tabView selectTabViewItemAtIndex:0];
    }
    else { // standalone version
        if( m_ActivationManager->UserHadRegistered() ) {
            if( m_ActivationManager->UserHasProVersionInstalled() ) { // Pro version
                [self.tabView selectTabViewItemAtIndex:0];
            }
            else { // License
                [self.tabView selectTabViewItemAtIndex:1];
                auto &info = m_ActivationManager->LicenseInformation();
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
}

- (IBAction)onOK:(id)[[maybe_unused]]_sender
{
    [self.window.sheetParent endSheet:self.window returnCode:0];
    m_Self = nil;
}

@end

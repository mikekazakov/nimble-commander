// Copyright (C) 2016-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "AskForPasswordWindowController.h"
#include <NimbleCommander/Core/GoogleAnalytics.h>
#include <Utility/CocoaAppearanceManager.h>
#include <Habanero/dispatch_cpp.h>
#include <Utility/StringExtras.h>

@interface AskForPasswordWindowController ()
@property (nonatomic) IBOutlet NSSecureTextField *Password;
@property (nonatomic) IBOutlet NSTextField *Resource;

@end

@implementation AskForPasswordWindowController

- (id)initWithResourceName:(NSString *)_name
{
    self = [super initWithWindowNibName:NSStringFromClass(self.class)];
    if(self) {
        (void)self.window;
        self.Resource.stringValue = _name;
        GA().PostScreenView("Ask For Password");
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    nc::utility::CocoaAppearanceManager::Instance().ManageWindowApperance(self.window);
}

- (NSString*)enteredPasswd
{
    return self.Password.stringValue ? self.Password.stringValue : @"";
}

- (IBAction)onOk:(id)[[maybe_unused]]_sender
{
    if( NSApp.modalWindow == self.window ) {
        [self.window close];
        [NSApp stopModalWithCode:NSModalResponseOK];
    }
    else {
        // ...
    }
}

- (IBAction)onCancel:(id)[[maybe_unused]]_sender
{
    if( NSApp.modalWindow == self.window ) {
        [self.window close];
        [NSApp stopModalWithCode:NSModalResponseCancel];
    }
    else {
        // ...
    }
}
@end

// consider the following:
// http://stackoverflow.com/questions/25310545/how-to-let-dropboxapi-work-in-runmodalforwindow

bool RunAskForPasswordModalWindow( const std::string& _password_for, std::string &_passwd )
{
    if( !dispatch_is_main_queue() ) {
        bool r = false;
        dispatch_sync( dispatch_get_main_queue(), [&]{ r = RunAskForPasswordModalWindow(_password_for, _passwd); } );
        return r;
    }
    
    auto wnd = [[AskForPasswordWindowController alloc] initWithResourceName:[NSString stringWithUTF8StdString:_password_for]];
    NSModalResponse ret = [NSApp runModalForWindow:wnd.window];
    if( ret == NSModalResponseOK ) {
        _passwd = wnd.enteredPasswd.UTF8String;
        return true;
    }
    return false;
}


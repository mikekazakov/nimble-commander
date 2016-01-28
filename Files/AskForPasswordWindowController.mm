//
//  AskForPasswordWindowController.m
//  Files
//
//  Created by Michael G. Kazakov on 26/01/16.
//  Copyright © 2016 Michael G. Kazakov. All rights reserved.
//

#include "Common.h"
#include "AskForPasswordWindowController.h"

@interface AskForPasswordWindowController ()
- (IBAction)onOk:(id)sender;
- (IBAction)onCancel:(id)sender;
@property (strong) IBOutlet NSSecureTextField *Password;
@property (strong) IBOutlet NSTextField *Resource;

@end

@implementation AskForPasswordWindowController

- (id)initWithResourceName:(NSString *)_name
{
    self = [super initWithWindowNibName:NSStringFromClass(self.class)];
    if(self) {
        (void)self.window;
        self.Resource.stringValue = _name;
    }
    return self;
}

- (NSString*)enteredPasswd
{
    return self.Password.stringValue ? self.Password.stringValue : @"";
}

- (IBAction)onOk:(id)sender
{
    if( NSApp.modalWindow == self.window ) {
        [self.window close];
        [NSApp stopModalWithCode:NSModalResponseOK];
    }
    else {
        // ...
    }
}

- (IBAction)onCancel:(id)sender
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

bool RunAskForPasswordModalWindow( const string& _password_for, string &_passwd )
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
//
//bool RunAskForPasswordSheet( const string& _password_for, string &_passwd, NSWindow *_for_window )
//{
//    
//    
//}

// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include <NimbleCommander/Core/Theming/CocoaAppearanceManager.h>
#include "Alert.h"


@interface AlertWindowController : NSWindowController
@end

@implementation AlertWindowController

- (void)moveRight:(id)sender
{
    [self.window selectNextKeyView:sender];
}

- (void)moveLeft:(id)sender
{
    [self.window selectPreviousKeyView:sender];
}

@end

@implementation Alert
{
    NSAlert                 *m_Alert;
    AlertWindowController   *m_Controller;
    void                   (^m_Handler)(NSModalResponse);
}

+ (Alert *)alertWithError:(NSError *)error
{
    NSAlert *a = [NSAlert alertWithError:error];
    return [[Alert alloc] initWithAlert:a];
}

- (instancetype) init
{
    return [self initWithAlert:[[NSAlert alloc] init]];
}

- (instancetype) initWithAlert:(NSAlert*)_alert
{
    if( self = [super init] ) {
        m_Alert = _alert;

        // m_Alert.window has no controller set, at least in 10.12/13.
        // use this fact to hijack the panel's window and move focus with arrow buttons:
        m_Controller = [[AlertWindowController alloc] initWithWindow:m_Alert.window];
        
        CocoaAppearanceManager::Instance().ManageWindowApperance( m_Alert.window );
    }
    return self;
}

- (NSString*) messageText
{
    return m_Alert.messageText;
}

- (void) setMessageText:(NSString *)messageText
{
    m_Alert.messageText = messageText;
}

- (NSString*) informativeText
{
    return m_Alert.informativeText;
}

- (void) setInformativeText:(NSString *)informativeText
{
    m_Alert.informativeText = informativeText;
}

- (NSImage*) icon
{
    return m_Alert.icon;
}

- (void) setIcon:(NSImage *)icon
{
    m_Alert.icon = icon;
}

- (NSButton *)addButtonWithTitle:(NSString *)title
{
    return [m_Alert addButtonWithTitle:title];
}

- (NSArray<NSButton *> *) buttons
{
    return m_Alert.buttons;
}

- (BOOL) showsHelp
{
    return m_Alert.showsHelp;
}

- (void) setShowsHelp:(BOOL)showsHelp
{
    m_Alert.showsHelp = showsHelp;
}

- (NSString*)helpAnchor
{
    return m_Alert.helpAnchor;
}

- (void) setHelpAnchor:(NSString *)helpAnchor
{
    m_Alert.helpAnchor = helpAnchor;
}

- (NSAlertStyle) alertStyle
{
    return m_Alert.alertStyle;
}

- (void) setAlertStyle:(NSAlertStyle)alertStyle
{
    m_Alert.alertStyle = alertStyle;
}

- (NSModalResponse)runModal
{
    return [m_Alert runModal];
}

- (void)beginSheetModalForWindow:(NSWindow *)sheetWindow
               completionHandler:(void (^ __nullable)(NSModalResponse returnCode))handler
{
    // use this artifical retain cycle to ensure longlivety of Alert
    m_Handler = handler;
    [m_Alert beginSheetModalForWindow:sheetWindow completionHandler:^(NSModalResponse returnCode){
        if(m_Handler)
            m_Handler(returnCode);
    }];
}

- (NSWindow*) window
{
    return m_Alert.window;
}

@end

namespace nc::core {

void ShowExceptionAlert( const string &_message )
{
    if( dispatch_is_main_queue() ) {
        auto alert = [[Alert alloc] init];
        alert.messageText = @"Unexpected exception was caught:";
        alert.informativeText = !_message.empty() ?
            [NSString stringWithUTF8StdString:_message] :
            @"Unknown exception";
        [alert runModal];
    }
    else {
        dispatch_to_main_queue([_message]{
            ShowExceptionAlert(_message);
        });
    }
}

void ShowExceptionAlert( const std::exception &_exception )
{
    ShowExceptionAlert( _exception.what() );
}

}

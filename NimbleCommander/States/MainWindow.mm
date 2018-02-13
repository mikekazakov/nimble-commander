// Copyright (C) 2014-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Utility/SystemInformation.h>
#include <NimbleCommander/Core/ActionsShortcutsManager.h>
#include <NimbleCommander/Core/Theming/CocoaAppearanceManager.h>
#include "MainWindow.h"
#include "MainWindowController.h"

static const auto g_Identifier = @"MainWindow";
static const auto g_FrameIdentifier = @"MainWindow";
static const auto g_MinWindowSize = NSMakeSize(640, 480);
static const auto g_InitialWindowContentRect = NSMakeRect(100, 100, 1000, 600);

@implementation NCMainWindow

+ (NSString*) defaultIdentifier
{
    return g_Identifier;
}

+ (NSString*) defaultFrameIdentifier
{
    return g_FrameIdentifier;
}

- (instancetype) init
{
    static const auto flags =
        NSResizableWindowMask|NSTitledWindowMask|NSClosableWindowMask|NSMiniaturizableWindowMask|
        NSTexturedBackgroundWindowMask|NSWindowStyleMaskFullSizeContentView;
    
    if( self = [super initWithContentRect:g_InitialWindowContentRect
                                styleMask:flags
                                  backing:NSBackingStoreBuffered
                                    defer:true] ) {
        self.minSize = g_MinWindowSize;
        self.collectionBehavior = NSWindowCollectionBehaviorFullScreenPrimary;
        self.restorable = true;
        self.identifier = g_Identifier;
        self.title = @"";
        
        // window placement logic below:
        // (it may be later overwritten by Cocoa's restoration mechanism)
        if( auto mwc = NCMainWindowController.lastFocused ) {
            // if there's any previous main window alive - copy that frame initially
            [self setFrame:mwc.window.frame
                   display:false
                   animate:false];
            // then cascade it using built-in AppKit logic:
            auto cascade_loc = NSMakePoint(0, 0);
            cascade_loc = [self cascadeTopLeftFromPoint:cascade_loc]; // init cascasing
            [self cascadeTopLeftFromPoint:cascade_loc]; // actually cascade this window
        }
        else {
            // if there's no alive window - grab previous value from user defaults
            if( ![self setFrameUsingName:g_FrameIdentifier] ) {
                // if we somehow don't have it - simply center window
                [self center];
            }
        }

        if( sysinfo::GetOSXVersion() >= sysinfo::OSXVersion::OSX_12 )
            self.tabbingMode = NSWindowTabbingModeDisallowed;
        
        [self setAutorecalculatesContentBorderThickness:false
                                                forEdge:NSMinYEdge];
        [self setContentBorderThickness:40
                                forEdge:NSMinYEdge];
        
//        self.contentView.wantsLayer = YES;
        CocoaAppearanceManager::Instance().ManageWindowApperance(self);
        [self invalidateShadow];
    }
    return self;
}

- (void)dealloc
{
    // NB! do NOT place anything much useful here.
    // It might not get called upoon Cmd+Q.
}

- (void)close
{
    [self saveFrameUsingName:g_FrameIdentifier];
    [super close];
}

+ (BOOL) allowsAutomaticWindowTabbing
{
    return false;
}

static const auto g_CloseWindowTitle =
    NSLocalizedString(@"Close Window", "Menu item title");
- (BOOL) validateMenuItem:(NSMenuItem *)item
{
    auto tag = item.tag;
    
    IF_MENU_TAG("menu.file.close") {
        item.title = g_CloseWindowTitle;
        return true;
    }
    IF_MENU_TAG("menu.file.close_window") {
        item.hidden = true;
        return true;
    }
    
    return [super validateMenuItem:item];
}

- (IBAction)OnFileCloseWindow:(id)sender { /* dummy, never called */ }

- (IBAction)toggleToolbarShown:(id)sender
{
    if( auto wc = objc_cast<NCMainWindowController>(self.windowController) )
        [wc OnShowToolbar:sender];
    else
        [super toggleToolbarShown:sender];
}

@end

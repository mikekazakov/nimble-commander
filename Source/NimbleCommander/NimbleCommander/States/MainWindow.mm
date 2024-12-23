// Copyright (C) 2014-2022 Michael Kazakov. Subject to GNU General Public License version 3.
#include "MainWindow.h"
#include <Utility/SystemInformation.h>
#include <NimbleCommander/Core/ActionsShortcutsManager.h>
#include "MainWindowController.h"
#include <Utility/ObjCpp.h>

static const auto g_Identifier = @"MainWindow";
static const auto g_FrameIdentifier = @"MainWindow";
static const auto g_MinWindowSize = NSMakeSize(640, 481);
// ^^^^ this additional pixel (481 instead of 480) appeared to have an even amount of rows
// for the Brief presentation with a default row height (i.e. 19 px)
static const auto g_InitialWindowContentRect = NSMakeRect(100, 100, 1000, 600);

@implementation NCMainWindow

+ (NSString *)defaultIdentifier
{
    return g_Identifier;
}

+ (NSString *)defaultFrameIdentifier
{
    return g_FrameIdentifier;
}

- (instancetype)init
{
    const auto flags = NSWindowStyleMaskResizable | NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                       NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskFullSizeContentView;
    self = [super initWithContentRect:g_InitialWindowContentRect
                            styleMask:flags
                              backing:NSBackingStoreBuffered
                                defer:true];
    if( self ) {
        self.minSize = g_MinWindowSize;
        self.collectionBehavior = NSWindowCollectionBehaviorFullScreenPrimary;
        self.restorable = true;
        self.identifier = g_Identifier;
        self.title = @"";

        if( @available(macOS 11.0, *) ) {
            self.titlebarSeparatorStyle = NSTitlebarSeparatorStyleNone;
            self.toolbarStyle = NSWindowToolbarStyleUnifiedCompact;
        }

        // window placement logic below:
        // (it may be later overwritten by Cocoa's restoration mechanism)
        if( auto mwc = NCMainWindowController.lastFocused ) {
            // if there's any previous main window alive - copy that frame initially
            [self setFrame:mwc.window.frame display:false animate:false];
            // then cascade it using built-in AppKit logic:
            auto cascade_loc = NSMakePoint(0, 0);
            cascade_loc = [self cascadeTopLeftFromPoint:cascade_loc]; // init cascasing
            [self cascadeTopLeftFromPoint:cascade_loc];               // actually cascade this window
        }
        else {
            // if there's no alive window - grab previous value from user defaults
            if( ![self setFrameUsingName:g_FrameIdentifier] ) {
                // if we somehow don't have it - simply center window
                [self center];
            }
        }

        self.tabbingMode = NSWindowTabbingModeDisallowed;

        [self setAutorecalculatesContentBorderThickness:false forEdge:NSMinYEdge];
        [self setContentBorderThickness:40 forEdge:NSMinYEdge];

        //        self.contentView.wantsLayer = YES;
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

+ (BOOL)allowsAutomaticWindowTabbing
{
    return false;
}

static const auto g_CloseWindowTitle = NSLocalizedString(@"Close Window", "Menu item title");
- (BOOL)validateMenuItem:(NSMenuItem *)item
{
    const long tag = item.tag;

    static const int close_tag = nc::core::ActionsShortcutsManager::TagFromAction("menu.file.close").value();
    if( tag == close_tag ) {
        item.title = g_CloseWindowTitle;
        return true;
    }

    static const int close_window_tag =
        nc::core::ActionsShortcutsManager::TagFromAction("menu.file.close_window").value();
    if( tag == close_window_tag ) {
        item.hidden = true;
        return true;
    }

    return [super validateMenuItem:item];
}

- (IBAction)OnFileCloseWindow:(id) [[maybe_unused]] _sender
{ /* dummy, never called */
}

- (IBAction)toggleToolbarShown:(id)sender
{
    if( auto wc = nc::objc_cast<NCMainWindowController>(self.windowController) )
        [wc OnShowToolbar:sender];
    else
        [super toggleToolbarShown:sender];
}

@end

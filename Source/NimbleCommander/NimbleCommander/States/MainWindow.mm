// Copyright (C) 2014-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "MainWindow.h"
#include <Utility/SystemInformation.h>
#include <Utility/NSMenu+Hierarchical.h>
#include <Utility/ActionsShortcutsManager.h>
#include <NimbleCommander/Bootstrap/AppDelegate.h> // TODO: bad, remove me!
#include "MainWindowController.h"
#include <Utility/ObjCpp.h>

static const auto g_Identifier = @"MainWindow";
static const auto g_FrameIdentifier = @"MainWindow";
static const auto g_MinWindowSize = NSMakeSize(640, 481);
// ^^^^ this additional pixel (481 instead of 480) appeared to have an even amount of rows
// for the Brief presentation with a default row height (i.e. 19 px)
static const auto g_InitialWindowContentRect = NSMakeRect(100, 100, 1000, 600);

@implementation NCMainWindow {
    nc::utility::ActionsShortcutsManager *m_ActionsShortcutsManager;
}

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
        m_ActionsShortcutsManager = &NCAppDelegate.me.actionsShortcutsManager; // TODO: DI this somehow
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

    static const int close_tag = m_ActionsShortcutsManager->TagFromAction("menu.file.close").value();
    if( tag == close_tag ) {
        item.title = g_CloseWindowTitle;
        return true;
    }

    static const int close_window_tag = m_ActionsShortcutsManager->TagFromAction("menu.file.close_window").value();
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

- (BOOL)performKeyEquivalent:(NSEvent *)_event
{
    using AS = nc::utility::ActionShortcut;
    using ASM = nc::utility::ActionsShortcutsManager;

    // Build a shortcut out of the keyboard event and check if it's not empty
    if( const AS event_shortcut = AS(AS::EventData(_event)) ) {

        // Find if any menu actions use this shortcut
        if( const std::optional<ASM::ActionTags> action_tags =
                m_ActionsShortcutsManager->ActionTagsFromShortcut(event_shortcut, "menu.");
            action_tags && !action_tags->empty() ) {

            // Get the tag of this action, ignore possible ambiguites - pick the first one.
            const int action_tag = action_tags->front();

            // Get the shortcuts of this action and check that the original shortcut is not the first one of them.
            // If it is the first one - we allow AppKit to process the shortcut via normal routing.
            if( const std::optional<ASM::Shortcuts> action_shortcuts =
                    m_ActionsShortcutsManager->ShortcutsFromTag(action_tag);
                action_shortcuts &&           //
                !action_shortcuts->empty() && //
                action_shortcuts->at(0) != event_shortcut ) {

                // Find the menu item corresponding to this action.
                if( NSMenuItem *const item = [NSApp.mainMenu itemWithTagHierarchical:action_tag] ) {

                    // Check if the action can be performed now. If it cannot - beep and bail out.
                    if( item.target ) {
                        // Validate using the specified target - ask it directly in case it supports validation.
                        if( [item.target respondsToSelector:@selector(validateMenuItem:)] &&
                            ![item.target validateMenuItem:item] ) {
                            NSBeep();
                            return true; // We've handled the event.
                        }
                    }
                    else {
                        // Manually traverse the responder chain and find the responsible responder.
                        NSResponder *resp = self.firstResponder;
                        while( resp != nil ) {
                            if( [resp respondsToSelector:item.action] ) {
                                // Found the responder, ask it now in case it supports validation.
                                if( [resp respondsToSelector:@selector(validateMenuItem:)] &&
                                    ![resp validateMenuItem:item] ) {
                                    NSBeep();
                                    return true; // We've handled the event.
                                }
                                break;
                            }
                            resp = resp.nextResponder;
                        }
                    }

                    // Find the parent of the menu item to ask it peform the action.
                    // We need to go via this route so that the menu will blink as expected upon this keypress.
                    if( NSMenu *const parent = item.menu ) {
                        if( const long idx = [parent indexOfItem:item]; idx >= 0 ) {
                            // Finally, perform the action.
                            [parent performActionForItemAtIndex:idx];
                        }
                    }

                    return true; // We've handled the event.
                }
            }
        }
    }
    return [super performKeyEquivalent:_event];
}

@end

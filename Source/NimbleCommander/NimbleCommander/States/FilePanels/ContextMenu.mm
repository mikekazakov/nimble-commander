// Copyright (C) 2013-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ContextMenu.h"
#include "Actions/Compress.h"
#include "Actions/CopyToPasteboard.h"
#include "Actions/Delete.h"
#include "Actions/Duplicate.h"
#include "Actions/OpenFile.h"
#include "NCPanelOpenWithMenuDelegate.h"
#include "PanelController.h"
#include <Panel/TagsStorage.h>
#include <Panel/UI/TagsPresentation.h>
#include <Utility/ObjCpp.h>
#include <Utility/StringExtras.h>
#include <VFS/VFS.h>
#include <algorithm>
#include <memory>
#include <pstld/pstld.h>
#include <ranges>

// TODO: remove this global dependency
#include <NimbleCommander/Bootstrap/AppDelegate.h>

#include <NimbleCommander/Core/AnyHolder.h>

using namespace nc::panel;

@interface NCPanelContextMenuSharingDelegate : NSObject <NSSharingServiceDelegate>
@property(nonatomic, weak) NSWindow *sourceWindow;
@end

@implementation NCPanelContextMenu {
    std::vector<VFSListingItem> m_Items;
    PanelController *m_Panel;
    NSMutableArray *m_ShareItemsURLs;
    NCPanelOpenWithMenuDelegate *m_OpenWithDelegate;
    std::unique_ptr<actions::PanelAction> m_CopyAction;
    std::unique_ptr<actions::PanelAction> m_MoveToTrashAction;
    std::unique_ptr<actions::PanelAction> m_DeletePermanentlyAction;
    std::unique_ptr<actions::PanelAction> m_DuplicateAction;
    std::unique_ptr<actions::PanelAction> m_CompressHereAction;
    std::unique_ptr<actions::PanelAction> m_CompressToOppositeAction;
    std::unique_ptr<actions::PanelAction> m_OpenFileAction;
}

- (instancetype)initWithItems:(std::vector<VFSListingItem>)_items
                      ofPanel:(PanelController *)_panel
               withFileOpener:(nc::panel::FileOpener &)_file_opener
                    withUTIDB:(const nc::utility::UTIDB &)_uti_db
{
    if( _items.empty() )
        throw std::invalid_argument("NCPanelContextMenu.initWithData - there's no items");
    self = [super init];
    if( self ) {
        m_Panel = _panel;
        m_Items = std::move(_items);

        self.delegate = self;
        self.minimumWidth = 230; // hardcoding is bad!
        auto &global_config = NCAppDelegate.me.globalConfig;

        m_CopyAction = std::make_unique<actions::context::CopyToPasteboard>(m_Items);
        m_MoveToTrashAction = std::make_unique<actions::context::MoveToTrash>(m_Items);
        m_DeletePermanentlyAction = std::make_unique<actions::context::DeletePermanently>(m_Items);
        m_DuplicateAction = std::make_unique<actions::context::Duplicate>(global_config, m_Items);
        m_CompressHereAction = std::make_unique<actions::context::CompressHere>(global_config, m_Items);
        m_CompressToOppositeAction = std::make_unique<actions::context::CompressToOpposite>(global_config, m_Items);
        m_OpenFileAction = std::make_unique<actions::context::OpenFileWithDefaultHandler>(m_Items, _file_opener);
        m_OpenWithDelegate = [[NCPanelOpenWithMenuDelegate alloc] initWithFileOpener:_file_opener utiDB:_uti_db];
        [m_OpenWithDelegate setContextSource:m_Items];
        m_OpenWithDelegate.target = m_Panel;

        [self doStuffing];
    }
    return self;
}

- (void)menuDidClose:(NSMenu *)menu
{
    [m_Panel contextMenuDidClose:menu];
}

- (void)doStuffing
{
    //////////////////////////////////////////////////////////////////////
    // regular Open item
    const auto open_item = [NSMenuItem new];
    open_item.title = NSLocalizedStringFromTable(
        @"Open", @"FilePanelsContextMenu", "Menu item title for opening a file by default, for English is 'Open'");
    open_item.target = self;
    open_item.action = @selector(OnRegularOpen:);
    [self addItem:open_item];

    //////////////////////////////////////////////////////////////////////
    // Open With... stuff
    {
        NSMenu *openwith_submenu = [NSMenu new];
        openwith_submenu.identifier = NCPanelOpenWithMenuDelegate.regularMenuIdentifier;
        openwith_submenu.delegate = m_OpenWithDelegate;
        [m_OpenWithDelegate addManagedMenu:openwith_submenu];

        NSMenuItem *openwith = [NSMenuItem new];
        openwith.title =
            NSLocalizedStringFromTable(@"Open With",
                                       @"FilePanelsContextMenu",
                                       "Submenu title to choose app to open with, for English is 'Open With'");
        openwith.submenu = openwith_submenu;
        openwith.keyEquivalent = @"";
        [self addItem:openwith];

        NSMenu *always_openwith_submenu = [NSMenu new];
        always_openwith_submenu.identifier = NCPanelOpenWithMenuDelegate.alwaysOpenWithMenuIdentifier;
        always_openwith_submenu.delegate = m_OpenWithDelegate;
        [m_OpenWithDelegate addManagedMenu:always_openwith_submenu];

        NSMenuItem *always_openwith = [NSMenuItem new];
        always_openwith.title = NSLocalizedStringFromTable(
            @"Always Open With",
            @"FilePanelsContextMenu",
            "Submenu title to choose app to always open with, for English is 'Always Open With'");
        always_openwith.submenu = always_openwith_submenu;
        always_openwith.alternate = true;
        always_openwith.keyEquivalent = @"";
        always_openwith.keyEquivalentModifierMask = NSEventModifierFlagOption;
        [self addItem:always_openwith];

        [self addItem:NSMenuItem.separatorItem];
    }

    //////////////////////////////////////////////////////////////////////
    // Move to Trash / Delete Permanently stuff
    const auto trash_item = [NSMenuItem new];
    trash_item.title = NSLocalizedStringFromTable(
        @"Move to Trash", @"FilePanelsContextMenu", "Menu item title to move to trash, for English is 'Move to Trash'");
    trash_item.target = self;
    trash_item.action = @selector(OnMoveToTrash:);
    trash_item.hidden = !m_MoveToTrashAction->Predicate(m_Panel);
    trash_item.keyEquivalent = @"";
    [self addItem:trash_item];

    const auto delete_item = [NSMenuItem new];
    delete_item.title =
        NSLocalizedStringFromTable(@"Delete Permanently",
                                   @"FilePanelsContextMenu",
                                   "Menu item title to delete file, for English is 'Delete Permanently'");
    delete_item.target = self;
    delete_item.action = @selector(OnDeletePermanently:);
    delete_item.alternate = !trash_item.hidden;
    delete_item.keyEquivalent = @"";
    delete_item.keyEquivalentModifierMask = trash_item.hidden ? 0 : NSEventModifierFlagOption;
    [self addItem:delete_item];

    [self addItem:NSMenuItem.separatorItem];

    //////////////////////////////////////////////////////////////////////
    // Compression stuff
    const auto compress_here_item = [NSMenuItem new];
    compress_here_item.title =
        NSLocalizedStringFromTable(@"Compress", @"FilePanelsContextMenu", "Compress some items here");
    compress_here_item.target = self;
    compress_here_item.action = @selector(OnCompressToCurrentPanel:);
    compress_here_item.keyEquivalent = @"";
    [self addItem:compress_here_item];

    const auto compress_in_opposite_item = [NSMenuItem new];
    compress_in_opposite_item.title =
        NSLocalizedStringFromTable(@"Compress in Opposite Panel", @"FilePanelsContextMenu", "Compress some items");
    compress_in_opposite_item.target = self;
    compress_in_opposite_item.action = @selector(OnCompressToOppositePanel:);
    compress_in_opposite_item.keyEquivalent = @"";
    compress_in_opposite_item.alternate = YES;
    compress_in_opposite_item.keyEquivalentModifierMask = NSEventModifierFlagOption;
    [self addItem:compress_in_opposite_item];

    //////////////////////////////////////////////////////////////////////
    // Duplicate stuff
    const auto duplicate_item = [NSMenuItem new];
    duplicate_item.title = NSLocalizedStringFromTable(@"Duplicate", @"FilePanelsContextMenu", "Duplicate an item");
    duplicate_item.target = self;
    duplicate_item.action = @selector(OnDuplicateItem:);
    [self addItem:duplicate_item];

    //////////////////////////////////////////////////////////////////////
    // Share stuff
    {
        const auto share_submenu = [NSMenu new];
        const auto eligible = std::ranges::all_of(m_Items, [](const auto &_i) { return _i.Host()->IsNativeFS(); });
        if( eligible ) {
            m_ShareItemsURLs = [NSMutableArray new];
            for( auto &i : m_Items )
                if( NSString *s = [NSString stringWithUTF8StdString:i.Path()] )
                    if( NSURL *url = [[NSURL alloc] initFileURLWithPath:s] )
                        [m_ShareItemsURLs addObject:url];

            auto services = [NSSharingService sharingServicesForItems:m_ShareItemsURLs];
            for( NSSharingService *service in services ) {
                NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:service.title
                                                              action:@selector(OnShareWithService:)
                                                       keyEquivalent:@""];
                item.image = service.image;
                item.representedObject = service;
                item.target = self;
                [share_submenu addItem:item];
            }
        }

        const auto share_menuitem = [NSMenuItem new];
        share_menuitem.title = NSLocalizedStringFromTable(@"Share", @"FilePanelsContextMenu", "Share submenu title");
        share_menuitem.submenu = share_submenu;
        share_menuitem.enabled = share_submenu.numberOfItems > 0;
        [self addItem:share_menuitem];
    }

    [self addItem:NSMenuItem.separatorItem];

    //////////////////////////////////////////////////////////////////////
    // Tags stuff
    if( const auto eligible = std::ranges::all_of(m_Items, [](const auto &_i) { return _i.Host()->IsNativeFS(); });
        eligible && NCAppDelegate.me.globalConfig.GetBool("filePanel.FinderTags.enable") ) {
        const std::vector<nc::utility::Tags::Tag> all_tags = NCAppDelegate.me.tagsStorage.Get();
        auto tag_state = [&](const nc::utility::Tags::Tag &_tag) -> NSControlStateValue {
            const auto count = std::ranges::count_if(m_Items, [&](const VFSListingItem &_item) -> bool {
                auto item_tags = _item.Tags();
                return std::ranges::find(item_tags, _tag) != item_tags.end();
            });
            if( count == 0 )
                return NSControlStateValueOff;
            else if( static_cast<size_t>(count) == m_Items.size() )
                return NSControlStateValueOn;
            else
                return NSControlStateValueMixed;
        };
        const auto tags_submenu = [NSMenu new];
        // TODO: that's O(N*M) complexity, might backfire when there's many tags used
        for( auto &tag : all_tags ) {
            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:[NSString stringWithUTF8StdString:tag.Label()]
                                                          action:@selector(onTagItem:)
                                                   keyEquivalent:@""];
            item.image = TagsMenuDisplay::Images().at(std::to_underlying(tag.Color()));
            item.state = tag_state(tag);
            item.representedObject = [[AnyHolder alloc] initWithAny:tag];
            item.target = self;
            [tags_submenu addItem:item];
        }

        const auto tags_menuitem = [NSMenuItem new];
        tags_menuitem.title = NSLocalizedStringFromTable(@"Tags", @"FilePanelsContextMenu", "Tags submenu title");
        tags_menuitem.submenu = tags_submenu;
        tags_menuitem.enabled = tags_submenu.numberOfItems > 0;
        [self addItem:tags_menuitem];
        [self addItem:NSMenuItem.separatorItem];
    }

    //////////////////////////////////////////////////////////////////////
    // Copy element for native FS. simply copies selected items' paths
    {
        NSMenuItem *item = [NSMenuItem new];
        item.target = self;
        item.action = @selector(OnCopyPaths:);
        [self addItem:item];
    }

    [self addItem:NSMenuItem.separatorItem];
}

- (BOOL)validateMenuItem:(NSMenuItem *)item
{
    if( item.action == @selector(OnCopyPaths:) )
        return m_CopyAction->ValidateMenuItem(m_Panel, item);
    if( item.action == @selector(OnMoveToTrash:) )
        return m_MoveToTrashAction->ValidateMenuItem(m_Panel, item);
    if( item.action == @selector(OnDeletePermanently:) )
        return m_DeletePermanentlyAction->ValidateMenuItem(m_Panel, item);
    if( item.action == @selector(OnDuplicateItem:) )
        return m_DuplicateAction->ValidateMenuItem(m_Panel, item);
    if( item.action == @selector(OnCompressToCurrentPanel:) )
        return m_CompressHereAction->ValidateMenuItem(m_Panel, item);
    if( item.action == @selector(OnCompressToOppositePanel:) )
        return m_CompressToOppositeAction->ValidateMenuItem(m_Panel, item);
    if( item.action == @selector(OnRegularOpen:) )
        return m_OpenFileAction->ValidateMenuItem(m_Panel, item);

    return true;
}

- (void)OnRegularOpen:(id)sender
{
    m_OpenFileAction->Perform(m_Panel, sender);
}

- (void)OnMoveToTrash:(id)sender
{
    m_MoveToTrashAction->Perform(m_Panel, sender);
}

- (void)OnDeletePermanently:(id)sender
{
    m_DeletePermanentlyAction->Perform(m_Panel, sender);
}

- (void)OnCopyPaths:(id)sender
{
    m_CopyAction->Perform(m_Panel, sender);
}

- (void)OnCompressToOppositePanel:(id)sender
{
    m_CompressToOppositeAction->Perform(m_Panel, sender);
}

- (void)OnCompressToCurrentPanel:(id)sender
{
    m_CompressHereAction->Perform(m_Panel, sender);
}

- (void)OnShareWithService:(id)sender
{
    auto delegate = [[NCPanelContextMenuSharingDelegate alloc] init];
    delegate.sourceWindow = m_Panel.window;

    NSSharingService *service = static_cast<NSMenuItem *>(sender).representedObject;
    service.delegate = delegate;
    [service performWithItems:m_ShareItemsURLs];
}

- (void)OnDuplicateItem:(id)sender
{
    m_DuplicateAction->Perform(m_Panel, sender);
}

- (void)onTagItem:(id)_sender
{
    // TODO: somehow move this action code into actual actions
    NSMenuItem *it = nc::objc_cast<NSMenuItem>(_sender);
    if( !it )
        return;
    const auto tag = std::any_cast<nc::utility::Tags::Tag>(nc::objc_cast<AnyHolder>(it.representedObject).any);
    const auto state = it.state;
    dispatch_to_background([tag, state, items = m_Items] {
        pstld::for_each(items.begin(), items.end(), [&](const VFSListingItem &_item) {
            if( state == NSControlStateValueOn )
                nc::utility::Tags::RemoveTag(_item.Path(), tag.Label());
            else
                nc::utility::Tags::AddTag(_item.Path(), tag);
        });
    });
}

- (std::span<VFSListingItem>)items
{
    return m_Items;
}

@end

@implementation NCPanelContextMenuSharingDelegate {
    NCPanelContextMenuSharingDelegate *m_Self;
}
@synthesize sourceWindow;

- (instancetype)init
{
    self = [super init];
    if( self ) {
        m_Self = self;
    }
    return self;
}

- (void)sharingService:(NSSharingService *) [[maybe_unused]] sharingService
    didFailToShareItems:(NSArray *) [[maybe_unused]] items
                  error:(NSError *) [[maybe_unused]] error
{
    m_Self = nil;
}

- (void)sharingService:(NSSharingService *) [[maybe_unused]] sharingService
         didShareItems:(NSArray *) [[maybe_unused]] items
{
    m_Self = nil;
}

- (nullable NSWindow *)sharingService:(NSSharingService *) [[maybe_unused]] sharingService
            sourceWindowForShareItems:(NSArray *) [[maybe_unused]] items
                  sharingContentScope:(NSSharingContentScope *) [[maybe_unused]] sharingContentScope
{
    return self.sourceWindow;
}

@end

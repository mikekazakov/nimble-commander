// Copyright (C) 2013-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ContextMenu.h"
#include "PanelController.h"
#include <NimbleCommander/Bootstrap/ActivationManager.h>
#include "Actions/CopyToPasteboard.h"
#include "Actions/Delete.h"
#include "Actions/Duplicate.h"
#include "Actions/Compress.h"
#include "Actions/OpenFile.h"
#include "NCPanelOpenWithMenuDelegate.h"
#include <VFS/VFS.h>

using namespace nc::panel;

@implementation NCPanelContextMenu
{
    vector<VFSListingItem>              m_Items;
    PanelController                    *m_Panel;
    NSMutableArray                     *m_ShareItemsURLs;
    NCPanelOpenWithMenuDelegate        *m_OpenWithDelegate;
    unique_ptr<actions::PanelAction>    m_CopyAction;
    unique_ptr<actions::PanelAction>    m_MoveToTrashAction;
    unique_ptr<actions::PanelAction>    m_DeletePermanentlyAction;
    unique_ptr<actions::PanelAction>    m_DuplicateAction;
    unique_ptr<actions::PanelAction>    m_CompressHereAction;
    unique_ptr<actions::PanelAction>    m_CompressToOppositeAction;
    unique_ptr<actions::PanelAction>    m_OpenFileAction;
}

- (instancetype) initWithItems:(vector<VFSListingItem>)_items
                       ofPanel:(PanelController*)_panel
{
    if( _items.empty() )
        throw invalid_argument("NCPanelContextMenu.initWithData - there's no items");
    self = [super init];
    if(self) {
        m_Panel = _panel;
        m_Items = move(_items);

        self.delegate = self;
        self.minimumWidth = 230; // hardcoding is bad!
    
        m_CopyAction.reset( new actions::context::CopyToPasteboard{m_Items} );
        m_MoveToTrashAction.reset( new actions::context::MoveToTrash{m_Items} );
        m_DeletePermanentlyAction.reset( new actions::context::DeletePermanently{m_Items} );
        m_DuplicateAction.reset( new actions::context::Duplicate{m_Items} );
        m_CompressHereAction.reset( new actions::context::CompressHere{m_Items} );
        m_CompressToOppositeAction.reset( new actions::context::CompressToOpposite{m_Items} );
        m_OpenFileAction.reset( new actions::context::OpenFileWithDefaultHandler{m_Items} );
        
        m_OpenWithDelegate = [[NCPanelOpenWithMenuDelegate alloc] init];
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

- (void) doStuffing
{
    //////////////////////////////////////////////////////////////////////
    // regular Open item
    const auto open_item = [NSMenuItem new];
    open_item.title = NSLocalizedStringFromTable(@"Open", @"FilePanelsContextMenu", "Menu item title for opening a file by default, for English is 'Open'");
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
        openwith.title = NSLocalizedStringFromTable(@"Open With", @"FilePanelsContextMenu", "Submenu title to choose app to open with, for English is 'Open With'");
        openwith.submenu = openwith_submenu;
        openwith.keyEquivalent = @"";
        [self addItem:openwith];

        NSMenu *always_openwith_submenu = [NSMenu new];
        always_openwith_submenu.identifier = NCPanelOpenWithMenuDelegate.alwaysOpenWithMenuIdentifier;
        always_openwith_submenu.delegate = m_OpenWithDelegate;
        [m_OpenWithDelegate addManagedMenu:always_openwith_submenu];

        NSMenuItem *always_openwith = [NSMenuItem new];
        always_openwith.title = NSLocalizedStringFromTable(@"Always Open With", @"FilePanelsContextMenu", "Submenu title to choose app to always open with, for English is 'Always Open With'");
        always_openwith.submenu = always_openwith_submenu;
        always_openwith.alternate = true;
        always_openwith.keyEquivalent = @"";
        always_openwith.keyEquivalentModifierMask = NSAlternateKeyMask;
        [self addItem:always_openwith];

        [self addItem:NSMenuItem.separatorItem];
    }

    //////////////////////////////////////////////////////////////////////
    // Move to Trash / Delete Permanently stuff
    const auto trash_item = [NSMenuItem new];
    trash_item.title = NSLocalizedStringFromTable(@"Move to Trash", @"FilePanelsContextMenu", "Menu item title to move to trash, for English is 'Move to Trash'");
    trash_item.target = self;
    trash_item.action = @selector(OnMoveToTrash:);
    trash_item.hidden = !m_MoveToTrashAction->Predicate(m_Panel);
    trash_item.keyEquivalent = @"";
    [self addItem:trash_item];
    
    const auto delete_item = [NSMenuItem new];
    delete_item.title = NSLocalizedStringFromTable(@"Delete Permanently", @"FilePanelsContextMenu", "Menu item title to delete file, for English is 'Delete Permanently'");
    delete_item.target = self;
    delete_item.action = @selector(OnDeletePermanently:);
    delete_item.alternate = trash_item.hidden ? false : true;
    delete_item.keyEquivalent = @"";
    delete_item.keyEquivalentModifierMask = trash_item.hidden ? 0 : NSAlternateKeyMask;
    [self addItem:delete_item];

    [self addItem:NSMenuItem.separatorItem];
    
    
    //////////////////////////////////////////////////////////////////////
    // Compression stuff
    const auto compression_enabled = ActivationManager::Instance().HasCompressionOperation();
   
    const auto compress_here_item = [NSMenuItem new];
    compress_here_item.title = NSLocalizedStringFromTable(@"Compress", @"FilePanelsContextMenu", "Compress some items here");
    compress_here_item.target = self;
    compress_here_item.action = compression_enabled ? @selector(OnCompressToCurrentPanel:) : nil;
    compress_here_item.keyEquivalent = @"";
    [self addItem:compress_here_item];
    
    const auto compress_in_opposite_item = [NSMenuItem new];
    compress_in_opposite_item.title = NSLocalizedStringFromTable(@"Compress in Opposite Panel", @"FilePanelsContextMenu", "Compress some items");
    compress_in_opposite_item.target = self;
    compress_in_opposite_item.action = compression_enabled ? @selector(OnCompressToOppositePanel:) : nil;
    compress_in_opposite_item.keyEquivalent = @"";
    compress_in_opposite_item.alternate = YES;
    compress_in_opposite_item.keyEquivalentModifierMask = NSAlternateKeyMask;
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
        const auto eligible = all_of(begin(m_Items),
                                     end(m_Items),
                                     [](const auto &_i){return _i.Host()->IsNativeFS(); });
        if( eligible ) {
            m_ShareItemsURLs = [NSMutableArray new];
            for( auto &i:m_Items )
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
    // Copy element for native FS. simply copies selected items' paths
    {
        NSMenuItem *item = [NSMenuItem new];
        item.target = self;
        item.action = @selector(OnCopyPaths:);
        [self addItem:item];
    }

    [self addItem:NSMenuItem.separatorItem];
}

- (BOOL) validateMenuItem:(NSMenuItem *)item
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
    NSSharingService *service = ((NSMenuItem*)sender).representedObject;
    [service performWithItems:m_ShareItemsURLs];
}

- (void)OnDuplicateItem:(id)sender
{
    m_DuplicateAction->Perform(m_Panel, sender);
}

@end

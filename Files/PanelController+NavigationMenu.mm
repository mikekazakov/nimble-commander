//
//  PanelController+NavigationMenu.m
//  Files
//
//  Created by Michael G. Kazakov on 10/08/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#include "vfs/vfs_native.h"
#import "NativeFSManager.h"
#import "Common.h"
#import "PanelController+NavigationMenu.h"
#import "MainWndGoToButton.h"
#import "SavedNetworkConnectionsManager.h"

static const auto g_IconSize = NSMakeSize(16, 16); //fuck dynamic layout!
//static const auto g_IconSize = NSMakeSize(NSFont.systemFontSize+3, NSFont.systemFontSize+3);

static vector<VFSPathStack> ProduceStacksForParentDirectories( const VFSFlexibleListing &_listing  )
{
    if( !_listing.IsUniform() )
        throw invalid_argument("ProduceStacksForParentDirectories: _listing should be uniform");
        
    vector<VFSPathStack> result;
    
    auto host = _listing.Host();
    path dir = _listing.Directory();
    if(dir.filename() == ".")
        dir.remove_filename();
    while( host ) {
        
        bool brk = false;
        do {
            if( dir == "/" )
                brk = true;
            
            result.emplace_back( VFSPathStack(host, dir == "/" ? dir.native() : dir.native() + "/") );
            
            dir = dir.parent_path();
        } while( !brk );
    

        dir = host->JunctionPath();
        dir = dir.parent_path();
        
        host = host->Parent();
    }
    
    if( !result.empty() )
        result.erase( begin(result) );
    
    return result;
}

static NSString *KeyEquivalent(int _ind)
{
    switch(_ind) {
        case  0: return @"1";
        case  1: return @"2";
        case  2: return @"3";
        case  3: return @"4";
        case  4: return @"5";
        case  5: return @"6";
        case  6: return @"7";
        case  7: return @"8";
        case  8: return @"9";
        case  9: return @"0";
        case 10: return @"-";
        case 11: return @"=";
        default: return @"";
    }
}

static NSImage *ImageForPathStack( const VFSPathStack &_stack )
{
    if( _stack.back().fs_tag == VFSNativeHost::Tag )
        if(auto image = [NSWorkspace.sharedWorkspace iconForFile:[NSString stringWithUTF8StdString:_stack.path()]]) {
            image.size = g_IconSize;
            return image;
        }
    
    static auto image = [NSImage imageNamed:NSImageNameFolder];
    image.size = g_IconSize;
    return image;
}

@interface PanelControllerQuickListMenuItemPathStackHolder : NSObject
- (instancetype) initWithObject:(const VFSPathStack&)_obj;
@property (readonly, nonatomic) const VFSPathStack& object;
@end

@implementation PanelControllerQuickListMenuItemPathStackHolder
{
    VFSPathStack m_Obj;
}
@synthesize object = m_Obj;
- (instancetype) initWithObject:(const VFSPathStack&)_obj
{
    self = [super init];
    if( self )
        m_Obj = _obj;
    return self;
}
@end

@interface PanelControllerQuickListConnectionHolder : NSObject
- (instancetype) initWithObject:(const shared_ptr<SavedNetworkConnectionsManager::AbstractConnection>&)_obj;
@property (readonly, nonatomic) const shared_ptr<SavedNetworkConnectionsManager::AbstractConnection>& object;
@end

@implementation PanelControllerQuickListConnectionHolder
{
    shared_ptr<SavedNetworkConnectionsManager::AbstractConnection> m_Obj;
}
@synthesize object = m_Obj;
- (instancetype) initWithObject:(const shared_ptr<SavedNetworkConnectionsManager::AbstractConnection>&)_obj
{
    self = [super init];
    if( self )
        m_Obj = _obj;
    return self;
}
@end

@implementation PanelController (NavigationMenu)

- (void) popUpQuickListMenu:(NSMenu*)menu
{
    auto items = menu.itemArray;
    for(int ind = 1; ind < items.count; ++ind)
        if( auto i = objc_cast<NSMenuItem>([items objectAtIndex:ind]) ) {
            i.keyEquivalent = KeyEquivalent( ind - 1 );
            i.keyEquivalentModifierMask = 0;
        }
    
    NSPoint p;
    p.x = (self.view.bounds.size.width - menu.size.width) / 2.;
    p.y = (self.view.bounds.size.height - menu.size.height) / 2.;
    
    p = [self.view convertPoint:p toView:nil];
    p = [self.view.window convertRectToScreen:NSMakeRect(p.x, p.y, 1, 1)].origin;
    
    [menu popUpMenuPositioningItem:nil
                        atLocation:p
                            inView:nil];
}

- (void) popUpQuickListWithHistory
{
    auto hist_items = m_History.All();
    
    NSMenu *menu = [[NSMenu alloc] init];
    
    int indx = 0;
    for( auto i = rbegin(hist_items), e = rend(hist_items); i != e; ++i, ++indx ) {
        auto &item = *i;
        
        NSString *title = [NSString stringWithUTF8StdString:item.get().verbose_string()];
        
        if( ![menu itemWithTitle:title] ) {
            NSMenuItem *it = [[NSMenuItem alloc] init];
            
            it.title = title;
            it.image = ImageForPathStack( item );
            it.tag = hist_items.size() - indx - 1;
            it.target = self;
            it.action = @selector(doCalloutByHistoryPopupMenuItem:);
            [menu addItem:it];
        }
    }
    if( menu.itemArray.count > 1 && m_History.IsRecording() )
        [menu removeItemAtIndex:0];
    
    [menu insertItem:[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"History", "History popup menu title in file panels") action:nullptr keyEquivalent:@""]
                                               atIndex:0];
    
    [self popUpQuickListMenu:menu];
}

- (void)doCalloutByHistoryPopupMenuItem:(id)sender
{
    if( auto item = objc_cast<NSMenuItem>(sender) )
        if( auto hist = m_History.RewindAt(item.tag) )
            [self GoToVFSPathStack:*hist];
}

- (void) popUpQuickListWithParentFolders
{
    if( !self.isUniform )
        return;
    
    auto stacks = ProduceStacksForParentDirectories( self.data.Listing() );
    
    NSMenu *menu = [[NSMenu alloc] init];
    [menu addItem:[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Parent Folders", "Upper-dirs popup menu title in file panels") action:nullptr keyEquivalent:@""]];
    
    for( auto &i: stacks) {
        NSString *title = [NSString stringWithUTF8StdString:i.verbose_string()];
        
        NSMenuItem *it = [[NSMenuItem alloc] init];
        it.title = title;
        it.image = ImageForPathStack( i );
        it.target = self;
        it.action = @selector(doCalloutWithPathStackHolder:);
        it.representedObject = [[PanelControllerQuickListMenuItemPathStackHolder alloc] initWithObject:i];
        [menu addItem:it];
    }
    
    [self popUpQuickListMenu:menu];
}

- (void)doCalloutWithPathStackHolder:(id)sender
{
    if( auto item = objc_cast<NSMenuItem>(sender) )
        if( auto holder = objc_cast<PanelControllerQuickListMenuItemPathStackHolder>(item.representedObject) )
            [self GoToVFSPathStack:holder.object];
}

- (void) popUpQuickListWithVolumes
{
    NSMenu *menu = [[NSMenu alloc] init];
    [menu addItem:[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Volumes", "Volumes popup menu title in file panels") action:nullptr keyEquivalent:@""]];
    
    for( auto &volume: NativeFSManager::Instance().Volumes() ) {
        if( volume->mount_flags.dont_browse )
            continue;

        auto path = VFSPathStack( VFSNativeHost::SharedHost(), volume->mounted_at_path );
        
        NSMenuItem *it = [[NSMenuItem alloc] init];
        if(volume->verbose.icon != nil) {
            NSImage *img = volume->verbose.icon.copy;
            img.size = g_IconSize;
            it.image = img;
        }
        it.title = volume->verbose.localized_name;
        it.target = self;
        it.action = @selector(doCalloutWithPathStackHolder:);
        it.representedObject = [[PanelControllerQuickListMenuItemPathStackHolder alloc] initWithObject:path];
        [menu addItem:it];
    }
    
    [self popUpQuickListMenu:menu];
}

- (void) popUpQuickListWithFavorites
{
    auto favourites = MainWndGoToButton.finderFavorites;
    
    NSMenu *menu = [[NSMenu alloc] init];
    [menu addItem:[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Favorites", "Favorites popup menu title in file panels") action:nullptr keyEquivalent:@""]];
    
    for( auto f: favourites ) {
        auto path = VFSPathStack( VFSNativeHost::SharedHost(),  f.path.fileSystemRepresentationSafe );

        NSString *title;
        [f getResourceValue:&title forKey:NSURLLocalizedNameKey error:nil];
        
        NSMenuItem *it = [[NSMenuItem alloc] init];
        NSImage *img;
        [f getResourceValue:&img forKey:NSURLEffectiveIconKey error:nil];
        if(img != nil) {
            img.size = g_IconSize;
            it.image = img;
        }
        it.title = title;
        it.target = self;
        it.action = @selector(doCalloutWithPathStackHolder:);
        it.representedObject = [[PanelControllerQuickListMenuItemPathStackHolder alloc] initWithObject:path];
        [menu addItem:it];
        
    }
   
    [self popUpQuickListMenu:menu];
}

- (void) popUpQuickListWithNetworkConnections
{
    static auto network_image = []{
        NSImage *m = [NSImage imageNamed:NSImageNameNetwork];
        m.size = g_IconSize;
        return m;
    }();
    
    NSMenu *menu = [[NSMenu alloc] init];
    [menu addItem:[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Connections", "Connections popup menu title in file panels") action:nullptr keyEquivalent:@""]];

    auto connections = SavedNetworkConnectionsManager::Instance().Connections();
    
    for(auto &c:connections) {
        NSMenuItem *it = [[NSMenuItem alloc] init];
        it.title = [NSString stringWithUTF8StdString:SavedNetworkConnectionsManager::Instance().TitleForConnection(c)];
        it.image = network_image;
        it.target = self;
        it.action = @selector(doCalloutWithConnectionHolder:);
        it.representedObject = [[PanelControllerQuickListConnectionHolder alloc] initWithObject:c];
        [menu addItem:it];
    }
    
    [self popUpQuickListMenu:menu];    
}

- (void)doCalloutWithConnectionHolder:(id)sender
{
    if( auto item = objc_cast<NSMenuItem>(sender) )
        if( auto holder = objc_cast<PanelControllerQuickListConnectionHolder>(item.representedObject) )
            [self GoToSavedConnection:holder.object];
}

@end

//
//  PanelController+NavigationMenu.m
//  Files
//
//  Created by Michael G. Kazakov on 10/08/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#include <Utility/NativeFSManager.h>
#include "vfs/vfs_native.h"
#include "PanelController+NavigationMenu.h"
#include "MainWndGoToButton.h"
#include "../NimbleCommander/Core/VFSInstanceManager.h"

static const auto g_IconSize = NSMakeSize(16, 16); //fuck dynamic layout!
//static const auto g_IconSize = NSMakeSize(NSFont.systemFontSize+3, NSFont.systemFontSize+3);

static vector<pair<VFSInstanceManager::Promise, string>> ProduceLocationsForParentDirectories( const VFSListing &_listing  )
{
    if( !_listing.IsUniform() )
        throw invalid_argument("ProduceLocationsForParentDirectories: _listing should be uniform");
    
    vector<pair<VFSInstanceManager::Promise, string>> result;
    
    auto host = _listing.Host();
    path dir = _listing.Directory();
    if(dir.filename() == ".")
        dir.remove_filename();
    while( host ) {
        
        bool brk = false;
        do {
            if( dir == "/" )
                brk = true;
            
            result.emplace_back(VFSInstanceManager::Instance().TameVFS(host),
                                dir == "/" ? dir.native() : dir.native() + "/");
            
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

static NSImage *ImageForPromiseAndPath( const VFSInstanceManager::Promise &_promise, const string& _path )
{
    if( _promise.tag() == VFSNativeHost::Tag )
        if(auto image = [NSWorkspace.sharedWorkspace iconForFile:[NSString stringWithUTF8StdString:_path]]) {
            image.size = g_IconSize;
            return image;
        }
    
    static auto image = [NSImage imageNamed:NSImageNameFolder];
    image.size = g_IconSize;
    return image;
}

@interface PanelControllerQuickListMenuItemVFSPromiseHolder : NSObject
- (instancetype) initWithPromise:(const VFSInstanceManager::Promise&)_promise andPath:(const string&)_path;
@property (readonly, nonatomic) const VFSInstanceManager::Promise& promise;
@property (readonly, nonatomic) const string& path;
@end

@implementation PanelControllerQuickListMenuItemVFSPromiseHolder
{
    VFSInstanceManager::Promise m_Promise;
    string m_Path;
}
@synthesize promise = m_Promise;
@synthesize path = m_Path;
- (instancetype) initWithPromise:(const VFSInstanceManager::Promise&)_promise andPath:(const string&)_path
{
    self = [super init];
    if( self ) {
        m_Promise = _promise;
        m_Path = _path;
    }
    return self;
}
@end

@interface PanelControllerQuickListConnectionHolder : NSObject
- (instancetype) initWithObject:(const NetworkConnectionsManager::Connection&)_obj;
@property (readonly, nonatomic) const NetworkConnectionsManager::Connection& object;
@end

@implementation PanelControllerQuickListConnectionHolder
{
    optional<NetworkConnectionsManager::Connection> m_Obj;
}
- (instancetype) initWithObject:(const NetworkConnectionsManager::Connection&)_obj
{
    self = [super init];
    if( self )
        m_Obj = _obj;
    return self;
}

- (const NetworkConnectionsManager::Connection&) object
{
    return *m_Obj;
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
        
        NSString *title = [NSString stringWithUTF8StdString:item.get().vfs.verbose_title() + item.get().path];
        
        if( ![menu itemWithTitle:title] ) {
            NSMenuItem *it = [[NSMenuItem alloc] init];
            
            it.title = title;
            it.image = ImageForPromiseAndPath(item.get().vfs, item.get().path);
            it.target = self;
            it.action = @selector(doCalloutWithVFSPromiseHolder:);
            it.representedObject = [[PanelControllerQuickListMenuItemVFSPromiseHolder alloc] initWithPromise:item.get().vfs andPath:item.get().path];
            [menu addItem:it];
        }
    }
    if( menu.itemArray.count > 1 && m_History.IsRecording() )
        [menu removeItemAtIndex:0];
    
    [menu insertItem:[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"History", "History popup menu title in file panels") action:nullptr keyEquivalent:@""]
                                               atIndex:0];
    
    [self popUpQuickListMenu:menu];
}

- (void) popUpQuickListWithParentFolders
{
    if( !self.isUniform )
        return;
    
    auto stack = ProduceLocationsForParentDirectories( self.data.Listing() );
    
    NSMenu *menu = [[NSMenu alloc] init];
    [menu addItem:[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Parent Folders", "Upper-dirs popup menu title in file panels") action:nullptr keyEquivalent:@""]];
    
    for( auto &i: stack) {
        NSString *title = [NSString stringWithUTF8StdString:i.first.verbose_title() + i.second];
        
        NSMenuItem *it = [[NSMenuItem alloc] init];
        it.title = title;
        it.image = ImageForPromiseAndPath(i.first, i.second);
        it.target = self;
        it.action = @selector(doCalloutWithVFSPromiseHolder:);
        it.representedObject = [[PanelControllerQuickListMenuItemVFSPromiseHolder alloc] initWithPromise:i.first andPath:i.second];
        [menu addItem:it];
    }
    
    [self popUpQuickListMenu:menu];
}

- (void)doCalloutWithVFSPromiseHolder:(id)sender
{
    if( auto item = objc_cast<NSMenuItem>(sender) )
        if( auto holder = objc_cast<PanelControllerQuickListMenuItemVFSPromiseHolder>(item.representedObject) )
            [self GoToVFSPromise:holder.promise onPath:holder.path];
}

- (void) popUpQuickListWithVolumes
{
    NSMenu *menu = [[NSMenu alloc] init];
    [menu addItem:[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Volumes", "Volumes popup menu title in file panels") action:nullptr keyEquivalent:@""]];
    
    auto vfs_promise = VFSInstanceManager::Instance().TameVFS(VFSNativeHost::SharedHost());
    
    for( auto &volume: NativeFSManager::Instance().Volumes() ) {
        if( volume->mount_flags.dont_browse )
            continue;

        NSMenuItem *it = [[NSMenuItem alloc] init];
        if(volume->verbose.icon != nil) {
            NSImage *img = volume->verbose.icon.copy;
            img.size = g_IconSize;
            it.image = img;
        }
        it.title = volume->verbose.localized_name;
        it.target = self;
        it.action = @selector(doCalloutWithVFSPromiseHolder:);
        it.representedObject = [[PanelControllerQuickListMenuItemVFSPromiseHolder alloc] initWithPromise:vfs_promise
                                                                                                 andPath:volume->mounted_at_path];
        [menu addItem:it];
    }
    
    [self popUpQuickListMenu:menu];
}

- (void) popUpQuickListWithFavorites
{
    auto favourites = MainWndGoToButton.finderFavorites;
    
    NSMenu *menu = [[NSMenu alloc] init];
    [menu addItem:[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Favorites", "Favorites popup menu title in file panels") action:nullptr keyEquivalent:@""]];

    auto vfs_promise = VFSInstanceManager::Instance().TameVFS(VFSNativeHost::SharedHost());
    
    for( auto f: favourites ) {

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
        it.action = @selector(doCalloutWithVFSPromiseHolder:);
        it.representedObject = [[PanelControllerQuickListMenuItemVFSPromiseHolder alloc] initWithPromise:vfs_promise
                                                                                            andPath:f.path.fileSystemRepresentationSafe];
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

    auto connections = NetworkConnectionsManager::Instance().AllConnectionsByMRU();
    
    for(auto &c:connections) {
        NSMenuItem *it = [[NSMenuItem alloc] init];
        it.title = [NSString stringWithUTF8StdString:NetworkConnectionsManager::Instance().TitleForConnection(c)];
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

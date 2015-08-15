//
//  PanelController+NavigationMenu.m
//  Files
//
//  Created by Michael G. Kazakov on 10/08/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#import "Common.h"
#import "PanelController+NavigationMenu.h"

static vector<VFSPathStack> ProduceStacksForParentDirectories( const VFSListing &_listing  )
{
    vector<VFSPathStack> result;
    
    auto host = _listing.Host();
    path dir = _listing.RelativePath();
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

@implementation PanelController (NavigationMenu)

- (void) popUpQuickListMenu:(NSMenu*)menu
{
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
            it.tag = hist_items.size() - indx - 1;
            it.target = self;
            it.action = @selector(doCalloutByHistoryPopupMenuItem:);
            it.indentationLevel = 1;
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
    auto stacks = ProduceStacksForParentDirectories( self.data.Listing() );
    
    NSMenu *menu = [[NSMenu alloc] init];
    [menu insertItem:[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Parent Folders", "Upper-dirs popup menu title in file panels") action:nullptr keyEquivalent:@""]
             atIndex:0];
    
    for( auto &i: stacks) {
        NSString *title = [NSString stringWithUTF8StdString:i.verbose_string()];
        
        NSMenuItem *it = [[NSMenuItem alloc] init];
        it.title = title;
        it.target = self;
        it.action = @selector(doCalloutByParentFoldersPopupMenuItem:);
        it.representedObject = [[PanelControllerQuickListMenuItemPathStackHolder alloc] initWithObject:i];
        it.indentationLevel = 1;
        [menu addItem:it];
    }
    
    [self popUpQuickListMenu:menu];
}

- (void)doCalloutByParentFoldersPopupMenuItem:(id)sender
{
    if( auto item = objc_cast<NSMenuItem>(sender) )
        if( auto holder = objc_cast<PanelControllerQuickListMenuItemPathStackHolder>(item.representedObject) )
            [self GoToVFSPathStack:holder.object];
}

@end

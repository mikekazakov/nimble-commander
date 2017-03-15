//
//  FavoritesWindowController.m
//  NimbleCommander
//
//  Created by Michael G. Kazakov on 3/15/17.
//  Copyright © 2017 Michael G. Kazakov. All rights reserved.
//

#include <VFS/Native.h>
#include "FavoritesWindowController.h"
#include "Favorites.h"
#include "FilesDraggingSource.h"

@interface FavoritesWindowController ()
@property (strong) IBOutlet NSTableView *table;
@property (strong) IBOutlet NSSegmentedControl *buttons;

@end

@implementation FavoritesWindowController
{
    FavoritesWindowController *m_Self;
    function<FavoriteLocationsStorage&()> m_Storage;
    
    vector<FavoriteLocationsStorage::Favorite> m_Favorites;
}

- (id) initWithFavoritesStorage:(function<FavoriteLocationsStorage&()>)_favorites_storage
{
    self = [super initWithWindowNibName:NSStringFromClass(self.class)];
    if( self ) {
        m_Storage = _favorites_storage;
        m_Favorites = m_Storage().Favorites();
    }
    return self;
}


- (void)windowDidLoad {
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    
    
//    + (NSString*) fileURLsDragUTI;
    [self.table registerForDraggedTypes:
     @[ FilesDraggingSource.fileURLsDragUTI, FilesDraggingSource.privateDragUTI ]];
    
}

- (void) show
{
    [self showWindow:self];
    m_Self = self;
//    GA().PostScreenView("VFS List Window");
}

- (void)windowWillClose:(NSNotification *)notification
{
    dispatch_to_main_queue_after(10ms, [=]{
        m_Self = nil;
    });
}



- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return m_Favorites.size();
//    if( self.listType.selectedSegment == 0 )
//        return VFSInstanceManager::Instance().AliveHosts().size();
//    else
//        return VFSInstanceManager::Instance().KnownVFSCount();
}

- (nullable NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row
{
    if( row >= m_Favorites.size() )
        return nil;;
    auto &f = m_Favorites[row];

    if( [tableColumn.identifier isEqualToString:@"Location"] ) {
        NSTextField *tf = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
        if( auto l = [NSString stringWithUTF8StdString:f.location->verbose_path] )
            tf.stringValue = l;
        tf.bordered = false;
        tf.editable = false;
        tf.drawsBackground = false;
        return tf;
    }
    if( [tableColumn.identifier isEqualToString:@"Title"] ) {
        NSTextField *tf = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
        if( auto t = [NSString stringWithUTF8StdString:f.title] )
            tf.stringValue = t;
        tf.bordered = false;
        tf.editable = true;
        tf.drawsBackground = false;
        tf.delegate = self;
        return tf;
    }

    return nil;
}

- (void) commit
{
    m_Storage().SetFavorites( m_Favorites );
}

- (void)controlTextDidEndEditing:(NSNotification *)obj
{
    NSTextField *tf = obj.object;
    if( !tf )
        return;
    if( auto rv = objc_cast<NSTableRowView>(tf.superview) ) {
        if( rv.superview == self.table ) {
            long row_no = [self.table rowForView:rv];
            if( row_no >= 0 && row_no < m_Favorites.size() ) {
                auto new_value = tf.stringValue ? tf.stringValue.UTF8String : "";
                if( m_Favorites[row_no].title != new_value ) {
                    m_Favorites[row_no].title = new_value;
                    [self commit];
                }
            }
        }
    }
}

- (NSDragOperation)tableView:(NSTableView *)aTableView
                validateDrop:(id < NSDraggingInfo >)info
                 proposedRow:(NSInteger)row
       proposedDropOperation:(NSTableViewDropOperation)operation
{
    return operation == NSTableViewDropOn ? NSDragOperationNone : NSDragOperationMove;
}

- (BOOL)tableView:(NSTableView *)aTableView
writeRowsWithIndexes:(NSIndexSet *)rowIndexes
     toPasteboard:(NSPasteboard *)pboard
{
//    [pboard declareTypes:@[g_PreferencesWindowThemesTabColoringRulesControlDataType]
//                   owner:self];
//    [pboard setData:[NSKeyedArchiver archivedDataWithRootObject:rowIndexes]
//            forType:g_PreferencesWindowThemesTabColoringRulesControlDataType];
    return true;
}

static optional< FavoriteLocationsStorage::Favorite > FavoriteFromURL( NSURL *_url )
{
    if( !_url || !_url.fileURL )
        return nullopt;
    
    if( !_url.hasDirectoryPath )
        return FavoriteFromURL( _url.URLByDeletingLastPathComponent );

    auto path = _url.fileSystemRepresentation;
    if( !path )
        return nullopt;

    auto f = FavoriteLocationsStorage::ComposeFavoriteLocation(*VFSNativeHost::SharedHost(), path);
    if( !f )
        return nullopt;
    

    NSString *title;
    [_url getResourceValue:&title forKey:NSURLLocalizedNameKey error:nil];
    if( title ) {
        f->title = title.UTF8String;
    }
    else {
        [_url getResourceValue:&title forKey:NSURLNameKey error:nil];
        if( title )
            f->title = title.UTF8String;
    }
    
    return move(f);
}

static optional<FavoriteLocationsStorage::Favorite>
FavoriteFromListingItem( const VFSListingItem &_i )
{
    if( !_i )
        return nullopt;

    auto path = _i.IsDir() ? _i.Path() : _i.Directory();
    auto f = FavoriteLocationsStorage::ComposeFavoriteLocation( *_i.Host(), path );
    if( !f )
        return nullopt;

    f->title = _i.Filename();

    return move(f);
}

- (bool) hasFavorite:(const FavoriteLocationsStorage::Favorite&)_f
{
    return any_of(begin(m_Favorites), end(m_Favorites), [&](auto &_i){
        return _i.footprint == _f.footprint;
    });
}

- (BOOL)tableView:(NSTableView *)aTableView
       acceptDrop:(id<NSDraggingInfo>)info
              row:(NSInteger)drag_to
    dropOperation:(NSTableViewDropOperation)operation
{
    auto pasteboard = info.draggingPasteboard;

    vector<FavoriteLocationsStorage::Favorite> addition;
    
    if( auto source = objc_cast<FilesDraggingSource>(info.draggingSource) ) {
        // dragging from some NC panel
        for( PanelDraggingItem *item: source.items )
            if( auto f = FavoriteFromListingItem(item.item) )
                if( ![self hasFavorite:*f] )
                    addition.emplace_back( move(*f) );
    }
    else if( [pasteboard.types containsObject:FilesDraggingSource.fileURLsDragUTI] ) {
        // dragging from outside
        static const auto read_opts = @{NSPasteboardURLReadingFileURLsOnlyKey:@YES};
        auto fileURLs = [pasteboard readObjectsForClasses:@[NSURL.class]
                                                  options:read_opts];
        for( NSURL *url in fileURLs )
            if( auto f = FavoriteFromURL(url) )
                if( ![self hasFavorite:*f] )
                    addition.emplace_back( move(*f) );
    }


    if( !addition.empty() ) {
        m_Favorites.insert(begin(m_Favorites) + drag_to,
                           begin(addition),
                           end(addition));
        
        [self.table reloadData];
        [self commit];
    }



//    NSIndexSet* inds = [NSKeyedUnarchiver unarchiveObjectWithData:[info.draggingPasteboard
//        dataForType:g_PreferencesWindowThemesTabColoringRulesControlDataType]];
//    NSInteger drag_from = inds.firstIndex;
//    
//    if(drag_to == drag_from || // same index, above
//       drag_to == drag_from + 1) // same index, below
//    return false;
//    
//    assert(drag_from < m_Rules.size());
//    
//    auto i = begin(m_Rules);
//    if( drag_from < drag_to )
//        rotate( i + drag_from, i + drag_from + 1, i + drag_to );
//    else
//        rotate( i + drag_to, i + drag_from, i + drag_from + 1 );
//    [self.table reloadData];
//    [self commit];
    return true;
}


- (void)removeFavorite:(id)sender
{
    const auto row = self.table.selectedRow;
    if( row < 0 )
        return;
    m_Favorites.erase( begin(m_Favorites) + row );
    [self.table reloadData];
    [self commit];
}

- (IBAction)onButtonClicked:(id)sender
{
    const auto segment = self.buttons.selectedSegment;
    if( segment == 0 ) {
//        [self OnNewEditor:sender];
    }
    else if( segment == 1 ) {
        [self removeFavorite:sender];
    //        if( self.ExtEditorsController.canRemove )
//            if( AskUserToDeleteEditor() )
//                [self.ExtEditorsController remove:sender];
    }
}

@end

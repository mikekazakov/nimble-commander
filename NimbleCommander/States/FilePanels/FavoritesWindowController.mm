//
//  FavoritesWindowController.m
//  NimbleCommander
//
//  Created by Michael G. Kazakov on 3/15/17.
//  Copyright © 2017 Michael G. Kazakov. All rights reserved.
//

#include <NimbleCommander/Bootstrap/AppDelegate.h>
#include <NimbleCommander/Core/Alert.h>
#include <NimbleCommander/Core/GoogleAnalytics.h>
#include <NimbleCommander/Core/Theming/CocoaAppearanceManager.h>
#include <NimbleCommander/States/MainWindowController.h>
#include <NimbleCommander/States/FilePanels/MainWindowFilePanelState.h>
#include "FavoritesWindowController.h"
#include "Favorites.h"
#include "FavoriteComposing.h"
#include "FilesDraggingSource.h"

static const auto g_FavoritesWindowControllerDragDataType =
    @"FavoritesWindowControllerDragDataType";

@interface FavoritesWindowController ()
@property (strong) IBOutlet NSTableView *table;
@property (strong) IBOutlet NSSegmentedControl *buttons;
@property (strong) IBOutlet NSMenu *optionsMenu;

@end

@implementation FavoritesWindowController
{
    FavoritesWindowController *m_Self;
    function<FavoriteLocationsStorage&()> m_Storage;
    
    vector<FavoriteLocationsStorage::Favorite> m_Favorites;
    vector<FavoriteLocationsStorage::Favorite> m_PopupMenuFavorites;
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

- (void)windowDidLoad
{
    [super windowDidLoad];
    CocoaAppearanceManager::Instance().ManageWindowApperance(self.window);
    GA().PostScreenView("Favorites");
    
    [self.table registerForDraggedTypes:@[FilesDraggingSource.fileURLsDragUTI,
                                          FilesDraggingSource.privateDragUTI,
                                          g_FavoritesWindowControllerDragDataType]];
}

- (void) show
{
    [self showWindow:self];
    m_Self = self;
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
}

- (nullable NSView *)tableView:(NSTableView *)tableView
            viewForTableColumn:(nullable NSTableColumn *)tableColumn
                           row:(NSInteger)row
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
        tf.textColor = NSColor.secondaryLabelColor;
        tf.usesSingleLineMode = true;
        tf.lineBreakMode = NSLineBreakByTruncatingTail;
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

- (void) loadData
{
    [self.table reloadData];
    [self.buttons setEnabled:false forSegment:1];
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
    if( auto rv = objc_cast<NSTableRowView>(tf.superview) )
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

- (NSDragOperation)tableView:(NSTableView *)aTableView
                validateDrop:(id < NSDraggingInfo >)info
                 proposedRow:(NSInteger)row
       proposedDropOperation:(NSTableViewDropOperation)operation
{
    if( operation == NSTableViewDropOn )
        return NSDragOperationNone;
    
    const auto external_drag = objc_cast<FilesDraggingSource>(info.draggingSource) ||
        [info.draggingPasteboard.types containsObject:FilesDraggingSource.fileURLsDragUTI];
    
    return external_drag ? NSDragOperationCopy : NSDragOperationMove;
}

- (BOOL)tableView:(NSTableView *)aTableView
writeRowsWithIndexes:(NSIndexSet *)rowIndexes
     toPasteboard:(NSPasteboard *)pboard
{
    [pboard declareTypes:@[g_FavoritesWindowControllerDragDataType]
                   owner:self];
    [pboard setData:[NSKeyedArchiver archivedDataWithRootObject:rowIndexes]
            forType:g_FavoritesWindowControllerDragDataType];
    return true;
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

    if( [pasteboard.types containsObject:g_FavoritesWindowControllerDragDataType] ) {
        // dragging items inside table
        auto data = [info.draggingPasteboard dataForType:g_FavoritesWindowControllerDragDataType];
        NSIndexSet* inds = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        NSInteger drag_from = inds.firstIndex;
        
        if(drag_to == drag_from || // same index, above
           drag_to == drag_from + 1) // same index, below
            return false;
        
        assert( drag_from < m_Favorites.size() );
        
        auto i = begin(m_Favorites);
        if( drag_from < drag_to )
            rotate( i + drag_from, i + drag_from + 1, i + drag_to );
        else
            rotate( i + drag_to, i + drag_from, i + drag_from + 1 );
        [self loadData];
        [self commit];
    }
    else {
        vector<FavoriteLocationsStorage::Favorite> addition;
        
        if( auto source = objc_cast<FilesDraggingSource>(info.draggingSource) ) {
            // dragging from some NC panel
            for( PanelDraggingItem *item: source.items )
                if( auto f = FavoriteComposing::FromListingItem(item.item) )
                    if( ![self hasFavorite:*f] )
                        addition.emplace_back( move(*f) );
        }
        else if( [pasteboard.types containsObject:FilesDraggingSource.fileURLsDragUTI] ) {
            // dragging from outside
            static const auto read_opts = @{NSPasteboardURLReadingFileURLsOnlyKey:@YES};
            auto fileURLs = [pasteboard readObjectsForClasses:@[NSURL.class]
                                                      options:read_opts];
            for( NSURL *url in fileURLs )
                if( auto f = FavoriteComposing::FromURL(url) )
                    if( ![self hasFavorite:*f] )
                        addition.emplace_back( move(*f) );
        }
        
        if( !addition.empty() ) {
            m_Favorites.insert(begin(m_Favorites) + drag_to,
                               begin(addition),
                               end(addition));
            
            [self loadData];
            [self commit];
        }
    }

    return true;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
    const auto row = self.table.selectedRow;
    [self.buttons setEnabled:row>=0 forSegment:1];
}

- (void)removeFavorite:(id)sender
{
    const auto row = self.table.selectedRow;
    if( row < 0 )
        return;
    assert( row < m_Favorites.size() );
    m_Favorites.erase( begin(m_Favorites) + row );

    [self loadData];
    [self commit];
}

- (IBAction)onButtonClicked:(id)sender
{
    const auto segment = self.buttons.selectedSegment;
    if( segment == 0 ) {
        [self showAvailableLocationsToAdd];
    }
    else if( segment == 1 ) {
        [self removeFavorite:sender];
    }
    else if( segment == 2 ) {
        const auto b = self.buttons.bounds;
        const auto origin = NSMakePoint(b.size.width - [self.buttons widthForSegment:2] - 3,
                                        b.size.height + 3);
        [self.optionsMenu popUpMenuPositioningItem:nil
                                        atLocation:origin
                                            inView:self.buttons];
    }
}

- (void)showAvailableLocationsToAdd
{
    vector< tuple<string,VFSHostPtr> > panel_paths;
    
    for( auto ctr: AppDelegate.me.mainWindowControllers ) {
        auto state = ctr.filePanelsState;
        auto paths = state.filePanelsCurrentPaths;
        panel_paths.insert( end(panel_paths), begin(paths), end(paths) );
    }

    unordered_map<size_t, FavoriteLocationsStorage::Favorite> proposed_favorites;
    for( auto &p: panel_paths )
        if( auto f = FavoriteLocationsStorage::ComposeFavoriteLocation(*get<1>(p), get<0>(p)) )
            if( ![self hasFavorite:*f] )
                proposed_favorites[f->footprint] = *f;

    m_PopupMenuFavorites.clear();
    NSMenu *menu = [[NSMenu alloc] init];
    for( auto &f: proposed_favorites ) {
        NSMenuItem *it = [[NSMenuItem alloc] init];
        if( auto title = [NSString stringWithUTF8StdString:f.second.location->verbose_path] )
            it.title = title;
        it.target = self;
        it.action = @selector(onAddFavoriteMenuItemClicked:);
        it.tag = m_PopupMenuFavorites.size();
        m_PopupMenuFavorites.emplace_back( f.second );
        [menu addItem:it];
    }
    
    const auto b = self.buttons.bounds;
    const auto origin = NSMakePoint(0 - 3,
                                    b.size.height + 3);
    [menu popUpMenuPositioningItem:nil
                        atLocation:origin
                            inView:self.buttons];
}

- (IBAction)onAddFavoriteMenuItemClicked:(id)sender
{
    if( auto it = objc_cast<NSMenuItem>(sender) ) {
        const auto ind = (int)it.tag;
        if( ind < m_PopupMenuFavorites.size() ) {
            m_Favorites.emplace_back( m_PopupMenuFavorites[ind] );
            [self loadData];
            [self commit];
        }
    }
}

- (IBAction)onResetToFinderFavorites:(id)sender
{
    auto ff = FavoriteComposing::FinderFavorites();
    if( ff.empty() ) {
        Alert *alert = [[Alert alloc] init];
        alert.messageText = NSLocalizedString(@"Failed to retreive Finder's Favorites",
            "Showing an error when NC isn't able to get Finder Favorites");
        [alert addButtonWithTitle:NSLocalizedString(@"OK", "")];
        [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse rc) {}];
        return;
    }

    m_Favorites = move(ff);
    [self loadData];
    [self commit];
}

- (IBAction)onResetToDefaultFavorites:(id)sender
{
    m_Favorites = FavoriteComposing::DefaultFavorites();
    [self loadData];
    [self commit];
}

@end

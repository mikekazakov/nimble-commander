// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "FavoritesWindowController.h"
#include "FavoriteComposing.h"
#include "Favorites.h"
#include "FilesDraggingSource.h"
#include <Base/algo.h>
#include <Base/dispatch_cpp.h>
#include <Carbon/Carbon.h>
#include <NimbleCommander/Core/Alert.h>
#include <NimbleCommander/States/FilePanels/MainWindowFilePanelState.h>
#include <NimbleCommander/States/MainWindowController.h>
#include <Utility/ObjCpp.h>
#include <Utility/SheetWithHotkeys.h>
#include <Utility/StringExtras.h>
#include <algorithm>
#include <unordered_map>

using namespace nc::panel;
using namespace std::literals;

static const auto g_FavoritesWindowControllerDragDataType = @"com.magnumbytes.nc.FavoritesWindowControllerDragDataType";

@interface FavoritesWindowController ()
@property(nonatomic) IBOutlet NSTableView *table;
@property(nonatomic) IBOutlet NSSegmentedControl *buttons;
@property(nonatomic) IBOutlet NSMenu *optionsMenu;

@end

@implementation FavoritesWindowController {
    FavoritesWindowController *m_Self;
    std::function<FavoriteLocationsStorage &()> m_Storage;

    std::vector<FavoriteLocationsStorage::Favorite> m_Favorites;
    std::vector<FavoriteLocationsStorage::Favorite> m_PopupMenuFavorites;

    FavoriteLocationsStorage::ObservationTicket m_ObservationTicket;
    bool m_IsCommitingFavorites;
    std::function<std::vector<std::pair<VFSHostPtr, std::string>>()> m_ProvideCurrentUniformPaths;
}
@synthesize table;
@synthesize buttons;
@synthesize optionsMenu;

- (id)initWithFavoritesStorage:(std::function<FavoriteLocationsStorage &()>)_favorites_storage
{
    self = [super initWithWindowNibName:NSStringFromClass(self.class)];
    if( self ) {
        m_Storage = _favorites_storage;
        m_Favorites = m_Storage().Favorites();
        m_IsCommitingFavorites = false;
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];

    [self.table registerForDraggedTypes:@[
        FilesDraggingSource.fileURLsDragUTI,
        FilesDraggingSource.privateDragUTI,
        g_FavoritesWindowControllerDragDataType
    ]];

    auto sheet = nc::objc_cast<NCSheetWithHotkeys>(self.window);

    sheet.onCtrlV = [sheet makeActionHotkey:@selector(showAvailableLocationsToAdd:)];
    sheet.onCtrlX = [sheet makeActionHotkey:@selector(removeFavorite:)];
    sheet.onCtrlO = [sheet makeActionHotkey:@selector(showOptionsMenu:)];

    m_ObservationTicket =
        m_Storage().ObserveFavoritesChanges(nc::objc_callback(self, @selector(favoritesHadChangedOutside)));
}

- (void)show
{
    [self showWindow:self];
    m_Self = self;
}

- (void)windowWillClose:(NSNotification *) [[maybe_unused]] notification
{
    dispatch_to_main_queue_after(10ms, [=] { m_Self = nil; });
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *) [[maybe_unused]] tableView
{
    return m_Favorites.size();
}

- (nullable NSView *)tableView:(NSTableView *) [[maybe_unused]] tableView
            viewForTableColumn:(nullable NSTableColumn *)tableColumn
                           row:(NSInteger)row
{
    if( row >= static_cast<int>(m_Favorites.size()) )
        return nil;

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
        tf.usesSingleLineMode = true;
        tf.lineBreakMode = NSLineBreakByTruncatingTail;
        tf.delegate = self;
        return tf;
    }

    return nil;
}

- (void)loadData
{
    [self.table reloadData];
    [self.buttons setEnabled:false forSegment:1];
}

- (void)commit
{
    m_IsCommitingFavorites = true;
    auto clear = at_scope_end([&] { m_IsCommitingFavorites = false; });
    m_Storage().SetFavorites(m_Favorites);
}

- (void)favoritesHadChangedOutside
{
    if( m_IsCommitingFavorites )
        return;

    m_Favorites = m_Storage().Favorites();
    [self loadData];
}

- (void)controlTextDidEndEditing:(NSNotification *)obj
{
    NSTextField *tf = obj.object;
    if( !tf )
        return;
    if( auto rv = nc::objc_cast<NSTableRowView>(tf.superview) )
        if( rv.superview == self.table ) {
            long row_no = [self.table rowForView:rv];
            if( row_no >= 0 && row_no < static_cast<int>(m_Favorites.size()) ) {
                auto new_value = tf.stringValue ? tf.stringValue.UTF8String : "";
                if( m_Favorites[row_no].title != new_value ) {
                    m_Favorites[row_no].title = new_value;
                    [self commit];
                }
            }
        }
}

- (NSDragOperation)tableView:(NSTableView *) [[maybe_unused]] aTableView
                validateDrop:(id<NSDraggingInfo>)info
                 proposedRow:(NSInteger) [[maybe_unused]] row
       proposedDropOperation:(NSTableViewDropOperation)operation
{
    if( operation == NSTableViewDropOn )
        return NSDragOperationNone;

    const auto external_drag = nc::objc_cast<FilesDraggingSource>(info.draggingSource) ||
                               [info.draggingPasteboard.types containsObject:FilesDraggingSource.fileURLsDragUTI];

    return external_drag ? NSDragOperationCopy : NSDragOperationMove;
}

- (nullable id<NSPasteboardWriting>)tableView:(NSTableView *)_table_view pasteboardWriterForRow:(NSInteger)_row
{
    auto data = [NSKeyedArchiver archivedDataWithRootObject:[NSNumber numberWithInteger:_row]
                                      requiringSecureCoding:false
                                                      error:nil];
    NSPasteboardItem *pbitem = [[NSPasteboardItem alloc] init];
    [pbitem setData:data forType:g_FavoritesWindowControllerDragDataType];
    return pbitem;
}

- (bool)hasFavorite:(const FavoriteLocationsStorage::Favorite &)_f
{
    return std::ranges::any_of(m_Favorites, [&](auto &_i) { return _i.footprint == _f.footprint; });
}

- (BOOL)tableView:(NSTableView *) [[maybe_unused]] aTableView
       acceptDrop:(id<NSDraggingInfo>)info
              row:(NSInteger)drag_to
    dropOperation:(NSTableViewDropOperation) [[maybe_unused]] operation
{
    auto pasteboard = info.draggingPasteboard;

    if( [pasteboard.types containsObject:g_FavoritesWindowControllerDragDataType] ) {
        // dragging items inside table
        auto data = [info.draggingPasteboard dataForType:g_FavoritesWindowControllerDragDataType];
        NSNumber *ind = [NSKeyedUnarchiver unarchivedObjectOfClass:NSNumber.class fromData:data error:nil];
        NSInteger drag_from = ind.integerValue;

        if( drag_to == drag_from ||    // same index, above
            drag_to == drag_from + 1 ) // same index, below
            return false;

        assert(drag_from < static_cast<int>(m_Favorites.size()));

        auto i = begin(m_Favorites);
        if( drag_from < drag_to )
            rotate(i + drag_from, i + drag_from + 1, i + drag_to);
        else
            rotate(i + drag_to, i + drag_from, i + drag_from + 1);
        [self loadData];
        [self commit];
    }
    else {
        std::vector<FavoriteLocationsStorage::Favorite> addition;
        auto &storage = m_Storage();
        if( auto source = nc::objc_cast<FilesDraggingSource>(info.draggingSource) ) {
            // dragging from some NC panel
            for( PanelDraggingItem *item : source.items )
                if( auto f = FavoriteComposing{storage}.FromListingItem(item.item) )
                    if( ![self hasFavorite:*f] )
                        addition.emplace_back(std::move(*f));
        }
        else if( [pasteboard.types containsObject:FilesDraggingSource.fileURLsDragUTI] ) {
            // dragging from outside
            static const auto read_opts = @{NSPasteboardURLReadingFileURLsOnlyKey: @YES};
            auto fileURLs = [pasteboard readObjectsForClasses:@[NSURL.class] options:read_opts];
            for( NSURL *url in fileURLs )
                if( auto f = FavoriteComposing{storage}.FromURL(url) )
                    if( ![self hasFavorite:*f] )
                        addition.emplace_back(std::move(*f));
        }

        if( !addition.empty() ) {
            m_Favorites.insert(begin(m_Favorites) + drag_to, begin(addition), end(addition));

            [self loadData];
            [self commit];
        }
    }

    return true;
}

- (void)tableViewSelectionDidChange:(NSNotification *) [[maybe_unused]] notification
{
    const auto row = self.table.selectedRow;
    [self.buttons setEnabled:row >= 0 forSegment:1];
}

- (void)removeFavorite:(id) [[maybe_unused]] sender
{
    const auto row = self.table.selectedRow;
    if( row < 0 )
        return;
    assert(row < static_cast<int>(m_Favorites.size()));
    m_Favorites.erase(begin(m_Favorites) + row);

    [self loadData];
    [self commit];
}

- (void)keyDown:(NSEvent *)event
{
    if( event.type == NSEventTypeKeyDown && event.keyCode == kVK_Delete && self.window.firstResponder == self.table &&
        self.table.selectedRow >= 0 ) {
        [self removeFavorite:self];
        return;
    }

    [super keyDown:event];
    return;
}

- (IBAction)onButtonClicked:(id)sender
{
    const auto segment = self.buttons.selectedSegment;
    if( segment == 0 )
        [self showAvailableLocationsToAdd:sender];
    else if( segment == 1 )
        [self removeFavorite:sender];
    else if( segment == 2 )
        [self showOptionsMenu:sender];
}

- (void)showOptionsMenu:(id) [[maybe_unused]] sender
{
    const auto b = self.buttons.bounds;
    const auto origin = NSMakePoint(b.size.width - [self.buttons widthForSegment:2] - 3, b.size.height + 3);
    [self.optionsMenu popUpMenuPositioningItem:nil atLocation:origin inView:self.buttons];
}

- (void)showAvailableLocationsToAdd:(id) [[maybe_unused]] sender
{
    if( !m_ProvideCurrentUniformPaths )
        return;
    const auto panel_paths = m_ProvideCurrentUniformPaths();

    std::unordered_map<size_t, FavoriteLocationsStorage::Favorite> proposed_favorites;
    auto &storage = m_Storage();
    for( auto &p : panel_paths )
        if( auto f = storage.ComposeFavoriteLocation(*p.first, p.second) )
            if( ![self hasFavorite:*f] )
                proposed_favorites[f->footprint] = *f;

    m_PopupMenuFavorites.clear();
    NSMenu *menu = [[NSMenu alloc] init];
    for( auto &f : proposed_favorites ) {
        NSMenuItem *it = [[NSMenuItem alloc] init];
        if( auto title = [NSString stringWithUTF8StdString:f.second.location->verbose_path] )
            it.title = title;
        it.target = self;
        it.action = @selector(onAddFavoriteMenuItemClicked:);
        it.tag = m_PopupMenuFavorites.size();
        m_PopupMenuFavorites.emplace_back(f.second);
        [menu addItem:it];
    }

    const auto b = self.buttons.bounds;
    const auto origin = NSMakePoint(0 - 3, b.size.height + 3);
    [menu popUpMenuPositioningItem:nil atLocation:origin inView:self.buttons];
}

- (IBAction)onAddFavoriteMenuItemClicked:(id)sender
{
    if( auto it = nc::objc_cast<NSMenuItem>(sender) ) {
        const auto ind = static_cast<int>(it.tag);
        if( ind < static_cast<int>(m_PopupMenuFavorites.size()) ) {
            m_Favorites.emplace_back(m_PopupMenuFavorites[ind]);
            [self loadData];
            [self commit];
        }
    }
}

- (IBAction)onResetToFinderFavorites:(id) [[maybe_unused]] sender
{
    auto ff = FavoriteComposing{m_Storage()}.FinderFavorites();
    if( ff.empty() ) {
        Alert *alert = [[Alert alloc] init];
        alert.messageText = NSLocalizedString(@"Failed to retreive Finder's Favorites",
                                              "Showing an error when NC isn't able to get Finder Favorites");
        [alert addButtonWithTitle:NSLocalizedString(@"OK", "")];
        [alert beginSheetModalForWindow:self.window
                      completionHandler:^([[maybe_unused]] NSModalResponse rc){
                      }];
        return;
    }

    m_Favorites = std::move(ff);
    [self loadData];
    [self commit];
}

- (IBAction)onResetToDefaultFavorites:(id) [[maybe_unused]] sender
{
    m_Favorites = FavoriteComposing{m_Storage()}.DefaultFavorites();
    [self loadData];
    [self commit];
}

- (void)setProvideCurrentUniformPaths:(std::function<std::vector<std::pair<VFSHostPtr, std::string>>()>)callback
{
    m_ProvideCurrentUniformPaths = std::move(callback);
}

- (std::function<std::vector<std::pair<VFSHostPtr, std::string>>()>)provideCurrentUniformPaths
{
    return m_ProvideCurrentUniformPaths;
}

@end

@interface FavoritesWindow : NCSheetWithHotkeys
@end

@implementation FavoritesWindow
- (void)cancelOperation:(id)sender
{
    [self performClose:sender];
}
@end

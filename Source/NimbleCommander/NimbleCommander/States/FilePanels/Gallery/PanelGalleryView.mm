// Copyright (C) 2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelGalleryView.h"
#include "PanelGalleryCollectionView.h"
#include "PanelGalleryCollectionViewItem.h"
#include "../Helpers/IconRepositoryCleaner.h"
#include "../PanelView.h"
#include <NimbleCommander/Bootstrap/Config.h>      // TODO: evil! DI instead!
#include <NimbleCommander/Bootstrap/AppDelegate.h> // TODO: evil! DI instead!
#include <NimbleCommander/Core/Theming/Theme.h>    // Evil!
#include <NimbleCommander/Core/Theming/ThemesManager.h>
#include <Panel/PanelData.h>
#include <Panel/Log.h>
#include <Base/dispatch_cpp.h>
#include <Utility/ExtensionLowercaseComparison.h>
#include <Utility/ObjCpp.h>
#include <Utility/StringExtras.h>
#include <Utility/FontExtras.h>
#include <Utility/PathManip.h>
#include <ankerl/unordered_dense.h>
#include <Quartz/Quartz.h>

using namespace nc;
using namespace nc::panel;
using namespace nc::panel::gallery;

static constexpr auto g_HazardousExtensionsList = "filePanel.presentation.quickLookHazardousExtensionsList";
static constexpr auto g_SmoothScrolling = "filePanel.presentation.smoothScrolling";

@implementation PanelGalleryView {
    data::Model *m_Data;
    PanelGalleryViewLayout m_Layout;
    ItemLayout m_ItemLayout;

    NSScrollView *m_ScrollView;
    NCPanelGalleryViewCollectionView *m_CollectionView;
    NSCollectionViewFlowLayout *m_CollectionViewLayout;
    NSLayoutConstraint *m_ScrollViewHeightConstraint;
    QLPreviewView *m_QLView;
    NSImageView *m_FallbackImageView;

    __weak PanelView *m_PanelView;

    ankerl::unordered_dense::map<vfsicon::IconRepository::SlotKey, int> m_IconSlotToItemIndexMapping;
    vfsicon::IconRepository *m_IconRepository;

    // It's a workaround for the macOS bug reported in FB9809109/FB5352643.
    bool m_CurrentPreviewIsHazardous;
    std::optional<nc::utility::ExtensionsLowercaseList> m_HazardousExtsList; // empty means everything is hazardous

    nc::ThemesManager::ObservationTicket m_ThemeObservation;
}

- (instancetype)initWithFrame:(NSRect)_frame andIR:(nc::vfsicon::IconRepository &)_ir
{
    self = [super initWithFrame:_frame];
    if( !self )
        return nil;

    m_Data = nullptr;
    m_IconRepository = &_ir;
    m_CurrentPreviewIsHazardous = false;

    [self rebuildItemLayout];

    m_CollectionViewLayout = [NSCollectionViewFlowLayout new];
    m_CollectionViewLayout.scrollDirection = NSCollectionViewScrollDirectionHorizontal;
    m_CollectionViewLayout.itemSize = NSMakeSize(m_ItemLayout.width, m_ItemLayout.height);
    m_CollectionViewLayout.minimumLineSpacing = 0.;
    m_CollectionViewLayout.minimumInteritemSpacing = 0.;
    m_CollectionViewLayout.sectionInset = NSEdgeInsetsMake(0., 0., 0., 0.);

    m_CollectionView = [[NCPanelGalleryViewCollectionView alloc] initWithFrame:_frame];
    m_CollectionView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    m_CollectionView.collectionViewLayout = m_CollectionViewLayout;
    m_CollectionView.dataSource = self;
    m_CollectionView.smoothScrolling = GlobalConfig().GetBool(g_SmoothScrolling);
    m_CollectionView.backgroundColors = @[nc::CurrentTheme().FilePanelsGalleryBackgroundColor()];
    [m_CollectionView registerClass:NCPanelGalleryCollectionViewItem.class forItemWithIdentifier:@"GalleryItem"];

    m_ScrollView = [[NSScrollView alloc] initWithFrame:_frame];
    m_ScrollView.translatesAutoresizingMaskIntoConstraints = false;
    m_ScrollView.hasVerticalScroller = false;
    m_ScrollView.hasHorizontalScroller = true;
    m_ScrollView.documentView = m_CollectionView;
    m_ScrollView.backgroundColor = nc::CurrentTheme().FilePanelsGalleryBackgroundColor();
    m_ScrollView.drawsBackground = true;
    [self addSubview:m_ScrollView];

    m_QLView = [[QLPreviewView alloc] initWithFrame:_frame style:QLPreviewViewStyleNormal];
    m_QLView.translatesAutoresizingMaskIntoConstraints = false;
    [self addSubview:m_QLView];

    m_FallbackImageView = [[NSImageView alloc] initWithFrame:_frame];
    m_FallbackImageView.translatesAutoresizingMaskIntoConstraints = false;
    m_FallbackImageView.imageScaling = NSImageScaleProportionallyUpOrDown;
    m_FallbackImageView.hidden = true;
    [self addSubview:m_FallbackImageView];

    const auto views_dict = NSDictionaryOfVariableBindings(m_ScrollView, m_QLView, m_FallbackImageView);
    const auto add_constraints = [&](NSString *_vis_fmt) {
        const auto constraints = [NSLayoutConstraint constraintsWithVisualFormat:_vis_fmt
                                                                         options:0
                                                                         metrics:nil
                                                                           views:views_dict];
        [self addConstraints:constraints];
    };
    add_constraints(@"|-(0)-[m_ScrollView]-(0)-|");
    add_constraints(@"|-(0)-[m_QLView]-(0)-|");
    add_constraints(@"|-(0)-[m_FallbackImageView]-(0)-|");
    add_constraints(@"V:|-(0)-[m_QLView]-(0)-[m_ScrollView]");
    add_constraints(@"V:|-(0)-[m_FallbackImageView]-(0)-[m_ScrollView]");
    add_constraints(@"V:[m_ScrollView]-(0)-|");
    m_ScrollViewHeightConstraint = [NSLayoutConstraint constraintWithItem:m_ScrollView
                                                                attribute:NSLayoutAttributeHeight
                                                                relatedBy:NSLayoutRelationEqual
                                                                   toItem:nil
                                                                attribute:NSLayoutAttributeNotAnAttribute
                                                               multiplier:1.0
                                                                 constant:m_ItemLayout.height];
    m_ScrollViewHeightConstraint.priority = 400; // TODO: why 400?
    [self addConstraint:m_ScrollViewHeightConstraint];

    __weak PanelGalleryView *weak_self = self;
    m_IconRepository->SetUpdateCallback([=](vfsicon::IconRepository::SlotKey _icon_no, NSImage *_icon) {
        if( auto strong_self = weak_self )
            [strong_self onIconUpdated:_icon_no image:_icon];
    });

    if( const std::string hazard_list = GlobalConfig().GetString(g_HazardousExtensionsList); hazard_list != "*" ) {
        m_HazardousExtsList.emplace(hazard_list);
    }

    m_ThemeObservation = NCAppDelegate.me.themesManager.ObserveChanges(
        nc::ThemesManager::Notifications::FilePanelsGallery | nc::ThemesManager::Notifications::FilePanelsGeneral,
        nc::objc_callback(self, @selector(themeDidChange)));

    return self;
}

- (void)dealloc
{
    [m_PanelView removeObserver:self forKeyPath:@"active"];
}

- (void)viewDidMoveToSuperview
{
    if( PanelView *panel_view = nc::objc_cast<PanelView>(self.superview) ) {
        m_PanelView = panel_view;
        [panel_view addObserver:self forKeyPath:@"active" options:0 context:nullptr];
        [self observeValueForKeyPath:@"active" ofObject:panel_view change:nil context:nil];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id) [[maybe_unused]] object
                        change:(NSDictionary *) [[maybe_unused]] change
                       context:(void *) [[maybe_unused]] context
{
    if( [keyPath isEqualToString:@"active"] ) {
        const bool active = m_PanelView.active;
        for( NCPanelGalleryCollectionViewItem *item in m_CollectionView.visibleItems )
            item.panelActive = active;
    }
}

- (int)itemsInColumn
{
    // TODO: implement
    return 1; // ??
}

- (int)maxNumberOfVisibleItems
{
    // TODO: implement
    return 5;
}

- (int)cursorPosition
{
    if( NSIndexPath *ip = m_CollectionView.selectionIndexPaths.anyObject )
        return static_cast<int>(ip.item);
    else
        return -1;
}

static bool IsQLSupportedSync(NSURL *_url)
{
    // TODO: never call this in the main thread
    const CGImageRef image = QLThumbnailImageCreate(nullptr, (__bridge CFURLRef)(_url), CGSizeMake(64, 64), nullptr);
    if( image ) {
        CGImageRelease(image);
        return true;
    }
    return false;
}

- (void)setCursorPosition:(int)_cursor_position
{
    assert(m_Data);
    if( self.cursorPosition == _cursor_position )
        return;

    const auto entries_count = [m_CollectionView numberOfItemsInSection:0];

    if( _cursor_position >= 0 && _cursor_position >= entries_count ) {
        return; // currently data<->cursor invariant is temporary broken => skipping this request
    }

    if( _cursor_position < 0 ) {
        m_CollectionView.selectionIndexPaths = [NSSet set];
    }
    else {
        const auto index_path = [NSIndexPath indexPathForItem:_cursor_position inSection:0];
        const auto indices = [NSSet setWithObject:index_path];
        m_CollectionView.selectionIndexPaths = indices;
        [m_CollectionView ensureItemIsVisible:_cursor_position];
    }

    if( auto vfs_item = m_Data->EntryAtSortPosition(_cursor_position) ) {
        const std::string path = vfs_item.Path();
        if( NSString *ns_path = [NSString stringWithUTF8StdString:path] ) {
            if( NSURL *url = [NSURL fileURLWithPath:ns_path] ) {
                if( IsQLSupportedSync(url) ) {
                    m_QLView.hidden = false;
                    m_FallbackImageView.hidden = true;
                    if( m_CurrentPreviewIsHazardous ) {
                        m_QLView.previewItem =
                            nil; // to prevent an ObjC exception from inside QL - reset the view first
                    }
                    m_QLView.previewItem = url;
                }
                else {
                    m_QLView.hidden = true;
                    m_QLView.previewItem =
                        nil; // NB! Without resetting the preview to nil, it somehow manages to completely freeze NC
                    m_FallbackImageView.hidden = false;

                    // TODO: never call this in the main thread
                    m_FallbackImageView.image = [[NSWorkspace sharedWorkspace] iconForFile:ns_path];
                }
                m_CurrentPreviewIsHazardous = [self isHazardousPath:path];
            }
        }
    }
}

- (void)onDataChanged
{
    // TODO: implement

    m_IconSlotToItemIndexMapping.clear();
    IconRepositoryCleaner{*m_IconRepository, *m_Data}.SweepUnusedSlots();

    [m_CollectionView reloadData];
}

- (void)onVolatileDataChanged
{
    Log::Trace("[PanelGalleryView onVolatileDataChanged]");
    dispatch_assert_main_queue();
    for( NCPanelGalleryCollectionViewItem *item in m_CollectionView.visibleItems )
        if( NSIndexPath *index_path = [m_CollectionView indexPathForItem:item] ) {
            const auto index = static_cast<int>(index_path.item);
            // need to firstly check if we're still in sync with panel data
            if( m_Data->IsValidSortPosition(index) )
                item.vd = m_Data->VolatileDataAtSortPosition(index);
        }
}

- (void)setData:(data::Model *)_data
{
    m_Data = _data;
}

- (bool)isItemVisible:(int)_sorted_item_index
{
    // TODO: implement
    return false;
}

- (void)setupFieldEditor:(NCPanelViewFieldEditor *)_editor forItemAtIndex:(int)_sorted_item_index
{
    // TODO: implement
}

- (int)sortedItemPosAtPoint:(NSPoint)_window_point hitTestOption:(PanelViewHitTest::Options)_options
{
    // TODO: implement
    return -1;
}

- (std::optional<NSRect>)frameOfItemAtIndex:(int)_sorted_item_index
{
    // TODO: implement
    return {};
}

- (PanelGalleryViewLayout)galleryLayout
{
    return m_Layout;
}

- (void)setGalleryLayout:(nc::panel::PanelGalleryViewLayout)_layout
{
    // TODO: implement
    m_Layout = _layout;
}

- (BOOL)isOpaque
{
    return true;
}

- (NSInteger)collectionView:(NSCollectionView *)_collection_view numberOfItemsInSection:(NSInteger)_section
{
    return m_Data ? m_Data->SortedDirectoryEntries().size() : 0;
}

- (NSCollectionViewItem *)collectionView:(NSCollectionView *)_collection_view
     itemForRepresentedObjectAtIndexPath:(NSIndexPath *)_index_path
{
    NCPanelGalleryCollectionViewItem *item = [m_CollectionView makeItemWithIdentifier:@"GalleryItem"
                                                                         forIndexPath:_index_path];
    item.itemLayout = m_ItemLayout;
    if( m_Data ) {
        const int index = static_cast<int>(_index_path.item);
        if( VFSListingItem vfs_item = m_Data->EntryAtSortPosition(index) ) {
            item.item = vfs_item;

            auto &vd = m_Data->VolatileDataAtSortPosition(index);
            if( !m_IconRepository->IsValidSlot(vd.icon) )
                vd.icon = m_IconRepository->Register(vfs_item);
            if( m_IconRepository->IsValidSlot(vd.icon) ) {
                item.icon = m_IconRepository->AvailableIconForSlot(vd.icon);
                m_IconRepository->ScheduleIconProduction(vd.icon, vfs_item);
                m_IconSlotToItemIndexMapping[vd.icon] = index;
            }
            else {
                item.icon = m_IconRepository->AvailableIconForListingItem(vfs_item);
            }
            item.vd = vd;
        }
        [item setPanelActive:m_PanelView.active];
    }

    return item;
}

- (void)onIconUpdated:(vfsicon::IconRepository::SlotKey)_icon_no image:(NSImage *)_icon
{
    dispatch_assert_main_queue();
    if( const auto it = m_IconSlotToItemIndexMapping.find(_icon_no); it != m_IconSlotToItemIndexMapping.end() ) {
        NSIndexPath *const index = [NSIndexPath indexPathForItem:it->second inSection:0];
        if( auto item = nc::objc_cast<NCPanelGalleryCollectionViewItem>([m_CollectionView itemAtIndexPath:index]) ) {
            item.imageView.image = _icon;
        }
    }
}

- (bool)isHazardousPath:(std::string_view)_path
{
    if( m_HazardousExtsList == std::nullopt )
        return true;
    return m_HazardousExtsList->contains(nc::utility::PathManip::Extension(_path));
}

- (void)rebuildItemLayout
{

    //    ItemLayout BuildItemLayout(unsigned _icon_size_px,
    //                               unsigned _font_height,
    //                               unsigned _text_lines);

    //    [SetPxSize-]

    //    if( self.window ) {

    //        m_IconsRepository->SetPxSize(px_size);
    //    }
    //    else {

    // TODO: add support for scaling
    //        const auto px_size = int(m_ItemLayout.icon_size * self.window.backingScaleFactor);

    nc::utility::FontGeometryInfo info(nc::CurrentTheme().FilePanelsGalleryFont());
    m_IconRepository->SetPxSize(32);
    m_ItemLayout =
        BuildItemLayout(32, static_cast<unsigned>(info.LineHeight()), static_cast<unsigned>(info.Descent()), 2);

    if( m_ScrollViewHeightConstraint != nil )
        m_ScrollViewHeightConstraint.constant = m_ItemLayout.height;
    if( m_CollectionViewLayout != nil )
        m_CollectionViewLayout.itemSize = NSMakeSize(m_ItemLayout.width, m_ItemLayout.height);
}

- (void)themeDidChange
{
    const int cursor_position = self.cursorPosition;
    [self rebuildItemLayout];
    [m_CollectionView reloadData];
    self.cursorPosition = cursor_position; // TODO: why is this here?
    m_CollectionView.backgroundColors = @[nc::CurrentTheme().FilePanelsGalleryBackgroundColor()];
    m_ScrollView.backgroundColor = nc::CurrentTheme().FilePanelsGalleryBackgroundColor();
}

@end

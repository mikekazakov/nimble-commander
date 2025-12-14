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
#include <Utility/UTI.h>
#include <ankerl/unordered_dense.h>
#include <Quartz/Quartz.h>

using namespace nc;
using namespace nc::panel;
using namespace nc::panel::gallery;

static constexpr auto g_HazardousExtensionsList = "filePanel.presentation.quickLookHazardousExtensionsList";
static constexpr auto g_SmoothScrolling = "filePanel.presentation.smoothScrolling";

@implementation NCPanelGalleryView {
    data::Model *m_Data;
    const nc::utility::UTIDB *m_UTIDB;
    PanelGalleryViewLayout m_Layout;
    ItemLayout m_ItemLayout;

    NSScrollView *m_CollectionScrollView;
    NCPanelGalleryViewCollectionView *m_CollectionView;
    NSCollectionViewFlowLayout *m_CollectionViewLayout;
    NSLayoutConstraint *m_ScrollViewHeightConstraint;
    QLPreviewView *m_QLView;
    NSImageView *m_FallbackImageView;
    std::filesystem::path m_FallbackImagePath;

    __weak PanelView *m_PanelView;

    ankerl::unordered_dense::map<vfsicon::IconRepository::SlotKey, int> m_IconSlotToItemIndexMapping;
    vfsicon::IconRepository *m_IconRepository;

    // It's a workaround for the macOS bug reported in FB9809109/FB5352643.
    bool m_CurrentPreviewIsHazardous;
    std::optional<nc::utility::ExtensionsLowercaseList> m_HazardousExtsList; // empty means everything is hazardous

    nc::ThemesManager::ObservationTicket m_ThemeObservation;
}

- (instancetype)initWithFrame:(NSRect)_frame
               iconRepository:(nc::vfsicon::IconRepository &)_ir
                        UTIDB:(const nc::utility::UTIDB &)_UTIDB
{
    self = [super initWithFrame:_frame];
    if( !self )
        return nil;

    m_Data = nullptr;
    m_IconRepository = &_ir;
    m_UTIDB = &_UTIDB;
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
    m_CollectionView.delegate = self;
    m_CollectionView.smoothScrolling = GlobalConfig().GetBool(g_SmoothScrolling);
    m_CollectionView.backgroundColors = @[nc::CurrentTheme().FilePanelsGalleryBackgroundColor()];
    [m_CollectionView registerClass:NCPanelGalleryCollectionViewItem.class forItemWithIdentifier:@"GalleryItem"];

    m_CollectionScrollView = [[NSScrollView alloc] initWithFrame:_frame];
    m_CollectionScrollView.translatesAutoresizingMaskIntoConstraints = false;
    m_CollectionScrollView.hasVerticalScroller = false;
    m_CollectionScrollView.hasHorizontalScroller = true;
    m_CollectionScrollView.documentView = m_CollectionView;
    m_CollectionScrollView.backgroundColor = nc::CurrentTheme().FilePanelsGalleryBackgroundColor();
    m_CollectionScrollView.drawsBackground = true;
    [self addSubview:m_CollectionScrollView];

    m_QLView = [[QLPreviewView alloc] initWithFrame:_frame style:QLPreviewViewStyleNormal];
    m_QLView.translatesAutoresizingMaskIntoConstraints = false;
    [self addSubview:m_QLView];

    m_FallbackImageView = [[NSImageView alloc] initWithFrame:_frame];
    m_FallbackImageView.translatesAutoresizingMaskIntoConstraints = false;
    m_FallbackImageView.imageScaling = NSImageScaleProportionallyUpOrDown;
    m_FallbackImageView.hidden = true;
    [self addSubview:m_FallbackImageView];

    const auto views_dict = NSDictionaryOfVariableBindings(m_CollectionScrollView, m_QLView, m_FallbackImageView);
    const auto add_constraints = [&](NSString *_vis_fmt) {
        const auto constraints = [NSLayoutConstraint constraintsWithVisualFormat:_vis_fmt
                                                                         options:0
                                                                         metrics:nil
                                                                           views:views_dict];
        [self addConstraints:constraints];
    };
    add_constraints(@"|-(0)-[m_CollectionScrollView]-(0)-|");
    add_constraints(@"|-(0)-[m_QLView]-(0)-|");
    add_constraints(@"|-(0)-[m_FallbackImageView]-(0)-|");
    add_constraints(@"V:|-(0)-[m_QLView]-(0)-[m_CollectionScrollView]");
    add_constraints(@"V:|-(0)-[m_FallbackImageView]-(0)-[m_CollectionScrollView]");
    add_constraints(@"V:[m_CollectionScrollView]-(0)-|");
    m_ScrollViewHeightConstraint = [NSLayoutConstraint constraintWithItem:m_CollectionScrollView
                                                                attribute:NSLayoutAttributeHeight
                                                                relatedBy:NSLayoutRelationEqual
                                                                   toItem:nil
                                                                attribute:NSLayoutAttributeNotAnAttribute
                                                               multiplier:1.0
                                                                 constant:m_ItemLayout.height];
    m_ScrollViewHeightConstraint.priority = 400; // TODO: why 400?
    [self addConstraint:m_ScrollViewHeightConstraint];

    __weak NCPanelGalleryView *weak_self = self;
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
    // Pretend that we have a row of 1-item columns, such that effectively Left==Up and Right==Down
    return 1;
}

- (int)maxNumberOfVisibleItems
{
    return static_cast<int>(m_CollectionScrollView.contentView.bounds.size.width /
                            static_cast<double>(m_ItemLayout.width));
}

- (int)cursorPosition
{
    if( NSIndexPath *ip = m_CollectionView.selectionIndexPaths.anyObject )
        return static_cast<int>(ip.item);
    else
        return -1;
}

- (bool)couldBeSupportedByQuickLook:(const VFSListingItem &)_item
{
    if( !_item.HasExtension() ) {
        // No extensions -> no UTI mapping -> no QL generator / preview appex / thumbnail appex can support it
        return false;
    }

    const std::string_view extension = _item.Extension();
    if( extension == "app" ) {
        return false; // QL cannot preview .app bundles, leave it to NSWorkspace
    }

    // Anything permanently registered in the system can be theoretically supported by QL
    const std::string uti = m_UTIDB->UTIForExtension(extension);
    return m_UTIDB->IsDeclaredUTI(uti);
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

    // For now only supporting native vfs
    if( auto vfs_item = m_Data->EntryAtSortPosition(_cursor_position); vfs_item.Host()->IsNativeFS() ) {
        const std::string path = vfs_item.Path();
        if( NSString *ns_path = [NSString stringWithUTF8StdString:path] ) {
            if( NSURL *url = [NSURL fileURLWithPath:ns_path] ) {
                //                if( IsQLSupportedSync(url) ) {
                if( [self couldBeSupportedByQuickLook:vfs_item] ) {
                    m_QLView.hidden = false;
                    m_FallbackImageView.hidden = true;
                    m_FallbackImagePath = "";
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
                    if( m_FallbackImagePath != path ) {
                        // fmt::println("Gallery fallback image for path: {}", path);
                        m_FallbackImageView.image = [[NSWorkspace sharedWorkspace] iconForFile:ns_path];
                        m_FallbackImagePath = path;
                    }
                }
                m_CurrentPreviewIsHazardous = [self isHazardousPath:path];
            }
        }
    }
}

- (void)onDataChanged
{
    Log::Trace("[PanelGalleryView dataChanged]");
    dispatch_assert_main_queue();
    assert(m_Data);
    m_IconSlotToItemIndexMapping.clear();
    IconRepositoryCleaner{*m_IconRepository, *m_Data}.SweepUnusedSlots();
    [m_CollectionView reloadData];
    [self onVolatileDataChanged];
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
    Log::Trace("[PanelGalleryView isItemVisible:{}]", _sorted_item_index);
    const long entries_count = [m_CollectionView numberOfItemsInSection:0];
    if( _sorted_item_index < 0 || _sorted_item_index >= entries_count )
        return false;

    const auto vis_rect = m_CollectionScrollView.documentVisibleRect;
    const auto item_rect = [m_CollectionView frameForItemAtIndex:_sorted_item_index];
    return NSContainsRect(vis_rect, item_rect) || NSIntersectsRect(vis_rect, item_rect);
}

- (void)setupFieldEditor:(NCPanelViewFieldEditor *)_editor forItemAtIndex:(int)_sorted_item_index
{
    NSIndexPath *const index = [NSIndexPath indexPathForItem:_sorted_item_index inSection:0];
    if( auto i = nc::objc_cast<NCPanelGalleryCollectionViewItem>([m_CollectionView itemAtIndexPath:index]) )
        [i setupFieldEditor:_editor];
}

- (std::optional<NSRect>)frameOfItemAtIndex:(int)_sorted_item_index
{
    const auto index_path = [NSIndexPath indexPathForItem:_sorted_item_index inSection:0];
    NSCollectionViewLayoutAttributes *const attrs = [m_CollectionView layoutAttributesForItemAtIndexPath:index_path];
    if( attrs == nil )
        return {};
    return [self convertRect:attrs.frame fromView:m_CollectionView];
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
            item.icon = _icon;
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
    const int logical_icon_size = 32;

    if( self.window ) {
        const int physical_icon_size = static_cast<int>(logical_icon_size * self.window.backingScaleFactor);
        m_IconRepository->SetPxSize(physical_icon_size);
    }

    nc::utility::FontGeometryInfo info(nc::CurrentTheme().FilePanelsGalleryFont());
    m_ItemLayout = BuildItemLayout(
        logical_icon_size, static_cast<unsigned>(info.LineHeight()), static_cast<unsigned>(info.Descent()), 2);

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
    m_CollectionScrollView.backgroundColor = nc::CurrentTheme().FilePanelsGalleryBackgroundColor();
}

- (void)viewDidMoveToWindow
{
    [super viewDidMoveToWindow];
    [self rebuildItemLayout]; // we call this here due to a possible DPI change
}

- (PanelView *)panelView
{
    return m_PanelView;
}

@end

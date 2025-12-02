// Copyright (C) 2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelGalleryView.h"
#include "PanelGalleryCollectionView.h"
#include "PanelGalleryCollectionViewItem.h"
#include "../Helpers/IconRepositoryCleaner.h"
#include <NimbleCommander/Bootstrap/Config.h> // TODO: evil! DI instead!
#include <Panel/PanelData.h>
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
static constexpr auto g_SmoothScrolling =  "filePanel.presentation.smoothScrolling";

@implementation PanelGalleryView {
    data::Model *m_Data;
    PanelGalleryViewLayout m_Layout;
    ItemLayout m_ItemLayout;

    NSScrollView *m_ScrollView;
    NCPanelGalleryViewCollectionView *m_CollectionView;
    NSCollectionViewFlowLayout *m_CollectionViewLayout;

    QLPreviewView *m_QLView;

    ankerl::unordered_dense::map<vfsicon::IconRepository::SlotKey, int> m_IconSlotToItemIndexMapping;
    vfsicon::IconRepository *m_IconRepository;
    
    // It's a workaround for the macOS bug reported in FB9809109/FB5352643.
    bool m_CurrentPreviewIsHazardous;
    std::optional<nc::utility::ExtensionsLowercaseList> m_HazardousExtsList; // empty means everything is hazardous
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

    m_ScrollView = [[NSScrollView alloc] initWithFrame:_frame];
    m_ScrollView.translatesAutoresizingMaskIntoConstraints = false;
    m_ScrollView.hasVerticalScroller = false;
    m_ScrollView.hasHorizontalScroller = true;
    [self addSubview:m_ScrollView];

    m_CollectionViewLayout = [NSCollectionViewFlowLayout new];
    m_CollectionViewLayout.scrollDirection = NSCollectionViewScrollDirectionHorizontal;
//    m_CollectionViewLayout.itemSize = NSMakeSize( 40, 40);
    m_CollectionViewLayout.itemSize = NSMakeSize(m_ItemLayout.width, m_ItemLayout.height);
    m_CollectionViewLayout.minimumLineSpacing = 10.;
    m_CollectionViewLayout.sectionInset = NSEdgeInsetsMake(0., 0., 0., 0.);
    
    m_CollectionView = [[NCPanelGalleryViewCollectionView alloc] initWithFrame:_frame];
    m_CollectionView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    m_CollectionView.collectionViewLayout = m_CollectionViewLayout;
    m_CollectionView.dataSource = self;
    m_CollectionView.smoothScrolling = GlobalConfig().GetBool(g_SmoothScrolling);
    [m_CollectionView registerClass:NCPanelGalleryCollectionViewItem.class forItemWithIdentifier:@"GalleryItem"];

    m_QLView = [[QLPreviewView alloc] initWithFrame:_frame style:QLPreviewViewStyleNormal];
    m_QLView.translatesAutoresizingMaskIntoConstraints = false;
    [self addSubview:m_QLView];

    m_ScrollView.documentView = m_CollectionView;

    const auto views_dict = NSDictionaryOfVariableBindings(m_ScrollView, m_QLView);
    const auto add_constraints = [&](NSString *_vis_fmt) {
        const auto constraints = [NSLayoutConstraint constraintsWithVisualFormat:_vis_fmt
                                                                         options:0
                                                                         metrics:nil
                                                                           views:views_dict];
        [self addConstraints:constraints];
    };
    add_constraints(@"V:|-(0)-[m_QLView]-(10)-[m_ScrollView(==80@400)]-(0)-|");
    add_constraints(@"|-(0)-[m_ScrollView]-(0)-|");
    add_constraints(@"|-(0)-[m_QLView]-(0)-|");

    __weak PanelGalleryView *weak_self = self;
    m_IconRepository->SetUpdateCallback([=](vfsicon::IconRepository::SlotKey _icon_no, NSImage *_icon) {
        if( auto strong_self = weak_self )
            [strong_self onIconUpdated:_icon_no image:_icon];
    });
        
    if(const std::string hazard_list = GlobalConfig().GetString(g_HazardousExtensionsList); hazard_list != "*" ) {
        m_HazardousExtsList.emplace(hazard_list);
    }

    return self;
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
                if (m_CurrentPreviewIsHazardous) {
                    m_QLView.previewItem = nil; // to prevent an ObjC exception from inside QL - reset the view first
                }
                m_QLView.previewItem = url;
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
    // TODO: implement
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
        const auto index = static_cast<int>(_index_path.item);
        if( auto vfs_item = m_Data->EntryAtSortPosition(index) ) {
            item.textField.stringValue = vfs_item.DisplayNameNS(); // TODO: wrong!

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
        }
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
    m_IconRepository->SetPxSize(32);
    m_ItemLayout = BuildItemLayout(32,
                                   static_cast<unsigned>(nc::utility::FontGeometryInfo([NSFont systemFontOfSize:12]).LineHeight()),
                                   2);
}


@end

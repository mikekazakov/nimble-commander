// Copyright (C) 2013-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelView.h"
#include <Utility/ActionsShortcutsManager.h>
#include <Utility/NSEventModifierFlagsHolder.h>
#include <Utility/MIMResponder.h>
#include <Utility/ObjCpp.h>
#include <Utility/StringExtras.h>
#include <Base/UnorderedUtil.h>
#include "PanelViewLayoutSupport.h"
#include <Panel/PanelData.h>
#include <Panel/Log.h>
#include "PanelController.h"
#include "Brief/PanelBriefView.h"
#include "List/PanelListView.h"
#include "PanelViewHeader.h"
#include "PanelViewFooter.h"
#include "PanelViewDelegate.h"
#include "DragReceiver.h"
#include "DragSender.h"
#include "ContextMenu.h"
#include <Panel/PanelViewFieldEditor.h>
#include <Panel/PanelViewKeystrokeSink.h>
#include "PanelViewDummyPresentation.h"
#include "PanelControllerActionsDispatcher.h"

using namespace nc::panel;
using nc::vfsicon::IconRepository;

namespace nc::panel {

enum class CursorSelectionType : int8_t {
    No = 0,
    Selection = 1,
    Unselection = 2
};

struct StateStorage {
    std::string focused_item;
};

} // namespace nc::panel

@interface PanelView ()

@property(nonatomic, readonly) PanelController *controller;

@end

@implementation PanelView {
    data::Model *m_Data;
    std::vector<__weak id<NCPanelViewKeystrokeSink>> m_KeystrokeSinks;

    ankerl::unordered_dense::map<uint64_t, StateStorage> m_States;
    NSString *m_HeaderTitle;
    NCPanelViewFieldEditor *m_RenamingEditor;

    __weak id<PanelViewDelegate> m_Delegate;
    NSView<NCPanelViewPresentationProtocol> *m_ItemsView;
    NCPanelViewHeader *m_HeaderView;
    NCPanelViewFooter *m_FooterView;

    std::unique_ptr<IconRepository> m_IconRepository;
    std::shared_ptr<nc::vfs::NativeHost> m_NativeHost;
    const nc::utility::ActionsShortcutsManager *m_ActionsShortcutsManager;

    int m_CursorPos;
    nc::utility::NSEventModifierFlagsHolder m_KeyboardModifierFlags;
    CursorSelectionType m_KeyboardCursorSelectionType;
}

@synthesize headerView = m_HeaderView;
@synthesize actionsDispatcher;

- (id)initWithFrame:(NSRect)frame
             iconRepository:(std::unique_ptr<nc::vfsicon::IconRepository>)_icon_repository
    actionsShortcutsManager:(const nc::utility::ActionsShortcutsManager &)_actions_shortcuts_manager
                  nativeVFS:(nc::vfs::NativeHost &)_native_vfs
                     header:(NCPanelViewHeader *)_header
                     footer:(NCPanelViewFooter *)_footer
{
    self = [super initWithFrame:frame];
    if( self ) {
        m_Data = nullptr;
        m_CursorPos = -1;
        m_HeaderTitle = @"";
        m_IconRepository = std::move(_icon_repository);
        m_NativeHost = _native_vfs.SharedPtr();
        m_ActionsShortcutsManager = &_actions_shortcuts_manager;

        m_ItemsView = [[NCPanelViewDummyPresentation alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
        [self addSubview:m_ItemsView];

        m_HeaderView = _header;
        m_HeaderView.translatesAutoresizingMaskIntoConstraints = false;
        m_HeaderView.defaultResponder = self;
        __weak PanelView *weak_self = self;
        m_HeaderView.sortModeChangeCallback = [weak_self](data::SortMode _sm) {
            if( PanelView *const strong_self = weak_self )
                [strong_self.controller changeSortingModeTo:_sm];
        };
        [self addSubview:m_HeaderView];

        m_FooterView = _footer;
        m_FooterView.translatesAutoresizingMaskIntoConstraints = false;
        [self addSubview:m_FooterView];

        [self setupLayout];
    }

    return self;
}

- (id)initWithFrame:(NSRect) [[maybe_unused]] _frame
{
    assert("don't call [PanelView initWithFrame:(NSRect)frame]" == nullptr);
    return nil;
}

- (void)setupLayout
{
    const auto views = NSDictionaryOfVariableBindings(m_ItemsView, m_HeaderView, m_FooterView);
    const auto constraints = {@"V:|-(==0)-[m_HeaderView(==20)]-(==0)-[m_ItemsView]-(==0)-[m_FooterView(==20)]-(==0)-|",
                              @"|-(0)-[m_HeaderView]-(0)-|",
                              @"|-(0)-[m_ItemsView]-(0)-|",
                              @"|-(0)-[m_FooterView]-(0)-|"};
    for( auto constraint : constraints )
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:constraint
                                                                     options:0
                                                                     metrics:nil
                                                                       views:views]];
}

- (NSView<NCPanelViewPresentationProtocol> *)spawnItemViewWithLayout:(const PanelViewLayout &)_layout
{
    if( auto ll = std::any_cast<PanelListViewColumnsLayout>(&_layout.layout) ) {
        auto v = [self spawnListView];
        v.columnsLayout = *ll;
        return v;
    }
    else if( auto bl = std::any_cast<PanelBriefViewColumnsLayout>(&_layout.layout) ) {
        auto v = [self spawnBriefView];
        v.columnsLayout = *bl;
        return v;
    }
    return nil;
}

- (void)dealloc
{
    m_Data = nullptr;
}

- (void)setDelegate:(id<PanelViewDelegate>)delegate
{
    m_Delegate = delegate;
    if( auto r = nc::objc_cast<NSResponder>(delegate) ) {
        NSResponder *current = self.nextResponder;
        super.nextResponder = r;
        r.nextResponder = current;
    }
}

- (id<PanelViewDelegate>)delegate
{
    return m_Delegate;
}

- (void)setNextResponder:(NSResponder *)newNextResponder
{
    if( auto r = nc::objc_cast<AttachedResponder>(self.delegate) ) {
        [r setNextResponder:newNextResponder];
        return;
    }
    [super setNextResponder:newNextResponder];
}

- (PanelListView *)spawnListView
{
    PanelListView *v = [[PanelListView alloc] initWithFrame:self.bounds andIR:*m_IconRepository];
    v.translatesAutoresizingMaskIntoConstraints = false;
    __weak PanelView *weak_self = self;
    v.sortModeChangeCallback = [=](data::SortMode _sm) {
        if( PanelView *const strong_self = weak_self )
            [strong_self.controller changeSortingModeTo:_sm];
    };
    return v;
}

- (PanelBriefView *)spawnBriefView
{
    auto v = [[PanelBriefView alloc] initWithFrame:self.bounds andIR:*m_IconRepository];
    v.translatesAutoresizingMaskIntoConstraints = false;
    return v;
}

- (BOOL)isOpaque
{
    return true;
}

- (BOOL)acceptsFirstResponder
{
    return true;
}

- (BOOL)becomeFirstResponder
{
    [self.controller panelViewDidBecomeFirstResponder];
    [self refreshActiveStatus];
    return true;
}

- (BOOL)resignFirstResponder
{
    __weak PanelView *weak_self = self;
    dispatch_to_main_queue([=] {
        if( PanelView *const strong_self = weak_self )
            [strong_self refreshActiveStatus];
    });
    return YES;
}

- (void)refreshActiveStatus
{
    [self willChangeValueForKey:@"active"];
    [self didChangeValueForKey:@"active"];
    const auto active = self.active;
    m_FooterView.active = active;
    m_HeaderView.active = active;
}

- (void)viewWillMoveToWindow:(NSWindow *)_wnd
{
    static const auto notify = NSNotificationCenter.defaultCenter;
    if( self.window ) {
        [notify removeObserver:self name:NSWindowDidBecomeKeyNotification object:nil];
        [notify removeObserver:self name:NSWindowDidResignKeyNotification object:nil];
        [notify removeObserver:self name:NSWindowDidBecomeMainNotification object:nil];
        [notify removeObserver:self name:NSWindowDidResignMainNotification object:nil];
    }
    if( _wnd ) {
        [notify addObserver:self
                   selector:@selector(windowStatusDidChange)
                       name:NSWindowDidBecomeKeyNotification
                     object:_wnd];
        [notify addObserver:self
                   selector:@selector(windowStatusDidChange)
                       name:NSWindowDidResignKeyNotification
                     object:_wnd];
        [notify addObserver:self
                   selector:@selector(windowStatusDidChange)
                       name:NSWindowDidBecomeMainNotification
                     object:_wnd];
        [notify addObserver:self
                   selector:@selector(windowStatusDidChange)
                       name:NSWindowDidResignMainNotification
                     object:_wnd];
    }
}

- (bool)active
{
    if( auto w = self.window )
        if( w.isKeyWindow || w.isMainWindow )
            if( id fr = w.firstResponder )
                return fr == self || [nc::objc_cast<NSView>(fr) isDescendantOf:self];
    return false;
}

- (data::Model *)data
{
    return m_Data;
}

- (void)setData:(data::Model *)data
{
    m_Data = data;

    if( data ) {
        [m_ItemsView setData:data];
        m_ItemsView.sortMode = data->SortMode();
        m_HeaderView.sortMode = data->SortMode();
    }

    if( !data ) {
        // we're in destruction phase
        [m_ItemsView removeFromSuperview];
        m_ItemsView = nil;

        [m_HeaderView removeFromSuperview];
        m_HeaderView = nil;

        [m_FooterView removeFromSuperview];
        m_FooterView = nil;
    }
}

- (void)HandlePrevFile
{
    dispatch_assert_main_queue();

    int origpos = m_CursorPos;

    if( m_CursorPos < 0 )
        return;

    [self performKeyboardSelection:origpos last_included:origpos];

    if( m_CursorPos == 0 )
        return;

    m_CursorPos--;

    [self OnCursorPositionChanged];
}

- (void)HandleNextFile
{
    dispatch_assert_main_queue();

    int origpos = m_CursorPos;
    [self performKeyboardSelection:origpos last_included:origpos];
    if( m_CursorPos + 1 >= static_cast<long>(m_Data->SortedDirectoryEntries().size()) )
        return;

    m_CursorPos++;

    [self OnCursorPositionChanged];
}

- (void)HandlePrevPage
{
    dispatch_assert_main_queue();

    const auto orig_pos = m_CursorPos;

    const auto total_items = static_cast<int>(m_Data->SortedDirectoryEntries().size());
    if( !total_items )
        return;

    const auto items_per_screen = m_ItemsView.maxNumberOfVisibleItems;
    const auto new_pos = std::max(orig_pos - items_per_screen, 0);

    if( new_pos == orig_pos )
        return;

    m_CursorPos = new_pos;

    [self performKeyboardSelection:orig_pos last_included:m_CursorPos];
    [self OnCursorPositionChanged];
}

- (void)HandleNextPage
{
    dispatch_assert_main_queue();

    const auto total_items = static_cast<int>(m_Data->SortedDirectoryEntries().size());
    if( !total_items )
        return;
    const auto orig_pos = m_CursorPos;
    const auto items_per_screen = m_ItemsView.maxNumberOfVisibleItems;
    const auto new_pos = std::min(orig_pos + items_per_screen, total_items - 1);

    if( new_pos == orig_pos )
        return;

    m_CursorPos = new_pos;

    [self performKeyboardSelection:orig_pos last_included:m_CursorPos];
    [self OnCursorPositionChanged];
}

- (void)HandlePrevColumn
{
    dispatch_assert_main_queue();

    const auto orig_pos = m_CursorPos;

    if( m_Data->SortedDirectoryEntries().empty() )
        return;
    const auto items_per_column = m_ItemsView.itemsInColumn;
    const auto new_pos = std::max(orig_pos - items_per_column, 0);

    if( new_pos == orig_pos )
        return;

    m_CursorPos = new_pos;

    [self performKeyboardSelection:orig_pos last_included:m_CursorPos];
    [self OnCursorPositionChanged];
}

- (void)HandleNextColumn
{
    dispatch_assert_main_queue();

    const auto orig_pos = m_CursorPos;

    if( m_Data->SortedDirectoryEntries().empty() )
        return;
    const auto total_items = static_cast<int>(m_Data->SortedDirectoryEntries().size());
    const auto items_per_column = m_ItemsView.itemsInColumn;
    const auto new_pos = std::min(orig_pos + items_per_column, total_items - 1);

    if( new_pos == orig_pos )
        return;

    m_CursorPos = new_pos;

    [self performKeyboardSelection:orig_pos last_included:m_CursorPos];
    [self OnCursorPositionChanged];
}

- (void)HandleFirstFile
{
    dispatch_assert_main_queue();

    const auto origpos = m_CursorPos;

    if( m_Data->SortedDirectoryEntries().empty() || m_CursorPos == 0 )
        return;

    m_CursorPos = 0;

    [self performKeyboardSelection:origpos last_included:m_CursorPos];
    [self OnCursorPositionChanged];
}

- (void)HandleLastFile
{
    dispatch_assert_main_queue();

    const auto origpos = m_CursorPos;

    if( m_Data->SortedDirectoryEntries().empty() ||
        m_CursorPos == static_cast<int>(m_Data->SortedDirectoryEntries().size()) - 1 )
        return;

    m_CursorPos = static_cast<int>(m_Data->SortedDirectoryEntries().size()) - 1;

    [self performKeyboardSelection:origpos last_included:m_CursorPos];
    [self OnCursorPositionChanged];
}

- (void)onInvertCurrentItemSelectionAndMoveNext
{
    dispatch_assert_main_queue();

    const auto origpos = m_CursorPos;

    if( auto entry = m_Data->EntryAtSortPosition(origpos) )
        [self SelectUnselectInRange:origpos
                      last_included:origpos
                             select:!m_Data->VolatileDataAtSortPosition(origpos).is_selected()];

    if( m_CursorPos + 1 < static_cast<int>(m_Data->SortedDirectoryEntries().size()) ) {
        m_CursorPos++;
        [self OnCursorPositionChanged];
    }
}

- (void)onInvertCurrentItemSelection
{
    dispatch_assert_main_queue();

    int pos = m_CursorPos;
    if( auto entry = m_Data->EntryAtSortPosition(pos) )
        [self SelectUnselectInRange:pos
                      last_included:pos
                             select:!m_Data->VolatileDataAtSortPosition(pos).is_selected()];
}

- (void)setCurpos:(int)_pos
{
    dispatch_assert_main_queue();

    const auto clipped_pos = (!m_Data->SortedDirectoryEntries().empty() && _pos >= 0 &&
                              _pos < static_cast<int>(m_Data->SortedDirectoryEntries().size()))
                                 ? _pos
                                 : -1;

    if( m_CursorPos == clipped_pos )
        return;

    m_CursorPos = clipped_pos;

    [self OnCursorPositionChanged];
}

- (int)curpos
{
    dispatch_assert_main_queue();
    return m_CursorPos;
}

- (void)OnCursorPositionChanged
{
    dispatch_assert_main_queue();
    [m_ItemsView setCursorPosition:m_CursorPos];
    [m_FooterView updateFocusedItem:self.item VD:self.item_vd];

    if( id<PanelViewDelegate> del = self.delegate )
        if( [del respondsToSelector:@selector(panelViewCursorChanged:)] )
            [del panelViewCursorChanged:self];

    if( m_RenamingEditor ) {
        // If we have a field editor in flight - commit it unless the cursor pos is of the item it's currently editing.
        if( m_CursorPos != [self findSortedIndexOfForeignListingItem:m_RenamingEditor.originalItem] )
            [self commitFieldEditor];
    }
}

- (void)keyDown:(NSEvent *)event
{
    using nc::utility::ActionShortcut;

    id<NCPanelViewKeystrokeSink> best_handler = nil;
    int best_bid = view::BiddingPriority::Skip;
    for( const auto &handler : m_KeystrokeSinks )
        if( id<NCPanelViewKeystrokeSink> h = handler ) {
            const auto bid = [h bidForHandlingKeyDown:event forPanelView:self];
            if( bid > best_bid ) {
                best_handler = h;
                best_bid = bid;
            }
        }

    if( best_handler ) {
        [best_handler handleKeyDown:event forPanelView:self];
        return;
    }

    NSString *character = [event charactersIgnoringModifiers];
    if( character.length != 1 ) {
        [super keyDown:event];
        return;
    }

    [self checkKeyboardModifierFlags:event.modifierFlags];

    struct Tags {
        int up = -1;
        int down = -1;
        int left = -1;
        int right = -1;
        int first = -1;
        int last = -1;
        int page_down = -1;
        int page_up = -1;
        int invert_and_move = -1;
        int invert = -1;
        int scroll_down = -1;
        int scroll_up = -1;
        int scroll_home = -1;
        int scroll_end = -1;
    };
    static const Tags tags = [&] {
        Tags t;
        t.up = m_ActionsShortcutsManager->TagFromAction("panel.move_up").value();
        t.down = m_ActionsShortcutsManager->TagFromAction("panel.move_down").value();
        t.left = m_ActionsShortcutsManager->TagFromAction("panel.move_left").value();
        t.right = m_ActionsShortcutsManager->TagFromAction("panel.move_right").value();
        t.first = m_ActionsShortcutsManager->TagFromAction("panel.move_first").value();
        t.last = m_ActionsShortcutsManager->TagFromAction("panel.move_last").value();
        t.page_down = m_ActionsShortcutsManager->TagFromAction("panel.move_next_page").value();
        t.page_up = m_ActionsShortcutsManager->TagFromAction("panel.move_prev_page").value();
        t.invert_and_move = m_ActionsShortcutsManager->TagFromAction("panel.move_next_and_invert_selection").value();
        t.invert = m_ActionsShortcutsManager->TagFromAction("panel.invert_item_selection").value();
        t.scroll_down = m_ActionsShortcutsManager->TagFromAction("panel.scroll_next_page").value();
        t.scroll_up = m_ActionsShortcutsManager->TagFromAction("panel.scroll_prev_page").value();
        t.scroll_home = m_ActionsShortcutsManager->TagFromAction("panel.scroll_first").value();
        t.scroll_end = m_ActionsShortcutsManager->TagFromAction("panel.scroll_last").value();
        return t;
    }();

    const auto event_data = ActionShortcut::EventData(event);
    const auto event_hotkey = ActionShortcut(event_data);
    const auto event_hotkey_wo_shift =
        ActionShortcut(ActionShortcut::EventData(event_data.char_with_modifiers,
                                                 event_data.char_without_modifiers,
                                                 event_data.key_code,
                                                 event_data.modifiers & ~NSEventModifierFlagShift));

    const std::optional<int> event_action_tag = m_ActionsShortcutsManager->FirstOfActionTagsFromShortcut(
        std::array{
            tags.scroll_down, tags.scroll_up, tags.scroll_home, tags.scroll_end, tags.invert_and_move, tags.invert},
        event_hotkey);

    const std::optional<int> event_action_tag_wo_shift = m_ActionsShortcutsManager->FirstOfActionTagsFromShortcut(
        std::array{tags.up, tags.down, tags.left, tags.right, tags.first, tags.last, tags.page_down, tags.page_up},
        event_hotkey_wo_shift);

    if( event_action_tag_wo_shift == tags.up )
        [self HandlePrevFile];
    else if( event_action_tag_wo_shift == tags.down )
        [self HandleNextFile];
    else if( event_action_tag_wo_shift == tags.left )
        [self HandlePrevColumn];
    else if( event_action_tag_wo_shift == tags.right )
        [self HandleNextColumn];
    else if( event_action_tag_wo_shift == tags.first )
        [self HandleFirstFile];
    else if( event_action_tag_wo_shift == tags.last )
        [self HandleLastFile];
    else if( event_action_tag_wo_shift == tags.page_down )
        [self HandleNextPage];
    else if( event_action_tag_wo_shift == tags.page_up )
        [self HandlePrevPage];
    else if( event_action_tag == tags.scroll_down )
        [m_ItemsView onPageDown:event];
    else if( event_action_tag == tags.scroll_up )
        [m_ItemsView onPageUp:event];
    else if( event_action_tag == tags.scroll_home )
        [m_ItemsView onScrollToBeginning:event];
    else if( event_action_tag == tags.scroll_end )
        [m_ItemsView onScrollToEnd:event];
    else if( event_action_tag == tags.invert_and_move )
        [self onInvertCurrentItemSelectionAndMoveNext];
    else if( event_action_tag == tags.invert )
        [self onInvertCurrentItemSelection];
    else
        [super keyDown:event];
}

- (void)checkKeyboardModifierFlags:(NSEventModifierFlags)_current_flags
{
    if( nc::utility::NSEventModifierFlagsHolder(_current_flags) == m_KeyboardModifierFlags )
        return; // we're ok

    // flags have changed, need to update selection logic
    m_KeyboardModifierFlags = _current_flags;

    if( !m_KeyboardModifierFlags.is_shift() ) {
        // clear selection type when user releases SHIFT button
        m_KeyboardCursorSelectionType = CursorSelectionType::No;
    }
    else if( m_KeyboardCursorSelectionType == CursorSelectionType::No ) {
        // lets decide if we need to select or unselect files when user will use navigation arrows
        if( auto item = self.item ) {
            if( !item.IsDotDot() ) { // regular case
                m_KeyboardCursorSelectionType =
                    self.item_vd.is_selected() ? CursorSelectionType::Unselection : CursorSelectionType::Selection;
            }
            else {
                // need to look at a first file (next to dotdot) for current representation if any.
                if( auto next_item = m_Data->EntryAtSortPosition(1) )
                    m_KeyboardCursorSelectionType = m_Data->VolatileDataAtSortPosition(1).is_selected()
                                                        ? CursorSelectionType::Unselection
                                                        : CursorSelectionType::Selection;
                else // singular case - selection doesn't matter - nothing to select
                    m_KeyboardCursorSelectionType = CursorSelectionType::Selection;
            }
        }
    }
}

- (void)flagsChanged:(NSEvent *)event
{
    [self checkKeyboardModifierFlags:event.modifierFlags];
    [super flagsChanged:event];
}

- (NSMenu *)panelItem:(int)_sorted_index menuForForEvent:(NSEvent *) [[maybe_unused]] _event
{
    if( _sorted_index >= 0 )
        return [self.delegate panelView:self requestsContextMenuForItemNo:_sorted_index];
    return nil;
}

- (VFSListingItem)item
{
    return m_Data->EntryAtSortPosition(m_CursorPos);
}

- (const data::ItemVolatileData &)item_vd
{
    dispatch_assert_main_queue();
    static const data::ItemVolatileData stub{};
    int indx = m_Data->RawIndexForSortIndex(m_CursorPos);
    if( indx < 0 )
        return stub;
    return m_Data->VolatileDataAtRawPosition(indx);
}

- (void)SelectUnselectInRange:(int)_start last_included:(int)_end select:(BOOL)_select
{
    dispatch_assert_main_queue();
    if( _start < 0 || _start >= static_cast<int>(m_Data->SortedDirectoryEntries().size()) || _end < 0 ||
        _end >= static_cast<int>(m_Data->SortedDirectoryEntries().size()) ) {
        NSLog(@"SelectUnselectInRange - invalid range");
        return;
    }

    if( _start > _end )
        std::swap(_start, _end);

    // we never want to select a first (dotdot) entry
    if( auto i = m_Data->EntryAtSortPosition(_start) )
        if( i.IsDotDot() )
            ++_start; // we don't want to select or unselect a dotdot entry - they are higher than
                      // that stuff

    for( int i = _start; i <= _end; ++i )
        m_Data->CustomFlagsSelectSorted(i, _select);

    //    [m_ItemsView syncVolatileData];
    [self volatileDataChanged];
}

- (void)performKeyboardSelection:(int)_start last_included:(int)_end
{
    dispatch_assert_main_queue();
    if( m_KeyboardCursorSelectionType == CursorSelectionType::No )
        return;
    [self SelectUnselectInRange:_start
                  last_included:_end
                         select:m_KeyboardCursorSelectionType == CursorSelectionType::Selection];
}

- (void)setupBriefPresentationWithLayout:(PanelBriefViewColumnsLayout)_layout
{
    const auto init = !nc::objc_cast<PanelBriefView>(m_ItemsView);
    if( init ) {
        auto v = [self spawnBriefView];
        // v.translatesAutoresizingMaskIntoConstraints = false;
        //    [self addSubview:m_ItemsView];

        [self replaceSubview:m_ItemsView with:v];
        m_ItemsView = v;

        NSDictionary *views = NSDictionaryOfVariableBindings(m_ItemsView, m_HeaderView, m_FooterView);
        [self
            addConstraints:[NSLayoutConstraint
                               constraintsWithVisualFormat:@"V:[m_HeaderView]-(==0)-[m_ItemsView]-(==0)-[m_FooterView]"
                                                   options:0
                                                   metrics:nil
                                                     views:views]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(0)-[m_ItemsView]-(0)-|"
                                                                     options:0
                                                                     metrics:nil
                                                                       views:views]];
        [self layout];

        if( m_Data ) {
            m_ItemsView.data = m_Data;
            m_ItemsView.sortMode = m_Data->SortMode();
        }

        if( m_CursorPos >= 0 )
            [m_ItemsView setCursorPosition:m_CursorPos];
    }

    if( auto v = nc::objc_cast<PanelBriefView>(m_ItemsView) ) {
        [v setColumnsLayout:_layout];
    }
}

- (void)setupListPresentationWithLayout:(PanelListViewColumnsLayout)_layout
{
    const auto init = !nc::objc_cast<PanelListView>(m_ItemsView);

    if( init ) {
        auto v = [self spawnListView];
        // v.translatesAutoresizingMaskIntoConstraints = false;

        [self replaceSubview:m_ItemsView with:v];
        m_ItemsView = v;

        NSDictionary *views = NSDictionaryOfVariableBindings(m_ItemsView, m_HeaderView, m_FooterView);
        [self
            addConstraints:[NSLayoutConstraint
                               constraintsWithVisualFormat:@"V:[m_HeaderView]-(==0)-[m_ItemsView]-(==0)-[m_FooterView]"
                                                   options:0
                                                   metrics:nil
                                                     views:views]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(0)-[m_ItemsView]-(0)-|"
                                                                     options:0
                                                                     metrics:nil
                                                                       views:views]];
        [self layout];

        if( m_Data ) {
            m_ItemsView.data = m_Data;
            m_ItemsView.sortMode = m_Data->SortMode();
        }

        if( m_CursorPos >= 0 )
            [m_ItemsView setCursorPosition:m_CursorPos];
    }

    if( auto v = nc::objc_cast<PanelListView>(m_ItemsView) ) {
        [v setColumnsLayout:_layout];
    }
}

- (std::any)presentationLayout
{
    if( auto v = nc::objc_cast<PanelBriefView>(m_ItemsView) )
        return std::any{[v columnsLayout]};
    if( auto v = nc::objc_cast<PanelListView>(m_ItemsView) )
        return std::any{[v columnsLayout]};
    return std::any{PanelViewDisabledLayout{}};
}

- (void)setPresentationLayout:(const PanelViewLayout &)_layout
{
    if( auto ll = std::any_cast<PanelListViewColumnsLayout>(&_layout.layout) ) {
        [self setupListPresentationWithLayout:*ll];
    }
    else if( auto bl = std::any_cast<PanelBriefViewColumnsLayout>(&_layout.layout) ) {
        [self setupBriefPresentationWithLayout:*bl];
    }
}

- (void)savePathState
{
    dispatch_assert_main_queue();
    if( !m_Data || !m_Data->Listing().IsUniform() )
        return;

    auto &listing = m_Data->Listing();

    const auto item = self.item;
    if( !item )
        return;

    const auto hash = listing.Host()->FullHashForPath(listing.Directory());
    auto &storage = m_States[hash];
    storage.focused_item = item.Filename();
}

- (void)loadPathState
{
    dispatch_assert_main_queue();
    if( !m_Data || !m_Data->Listing().IsUniform() )
        return;

    const auto &listing = m_Data->Listing();

    const auto hash = listing.Host()->FullHashForPath(listing.Directory());
    const auto it = m_States.find(hash);
    if( it == end(m_States) )
        return;

    const auto &storage = it->second;
    int cursor = m_Data->SortedIndexForName(storage.focused_item);
    if( cursor < 0 )
        return;

    [self setCurpos:cursor];
    [self OnCursorPositionChanged];
}

- (void)panelChangedWithFocusedFilename:(const std::string &)_focused_filename loadPreviousState:(bool)_load
{
    dispatch_assert_main_queue();
    m_CursorPos = -1;

    if( _load )
        [self loadPathState];

    const int cur = m_Data->SortedIndexForName(_focused_filename);
    if( cur >= 0 ) {
        [self setCurpos:cur];
    }

    if( m_CursorPos < 0 && !m_Data->SortedDirectoryEntries().empty() ) {
        [self setCurpos:0];
    }

    [self discardFieldEditor];
    [self setHeaderTitle:self.headerTitleForPanel];
}

- (void)startFieldEditorRenaming
{
    if( m_RenamingEditor != nil ) {
        // if renaming editor is already here - just iterate a selection.
        // (assuming consequent ctrl+f6 hits here)
        [m_RenamingEditor markNextFilenamePart];
        return;
    }

    const int cursor_pos = m_CursorPos;
    if( ![m_ItemsView isItemVisible:cursor_pos] )
        return;

    const auto item = self.item;
    if( !item || item.IsDotDot() || !item.Host()->IsWritable() )
        return;

    m_RenamingEditor = [[NCPanelViewFieldEditor alloc] initWithItem:item];
    __weak PanelView *weak_self = self;
    __weak NSResponder *current_responder = self.window.firstResponder;
    m_RenamingEditor.onTextEntered = ^(const std::string &_new_filename) {
      if( auto sself = weak_self ) {
          if( !sself->m_RenamingEditor )
              return;

          [sself.controller requestQuickRenamingOfItem:sself->m_RenamingEditor.originalItem to:_new_filename];
      }
    };
    m_RenamingEditor.onEditingFinished = ^{
      if( auto sself = weak_self ) {
          [sself.window makeFirstResponder:current_responder];
          [sself->m_RenamingEditor removeFromSuperview];
          sself->m_RenamingEditor = nil;
      }
    };
    m_RenamingEditor.editor.nextKeyView = self;

    [m_ItemsView setupFieldEditor:m_RenamingEditor forItemAtIndex:cursor_pos];
    [self.window makeFirstResponder:m_RenamingEditor];
}

- (void)commitFieldEditor
{
    if( m_RenamingEditor ) {
        [self.window makeFirstResponder:self];
        [m_RenamingEditor removeFromSuperview];
        m_RenamingEditor = nil;
    }
}

- (void)discardFieldEditor
{
    if( m_RenamingEditor ) {
        m_RenamingEditor.onTextEntered = nil;
        [self.window makeFirstResponder:self];
        [m_RenamingEditor removeFromSuperview];
        m_RenamingEditor = nil;
    }
}

// Search the current data for an item which has the same name, the same directory and the same VFS as the queried item
- (int)findSortedIndexOfForeignListingItem:(const VFSListingItem &)_item
{
    if( !_item )
        return -1;

    const auto raw_inds = m_Data->RawIndicesForName(_item.Filename()); // O(logN)
    for( const auto raw_ind : raw_inds ) {
        const auto sort_ind = m_Data->SortedIndexForRawIndex(raw_ind); // O(1)
        if( sort_ind < 0 )
            continue; // skip any items not currently presented due to filtering
        const auto new_item = m_Data->EntryAtRawPosition(raw_ind);
        assert(new_item.Filename() == _item.Filename()); // the filename is assumed to be the same
        if( new_item.Directory() != _item.Directory() )
            continue; // different directory (perhaps a non-uniform listing) - skip this entry
        if( new_item.Host() != _item.Host() )
            continue; // different vfs host (perhaps a non-uniform listing) - skip this entry

        // a match - return the sorted index
        return sort_ind;
    }
    return -1; // no luck - this item wasn't found
}

- (void)dataUpdated
{
    dispatch_assert_main_queue();
    std::optional<int> renaming_item_ind;
    if( m_RenamingEditor ) {
        const auto new_item_ind = [self findSortedIndexOfForeignListingItem:m_RenamingEditor.originalItem];
        if( new_item_ind >= 0 ) {
            renaming_item_ind = new_item_ind;
            [m_RenamingEditor stash];
        }
        else {
            [self discardFieldEditor];
        }
    }

    [m_ItemsView dataChanged];
    [m_ItemsView setCursorPosition:m_CursorPos];

    [self volatileDataChanged];
    [m_FooterView updateListing:m_Data->ListingPtr()];

    if( m_RenamingEditor ) {
        assert(renaming_item_ind);
        [m_ItemsView setupFieldEditor:m_RenamingEditor forItemAtIndex:*renaming_item_ind];
        [self.window makeFirstResponder:m_RenamingEditor];
        [m_RenamingEditor unstash];
    }
}

- (void)volatileDataChanged
{
    [m_ItemsView syncVolatileData];
    [m_FooterView updateFocusedItem:self.item VD:self.item_vd];
    [m_FooterView updateStatistics:m_Data->Stats()];
}

- (int)sortedItemPosAtPoint:(NSPoint)_window_point hitTestOption:(PanelViewHitTest::Options)_options
{
    dispatch_assert_main_queue();
    auto pos = [m_ItemsView sortedItemPosAtPoint:_window_point hitTestOption:_options];
    return pos;
}

- (void)windowStatusDidChange
{
    [self refreshActiveStatus];
}

- (void)setHeaderTitle:(NSString *)headerTitle
{
    dispatch_assert_main_queue();
    if( m_HeaderTitle != headerTitle ) {
        m_HeaderTitle = headerTitle;
        [m_HeaderView setPath:m_HeaderTitle];
    }
}

- (NSString *)headerTitle
{
    return m_HeaderTitle;
}

- (NSString *)headerTitleForPanel
{
    auto title = [&] {
        switch( m_Data->Type() ) {
            case data::Model::PanelType::Directory:
                return [NSString stringWithUTF8StdString:m_Data->VerboseDirectoryFullPath()];
            case data::Model::PanelType::Temporary: {
                auto &listing = m_Data->Listing();
                if( listing.Title().empty() )
                    return NSLocalizedString(@"__PANELVIEW_TEMPORARY_PANEL_WITHOUT_TITLE", "");
                else {
                    auto fmt = NSLocalizedString(@"__PANELVIEW_TEMPORARY_PANEL_WITH_TITLE", "");
                    return [NSString localizedStringWithFormat:fmt, [NSString stringWithUTF8StdString:listing.Title()]];
                }
            }
            default:
                return @"";
        }
    }();
    return title ? title : @"";
}

- (void)panelItem:(int)_sorted_index mouseDown:(NSEvent *)_event
{
    nc::panel::Log::Trace("[PanelController panelItem:mouseDown:] called for sorted index '{}'", _sorted_index);

    if( !self.window.isKeyWindow ) {
        // any cursor movements or selection changes should be performed only in active window
        return;
    }

    if( !self.active )
        [self.window makeFirstResponder:self];

    if( !m_Data->IsValidSortPosition(_sorted_index) ) {
        [self commitFieldEditor];
        return;
    }

    const int current_cursor_pos = m_CursorPos;
    const auto click_entry_vd = m_Data->VolatileDataAtSortPosition(_sorted_index);
    const auto modifier_flags = _event.modifierFlags & NSEventModifierFlagDeviceIndependentFlagsMask;

    // Select range of items with shift+click.
    // If clicked item is selected, then deselect the range instead.
    if( modifier_flags & NSEventModifierFlagShift )
        [self SelectUnselectInRange:current_cursor_pos >= 0 ? current_cursor_pos : 0
                      last_included:_sorted_index
                             select:!click_entry_vd.is_selected()];
    else if( modifier_flags & NSEventModifierFlagCommand ) // Select or deselect a single item with cmd+click.
        [self SelectUnselectInRange:_sorted_index last_included:_sorted_index select:!click_entry_vd.is_selected()];

    [self setCurpos:_sorted_index];
}

- (void)panelItem:(int)_sorted_index fieldEditor:(NSEvent *) [[maybe_unused]] _event
{
    if( _sorted_index >= 0 && _sorted_index == m_CursorPos )
        [self startFieldEditorRenaming];
}

- (void)panelItem:(int)_sorted_index dblClick:(NSEvent *) [[maybe_unused]] _event
{
    nc::panel::Log::Trace("[PanelController panelItem:dblClick:] called for sorted index '{}'", _sorted_index);
    if( _sorted_index >= 0 && _sorted_index == m_CursorPos ) {
        if( auto action_dispatcher = self.actionsDispatcher )
            [action_dispatcher OnOpen:self];
    }
}

- (void)panelItem:(int)_sorted_index mouseDragged:(NSEvent *)_event
{
    auto icon_producer = DragSender::IconCallback{[self](const VFSListingItem &_item) -> NSImage * {
        assert(m_Data->ListingPtr() == _item.Listing());
        const auto vd = m_Data->VolatileDataAtRawPosition(_item.Index());
        if( m_IconRepository->IsValidSlot(vd.icon) )
            return m_IconRepository->AvailableIconForSlot(vd.icon);
        else
            return m_IconRepository->AvailableIconForListingItem(_item);
    }};

    DragSender sender{self.controller, std::move(icon_producer), *m_NativeHost};
    sender.Start(self, _event, _sorted_index);
}

- (void)dataSortingHasChanged
{
    m_HeaderView.sortMode = m_Data->SortMode();
    m_ItemsView.sortMode = m_Data->SortMode();
}

- (PanelController *)controller
{
    return nc::objc_cast<PanelController>(m_Delegate);
}

- (int)headerBarHeight
{
    return 20;
}

+ (NSArray *)acceptedDragAndDropTypes
{
    return DragReceiver::AcceptedUTIs();
}

- (NSDragOperation)panelItem:(int)_sorted_index operationForDragging:(id<NSDraggingInfo>)_dragging
{
    auto receiver = [self.delegate panelView:self requestsDragReceiverForDragging:_dragging onItem:_sorted_index];
    return receiver->Validate();
}

- (bool)panelItem:(int)_sorted_index performDragOperation:(id<NSDraggingInfo>)_dragging
{
    auto receiver = [self.delegate panelView:self requestsDragReceiverForDragging:_dragging onItem:_sorted_index];
    return receiver->Receive();
}

- (NSPopover *)showPopoverUnderPathBarWithView:(NSViewController *)_view andDelegate:(id<NSPopoverDelegate>)_delegate
{
    const auto bounds = self.bounds;
    NSPopover *popover = [NSPopover new];
    popover.contentViewController = _view;
    popover.behavior = NSPopoverBehaviorTransient;
    popover.delegate = _delegate;
    [popover showRelativeToRect:NSMakeRect(
                                    0, bounds.size.height - self.headerBarHeight, bounds.size.width, bounds.size.height)
                         ofView:self
                  preferredEdge:NSMinYEdge];
    return popover;
}

- (NSProgressIndicator *)busyIndicator
{
    return m_HeaderView.busyIndicator;
}

- (void)notifyAboutPresentationLayoutChange
{
    [self.controller panelViewDidChangePresentationLayout];
}

- (void)addKeystrokeSink:(id<NCPanelViewKeystrokeSink>)_sink
{
    m_KeystrokeSinks.emplace_back(_sink);
}

- (void)removeKeystrokeSink:(id<NCPanelViewKeystrokeSink>)_sink
{
    std::erase(m_KeystrokeSinks, _sink);
}

- (std::optional<NSRect>)frameOfItemAtSortPos:(int)_sorted_position
{
    const std::optional<NSRect> frame = [m_ItemsView frameOfItemAtIndex:_sorted_position];
    if( !frame )
        return {};
    return [self convertRect:*frame fromView:m_ItemsView];
}

@end

#include <NimbleCommander/Bootstrap/AppDelegate.h>
#include <NimbleCommander/Core/ActionsShortcutsManager.h>
#include <Utility/NSEventModifierFlagsHolder.h>
#include "PanelViewLayoutSupport.h"
#include "PanelView.h"
#include "PanelController.h"
#include "Brief/PanelBriefView.h"
#include "List/PanelListView.h"
#include "PanelViewHeader.h"
#include "PanelViewFooter.h"
#include "IconsGenerator2.h"

enum class CursorSelectionType : int8_t
{
    No          = 0,
    Selection   = 1,
    Unselection = 2
};

struct PanelViewStateStorage
{
    string focused_item;
};

static size_t HashForPath( const VFSHostPtr &_at_vfs, const string &_path )
{
    string full;
    auto c = _at_vfs;
    while( c ) {
        // we need to incorporate options somehow here. or not?
        string part = string(c->Tag) + string(c->JunctionPath()) + "|";
        full.insert(0, part);
        c = c->Parent();
    }
    full += _path;
    return hash<string>()(full);
}

////////////////////////////////////////////////////////////////////////////////

@interface PanelView()

@property (nonatomic, readonly) PanelController *controller;

@end

@implementation PanelView
{
    PanelData                  *m_Data;
    
    unordered_map<size_t, PanelViewStateStorage> m_States; // TODO: change no something simplier
    NSString                   *m_HeaderTitle;
    NSScrollView               *m_RenamingEditor; // NSTextView inside
    string                      m_RenamingOriginalName;

    __weak id<PanelViewDelegate> m_Delegate;
    NSView<PanelViewImplementationProtocol> *m_ItemsView;
    PanelViewHeader            *m_HeaderView;
    PanelViewFooter            *m_FooterView;
    
    IconsGenerator2             m_IconsGenerator;
    
    int                         m_CursorPos;
    NSEventModifierFlagsHolder  m_KeyboardModifierFlags;
    CursorSelectionType         m_KeyboardCursorSelectionType;
}

- (id)initWithFrame:(NSRect)frame layout:(const PanelViewLayout&)_layout
{
    self = [super initWithFrame:frame];
    if (self) {
        m_Data = nullptr;
        m_CursorPos = -1;
        m_HeaderTitle = @"";

        m_ItemsView = [self spawnItemViewWithLayout:_layout];
        [self addSubview:m_ItemsView];
        
        m_HeaderView = [[PanelViewHeader alloc] initWithFrame:frame];
        m_HeaderView.translatesAutoresizingMaskIntoConstraints = false;
        __weak PanelView *weak_self = self;
        m_HeaderView.sortModeChangeCallback = [weak_self](PanelDataSortMode _sm){
            if( PanelView *strong_self = weak_self )
                [strong_self.controller changeSortingModeTo:_sm];
        };
        [self addSubview:m_HeaderView];
        
        m_FooterView = [[PanelViewFooter alloc] initWithFrame:NSRect()];
        m_FooterView.translatesAutoresizingMaskIntoConstraints = false;
        [self addSubview:m_FooterView];
        
        NSDictionary *views = NSDictionaryOfVariableBindings(m_ItemsView, m_HeaderView, m_FooterView);
//        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(==0)-[m_ItemsView]-(==0)-|" options:0 metrics:nil views:views]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(==0)-[m_HeaderView(==20)]-(==0)-[m_ItemsView]-(==0)-[m_FooterView(==20)]-(==0)-|" options:0 metrics:nil views:views]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(0)-[m_HeaderView]-(0)-|" options:0 metrics:nil views:views]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(0)-[m_ItemsView]-(0)-|" options:0 metrics:nil views:views]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(0)-[m_FooterView]-(0)-|" options:0 metrics:nil views:views]];
    }
    
    return self;
}

- (id)initWithFrame:(NSRect)frame
{
    assert( !"don't call [PanelView initWithFrame:(NSRect)frame]" );
    return nil;
}

- (NSView<PanelViewImplementationProtocol>*) spawnItemViewWithLayout:(const PanelViewLayout&)_layout
{
    if( auto ll = any_cast<PanelListViewColumnsLayout>(&_layout.layout) ) {
        auto v = [self spawnListView];
        v.columnsLayout = *ll;
        return v;
    }
    else if( auto bl = any_cast<PanelBriefViewColumnsLayout>(&_layout.layout) ) {
        auto v = [self spawnBriefView];
        v.columnsLayout = *bl;
        return v;
    }
    return nil;
}

-(void) dealloc
{
    m_Data = nullptr;
}

- (void) setDelegate:(id<PanelViewDelegate>)delegate
{
    m_Delegate = delegate;
    if( auto r = objc_cast<NSResponder>(delegate) ) {
        NSResponder *current = self.nextResponder;
        super.nextResponder = r;
        r.nextResponder = current;
    }
}

- (id<PanelViewDelegate>) delegate
{
    return m_Delegate;
}

- (PanelListView*) spawnListView
{
   PanelListView *v = [[PanelListView alloc] initWithFrame:self.bounds andIC:m_IconsGenerator];
    v.translatesAutoresizingMaskIntoConstraints = false;
    __weak PanelView *weak_self = self;
    v.sortModeChangeCallback = [=](PanelDataSortMode _sm){
        if( PanelView *strong_self = weak_self )
            [strong_self.controller changeSortingModeTo:_sm];
    };
    return v;
}

- (PanelBriefView*) spawnBriefView
{
    auto v = [[PanelBriefView alloc] initWithFrame:self.bounds andIC:m_IconsGenerator];
    v.translatesAutoresizingMaskIntoConstraints = false;
    return v;
}

- (BOOL) isOpaque
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
    [self willChangeValueForKey:@"active"];
    [self didChangeValueForKey:@"active"];
    return true;
}

- (BOOL)resignFirstResponder
{
    __weak PanelView* weak_self = self;
    dispatch_to_main_queue([=]{
        if( PanelView* strong_self = weak_self ) {
            [strong_self willChangeValueForKey:@"active"];
            [strong_self didChangeValueForKey:@"active"];
        }
    });
    return YES;
}

- (void)setNextResponder:(NSResponder *)newNextResponder
{
    if( auto r = objc_cast<NSResponder>(self.delegate) ) {
        r.nextResponder = newNextResponder;
        return;
    }
    
    [super setNextResponder:newNextResponder];
}

- (void)viewWillMoveToWindow:(NSWindow *)_wnd
{
    if( self.window ) {
        [NSNotificationCenter.defaultCenter removeObserver:self
                                                      name:NSWindowDidBecomeKeyNotification
                                                    object:nil];
        [NSNotificationCenter.defaultCenter removeObserver:self
                                                      name:NSWindowDidResignKeyNotification
                                                    object:nil];
        [NSNotificationCenter.defaultCenter removeObserver:self
                                                      name:NSWindowDidBecomeMainNotification
                                                    object:nil];
        [NSNotificationCenter.defaultCenter removeObserver:self
                                                      name:NSWindowDidResignMainNotification
                                                    object:nil];
    }
    
    if( _wnd ) {
        m_IconsGenerator.SetHiDPI( _wnd.backingScaleFactor > 1.0 );
    
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(windowStatusDidChange)
                                                   name:NSWindowDidBecomeKeyNotification
                                                 object:_wnd];
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(windowStatusDidChange)
                                                   name:NSWindowDidResignKeyNotification
                                                 object:_wnd];
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(windowStatusDidChange)
                                                   name:NSWindowDidBecomeMainNotification
                                                 object:_wnd];
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(windowStatusDidChange)
                                                   name:NSWindowDidResignMainNotification
                                                 object:_wnd];
    }
}

- (bool) active
{
    if( auto w = self.window )
        if( w.isKeyWindow || w.isMainWindow )
            if( id fr = w.firstResponder )
                return fr == self || [objc_cast<NSView>(fr) isDescendantOf:self];
    return false;
}

- (PanelData*) data
{
    return m_Data;
}

- (void) setData:(PanelData *)data
{
//    self.needsDisplay = true;
    m_Data = data;
    
//    if( data )

    if( data ) {
        [m_ItemsView setData:data];
        m_ItemsView.sortMode = data->SortMode();
        m_HeaderView.sortMode = data->SortMode();
    }
    
    if( !data ) {
        // we're in destruction phase
        
        // !!! this might be dangerous!
        
        [m_ItemsView removeFromSuperview];
        m_ItemsView = nil;
        
        [m_HeaderView removeFromSuperview];
        m_HeaderView = nil;
        
        [m_FooterView removeFromSuperview];
        m_FooterView = nil;
 
//        self.presentation = nullptr;
    }
}

- (void) HandlePrevFile
{
    dispatch_assert_main_queue();
    
    int origpos = m_CursorPos;
    
//    m_Presentation->MoveCursorToPrevItem();
//    if(m_State->Data->SortedDirectoryEntries().empty()) return;
//
    if( m_CursorPos < 0 )
        return;
    
    [self performKeyboardSelection:origpos last_included:origpos];

    if( m_CursorPos == 0 )
        return;
    
    
    m_CursorPos--;
//    EnsureCursorIsVisible();
    
    
//    if(m_CursorSelectionType != CursorSelectionType::No)
    
    
    [self OnCursorPositionChanged];
}

- (void) HandleNextFile
{
    dispatch_assert_main_queue();
    
    int origpos = m_CursorPos;
//    m_Presentation->MoveCursorToNextItem();
    
//    if(m_State->Data->SortedDirectoryEntries().empty()) return;
//
    [self performKeyboardSelection:origpos last_included:origpos];
    if( m_CursorPos + 1 >= m_Data->SortedDirectoryEntries().size() )
        return;

    m_CursorPos++;
    
    
    [self OnCursorPositionChanged];
}

- (void) HandlePrevPage
{
    dispatch_assert_main_queue();
    
    const auto orig_pos = m_CursorPos;

    
    const auto total_items = (int)m_Data->SortedDirectoryEntries().size();
    if( !total_items )
        return;
    
    const auto items_per_screen = m_ItemsView.maxNumberOfVisibleItems;
    const auto new_pos = max( orig_pos - items_per_screen, 0 );
    
    if( new_pos == orig_pos )
        return;
    
    m_CursorPos = new_pos;
    
    [self performKeyboardSelection:orig_pos last_included:m_CursorPos];
    [self OnCursorPositionChanged];
    
}

- (void) HandleNextPage
{
    dispatch_assert_main_queue();
    
    const auto total_items = (int)m_Data->SortedDirectoryEntries().size();
    if( !total_items )
        return;
    const auto orig_pos = m_CursorPos;
    const auto items_per_screen = m_ItemsView.maxNumberOfVisibleItems;
    const auto new_pos = min( orig_pos + items_per_screen, total_items - 1 );
    
    if( new_pos == orig_pos )
        return;
    
    m_CursorPos = new_pos;
    
    [self performKeyboardSelection:orig_pos last_included:m_CursorPos];
    [self OnCursorPositionChanged];
}

- (void) HandlePrevColumn
{
    dispatch_assert_main_queue();
    
    const auto orig_pos = m_CursorPos;
    
    if( m_Data->SortedDirectoryEntries().empty() ) return;
    const auto items_per_column = m_ItemsView.itemsInColumn;
    const auto new_pos = max( orig_pos - items_per_column, 0 );
    
    if( new_pos == orig_pos )
        return;

    m_CursorPos = new_pos;
    
    [self performKeyboardSelection:orig_pos last_included:m_CursorPos];
    [self OnCursorPositionChanged];
}

- (void) HandleNextColumn
{
    dispatch_assert_main_queue();
    
    const auto orig_pos = m_CursorPos;
//    m_Presentation->MoveCursorToNextColumn();
    
    if( m_Data->SortedDirectoryEntries().empty() ) return;
    const auto total_items = (int)m_Data->SortedDirectoryEntries().size();
    const auto items_per_column = m_ItemsView.itemsInColumn;
    const auto new_pos = min( orig_pos + items_per_column, total_items - 1 );
    
    if( new_pos == orig_pos )
        return;
    
    m_CursorPos = new_pos;

    [self performKeyboardSelection:orig_pos last_included:m_CursorPos];
    [self OnCursorPositionChanged];
}

- (void) HandleFirstFile;
{
    dispatch_assert_main_queue();
    
    const auto origpos = m_CursorPos;
    
    if( m_Data->SortedDirectoryEntries().empty() ||
        m_CursorPos == 0 )
        return;
    
    m_CursorPos = 0;
    
//    m_Presentation->MoveCursorToFirstItem();

    [self performKeyboardSelection:origpos last_included:m_CursorPos];
    [self OnCursorPositionChanged];
}

- (void) HandleLastFile;
{
    dispatch_assert_main_queue();
    
    const auto origpos = m_CursorPos;
    
    if( m_Data->SortedDirectoryEntries().empty() ||
        m_CursorPos == m_Data->SortedDirectoryEntries().size() - 1 )
        return;
    
    m_CursorPos = (int)m_Data->SortedDirectoryEntries().size() - 1;
    
//    m_Presentation->MoveCursorToLastItem();

    [self performKeyboardSelection:origpos last_included: m_CursorPos];
    [self OnCursorPositionChanged];
}

- (void) onInvertCurrentItemSelectionAndMoveNext
{
    dispatch_assert_main_queue();
    
    const auto origpos = m_CursorPos;
    
    if(auto entry = m_Data->EntryAtSortPosition(origpos))
        [self SelectUnselectInRange:origpos
                      last_included:origpos
                             select:!m_Data->VolatileDataAtSortPosition(origpos).is_selected()];

    if( m_CursorPos + 1 < m_Data->SortedDirectoryEntries().size() ) {
        m_CursorPos++;
        [self OnCursorPositionChanged];
    }
    
}

- (void) onInvertCurrentItemSelection
{
    dispatch_assert_main_queue();
    
    int pos = m_CursorPos;
    if( auto entry = m_Data->EntryAtSortPosition(pos) )
        [self SelectUnselectInRange:pos
                      last_included:pos
                             select:!m_Data->VolatileDataAtSortPosition(pos).is_selected()];
}

- (void) setCurpos:(int)_pos
{
    dispatch_assert_main_queue();
    
    const auto clipped_pos = (m_Data->SortedDirectoryEntries().size() > 0 &&
                         _pos >= 0 &&
                         _pos < m_Data->SortedDirectoryEntries().size() ) ?
                        _pos : -1;
    
    if (m_CursorPos == clipped_pos)
        return;
    
    m_CursorPos = clipped_pos;
    
    [self OnCursorPositionChanged];
}

- (int) curpos
{
    dispatch_assert_main_queue();
    return m_CursorPos;
}

- (void) OnCursorPositionChanged
{
    dispatch_assert_main_queue();
    [m_ItemsView setCursorPosition:m_CursorPos];
    [m_FooterView updateFocusedItem:self.item VD:self.item_vd];
    
    if(id<PanelViewDelegate> del = self.delegate)
        if([del respondsToSelector:@selector(PanelViewCursorChanged:)])
            [del PanelViewCursorChanged:self];
    
//    m_LastPotentialRenamingLBDown = -1;
    [self commitFieldEditor];
}

- (void)keyDown:(NSEvent *)event
{
    if(id<PanelViewDelegate> del = self.delegate)
        if([del respondsToSelector:@selector(PanelViewProcessKeyDown:event:)])
            if([del PanelViewProcessKeyDown:self event:event])
                return;
    
    NSString* character = [event charactersIgnoringModifiers];
    if ( character.length != 1 ) {
        [super keyDown:event];
        return;
    }
    
    const auto modifiers    = event.modifierFlags;
    const auto unicode      = [character characterAtIndex:0];
    const auto keycode      = event.keyCode;
    
    [self checkKeyboardModifierFlags:modifiers];
    
    static ActionsShortcutsManager::ShortCut hk_up, hk_down, hk_left, hk_right, hk_first, hk_last,
    hk_pgdown, hk_pgup, hk_inv_and_move, hk_inv, hk_scrdown, hk_scrup, hk_scrhome, hk_scrend;
    static ActionsShortcutsManager::ShortCutsUpdater hotkeys_updater(
       {&hk_up, &hk_down, &hk_left, &hk_right, &hk_first, &hk_last, &hk_pgdown, &hk_pgup,
           &hk_inv_and_move, &hk_inv, &hk_scrdown, &hk_scrup, &hk_scrhome, &hk_scrend},
       {"panel.move_up", "panel.move_down", "panel.move_left", "panel.move_right", "panel.move_first",
           "panel.move_last", "panel.move_next_page", "panel.move_prev_page",
           "panel.move_next_and_invert_selection", "panel.invert_item_selection",
           "panel.scroll_next_page", "panel.scroll_prev_page", "panel.scroll_first", "panel.scroll_last"
       }
      );

    if( hk_up.IsKeyDown(unicode, keycode, modifiers & ~NSShiftKeyMask) )
        [self HandlePrevFile];
    else if( hk_down.IsKeyDown(unicode, keycode, modifiers & ~NSShiftKeyMask) )
        [self HandleNextFile];
    else if( hk_left.IsKeyDown(unicode, keycode, modifiers & ~NSShiftKeyMask) )
        [self HandlePrevColumn];
    else if( hk_right.IsKeyDown(unicode, keycode, modifiers & ~NSShiftKeyMask) )
        [self HandleNextColumn];
    else if( hk_first.IsKeyDown(unicode, keycode, modifiers & ~NSShiftKeyMask) )
        [self HandleFirstFile];
    else if( hk_last.IsKeyDown(unicode, keycode, modifiers & ~NSShiftKeyMask) )
        [self HandleLastFile];
    else if( hk_pgdown.IsKeyDown(unicode, keycode, modifiers & ~NSShiftKeyMask) )
        [self HandleNextPage];
    else if( hk_scrdown.IsKeyDown(unicode, keycode, modifiers) )
        [m_ItemsView onPageDown:event];
    else if( hk_pgup.IsKeyDown(unicode, keycode, modifiers & ~NSShiftKeyMask) )
        [self HandlePrevPage];
    else if( hk_scrup.IsKeyDown(unicode, keycode, modifiers) )
        [m_ItemsView onPageUp:event];
    else if( hk_scrhome.IsKeyDown(unicode, keycode, modifiers) )
        [m_ItemsView onScrollToBeginning:event];
    else if( hk_scrend.IsKeyDown(unicode, keycode, modifiers) )
        [m_ItemsView onScrollToEnd:event];
    else if( hk_inv_and_move.IsKeyDown(unicode, keycode, modifiers) )
        [self onInvertCurrentItemSelectionAndMoveNext];
    else if( hk_inv.IsKeyDown(unicode, keycode, modifiers) )
        [self onInvertCurrentItemSelection];
    else
        [super keyDown:event];
}

- (void) checkKeyboardModifierFlags:(unsigned long)_current_flags
{
    if( _current_flags == m_KeyboardModifierFlags )
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
                m_KeyboardCursorSelectionType = self.item_vd.is_selected() ? CursorSelectionType::Unselection : CursorSelectionType::Selection;
            }
            else {
                // need to look at a first file (next to dotdot) for current representation if any.
                if( auto next_item = m_Data->EntryAtSortPosition(1) )
                    m_KeyboardCursorSelectionType = m_Data->VolatileDataAtSortPosition(1).is_selected() ? CursorSelectionType::Unselection : CursorSelectionType::Selection;
                else // singular case - selection doesn't matter - nothing to select
                    m_KeyboardCursorSelectionType = CursorSelectionType::Selection;
            }
        }
    }
}

/*- (void)modifierFlagsChanged:(unsigned long)_flags
{
    [self checkKeyboardModifierFlags:_flags];
}*/

- (void)flagsChanged:(NSEvent *)event
{
    [self checkKeyboardModifierFlags:event.modifierFlags];
    [super flagsChanged:event];
}

- (NSMenu *)panelItem:(int)_sorted_index menuForForEvent:(NSEvent*)_event
{
    if( _sorted_index >= 0 )
        return [self.delegate panelView:self requestsContextMenuForItemNo:_sorted_index];    
    return nil;
}

- (VFSListingItem)item
{
    return m_Data->EntryAtSortPosition(m_CursorPos);
}

- (const PanelData::VolatileData &)item_vd
{
    assert( dispatch_is_main_queue() );
    static const PanelData::VolatileData stub{};
    int indx = m_Data->RawIndexForSortIndex( m_CursorPos );
    if( indx < 0 )
        return stub;
    return m_Data->VolatileDataAtRawPosition(indx);
}

- (void) SelectUnselectInRange:(int)_start last_included:(int)_end select:(BOOL)_select
{
    assert( dispatch_is_main_queue() );
    if(_start < 0 || _start >= m_Data->SortedDirectoryEntries().size() ||
         _end < 0 || _end >= m_Data->SortedDirectoryEntries().size() ) {
        NSLog(@"SelectUnselectInRange - invalid range");
        return;
    }
    
    if(_start > _end)
        swap(_start, _end);
    
    // we never want to select a first (dotdot) entry
    if( auto i = m_Data->EntryAtSortPosition(_start) )
        if( i.IsDotDot() )
            ++_start; // we don't want to select or unselect a dotdot entry - they are higher than that stuff
    
    for(int i = _start; i <= _end; ++i)
        m_Data->CustomFlagsSelectSorted(i, _select);
    
//    [m_ItemsView syncVolatileData];
    [self volatileDataChanged];
}

- (void)performKeyboardSelection:(int)_start last_included:(int)_end
{
    assert( dispatch_is_main_queue() );
    if( m_KeyboardCursorSelectionType == CursorSelectionType::No )
        return;
    [self SelectUnselectInRange:_start
                  last_included:_end
                         select:m_KeyboardCursorSelectionType == CursorSelectionType::Selection];
}

- (void) setupBriefPresentationWithLayout:(PanelBriefViewColumnsLayout)_layout
{
    const auto init = !objc_cast<PanelBriefView>(m_ItemsView);
    if( init ) {
        auto v = [self spawnBriefView];
        //v.translatesAutoresizingMaskIntoConstraints = false;
        //    [self addSubview:m_ItemsView];
        
        [self replaceSubview:m_ItemsView with:v];
        m_ItemsView = v;
        
        NSDictionary *views = NSDictionaryOfVariableBindings(m_ItemsView, m_HeaderView, m_FooterView);
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[m_HeaderView]-(==0)-[m_ItemsView]-(==0)-[m_FooterView]" options:0 metrics:nil views:views]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(0)-[m_ItemsView]-(0)-|" options:0 metrics:nil views:views]];
        [self layout];
        
        if( m_Data ) {
            m_ItemsView.data = m_Data;
            m_ItemsView.sortMode = m_Data->SortMode();
        }
        
        if( m_CursorPos >= 0 )
            [m_ItemsView setCursorPosition:m_CursorPos];
    }

    if( auto v = objc_cast<PanelBriefView>(m_ItemsView) ) {
        [v setColumnsLayout:_layout];
    }
}

- (void) setupListPresentationWithLayout:(PanelListViewColumnsLayout)_layout
{
    const auto init = !objc_cast<PanelListView>(m_ItemsView);
    
    if( init ) {
        auto v = [self spawnListView];
        //v.translatesAutoresizingMaskIntoConstraints = false;
        
        [self replaceSubview:m_ItemsView with:v];
        m_ItemsView = v;
        
//        NSDictionary *views = NSDictionaryOfVariableBindings(m_ItemsView, m_HeaderView, m_FooterView);
        //        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(==0)-[m_ItemsView]-(==0)-|" options:0 metrics:nil views:views]];
//        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(==0)-[m_HeaderView(==20)]-(==0)-[m_ItemsView]-(==0)-[m_FooterView(==20)]-(==0)-|" options:0 metrics:nil views:views]];
        
        
        NSDictionary *views = NSDictionaryOfVariableBindings(m_ItemsView, m_HeaderView, m_FooterView);
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[m_HeaderView]-(==0)-[m_ItemsView]-(==0)-[m_FooterView]" options:0 metrics:nil views:views]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(0)-[m_ItemsView]-(0)-|" options:0 metrics:nil views:views]];
        [self layout];
        
        if( m_Data ) {
            m_ItemsView.data = m_Data;
            m_ItemsView.sortMode = m_Data->SortMode();
        }
        
        if( m_CursorPos >= 0 )
            [m_ItemsView setCursorPosition:m_CursorPos];
    }
    
    if( auto v = objc_cast<PanelListView>(m_ItemsView) ) {
        [v setColumnsLayout:_layout];
    }
}


- (void) setLayout:(const PanelViewLayout&)_layout
{
    if( auto ll = any_cast<PanelListViewColumnsLayout>(&_layout.layout) ) {
        [self setupListPresentationWithLayout:*ll];
    }
    else if( auto bl = any_cast<PanelBriefViewColumnsLayout>(&_layout.layout) ) {
        [self setupBriefPresentationWithLayout:*bl];
        
    }
}

- (void) SavePathState
{
    assert( dispatch_is_main_queue() );
    if(!m_Data || !m_Data->Listing().IsUniform())
        return;
    
    auto &listing = m_Data->Listing();
    
    auto item = self.item;
    if( !item )
        return;
    
    auto &storage = m_States[ HashForPath(listing.Host(), listing.Directory()) ];
    
    storage.focused_item = item.Name();
}

- (void) LoadPathState
{
    assert( dispatch_is_main_queue() );
    if( !m_Data || !m_Data->Listing().IsUniform() )
        return;
    
    auto &listing = m_Data->Listing();
    
    auto it = m_States.find(HashForPath(listing.Host(), listing.Directory()));
    if(it == end(m_States))
        return;
    
    auto &storage = it->second;
    int cursor = m_Data->SortedIndexForName(storage.focused_item.c_str());
    if( cursor < 0 )
        return;
    
    [self setCurpos:cursor];
    [self OnCursorPositionChanged];
}

- (void)panelChangedWithFocusedFilename:(const string&)_focused_filename loadPreviousState:(bool)_load
{
    assert( dispatch_is_main_queue() );
//    m_State.ItemsDisplayOffset = 0;
    m_CursorPos = -1;
    
    if( _load )
        [self LoadPathState];
    
    const int cur = m_Data->SortedIndexForName(_focused_filename.c_str());
    if( cur >= 0 ) {
        //m_Presentation->SetCursorPos(cur);
        [self setCurpos:cur];
//        [self OnCursorPositionChanged];
    }
    
    if( m_CursorPos < 0 &&
        m_Data->SortedDirectoryEntries().size() > 0) {
//        m_Presentation->SetCursorPos(0);
        [self setCurpos:0];
//        [self OnCursorPositionChanged];
    }
    
    [self discardFieldEditor];
    [self setHeaderTitle:self.headerTitleForPanel];
//    m_Presentation->OnDirectoryChanged();
}

static NSRange NextFilenameSelectionRange( NSString *_string, NSRange _current_selection )
{
    static auto dot = [NSCharacterSet characterSetWithCharactersInString:@"."];

    // disassemble filename into parts
    const auto length = _string.length;
    const NSRange whole = NSMakeRange(0, length);
    NSRange name;
    optional<NSRange> extension;
    
    const NSRange r = [_string rangeOfCharacterFromSet:dot options:NSBackwardsSearch];
    if( r.location > 0 && r.location < length - 1) { // has extension
        name = NSMakeRange(0, r.location);
        extension = NSMakeRange(r.location + 1, length - r.location - 1);
    }
    else { // no extension
        name = whole;
    }

    if( _current_selection.length == 0 ) // no selection currently - return name
        return name;
    else {
        if( NSEqualRanges(_current_selection, name) ) // current selection is name only
            return extension ? *extension : whole;
        else if( NSEqualRanges(_current_selection, whole) ) // current selection is all filename
            return name;
        else
            return whole;
    }
}

- (void)startFieldEditorRenaming
{
    if( m_RenamingEditor != nil ) {
        // if renaming editor is already here - iterate selection. (assuming consequent ctrl+f6 hits here
        if( auto tv = objc_cast<NSTextView>(m_RenamingEditor.documentView) )
            tv.selectedRange = NextFilenameSelectionRange( tv.string, tv.selectedRange );
        return;
    }
    
    const int cursor_pos = m_CursorPos;
    if( ![m_ItemsView isItemVisible:cursor_pos] )
        return;

    const auto item = self.item;
    if( !item || item.IsDotDot() || !item.Host()->IsWritable() )
        return;
    
    m_RenamingEditor = [NSScrollView new];
    m_RenamingEditor.borderType = NSNoBorder;
    m_RenamingEditor.hasVerticalScroller = false;
    m_RenamingEditor.hasHorizontalScroller = false;
    m_RenamingEditor.autoresizingMask = NSViewNotSizable;
    m_RenamingEditor.verticalScrollElasticity = NSScrollElasticityNone;
    m_RenamingEditor.horizontalScrollElasticity = NSScrollElasticityNone;

    NSTextView *tv = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
    tv.delegate = self;
    tv.fieldEditor = true;
    tv.string = item.NSName();
    tv.selectedRange = NextFilenameSelectionRange( tv.string, tv.selectedRange );
    tv.maxSize = NSMakeSize(FLT_MAX, FLT_MAX);
    tv.verticallyResizable = tv.horizontallyResizable = true;
    tv.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    tv.richText = false;
    tv.importsGraphics = false;
    tv.allowsImageEditing = false;
    tv.automaticQuoteSubstitutionEnabled = false;
    tv.automaticLinkDetectionEnabled = false;
    tv.continuousSpellCheckingEnabled = false;
    tv.grammarCheckingEnabled = false;
    tv.insertionPointColor = NSColor.blackColor;
    tv.backgroundColor = NSColor.whiteColor;
    tv.textColor = NSColor.blackColor;
    
    static const auto ps = []()-> NSParagraphStyle* {
        NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
        style.lineBreakMode = NSLineBreakByClipping;
        return style;
    }();
    tv.defaultParagraphStyle = ps;
    tv.textContainer.widthTracksTextView = tv.textContainer.heightTracksTextView = false;
    tv.textContainer.containerSize = CGSizeMake(FLT_MAX, FLT_MAX);
    
    m_RenamingEditor.documentView = tv;
    [m_ItemsView setupFieldEditor:m_RenamingEditor forItemAtIndex:cursor_pos];
    
    [self.window makeFirstResponder:m_RenamingEditor];
    
    m_RenamingOriginalName = item.Name();
}

- (void)commitFieldEditor
{
    if(m_RenamingEditor) {
        [self.window makeFirstResponder:self]; // will implicitly call textShouldEndEditing:
        [m_RenamingEditor removeFromSuperview];
        m_RenamingEditor = nil;
    }
    m_RenamingOriginalName = "";
}

- (void)discardFieldEditor
{
    m_RenamingOriginalName = "";
    if(m_RenamingEditor) {
        [self.window makeFirstResponder:self];
        [m_RenamingEditor removeFromSuperview];
        m_RenamingEditor = nil;
    }
}

- (BOOL)textShouldEndEditing:(NSText *)textObject
{
    if(!m_RenamingEditor)
        return true;
    
    if(!self.item || m_RenamingOriginalName != self.item.Name())
        return true;
    
    NSTextView *tv = m_RenamingEditor.documentView;
    [self.delegate PanelViewRenamingFieldEditorFinished:self text:tv.string];
    return true;
}

- (void)textDidEndEditing:(NSNotification *)notification
{
    [m_RenamingEditor removeFromSuperview];
    m_RenamingEditor = nil;
    m_RenamingOriginalName = "";
    
    if( self.window.firstResponder == nil || self.window.firstResponder == self.window )
        dispatch_to_main_queue([=]{
            [self.window makeFirstResponder:self];
        });
}

- (NSArray *)textView:(NSTextView *)textView
          completions:(NSArray *)words
  forPartialWordRange:(NSRange)charRange
  indexOfSelectedItem:(NSInteger *)index
{
    return @[];
}

- (BOOL)textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector
{
    if(commandSelector == NSSelectorFromString(@"cancelOperation:")) {
        [self discardFieldEditor];
        return true;
    }
    return false;
}

- (void) dataUpdated
{
    assert( dispatch_is_main_queue() );
    if(!self.item || m_RenamingOriginalName != self.item.Name())
        [self discardFieldEditor];
//    [self setNeedsDisplay];
    [m_ItemsView dataChanged];
    [m_ItemsView setCursorPosition:m_CursorPos];
    
    [self volatileDataChanged];
    [m_FooterView updateListing:m_Data->ListingPtr()];
}

- (void) volatileDataChanged
{
    [m_ItemsView syncVolatileData];
    [m_FooterView updateFocusedItem:self.item VD:self.item_vd];
    [m_FooterView updateStatistics:m_Data->Stats()];
}

- (void) setQuickSearchPrompt:(NSString*)_text withMatchesCount:(int)_count
{
//    [self setHeaderTitle:_text != nil ? _text : self.headerTitleForPanel];
//    [self setNeedsDisplay];
    m_HeaderView.searchPrompt = _text;
    m_HeaderView.searchMatches = _count;
    
}

- (int) sortedItemPosAtPoint:(NSPoint)_window_point hitTestOption:(PanelViewHitTest::Options)_options;
{
    
    assert(dispatch_is_main_queue());
    auto pos = [m_ItemsView sortedItemPosAtPoint:_window_point hitTestOption:_options];
    return pos;
    
    
//    if(pos < 0)
//    return -1;
    
    //return -1;
//    assert(dispatch_is_main_queue());
//    int pos = m_Presentation->GetItemIndexByPointInView(_point, _options);
//    if(pos < 0)
//        return -1;
//    
//    auto item = m_State.Data->EntryAtSortPosition(pos);
//    if(!item)
//        return -1;
//    return pos;
}

/*- (void) appWillResignActive
{
    [self commitFieldEditor];
}*/

- (void) windowStatusDidChange
{
    [self willChangeValueForKey:@"active"];
    [self didChangeValueForKey:@"active"];
}

- (void) setHeaderTitle:(NSString *)headerTitle
{
    dispatch_assert_main_queue();
    if( m_HeaderTitle != headerTitle ) {
        m_HeaderTitle = headerTitle;
//        if( m_Presentation )
//            m_Presentation->OnPanelTitleChanged();
        [m_HeaderView setPath:m_HeaderTitle];        
    }
}

- (NSString *) headerTitle
{
    return m_HeaderTitle;
}

- (NSString *) headerTitleForPanel
{
    auto title = [&]{
        switch( m_Data->Type() ) {
            case PanelData::PanelType::Directory:
                return [NSString stringWithUTF8StdString:m_Data->VerboseDirectoryFullPath()];
            case PanelData::PanelType::Temporary:
                return @"Temporary Panel"; // TODO: localize
            default:
                return @"";
        }}();
    return title ? title : @"";
}

- (void)panelItem:(int)_sorted_index mouseDown:(NSEvent*)_event
{
    // any cursor movements or selection changes should be performed only in active window
    const bool window_focused = self.window.isKeyWindow;
    if( window_focused ) {
        if( !self.active )
            [self.window makeFirstResponder:self];
        
        if( !m_Data->IsValidSortPosition(_sorted_index) )
            return;

        const int current_cursor_pos = m_CursorPos;
        const auto click_entry_vd = m_Data->VolatileDataAtSortPosition(_sorted_index);
        const auto modifier_flags = _event.modifierFlags & NSDeviceIndependentModifierFlagsMask;
    
        // Select range of items with shift+click.
        // If clicked item is selected, then deselect the range instead.
        if( modifier_flags & NSShiftKeyMask )
            [self SelectUnselectInRange:current_cursor_pos >= 0 ? current_cursor_pos : 0
                          last_included:_sorted_index
                                 select:!click_entry_vd.is_selected()];
        else if( modifier_flags & NSCommandKeyMask ) // Select or deselect a single item with cmd+click.
            [self SelectUnselectInRange:_sorted_index
                          last_included:_sorted_index
                                 select:!click_entry_vd.is_selected()];
        
        [self setCurpos:_sorted_index];        
    }
}

- (void)panelItem:(int)_sorted_index fieldEditor:(NSEvent*)_event
{
    if( _sorted_index >= 0 && _sorted_index == m_CursorPos )
        [self startFieldEditorRenaming];
}

- (void)panelItem:(int)_sorted_index dblClick:(NSEvent*)_event
{
    if( _sorted_index >= 0 && _sorted_index == m_CursorPos )
        [self.delegate PanelViewDoubleClick:self atElement:_sorted_index];
}

- (void)panelItem:(int)_sorted_index mouseDragged:(NSEvent*)_event
{
    [self.controller initiateDragFromView:self itemNo:_sorted_index byEvent:_event];
}

- (void) dataSortingHasChanged
{
    m_HeaderView.sortMode = m_Data->SortMode();
    m_ItemsView.sortMode = m_Data->SortMode();
}

//@property (nonatomic, readonly) PanelController *controller
- (PanelController*)controller
{
    return objc_cast<PanelController>(m_Delegate);
}

- (int) headerBarHeight
{
    return 20;
}

+ (NSArray*) acceptedDragAndDropTypes
{
    return PanelController.acceptedDragAndDropTypes;
}

- (NSDragOperation)panelItem:(int)_sorted_index operationForDragging:(id <NSDraggingInfo>)_dragging
{
    return [self.controller validateDraggingOperation:_dragging
                                         forPanelItem:_sorted_index];
}

- (bool)panelItem:(int)_sorted_index performDragOperation:(id<NSDraggingInfo>)_dragging
{
    return [self.controller performDragOperation:_dragging forPanelItem:_sorted_index];
}

- (NSPopover*)showPopoverUnderPathBarWithView:(NSViewController*)_view
                                  andDelegate:(id<NSPopoverDelegate>)_delegate
{
    const auto bounds = self.bounds;
    NSPopover *popover = [NSPopover new];
    popover.contentViewController = _view;
    popover.behavior = NSPopoverBehaviorTransient;
    popover.delegate = _delegate;
    [popover showRelativeToRect:NSMakeRect(0,
                                           bounds.size.height - self.headerBarHeight,
                                           bounds.size.width,
                                           bounds.size.height)
                         ofView:self
                  preferredEdge:NSMinYEdge];
    return popover;
}

- (NSProgressIndicator *)busyIndicator
{
    return m_HeaderView.busyIndicator;
}

@end

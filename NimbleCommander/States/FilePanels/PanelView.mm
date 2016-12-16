//
//  PanelView.m
//  Directories
//
//  Created by Michael G. Kazakov on 08.02.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include <NimbleCommander/Bootstrap/AppDelegate.h>
#include <NimbleCommander/Core/ActionsShortcutsManager.h>
//#include <Utility/NSView+Sugar.h>
#include "PanelViewLayoutSupport.h"
#include "PanelView.h"
//#include "PanelData.h"
#include "PanelController.h"
//#include "PanelViewPresentation.h"
//#include "ModernPanelViewPresentation.h"
//#include "ClassicPanelViewPresentation.h"

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
//    int dispay_offset;
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
    unsigned long               m_KeyboardModifierFlags;
    CursorSelectionType         m_CursorSelectionType;
//    unique_ptr<PanelViewPresentation> m_Presentation;
//    PanelViewState             m_State;
    PanelData                  *m_Data;
    int                         m_CursorPos;
//    PanelViewType               m_ViewType;
    
    unordered_map<size_t, PanelViewStateStorage> m_States;
    NSString                   *m_HeaderTitle;
    
    NSScrollView               *m_RenamingEditor; // NSTextView inside
    string                      m_RenamingOriginalName;
    
    bool                        m_ReadyToDrag;
    
    __weak id<PanelViewDelegate> m_Delegate;
//    nanoseconds                 m_ActivationTime; // time when view did became a first responder
    
    bool                        m_DraggingOver;
    int                         m_DraggingOverItemAtPosition;
    
//    PanelBriefView             *m_ItemsView;
//    PanelListView              *m_ItemsView;
    NSView<PanelViewImplementationProtocol> *m_ItemsView;
    
    PanelViewHeader            *m_HeaderView;
    PanelViewFooter            *m_FooterView;
    
    IconsGenerator2             m_IconsGenerator;
}

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
//        self.wantsLayer = true;
        m_Data = nullptr;
        m_CursorPos = -1;
//        m_ViewType = PanelViewType::Medium;
        
        __weak PanelView *weak_self = self;
        m_KeyboardModifierFlags = 0;
        m_HeaderTitle = @"";
//        m_FieldRenamingRequestTicket = 0;
//        m_LastPotentialRenamingLBDown = -1;
        m_DraggingOver = false;
        m_DraggingOverItemAtPosition = -1;
        
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(frameDidChange)
                                                   name:NSViewFrameDidChangeNotification
                                                 object:self];
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(appWillResignActive)
                                                   name:NSApplicationWillResignActiveNotification
                                                 object:[NSApplication sharedApplication]];
//        [AppDelegate.me addObserver:self forKeyPath:@"skin" options:0 context:NULL];
        
//        auto skin = AppDelegate.me.skin;
//        if (skin == ApplicationSkin::Modern)
//            [self setPresentation:make_unique<ModernPanelViewPresentation>(self, &m_State)];
//        else if(skin == ApplicationSkin::Classic)
//            [self setPresentation:make_unique<ClassicPanelViewPresentation>(self, &m_State)];
//        
        
        //m_ItemsView = [[PanelBriefView alloc] initWithFrame:frame];
//        m_ItemsView = [[PanelListView alloc] initWithFrame:frame];
        m_ItemsView = [self spawnListView];
        m_ItemsView.translatesAutoresizingMaskIntoConstraints = false;
        [self addSubview:m_ItemsView];
        
        m_HeaderView = [[PanelViewHeader alloc] initWithFrame:frame];
        m_HeaderView.translatesAutoresizingMaskIntoConstraints = false;
        m_HeaderView.sortModeChangeCallback = [=](PanelDataSortMode _sm){
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

-(void) dealloc
{
    m_Data = nullptr;
    [NSNotificationCenter.defaultCenter removeObserver:self];
//    [AppDelegate.me removeObserver:self forKeyPath:@"skin"];    
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
    return [[PanelListView alloc] initWithFrame:self.bounds andIC:m_IconsGenerator];
}

- (PanelBriefView*) spawnBriefView
{
    return [[PanelBriefView alloc] initWithFrame:self.bounds andIC:m_IconsGenerator];
    
}

//- (BOOL)isFlipped
//{
//    return YES;
//}

- (BOOL)acceptsFirstResponder
{
    return true;
}

- (BOOL)becomeFirstResponder
{
//    m_ActivationTime = machtime();
//    self.needsDisplay = true;
//    [self.delegate PanelViewDidBecomeFirstResponder:self];
//    m_ReadyToDrag = false;
//    m_LastPotentialRenamingLBDown = -1;
//    
//    [self.window makeFirstResponder:m_ItemsView];
//
    [self willChangeValueForKey:@"active"];
    [self didChangeValueForKey:@"active"];
    return true;
}

- (BOOL)resignFirstResponder
{
//    self.needsDisplay = true;
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
    if(_wnd == nil && self.active == true)
        [self resignFirstResponder];
    
    if(_wnd) {
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(windowDidBecomeKey)
                                                   name:NSWindowDidBecomeKeyNotification
                                                 object:_wnd];
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(windowDidResignKey)
                                                   name:NSWindowDidResignKeyNotification
                                                 object:_wnd];
    }
    
    if( _wnd == nil ) {
    }

}

- (bool) active
{
//    return w == nil ? false : w.isKeyWindow && w.firstResponder == self;
    if( NSWindow *w = self.window )
        if( w.isKeyWindow )
            if( id fr = w.firstResponder )
                return fr == self || [objc_cast<NSView>(fr) isDescendantOf:self];
    return false;
}

//- (void)drawRect:(NSRect)dirtyRect
//{
//    if (!m_State.Data || !m_Presentation) return;
//    m_Presentation->Draw(dirtyRect);
//    
//    if(m_RenamingEditor) {
//        [NSGraphicsContext saveGraphicsState];
//        NSSetFocusRingStyle(NSFocusRingOnly);
//        [[NSBezierPath bezierPathWithRect:m_RenamingEditor.frame] fill];
//        [NSGraphicsContext restoreGraphicsState];
//    }
//    
//    if( m_DraggingOver ) {
//        if( m_DraggingOverItemAtPosition >= 0 && m_Presentation->IsItemVisible(m_DraggingOverItemAtPosition) ) {
//            NSRect rc = m_Presentation->ItemRect(m_DraggingOverItemAtPosition);
//            [NSGraphicsContext saveGraphicsState];
//            NSSetFocusRingStyle(NSFocusRingOnly);
//            [[NSBezierPath bezierPathWithRect:NSInsetRect(rc,2,2)] fill];
//            [NSGraphicsContext restoreGraphicsState];
//        }
//        else {
//            [NSGraphicsContext saveGraphicsState];
//            NSSetFocusRingStyle(NSFocusRingOnly);
//            [[NSBezierPath bezierPathWithRect:NSInsetRect(self.bounds,2,2)] fill];
//            [NSGraphicsContext restoreGraphicsState];
//        }
//    }
//  
//    for( auto n: m_ContextMenuHighlights ) {
//        if( m_Presentation->IsItemVisible(n) ) {
//            NSRect rc = m_Presentation->ItemRect(n);
//            [NSGraphicsContext saveGraphicsState];
//            NSSetFocusRingStyle(NSFocusRingOnly);
//            [[NSBezierPath bezierPathWithRect:NSInsetRect(rc,2,2)] fill];
//            [NSGraphicsContext restoreGraphicsState];
//        }
//    }
//}

- (void)frameDidChange
{
//    if (m_Presentation)
//        m_Presentation->OnFrameChanged([self frame]);
    [self commitFieldEditor];
}

- (PanelData*) data
{
    return m_Data;
}

- (void) setData:(PanelData *)data
{
    self.needsDisplay = true;
    m_Data = data;
    
//    if( data )

    if( data ) {
        [m_ItemsView setData:data];
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

//- (void) setPresentation:(unique_ptr<PanelViewPresentation>)_presentation
//{
//    m_Presentation = move(_presentation);
//    if (m_Presentation) {
//        [self frameDidChange];
//        self.needsDisplay = true;
//    }
//}

//- (PanelViewPresentation*) presentation
//{
//    return m_Presentation.get();
//}

- (void) HandlePrevFile
{
    dispatch_assert_main_queue();
    
    int origpos = m_CursorPos;
    
//    m_Presentation->MoveCursorToPrevItem();
//    if(m_State->Data->SortedDirectoryEntries().empty()) return;
//
    if( m_CursorPos < 0 )
        return;
    
    [self SelectUnselectInRange:origpos last_included:origpos];

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
    [self SelectUnselectInRange:origpos last_included:origpos];
    if( m_CursorPos + 1 >= m_Data->SortedDirectoryEntries().size() )
        return;

    m_CursorPos++;
    
    
    [self OnCursorPositionChanged];
}

/*- (void) HandlePrevPage
{
    dispatch_assert_main_queue();
    
    int origpos = m_CursorPos;
//    m_Presentation->MoveCursorToPrevPage();

    [self SelectUnselectInRange:origpos last_included:m_CursorPos];
    [self OnCursorPositionChanged];
}

- (void) HandleNextPage
{
    dispatch_assert_main_queue();
    
    int origpos = m_CursorPos;
//    m_Presentation->MoveCursorToNextPage();

    [self SelectUnselectInRange:origpos last_included:m_CursorPos];
    [self OnCursorPositionChanged];
}*/

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
    
    [self SelectUnselectInRange:orig_pos last_included:m_CursorPos];
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

    [self SelectUnselectInRange:orig_pos last_included:m_CursorPos];
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

    [self SelectUnselectInRange:origpos last_included:m_CursorPos];
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

    [self SelectUnselectInRange:origpos last_included: m_CursorPos];
    [self OnCursorPositionChanged];
}

- (void) onInvertCurrentItemSelectionAndMoveNext
{
    dispatch_assert_main_queue();
    
    int origpos = m_CursorPos;
//    m_Presentation->MoveCursorToNextItem();
    
    if(auto entry = m_Data->EntryAtSortPosition(origpos))
        [self SelectUnselectInRange:origpos
                      last_included:origpos
                             select:!m_Data->VolatileDataAtSortPosition(origpos).is_selected()];
    
    [self OnCursorPositionChanged];
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

//    m_Presentation->SetCursorPos(_pos); // _pos wil be filtered here
//    [m_ItemsView setCursorPosition:_pos];
    
    m_CursorPos = clipped_pos;
//        m_Presentation->SetCursorPos(cursor);
//    m_State.CursorPos = (m_State.Data->SortedDirectoryEntries().size() > 0 &&
//                         _pos >= 0 &&
//                         _pos < m_State.Data->SortedDirectoryEntries().size() ) ?
//                        _pos : -1;
    
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
    
    static ActionsShortcutsManager::ShortCut hk_up, hk_down, hk_left, hk_right, hk_first, hk_last, hk_pgdown, hk_pgup, hk_inv_and_move, hk_inv;
    static ActionsShortcutsManager::ShortCutsUpdater hotkeys_updater(
       {&hk_up, &hk_down, &hk_left, &hk_right, &hk_first, &hk_last, &hk_pgdown, &hk_pgup, &hk_inv_and_move, &hk_inv},
       {"panel.move_up", "panel.move_down", "panel.move_left", "panel.move_right", "panel.move_first", "panel.move_last", "panel.move_next_page", "panel.move_prev_page", "panel.move_next_and_invert_selection", "panel.invert_item_selection"}
      );
    hotkeys_updater.CheckAndUpdate();

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
//    else if( hk_pgdown.IsKeyDown(unicode, keycode, modifiers & ~NSShiftKeyMask) )
//        [self HandleNextPage];
    else if( hk_pgdown.IsKeyDown(unicode, keycode, modifiers) )
        [m_ItemsView onPageDown:event];
//    else if( hk_pgup.IsKeyDown(unicode, keycode, modifiers & ~NSShiftKeyMask) )
//        [self HandlePrevPage];
    else if( hk_pgup.IsKeyDown(unicode, keycode, modifiers) )
        [m_ItemsView onPageUp:event];
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
    
    if( (m_KeyboardModifierFlags & NSShiftKeyMask) == 0 ) {
        // clear selection type when user releases SHIFT button
        m_CursorSelectionType = CursorSelectionType::No;
    }
    else if( m_CursorSelectionType == CursorSelectionType::No ) {
        // lets decide if we need to select or unselect files when user will use navigation arrows
        if( auto item = self.item ) {
            if( !item.IsDotDot() ) { // regular case
                m_CursorSelectionType = self.item_vd.is_selected() ? CursorSelectionType::Unselection : CursorSelectionType::Selection;
            }
            else {
                // need to look at a first file (next to dotdot) for current representation if any.
                if( auto next_item = m_Data->EntryAtSortPosition(1) )
                    m_CursorSelectionType = m_Data->VolatileDataAtSortPosition(1).is_selected() ? CursorSelectionType::Unselection : CursorSelectionType::Selection;
                else // singular case - selection doesn't matter - nothing to select
                    m_CursorSelectionType = CursorSelectionType::Selection;
            }
        }
    }
}

- (void)modifierFlagsChanged:(unsigned long)_flags
{
    [self checkKeyboardModifierFlags:_flags];
}

- (void)flagsChanged:(NSEvent *)event
{
    [self checkKeyboardModifierFlags:event.modifierFlags];
    [super flagsChanged:event];
}

//- (BOOL) acceptsFirstMouse:(NSEvent *)theEvent
//{
//    /* really always??? */
//    return true;
//}
//
//- (BOOL)shouldDelayWindowOrderingForEvent:(NSEvent *)theEvent
//{
//    /* really always??? */
//    return true;
//}

//- (void) mouseDown:(NSEvent *)_event
//{
//    m_LastPotentialRenamingLBDown = -1;
//    
//    const NSPoint local_point = [self convertPoint:_event.locationInWindow fromView:nil];
//    const int current_cursor_pos = m_State.CursorPos;
//    const bool window_focused = self.window.isKeyWindow;
//    
//    const int clicked_pos = m_Presentation->GetItemIndexByPointInView(local_point, PanelViewHitTest::FullArea);
//    if( clicked_pos == -1 )
//        return;
//
//    const auto click_entry_vd = m_State.Data->VolatileDataAtSortPosition(clicked_pos);
//    const bool lb_pressed = (NSEvent.pressedMouseButtons & 1) == 1;
//    const bool lb_cooldown = machtime() - m_ActivationTime < 300ms;
//    
//    // any cursor movements or selection changes should be performed only in active window
//    if( window_focused ) {
//        const auto modifier_flags = _event.modifierFlags & NSDeviceIndependentModifierFlagsMask;
//        
//        // Select range of items with shift+click.
//        // If clicked item is selected, then deselect the range instead.
//        if(modifier_flags & NSShiftKeyMask)
//            [self SelectUnselectInRange:current_cursor_pos >= 0 ? current_cursor_pos : 0
//                          last_included:clicked_pos
//                                 select:!click_entry_vd.is_selected()];
//        else if(modifier_flags & NSCommandKeyMask) // Select or deselect a single item with cmd+click.
//            [self SelectUnselectInRange:clicked_pos
//                          last_included:clicked_pos
//                                 select:!click_entry_vd.is_selected()];
//        
//        m_Presentation->SetCursorPos(clicked_pos);
//        
//        if( current_cursor_pos != clicked_pos )
//            [self OnCursorPositionChanged];
//        else if(lb_pressed && !lb_cooldown)
//            m_LastPotentialRenamingLBDown = clicked_pos; // need more complex logic here (?)
//
//    }
//    
//    if( lb_pressed ) {
//        m_ReadyToDrag = true;
//        m_LButtonDownPos = local_point;
//    }
//}

- (NSMenu *)panelItem:(int)_sorted_index menuForForEvent:(NSEvent*)_event
{
    if( _sorted_index >= 0 )
        return [self.delegate panelView:self requestsContextMenuForItemNo:_sorted_index];    
    return nil;
}

//- (void) mouseDragged:(NSEvent *)_event
//{
//    const auto max_drag_dist = 5.;
//    if( m_ReadyToDrag ) {
//        NSPoint lp = [self convertPoint:_event.locationInWindow fromView:nil];
//        if( hypot(lp.x - m_LButtonDownPos.x, lp.y - m_LButtonDownPos.y) > max_drag_dist ) {
//            const int clicked_pos = m_Presentation->GetItemIndexByPointInView(m_LButtonDownPos, PanelViewHitTest::FullArea);
//            if( clicked_pos == -1 )
//                return;
//            
//            [self.delegate panelView:self wantsToDragItemNo:clicked_pos byEvent:_event];
//            
//            m_ReadyToDrag = false;
//            m_LastPotentialRenamingLBDown = -1;
//        }
//    }
//}

//- (void) mouseUp:(NSEvent *)_event
//{
//    int click_count = (int)_event.clickCount;
//    NSPoint local_point = [self convertPoint:_event.locationInWindow fromView:nil];
//    int cursor_pos = m_Presentation->GetItemIndexByPointInView(local_point, PanelViewHitTest::FullArea);
//
//    if( click_count <= 1 ) {
//        if( m_LastPotentialRenamingLBDown >= 0 && m_LastPotentialRenamingLBDown == cursor_pos ) {
//            static const nanoseconds delay = milliseconds( int(NSEvent.doubleClickInterval*1000) );
//            uint64_t renaming_ticket = ++m_FieldRenamingRequestTicket;
//            dispatch_to_main_queue_after(delay,[=]{
//                               if(renaming_ticket == m_FieldRenamingRequestTicket)
//                                   [self startFieldEditorRenamingByEvent:_event];
//                           });
//        }
//    }
//    else if( click_count == 2 || click_count == 4 || click_count == 6 || click_count == 8 ) {
//        // Handle double-or-four-etc clicks as double-click
//        ++m_FieldRenamingRequestTicket; // to abort field editing
//        if(cursor_pos >= 0 && cursor_pos == m_State.CursorPos)
//            [self.delegate PanelViewDoubleClick:self atElement:cursor_pos];
//    }
//
//    m_ReadyToDrag = false;
//    m_LastPotentialRenamingLBDown = -1;
//}

- (VFSListingItem)item
{
    return m_Data->EntryAtSortPosition(m_CursorPos);
}

- (const PanelData::VolatileData &)item_vd
{
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

- (void) SelectUnselectInRange:(int)_start last_included:(int)_end
{
    assert( dispatch_is_main_queue() );
    if(m_CursorSelectionType == CursorSelectionType::No)
        return;
    [self SelectUnselectInRange:_start
                  last_included:_end
                         select:m_CursorSelectionType == CursorSelectionType::Selection];
}

- (void) setupBriefPresentationWithLayout:(PanelBriefViewColumnsLayout)_layout
{
    const auto init = !objc_cast<PanelBriefView>(m_ItemsView);
    if( init ) {
        auto v = [self spawnBriefView];
        v.translatesAutoresizingMaskIntoConstraints = false;
        //    [self addSubview:m_ItemsView];
        
        [self replaceSubview:m_ItemsView with:v];
        m_ItemsView = v;
        
        NSDictionary *views = NSDictionaryOfVariableBindings(m_ItemsView, m_HeaderView, m_FooterView);
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[m_HeaderView]-(==0)-[m_ItemsView]-(==0)-[m_FooterView]" options:0 metrics:nil views:views]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(0)-[m_ItemsView]-(0)-|" options:0 metrics:nil views:views]];
        [self layout];
        
        if( m_Data )
            [m_ItemsView setData:m_Data];
        
        if( m_CursorPos >= 0 )
            [m_ItemsView setCursorPosition:m_CursorPos];
        
        m_ItemsView.sortMode = m_Data->SortMode();
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
        v.translatesAutoresizingMaskIntoConstraints = false;
        
        [self replaceSubview:m_ItemsView with:v];
        m_ItemsView = v;
        
//        NSDictionary *views = NSDictionaryOfVariableBindings(m_ItemsView, m_HeaderView, m_FooterView);
        //        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(==0)-[m_ItemsView]-(==0)-|" options:0 metrics:nil views:views]];
//        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(==0)-[m_HeaderView(==20)]-(==0)-[m_ItemsView]-(==0)-[m_FooterView(==20)]-(==0)-|" options:0 metrics:nil views:views]];
        
        
        NSDictionary *views = NSDictionaryOfVariableBindings(m_ItemsView, m_HeaderView, m_FooterView);
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[m_HeaderView]-(==0)-[m_ItemsView]-(==0)-[m_FooterView]" options:0 metrics:nil views:views]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(0)-[m_ItemsView]-(0)-|" options:0 metrics:nil views:views]];
        [self layout];
        
        if( m_Data )
            [m_ItemsView setData:m_Data];
        
        if( m_CursorPos >= 0 )
            [m_ItemsView setCursorPosition:m_CursorPos];
        
        m_ItemsView.sortMode = m_Data->SortMode();
        
        __weak PanelView *weak_self = self;
        v.sortModeChangeCallback = [=](PanelDataSortMode _sm){
            if( PanelView *strong_self = weak_self )
                [strong_self.controller changeSortingModeTo:_sm];
        };
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

//- (void) setupPresentationLayout:(const PanelViewLayout&)_pvl
//{
//}

PanelViewLayout L1()
{
    
    //    struct PanelBriefViewColumnsLayout
    //    {
    //        enum class Mode : short {
    //            FixedWidth      = 0,
    //            FixedAmount     = 1,
    //            DynamicWidth    = 2
    //        };
    //        Mode    mode                = Mode::FixedAmount;
    //        short   fixed_mode_width    = 150;
    //        short   fixed_amount_value  = 3;
    //        short   dynamic_width_min   = 100;
    //        short   dynamic_width_max   = 300;
    //        bool    dynamic_width_equal = false;
    
    PanelBriefViewColumnsLayout cl;
    cl.mode = PanelBriefViewColumnsLayout::Mode::FixedAmount;
    cl.fixed_amount_value = 3;
    
    PanelViewLayout ret;
    ret.layout = cl;
    return ret;
}

PanelViewLayout L2()
{
    
    //    struct PanelBriefViewColumnsLayout
    //    {
    //        enum class Mode : short {
    //            FixedWidth      = 0,
    //            FixedAmount     = 1,
    //            DynamicWidth    = 2
    //        };
    //        Mode    mode                = Mode::FixedAmount;
    //        short   fixed_mode_width    = 150;
    //        short   fixed_amount_value  = 3;
    //        short   dynamic_width_min   = 100;
    //        short   dynamic_width_max   = 300;
    //        bool    dynamic_width_equal = false;
    
    PanelBriefViewColumnsLayout cl;
    cl.mode = PanelBriefViewColumnsLayout::Mode::DynamicWidth;
    
    PanelViewLayout ret;
    ret.layout = cl;
    return ret;
}

PanelViewLayout L3()
{
    PanelListViewColumnsLayout l;
    
    PanelListViewColumnsLayout::Column c;
    c.kind = PanelListViewColumns::Filename;
    l.columns.emplace_back(c);
    
    c.kind = PanelListViewColumns::Size;
    l.columns.emplace_back(c);
    
    c.kind = PanelListViewColumns::DateCreated;
    l.columns.emplace_back(c);
    
    c.kind = PanelListViewColumns::DateModified;
    l.columns.emplace_back(c);
    
    c.kind = PanelListViewColumns::DateAdded;
    l.columns.emplace_back(c);
    
    PanelViewLayout ret;
    ret.layout = l;
    return ret;
}

PanelViewLayout L4()
{
    PanelListViewColumnsLayout l;
    
    PanelListViewColumnsLayout::Column c;
    c.kind = PanelListViewColumns::Filename;
    l.columns.emplace_back(c);
    
    c.kind = PanelListViewColumns::Size;
    l.columns.emplace_back(c);
    
    PanelViewLayout ret;
    ret.layout = l;
    return ret;
}

//- (void) setType:(PanelViewType)_type
//{
//    
//    if( _type == PanelViewType::Short )
//        [self setLayout:L1()];
//
//    if( _type == PanelViewType::Medium )
//        [self setLayout:L2()];
//    
//    if( _type == PanelViewType::Full )
//        [self setLayout:L3()];
//    
//    if( _type == PanelViewType::Wide )
//        [self setLayout:L4()];
//    
//    
////    m_State.ViewType = _type;
////    if (m_Presentation) m_Presentation->EnsureCursorIsVisible();
////    [self commitFieldEditor];
////    self.needsDisplay = true;
//}

//- (PanelViewType)type
//{
//    return m_ViewType;
//}

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
//    storage.dispay_offset = m_State.ItemsDisplayOffset;
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
    
//    m_State.ItemsDisplayOffset = storage.dispay_offset;
//    m_Presentation->SetCursorPos(cursor);
//    m_State.CursorPos = (m_State.Data->SortedDirectoryEntries().size() > 0 &&
//                         cursor >= 0 &&
//                         cursor < m_State.Data->SortedDirectoryEntries().size() ) ?
//                         cursor : -1;
    
    
//    m_State->CursorPos = -1;
//    if(m_State->Data->SortedDirectoryEntries().size() > 0 &&
//       _pos >= 0 &&
//       _pos < m_State->Data->SortedDirectoryEntries().size())
//        m_State->CursorPos = _pos;
    
    
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

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
    NSDragOperation result = NSDragOperationNone;
    if(id<PanelViewDelegate> del = self.delegate)
        if([del respondsToSelector:@selector(PanelViewDraggingEntered:sender:)])
            result = [del PanelViewDraggingEntered:self sender:sender];
    return result;
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
    NSDragOperation result = NSDragOperationNone;
    if(id<PanelViewDelegate> del = self.delegate)
        if([del respondsToSelector:@selector(PanelViewDraggingUpdated:sender:)])
            result = [del PanelViewDraggingUpdated:self sender:sender];
    return result;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
    if(id<PanelViewDelegate> del = self.delegate)
        if([del respondsToSelector:@selector(PanelViewDraggingExited:sender:)])
            [del PanelViewDraggingExited:self sender:sender];
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
    // possibly add some checking stage here later
    return YES;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
    if(id<PanelViewDelegate> del = self.delegate)
        if([del respondsToSelector:@selector(PanelViewPerformDragOperation:sender:)])
            return [del PanelViewPerformDragOperation:self sender:sender];
    return NO;
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
    
    int cursor_pos = m_CursorPos;
//    if( !m_Presentation->IsItemVisible(cursor_pos) )
    if( ![m_ItemsView isItemVisible:cursor_pos] )
        return;

    if(![self.delegate PanelViewWantsRenameFieldEditor:self])
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
    tv.string = self.item.NSName();
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
    NSMutableParagraphStyle *ps = [NSMutableParagraphStyle new];
    ps.lineBreakMode = NSLineBreakByClipping;
    tv.defaultParagraphStyle = ps;
    tv.textContainer.widthTracksTextView = tv.textContainer.heightTracksTextView = false;
    tv.textContainer.containerSize = CGSizeMake(FLT_MAX, FLT_MAX);
    
    m_RenamingEditor.documentView = tv;
    [m_ItemsView setupFieldEditor:m_RenamingEditor forItemAtIndex:cursor_pos];
    
    [self.window makeFirstResponder:m_RenamingEditor];
    
    m_RenamingOriginalName = self.item.Name();
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
    return nil;
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

- (int) sortedItemPosAtPoint:(NSPoint)_point hitTestOption:(PanelViewHitTest::Options)_options;
{
    return -1;
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

- (int) draggingOverItemAtPosition
{
    return m_DraggingOverItemAtPosition;
}

- (void) setDraggingOverItemAtPosition:(int)draggingOverItemAtPosition
{
    if(m_DraggingOverItemAtPosition != draggingOverItemAtPosition) {
        m_DraggingOverItemAtPosition = draggingOverItemAtPosition;
        self.needsDisplay = true;
    }
}

- (bool) draggingOver
{
    return m_DraggingOver;
}

- (void) setDraggingOver:(bool)draggingOver
{
    if(m_DraggingOver != draggingOver)
    {
        m_DraggingOverItemAtPosition = -1;
        m_DraggingOver = draggingOver;
        self.needsDisplay = true;
    }
}

- (void) appWillResignActive
{
    [self commitFieldEditor];
}

- (void) windowDidBecomeKey
{
    [self willChangeValueForKey:@"active"];
    [self didChangeValueForKey:@"active"];
}

- (void) windowDidResignKey
{
    [self willChangeValueForKey:@"active"];
    [self didChangeValueForKey:@"active"];
}

//- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
//{
//    if (object == AppDelegate.me && [keyPath isEqualToString:@"skin"]) {
//        auto skin = AppDelegate.me.skin;
//        if (skin == ApplicationSkin::Modern)
//            [self setPresentation:make_unique<ModernPanelViewPresentation>(self, &m_State)];
//        else if(skin == ApplicationSkin::Classic)
//            [self setPresentation:make_unique<ClassicPanelViewPresentation>(self, &m_State)];
//    }
//}

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
    switch( m_Data->Type() ) {
        case PanelData::PanelType::Directory:
            return [NSString stringWithUTF8StdString:m_Data->VerboseDirectoryFullPath()];
        case PanelData::PanelType::Temporary:
            return @"Temporary Panel"; // TODO: localize
        default:
            return @"";
    }
}

- (rapidjson::StandaloneValue) encodeRestorableState
{
    rapidjson::StandaloneValue json(rapidjson::kObjectType);
    auto add_int = [&](const char*_name, int _v) {
        json.AddMember(rapidjson::StandaloneValue(_name, rapidjson::g_CrtAllocator), rapidjson::StandaloneValue(_v), rapidjson::g_CrtAllocator); };
    
//    add_int("viewMode", (int)self.type);
    return json;
}

- (void) loadRestorableState:(const rapidjson::StandaloneValue&)_state
{
    if( !_state.IsObject() )
        return;
    
//    if( _state.HasMember("viewMode") && _state["viewMode"].IsInt() ) {
//        PanelViewType vt = (PanelViewType)_state["viewMode"].GetInt();
//        if( vt == PanelViewType::Short || // brutal validation
//            vt == PanelViewType::Medium ||
//            vt == PanelViewType::Full ||
//            vt == PanelViewType::Wide )
//            self.type = vt;
//    }
}

- (void)panelItem:(int)_sorted_index mouseDown:(NSEvent*)_event
{
    if( _sorted_index < 0 )
        return;
    
    const int current_cursor_pos = m_CursorPos;
    const bool window_focused = self.window.isKeyWindow;
    const auto click_entry_vd = m_Data->VolatileDataAtSortPosition(_sorted_index);
    
    // any cursor movements or selection changes should be performed only in active window
    if( window_focused ) {
        const auto modifier_flags = _event.modifierFlags & NSDeviceIndependentModifierFlagsMask;
        
        if( !self.active )
            [self.window makeFirstResponder:self];
        
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

@end

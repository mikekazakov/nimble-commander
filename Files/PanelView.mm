//
//  PanelView.m
//  Directories
//
//  Created by Michael G. Kazakov on 08.02.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include "PanelView.h"
#include "PanelData.h"
#include "PanelViewPresentation.h"
#include "ModernPanelViewPresentation.h"
#include "ClassicPanelViewPresentation.h"
#include "Common.h"
#include "vfs/VFS.h"
#include "AppDelegate.h"

enum class CursorSelectionType
{
    No,
    Selection,
    Unselection
};

struct PanelViewStateStorage
{
    int dispay_offset;
    string focused_item;
};

////////////////////////////////////////////////////////////////////////////////

@implementation PanelView
{
    CursorSelectionType         m_CursorSelectionType;
    unique_ptr<PanelViewPresentation> m_Presentation;
    PanelViewState              m_State;
    
    map<hash<VFSPathStack>::value_type, PanelViewStateStorage> m_States;
    
    NSScrollView               *m_RenamingEditor; // NSTextView inside
    string                      m_RenamingOriginalName;
    int                         m_LastPotentialRenamingLBDown; // -1 if there's no such
    atomic_ullong               m_FieldRenamingRequestTicket; // used for delayed action to ensure that click was single, not double or more
    
    double                      m_ScrollDY;
    
    bool                        m_ReadyToDrag;
    NSPoint                     m_LButtonDownPos;
    bool                        m_IsCurrentlyMomentumScroll;
    bool                        m_DisableCurrentMomentumScroll;
    
    __weak id<PanelViewDelegate> m_Delegate;
    nanoseconds                 m_ActivationTime; // time when view did became a first responder
    
    bool                        m_DraggingOver;
    int                         m_DraggingOverItemAtPosition;
    
    FPSLimitedDrawer           *m_FPSLimitedDrawer;
}

@synthesize fpsDrawer = m_FPSLimitedDrawer;

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.wantsLayer = true;
        m_FieldRenamingRequestTicket = 0;
        m_ScrollDY = 0.0;
        m_DisableCurrentMomentumScroll = false;
        m_IsCurrentlyMomentumScroll = false;
        m_LastPotentialRenamingLBDown = -1;
        m_DraggingOver = false;
        m_DraggingOverItemAtPosition = -1;
        m_FPSLimitedDrawer = [[FPSLimitedDrawer alloc] initWithView:self];
        m_FPSLimitedDrawer.fps = 60;
        
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(frameDidChange)
                                                   name:NSViewFrameDidChangeNotification
                                                 object:self];
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(appWillResignActive)
                                                   name:NSApplicationWillResignActiveNotification
                                                 object:[NSApplication sharedApplication]];
        [AppDelegate.me addObserver:self forKeyPath:@"skin" options:0 context:NULL];
        
        auto skin = AppDelegate.me.skin;
        if (skin == ApplicationSkin::Modern)
            [self setPresentation:make_unique<ModernPanelViewPresentation>()];
        else if(skin == ApplicationSkin::Classic)
            [self setPresentation:make_unique<ClassicPanelViewPresentation>()];
    }
    
    return self;
}

-(void) dealloc
{
    m_State.Data = nullptr;
    [NSNotificationCenter.defaultCenter removeObserver:self];
    [AppDelegate.me removeObserver:self forKeyPath:@"skin"];    
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

- (BOOL)isFlipped
{
    return YES;
}

- (BOOL)isOpaque
{
    return YES;
}

- (BOOL)acceptsFirstResponder
{
    return YES;
}

- (BOOL)becomeFirstResponder
{
    m_ActivationTime = machtime();
    self.needsDisplay = true;
    [self.delegate PanelViewDidBecomeFirstResponder:self];
    m_ReadyToDrag = false;
    m_LastPotentialRenamingLBDown = -1;
    return YES;
}

- (BOOL)resignFirstResponder
{
    self.needsDisplay = true;
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

}

- (bool)active
{
    return self.window == nil ? false : self.window.firstResponder == self;
}

- (void)resetCursorRects
{
    [self addCursorRect:self.frame cursor:NSCursor.arrowCursor];
}

- (void)drawRect:(NSRect)dirtyRect
{
    if (!m_State.Data || !m_Presentation) return;
    m_Presentation->Draw(dirtyRect);
    
    if(m_RenamingEditor) {
        [NSGraphicsContext saveGraphicsState];
        NSSetFocusRingStyle(NSFocusRingOnly);
        [[NSBezierPath bezierPathWithRect:m_RenamingEditor.frame] fill];
        [NSGraphicsContext restoreGraphicsState];
    }
    
    if( m_DraggingOver ) {
        if( m_DraggingOverItemAtPosition >= 0 && m_Presentation->IsItemVisible(m_DraggingOverItemAtPosition) ) {
            NSRect rc = m_Presentation->ItemRect(m_DraggingOverItemAtPosition);
            [NSGraphicsContext saveGraphicsState];
            NSSetFocusRingStyle(NSFocusRingOnly);
            [[NSBezierPath bezierPathWithRect:NSInsetRect(rc,2,2)] fill];
            [NSGraphicsContext restoreGraphicsState];
        }
        else {
            [NSGraphicsContext saveGraphicsState];
            NSSetFocusRingStyle(NSFocusRingOnly);
            [[NSBezierPath bezierPathWithRect:NSInsetRect(self.bounds,2,2)] fill];
            [NSGraphicsContext restoreGraphicsState];
        }
    }
}

- (void)frameDidChange
{
    if (m_Presentation)
        m_Presentation->OnFrameChanged([self frame]);
    [self commitFieldEditor];
}

- (PanelData*) data
{
    return m_State.Data;
}

- (void) setData:(PanelData *)data
{
    m_State.Data = data;
    self.needsDisplay = true;
}

- (void) setPresentation:(unique_ptr<PanelViewPresentation>)_presentation
{
    m_Presentation = move(_presentation);
    if (m_Presentation) {
        m_Presentation->SetState(&m_State);
        m_Presentation->SetView(self);
        [self frameDidChange];
        self.needsDisplay = true;
    }
}

- (PanelViewPresentation*) presentation
{
    return m_Presentation.get();
}

- (void) HandlePrevFile
{
    assert( dispatch_is_main_queue() );
    
    int origpos = m_State.CursorPos;
    
    m_Presentation->MoveCursorToPrevItem();
    
    if(m_CursorSelectionType != CursorSelectionType::No)
        [self SelectUnselectInRange:origpos last_included:origpos];
    
    [self OnCursorPositionChanged];
}

- (void) HandleNextFile
{
    assert( dispatch_is_main_queue() );
    
    int origpos = m_State.CursorPos;
    m_Presentation->MoveCursorToNextItem();
    
    [self SelectUnselectInRange:origpos last_included:origpos];
    [self OnCursorPositionChanged];
}

- (void) HandlePrevPage
{
    assert( dispatch_is_main_queue() );
    
    int origpos = m_State.CursorPos;
    m_Presentation->MoveCursorToPrevPage();

    [self SelectUnselectInRange:origpos last_included:m_State.CursorPos];
    [self OnCursorPositionChanged];
}

- (void) HandleNextPage
{
    assert( dispatch_is_main_queue() );
    
    int origpos = m_State.CursorPos;
    m_Presentation->MoveCursorToNextPage();

    [self SelectUnselectInRange:origpos last_included:m_State.CursorPos];
    [self OnCursorPositionChanged];
}

- (void) HandlePrevColumn
{
    assert( dispatch_is_main_queue() );
    
    int origpos = m_State.CursorPos;
    m_Presentation->MoveCursorToPrevColumn();
    
    [self SelectUnselectInRange:origpos last_included:m_State.CursorPos];
    [self OnCursorPositionChanged];
}

- (void) HandleNextColumn
{
    assert( dispatch_is_main_queue() );
    
    int origpos = m_State.CursorPos;
    m_Presentation->MoveCursorToNextColumn();

    [self SelectUnselectInRange:origpos last_included:m_State.CursorPos];
    [self OnCursorPositionChanged];
}

- (void) HandleFirstFile;
{
    assert( dispatch_is_main_queue() );
    
    int origpos = m_State.CursorPos;
    m_Presentation->MoveCursorToFirstItem();

    [self SelectUnselectInRange:origpos last_included:m_State.CursorPos];
    [self OnCursorPositionChanged];
}

- (void) HandleLastFile;
{
    assert( dispatch_is_main_queue() );
    
    int origpos = m_State.CursorPos;
    m_Presentation->MoveCursorToLastItem();

    [self SelectUnselectInRange:origpos last_included: m_State.CursorPos];
    [self OnCursorPositionChanged];
}

- (void) HandleInsert
{
    assert( dispatch_is_main_queue() );
    
    int origpos = m_State.CursorPos;
    m_Presentation->MoveCursorToNextItem();
    
    if(auto entry = m_State.Data->EntryAtSortPosition(origpos))
        [self SelectUnselectInRange:origpos
                      last_included:origpos
                             select:!m_State.Data->VolatileDataAtSortPosition(origpos).is_selected()];
    
    [self OnCursorPositionChanged];
}

- (void) setCurpos:(int)_pos
{
    assert( dispatch_is_main_queue() );
    
    if (m_State.CursorPos == _pos) return;

    m_Presentation->SetCursorPos(_pos); // _pos wil be filtered here

    [self OnCursorPositionChanged];
}

- (int) curpos
{
    assert( dispatch_is_main_queue() );
    return m_State.CursorPos;
}

- (void) OnCursorPositionChanged
{
    assert( dispatch_is_main_queue() );
    [m_FPSLimitedDrawer invalidate];
    
    if(id<PanelViewDelegate> del = self.delegate)
        if([del respondsToSelector:@selector(PanelViewCursorChanged:)])
            [del PanelViewCursorChanged:self];
    
    m_LastPotentialRenamingLBDown = -1;
    [self commitFieldEditor];
}

- (void)keyDown:(NSEvent *)event
{
    if(id<PanelViewDelegate> del = self.delegate)
        if([del respondsToSelector:@selector(PanelViewProcessKeyDown:event:)])
            if([del PanelViewProcessKeyDown:self event:event])
                return;
    
    NSString* character = [event charactersIgnoringModifiers];
    if ( [character length] != 1 ) {
        [super keyDown:event];
        return;
    }
    
    auto mod = event.modifierFlags;
    auto unicode = [character characterAtIndex:0];

    switch (unicode) {
        case NSHomeFunctionKey:       [self HandleFirstFile];     return;
        case NSEndFunctionKey:        [self HandleLastFile];      return;
        case NSPageDownFunctionKey:   [self HandleNextPage];      return;
        case NSPageUpFunctionKey:     [self HandlePrevPage];      return;
        case 0x03:                    [self HandleInsert];        return;
        case NSLeftArrowFunctionKey:
            if(!(mod & NSControlKeyMask) && !(mod & NSCommandKeyMask) && !(mod & NSAlternateKeyMask) ) {
                [self HandlePrevColumn];
                return;
            }
            break;
        case NSRightArrowFunctionKey:
            if(!(mod & NSControlKeyMask) && !(mod & NSCommandKeyMask) && !(mod & NSAlternateKeyMask) ) {
                [self HandleNextColumn];
                return;
            }
            break;
        case NSUpArrowFunctionKey:
            if(!(mod & NSControlKeyMask) && !(mod & NSCommandKeyMask) && !(mod & NSAlternateKeyMask) ) {
                [self HandlePrevFile];
                return;
            }
            break;
        case NSDownArrowFunctionKey:
            if(!(mod & NSControlKeyMask) && !(mod & NSCommandKeyMask) && !(mod & NSAlternateKeyMask) ) {
                [self HandleNextFile];
                return;
            }
            break;
    }
    
    [super keyDown:event];
}

- (void) ModifierFlagsChanged:(unsigned long)_flags
{
    if( (_flags & NSShiftKeyMask) == 0 ) {
        // clear selection type when user releases SHIFT button
        m_CursorSelectionType = CursorSelectionType::No;
    }
    else if( m_CursorSelectionType == CursorSelectionType::No ) {
            // lets decide if we need to select or unselect files when user will use navigation arrows
            if( auto item = self.item ) {
                if(!item.IsDotDot()) { // regular case
                    m_CursorSelectionType = self.item_vd.is_selected() ? CursorSelectionType::Unselection : CursorSelectionType::Selection;
                }
                else {
                    // need to look at a first file (next to dotdot) for current representation if any.
                    if(auto item = m_State.Data->EntryAtSortPosition(1))
                        m_CursorSelectionType = m_State.Data->VolatileDataAtSortPosition(1).is_selected() ? CursorSelectionType::Unselection : CursorSelectionType::Selection;
                    else // singular case - selection doesn't matter - nothing to select
                        m_CursorSelectionType = CursorSelectionType::Selection;
                }
            }
        }
}


- (void) mouseDown:(NSEvent *)_event
{
    m_LastPotentialRenamingLBDown = -1;
    
    NSPoint local_point = [self convertPoint:_event.locationInWindow fromView:nil];
    
    int old_cursor_pos = m_State.CursorPos;
    int cursor_pos = m_Presentation->GetItemIndexByPointInView(local_point, PanelViewHitTest::FullArea);
    if (cursor_pos == -1)
        return;

    auto &click_entry_vd = m_State.Data->VolatileDataAtSortPosition(cursor_pos);
    
    NSUInteger modifier_flags = _event.modifierFlags & NSDeviceIndependentModifierFlagsMask;
    bool lb_pressed = (NSEvent.pressedMouseButtons & 1) == 1;
    bool lb_cooldown = machtime() - m_ActivationTime < 300ms;
    
    // Select range of items with shift+click.
    // If clicked item is selected, then deselect the range instead.
    if(modifier_flags & NSShiftKeyMask)
        [self SelectUnselectInRange:old_cursor_pos >= 0 ? old_cursor_pos : 0
                      last_included:cursor_pos
                             select:!click_entry_vd.is_selected()];
    else if(modifier_flags & NSCommandKeyMask) // Select or deselect a single item with cmd+click.
        [self SelectUnselectInRange:cursor_pos
                      last_included:cursor_pos
                             select:!click_entry_vd.is_selected()];
    
    m_Presentation->SetCursorPos(cursor_pos);
    
    if(old_cursor_pos != cursor_pos)
        [self OnCursorPositionChanged];
    else if(lb_pressed && !lb_cooldown)
        m_LastPotentialRenamingLBDown = cursor_pos; // need more complex logic here (?)

    if(lb_pressed && self.active && !lb_cooldown) {
        m_ReadyToDrag = true;
        m_LButtonDownPos = local_point;
    }
}

- (NSMenu *)menuForEvent:(NSEvent *)_event
{
    [self mouseDown:_event]; // interpret right mouse downs or ctrl+left mouse downs as regular mouse down
    
    NSPoint local_point = [self convertPoint:_event.locationInWindow fromView:nil];
    int cursor_pos = m_Presentation->GetItemIndexByPointInView(local_point, PanelViewHitTest::FullArea);
    if (cursor_pos >= 0) {
        self.needsDisplay = true; // force immediately redraw on any rbc since by default there's a delay by invalidate timer and
                                  // in this case it wont be fired before menu showed
        return [self.delegate PanelViewRequestsContextMenu:self];
    }
    return nil;
}

- (void) mouseDragged:(NSEvent *)_event
{
    if(m_ReadyToDrag)
    {
        NSPoint lp = [self convertPoint:_event.locationInWindow fromView:nil];
        if(hypot(lp.x - m_LButtonDownPos.x, lp.y - m_LButtonDownPos.y) > 5)
        {
            [self.delegate PanelViewWantsDragAndDrop:self event:_event];
            m_ReadyToDrag = false;
            m_LastPotentialRenamingLBDown = -1;
        }
    }
}

- (void) mouseUp:(NSEvent *)_event
{
    int click_count = (int)_event.clickCount;
    NSPoint local_point = [self convertPoint:_event.locationInWindow fromView:nil];
    int cursor_pos = m_Presentation->GetItemIndexByPointInView(local_point, PanelViewHitTest::FullArea);

    if( click_count <= 1 ) {
        if( m_LastPotentialRenamingLBDown >= 0 && m_LastPotentialRenamingLBDown == cursor_pos ) {
            static const nanoseconds delay = milliseconds( int(NSEvent.doubleClickInterval*1000) );
            uint64_t renaming_ticket = ++m_FieldRenamingRequestTicket;
            dispatch_to_main_queue_after(delay,[=]{
                               if(renaming_ticket == m_FieldRenamingRequestTicket)
                                   [self startFieldEditorRenamingByEvent:_event];
                           });
        }
    }
    else if( click_count == 2 || click_count == 4 || click_count == 6 || click_count == 8 ) {
        // Handle double-or-four-etc clicks as double-click
        ++m_FieldRenamingRequestTicket; // to abort field editing
        if(cursor_pos >= 0 && cursor_pos == m_State.CursorPos)
            [self.delegate PanelViewDoubleClick:self atElement:cursor_pos];
    }

    m_ReadyToDrag = false;
    m_LastPotentialRenamingLBDown = -1;
}

- (void)scrollWheel:(NSEvent *)_event
{
    if (!self.active) // will react only on active panels
        return;
    
    if(m_DisableCurrentMomentumScroll == true &&
       _event.phase == NSEventPhaseNone &&
       _event.momentumPhase != NSEventPhaseNone )
        return; // momentum scroll is temporary disabled due to folder change or quick search.
    m_DisableCurrentMomentumScroll = false;    
    if(_event.momentumPhase == NSEventPhaseBegan)
        m_IsCurrentlyMomentumScroll = true;
    else if(_event.momentumPhase == NSEventPhaseEnded)
        m_IsCurrentlyMomentumScroll = false;
    
    const double item_height = m_Presentation->GetSingleItemHeight();
    m_ScrollDY += _event.hasPreciseScrollingDeltas ? _event.scrollingDeltaY : _event.deltaY * item_height;
    int idx = int(_event.deltaX/2.0); // less sensitive than vertical scrolling
    int old_curpos = m_State.CursorPos, old_offset = m_State.ItemsDisplayOffset;
    
    if(fabs(m_ScrollDY) >= item_height) {
        const double sgn = m_ScrollDY / fabs(m_ScrollDY);
        for(;fabs(m_ScrollDY) >= item_height; m_ScrollDY -= item_height * sgn)
            m_Presentation->ScrollCursor(0, int(sgn));
    }
    else if(idx != 0)
        m_Presentation->ScrollCursor(idx, 0);

    if(old_curpos != m_State.CursorPos || old_offset != m_State.ItemsDisplayOffset)
        [self OnCursorPositionChanged];
}

- (VFSFlexibleListingItem)item
{
    return m_State.Data->EntryAtSortPosition(m_State.CursorPos);
}

- (PanelVolatileData &)item_vd
{
    return m_State.Data->VolatileDataAtSortPosition(m_State.CursorPos);
}

- (void) SelectUnselectInRange:(int)_start last_included:(int)_end select:(BOOL)_select
{
    assert( dispatch_is_main_queue() );
    if(_start < 0 || _start >= m_State.Data->SortedDirectoryEntries().size() ||
         _end < 0 || _end >= m_State.Data->SortedDirectoryEntries().size() ) {
        NSLog(@"SelectUnselectInRange - invalid range");
        return;
    }
    
    if(_start > _end)
        swap(_start, _end);
    
    // we never want to select a first (dotdot) entry
    if( auto i = m_State.Data->EntryAtSortPosition(_start) )
        if( i.IsDotDot() )
            ++_start; // we don't want to select or unselect a dotdot entry - they are higher than that stuff
    
    for(int i = _start; i <= _end; ++i)
        m_State.Data->CustomFlagsSelectSorted(i, _select);
    
    [self setNeedsDisplay];
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

- (void) setType:(PanelViewType)_type
{
    m_State.ViewType = _type;
    if (m_Presentation) m_Presentation->EnsureCursorIsVisible();
    [self commitFieldEditor];
    self.needsDisplay = true;
}

- (PanelViewType)type
{
    return m_State.ViewType;
}

- (void) SavePathState
{
    assert( dispatch_is_main_queue() );
    if(!m_State.Data || !m_State.Data->Listing().IsUniform())
        return;
    
    auto &listing = m_State.Data->Listing();
    
    auto item = self.item;
    if( !item )
        return;
    
    auto path = VFSPathStack( listing.Host(), listing.Directory() );
    auto &storage = m_States[hash<VFSPathStack>()(path)];
    
    storage.focused_item = item.Name();
    storage.dispay_offset = m_State.ItemsDisplayOffset;
}

- (void) LoadPathState
{
    assert( dispatch_is_main_queue() );
    if(!m_State.Data || !m_State.Data->Listing().IsUniform())
        return;
    
    auto &listing = m_State.Data->Listing();
    
    auto path = VFSPathStack( listing.Host(), listing.Directory() );
    auto it = m_States.find(hash<VFSPathStack>()(path));
    if(it == end(m_States))
        return;
    
    auto &storage = it->second;
    int cursor = m_State.Data->SortedIndexForName(storage.focused_item.c_str());
    if(cursor < 0)
        return;
    
    m_State.ItemsDisplayOffset = storage.dispay_offset;
    m_Presentation->SetCursorPos(cursor);
    [self OnCursorPositionChanged];
}

- (void)directoryChangedWithFocusedFilename:(const string&)_focused_filename loadPreviousState:(bool)_load
{
    assert( dispatch_is_main_queue() );
    m_State.ItemsDisplayOffset = 0;
    m_State.CursorPos = -1;
    
    if(_load)
        [self LoadPathState];
    
    int cur = m_State.Data->SortedIndexForName(_focused_filename.c_str());
    if(cur >= 0) {
        m_Presentation->SetCursorPos(cur);
        [self OnCursorPositionChanged];
    }
    
    if(m_State.CursorPos < 0 &&
       m_State.Data->SortedDirectoryEntries().size() > 0) {
        m_Presentation->SetCursorPos(0);
        [self OnCursorPositionChanged];        
    }
    
    [self disableCurrentMomentumScroll];
    [self discardFieldEditor];
    m_Presentation->OnDirectoryChanged();
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

- (void)startFieldEditorRenamingByEvent:(NSEvent*)_event
{
    NSPoint local_point = [self convertPoint:_event.locationInWindow fromView:nil];
    int cursor_pos = m_Presentation->GetItemIndexByPointInView(local_point, PanelViewHitTest::FilenameFact);
    if (cursor_pos < 0 || cursor_pos != m_State.CursorPos)
        return;
    
    [self startFieldEditorRenaming];
}

- (void)startFieldEditorRenaming
{
    int cursor_pos = m_State.CursorPos;
    if(!m_Presentation->IsItemVisible(cursor_pos))
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
    NSRange sel_range = NSMakeRange(0, tv.string.length); // select whole filename by default
    if(self.item.HasExtension()) { // find where extension starts and select filename only
        NSRange r = [tv.string rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"."]
                                               options:NSBackwardsSearch];
        if(r.location > 0)
            sel_range = NSMakeRange(0, r.location);
    }
    tv.selectedRange = sel_range;
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
    
    m_Presentation->SetupFieldRenaming(m_RenamingEditor, cursor_pos);

    [self addSubview:m_RenamingEditor];
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
    
    if(self.window.firstResponder == nil || self.window.firstResponder == self.window)
        [self.window makeFirstResponder:self];
}

- (NSArray *)textView:(NSTextView *)textView completions:(NSArray *)words forPartialWordRange:(NSRange)charRange indexOfSelectedItem:(NSInteger *)index
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
    [self setNeedsDisplay];
}

- (void) setQuickSearchPrompt:(NSString*)_text
{
    m_Presentation->SetQuickSearchPrompt(_text);
    [self setNeedsDisplay];
}

- (void) disableCurrentMomentumScroll
{
    if(m_IsCurrentlyMomentumScroll)
        m_DisableCurrentMomentumScroll = true;
}

- (int) sortedItemPosAtPoint:(NSPoint)_point hitTestOption:(PanelViewHitTest::Options)_options;
{
    assert(dispatch_is_main_queue());
    int pos = m_Presentation->GetItemIndexByPointInView(_point, _options);
    if(pos < 0)
        return -1;
    
    auto item = m_State.Data->EntryAtSortPosition(pos);
    if(!item)
        return -1;
    return pos;
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
    self.needsDisplay = true;
}

- (void) windowDidResignKey
{
    self.needsDisplay = true;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (object == AppDelegate.me && [keyPath isEqualToString:@"skin"]) {
        auto skin = AppDelegate.me.skin;
        if (skin == ApplicationSkin::Modern)
            [self setPresentation:make_unique<ModernPanelViewPresentation>()];
        else if(skin == ApplicationSkin::Classic)
            [self setPresentation:make_unique<ClassicPanelViewPresentation>()];
    }
}

@end

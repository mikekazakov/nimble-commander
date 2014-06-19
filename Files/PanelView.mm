//
//  PanelView.m
//  Directories
//
//  Created by Michael G. Kazakov on 08.02.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "PanelView.h"
#import "PanelData.h"
#import "PanelViewPresentation.h"
#import "Common.h"
#import "VFS.h"

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
    PanelViewPresentation      *m_Presentation;
    PanelViewState              m_State;
    
    map<hash<VFSPathStack>::value_type, PanelViewStateStorage> m_States;
    
    NSScrollView               *m_RenamingEditor; // NSTextView inside
    
    
    double                      m_ScrollDY;
    
    bool                        m_ReadyToDrag;
    NSPoint                     m_LButtonDownPos;
    bool                        m_DraggingIntoMe;
    bool                        m_IsCurrentlyMomentumScroll;
    bool                        m_DisableCurrentMomentumScroll;
    int                         m_LastPotentialRenamingLBDown; // -1 if there's no such
    __weak id<PanelViewDelegate> m_Delegate;
}


- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        m_DraggingIntoMe = false;
        m_ScrollDY = 0.0;
        m_DisableCurrentMomentumScroll = false;
        m_IsCurrentlyMomentumScroll = false;
        m_LastPotentialRenamingLBDown = -1;
        
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(frameDidChange)
                                                   name:NSViewFrameDidChangeNotification
                                                 object:self];
        [self frameDidChange];
        
    }
    
    return self;
}

-(void) dealloc
{
    m_State.Data = nullptr;
    delete m_Presentation;
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void) setDelegate:(id<PanelViewDelegate>)delegate
{
    m_Delegate = delegate;
    if(delegate)
    {
        id<PanelViewDelegate> del = m_Delegate;
        if([del isKindOfClass:NSResponder.class])
        {
            NSResponder *r = (NSResponder*)del;
            NSResponder *current = self.nextResponder;
            super.nextResponder = r;
            r.nextResponder = current;
        }
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
    [self setNeedsDisplay:true];
    return YES;
}

- (BOOL)resignFirstResponder
{
    m_ReadyToDrag = false;
    m_LastPotentialRenamingLBDown = -1;
    [self setNeedsDisplay:true];
    return YES;
}

- (void)setNextResponder:(NSResponder *)newNextResponder
{
    if(self.delegate && [self.delegate isKindOfClass:NSResponder.class])
    {
        NSResponder *r = (NSResponder*)self.delegate;
        r.nextResponder = newNextResponder;
        return;
    }
    
    [super setNextResponder:newNextResponder];
}

- (void)viewWillMoveToWindow:(NSWindow *)_wnd
{
    if(_wnd == nil && self.active == true)
        [self resignFirstResponder];
}

- (bool)active
{
    return self.window == nil ? false : self.window.firstResponder == self;
}

- (void)drawRect:(NSRect)dirtyRect
{
    if (!m_State.Data || !m_Presentation) return;
    m_Presentation->Draw(dirtyRect);
    
    if(m_DraggingIntoMe) {
        [NSGraphicsContext saveGraphicsState];
        NSSetFocusRingStyle(NSFocusRingOnly);
        [[NSBezierPath bezierPathWithRect:NSInsetRect(self.bounds,2,2)] fill];
        [NSGraphicsContext restoreGraphicsState];
    }
    
    if(m_RenamingEditor) {
        [NSGraphicsContext saveGraphicsState];
        NSSetFocusRingStyle(NSFocusRingOnly);
        [[NSBezierPath bezierPathWithRect:m_RenamingEditor.frame] fill];
        [NSGraphicsContext restoreGraphicsState];
    }
}

- (void)frameDidChange
{
    if (m_Presentation)
        m_Presentation->OnFrameChanged([self frame]);
    [self cancelFieldEditor];
}

- (void) SetPanelData: (PanelData*) _data
{
    m_State.Data = _data;
    [self setNeedsDisplay:true];
}

- (void) SetPresentation:(PanelViewPresentation *)_presentation
{
    if (m_Presentation) delete m_Presentation;
    m_Presentation = _presentation;
    if (m_Presentation)
    {
        m_Presentation->SetState(&m_State);
        m_Presentation->SetView(self);
        [self frameDidChange];
        [self setNeedsDisplay:true];
    }
}

- (PanelViewPresentation*) Presentation
{
    return m_Presentation;
}

- (void) HandlePrevFile
{
    int origpos = m_State.CursorPos;
    
    m_Presentation->MoveCursorToPrevItem();
    
    if(m_CursorSelectionType != CursorSelectionType::No)
        [self SelectUnselectInRange:origpos last_included:origpos];
    
    [self OnCursorPositionChanged];
}

- (void) HandleNextFile
{
    int origpos = m_State.CursorPos;
    m_Presentation->MoveCursorToNextItem();
    
    [self SelectUnselectInRange:origpos last_included:origpos];
    [self OnCursorPositionChanged];
}

- (void) HandlePrevPage
{
    int origpos = m_State.CursorPos;
    m_Presentation->MoveCursorToPrevPage();

    [self SelectUnselectInRange:origpos last_included:m_State.CursorPos];
    [self OnCursorPositionChanged];
}

- (void) HandleNextPage
{
    int origpos = m_State.CursorPos;
    m_Presentation->MoveCursorToNextPage();

    [self SelectUnselectInRange:origpos last_included:m_State.CursorPos];
    [self OnCursorPositionChanged];
}

- (void) HandlePrevColumn
{
    int origpos = m_State.CursorPos;
    m_Presentation->MoveCursorToPrevColumn();
    
    [self SelectUnselectInRange:origpos last_included:m_State.CursorPos];
    [self OnCursorPositionChanged];
}

- (void) HandleNextColumn
{
    int origpos = m_State.CursorPos;
    m_Presentation->MoveCursorToNextColumn();

    [self SelectUnselectInRange:origpos last_included:m_State.CursorPos];
    [self OnCursorPositionChanged];
}

- (void) HandleFirstFile;
{
    int origpos = m_State.CursorPos;
    m_Presentation->MoveCursorToFirstItem();

    [self SelectUnselectInRange:origpos last_included:m_State.CursorPos];
    [self OnCursorPositionChanged];
}

- (void) HandleLastFile;
{
    int origpos = m_State.CursorPos;
    m_Presentation->MoveCursorToLastItem();

    [self SelectUnselectInRange:origpos last_included: m_State.CursorPos];
    [self OnCursorPositionChanged];
}

- (void) HandleInsert
{
    int origpos = m_State.CursorPos;
    m_Presentation->MoveCursorToNextItem();
    
    if(auto entry = m_State.Data->EntryAtSortPosition(origpos))
        [self SelectUnselectInRange:origpos
                      last_included:origpos
                             select:!entry->CFIsSelected()];
    
    [self OnCursorPositionChanged];
}

- (void) setCurpos:(int)_pos
{
//    assert(_pos >= 0 && _pos < m_State.Data->SortedDirectoryEntries().size());
    
    if (m_State.CursorPos == _pos) return;

    m_Presentation->SetCursorPos(_pos); // _pos wil be filtered here

    [self OnCursorPositionChanged];
}

- (int) curpos
{
    return m_State.CursorPos;
}

- (void) OnCursorPositionChanged
{
    [self setNeedsDisplay:true];
    
    if(id<PanelViewDelegate> del = self.delegate)
        if([del respondsToSelector:@selector(PanelViewCursorChanged:)])
            [del PanelViewCursorChanged:self];
    
    m_LastPotentialRenamingLBDown = -1;
    [self cancelFieldEditor];
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
    if((_flags & NSShiftKeyMask) == 0)
    { // clear selection type when user releases SHIFT button
        m_CursorSelectionType = CursorSelectionType::No;
    }
    else
    {
        if(m_CursorSelectionType == CursorSelectionType::No)
        { // lets decide if we need to select or unselect files when user will use navigation arrows
            if(const auto *item = self.item)
            {
                if(!item->IsDotDot())
                { // regular case
                    if(item->CFIsSelected()) m_CursorSelectionType = CursorSelectionType::Unselection;
                    else                     m_CursorSelectionType = CursorSelectionType::Selection;
                }
                else
                { // need to look at a first file (next to dotdot) for current representation if any.
                    if(m_State.Data->SortedDirectoryEntries().size() > 1)
                    { // using [1] item
                        const auto &item = m_State.Data->DirectoryEntries()[ m_State.Data->SortedDirectoryEntries()[1] ];
                        if(item.CFIsSelected()) m_CursorSelectionType = CursorSelectionType::Unselection;
                        else                     m_CursorSelectionType = CursorSelectionType::Selection;
                    }
                    else
                    { // singular case - selection doesn't matter - nothing to select
                        m_CursorSelectionType = CursorSelectionType::Selection;
                    }
                }
            }
        }
    }
}


- (void) mouseDown:(NSEvent *)_event
{
    m_LastPotentialRenamingLBDown = -1;
    
    NSPoint local_point = [self convertPoint:_event.locationInWindow fromView:nil];
    
    int old_cursor_pos = m_State.CursorPos;
    int cursor_pos = m_Presentation->GetItemIndexByPointInView(local_point);
    if (cursor_pos == -1) return;

    auto click_entry = m_State.Data->EntryAtSortPosition(cursor_pos);
    assert(click_entry);
    
    NSUInteger modifier_flags = _event.modifierFlags & NSDeviceIndependentModifierFlagsMask;
    
    // Select range of items with shift+click.
    // If clicked item is selected, then deselect the range instead.
    if(modifier_flags & NSShiftKeyMask)
        [self SelectUnselectInRange:old_cursor_pos >= 0 ? old_cursor_pos : 0
                      last_included:cursor_pos
                             select:!click_entry->CFIsSelected()];
    // Select or deselect a single item with cmd+click.
    else if(modifier_flags & NSCommandKeyMask)
        [self SelectUnselectInRange:cursor_pos
                      last_included:cursor_pos
                             select:!click_entry->CFIsSelected()];
    
    m_Presentation->SetCursorPos(cursor_pos);
    
    
    if(old_cursor_pos != cursor_pos)
    {
        [self OnCursorPositionChanged];
    }
    else
    {
        // need more complex logic here
        m_LastPotentialRenamingLBDown = cursor_pos;
    }

    if(self.active)
    {
        m_ReadyToDrag = true;
        m_LButtonDownPos = local_point;
    }
}

- (NSMenu *)menuForEvent:(NSEvent *)_event
{
    [self mouseDown:_event]; // interpret right mouse downs or ctrl+left mouse downs as regular mouse down
    
    NSPoint local_point = [self convertPoint:_event.locationInWindow fromView:nil];
    int cursor_pos = m_Presentation->GetItemIndexByPointInView(local_point);
    if (cursor_pos >= 0)
        return [self.delegate PanelViewRequestsContextMenu:self];
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
    NSPoint local_point = [self convertPoint:_event.locationInWindow fromView:nil];
    int cursor_pos = m_Presentation->GetItemIndexByPointInView(local_point);
    if(_event.clickCount <= 1 )
    {
        if(m_LastPotentialRenamingLBDown >= 0)
        {
            if(cursor_pos >= 0 && cursor_pos == m_LastPotentialRenamingLBDown)
                [self performSelector:@selector(startFieldEditorRenaming:)
                           withObject:_event
                           afterDelay:NSEvent.doubleClickInterval];
        }
    }
    else if(_event.clickCount == 2) // Handle double click mouse up
    {
        if(cursor_pos >= 0 && cursor_pos == m_State.CursorPos)
            [self.delegate PanelViewDoubleClick:self atElement:cursor_pos];
        
        [NSObject cancelPreviousPerformRequestsWithTarget:self];
    }
    else

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
        return; // momentum scroll is temporary disabled due to folder change.
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

- (const VFSListingItem*)item
{
    return m_State.Data->EntryAtSortPosition(m_State.CursorPos);
}

- (void) SelectUnselectInRange:(int)_start last_included:(int)_end select:(BOOL)_select
{
    
    // we never want to select a first (dotdot) entry
    assert(_start >= 0 && _start < m_State.Data->SortedDirectoryEntries().size());
    assert(_end >= 0 && _end < m_State.Data->SortedDirectoryEntries().size());
    if(_start > _end)
    {
        int t = _start;
        _start = _end;
        _end = t;
    }
    
    if(m_State.Data->DirectoryEntries()[m_State.Data->SortedDirectoryEntries()[_start]].IsDotDot())
        ++_start; // we don't want to select or unselect a dotdot entry - they are higher than that stuff
    
    for(int i = _start; i <= _end; ++i)
        m_State.Data->CustomFlagsSelectSorted(i, _select);
}

- (void) SelectUnselectInRange:(int)_start last_included:(int)_end
{
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
    [self cancelFieldEditor];
    [self setNeedsDisplay:true];
}

- (PanelViewType)type
{
    return m_State.ViewType;
}

- (void) SavePathState
{
    if(!m_State.Data)
        return;
    
    auto listing = m_State.Data->Listing();
    if(listing.get() == nullptr)
        return;
    
    auto item = self.item;
    if(item == nullptr)
        return;
    
    auto path = VFSPathStack(listing);
    auto &storage = m_States[hash<VFSPathStack>()(path)];
    
    storage.focused_item = item->Name();
    storage.dispay_offset = m_State.ItemsDisplayOffset;
}

- (void) LoadPathState
{
    if(!m_State.Data)
        return;
    
    auto listing = m_State.Data->Listing();
    if(listing.get() == nullptr)
        return;
    
    auto path = VFSPathStack(listing);
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

- (void) DirectoryChanged:(const char*)_focused_filename
{
    m_State.ItemsDisplayOffset = 0;
    m_State.CursorPos = -1;
    
    [self LoadPathState];
    
    int cur = m_State.Data->SortedIndexForName(_focused_filename);
    if(cur >= 0) {
        m_Presentation->SetCursorPos(cur);
        [self OnCursorPositionChanged];
    }
    
    if(m_State.CursorPos < 0 &&
       m_State.Data->SortedDirectoryEntries().size() > 0) {
        m_Presentation->SetCursorPos(0);
        [self OnCursorPositionChanged];        
    }
    
    if(m_IsCurrentlyMomentumScroll)
        m_DisableCurrentMomentumScroll = true;
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
    NSDragOperation result = NSDragOperationNone;
    if(id<PanelViewDelegate> del = self.delegate)
        if([del respondsToSelector:@selector(PanelViewDraggingEntered:sender:)])
            result = [del PanelViewDraggingEntered:self sender:sender];

    if(result != NSDragOperationNone && m_DraggingIntoMe == false) {
        m_DraggingIntoMe = true;
        [self setNeedsDisplay];
    }
    
    return result;
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
    NSDragOperation result = NSDragOperationNone;
    if(id<PanelViewDelegate> del = self.delegate)
        if([del respondsToSelector:@selector(PanelViewDraggingUpdated:sender:)])
            result = [del PanelViewDraggingUpdated:self sender:sender];
    
    if(result != NSDragOperationNone && m_DraggingIntoMe == false) {
        m_DraggingIntoMe = true;
        [self setNeedsDisplay];
    }
    
    return result;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
    m_DraggingIntoMe = false;
    [self setNeedsDisplay];
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
    m_DraggingIntoMe = false;
    [self setNeedsDisplay];
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

- (void)startFieldEditorRenaming:(NSEvent*)_event
{
    NSPoint local_point = [self convertPoint:_event.locationInWindow fromView:nil];
    int cursor_pos = m_Presentation->GetItemIndexByPointInView(local_point);
    if (cursor_pos < 0 || cursor_pos != m_State.CursorPos)
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
    tv.string = self.item->NSName().copy;
    tv.maxSize = NSMakeSize(FLT_MAX, FLT_MAX);
    tv.verticallyResizable = false;
    tv.horizontallyResizable = true;
    tv.autoresizingMask = NSViewWidthSizable;
    tv.textContainer.widthTracksTextView = true;
    tv.textContainer.heightTracksTextView = true;
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
    
    m_RenamingEditor.documentView = tv;
    
    m_Presentation->SetupFieldRenaming(m_RenamingEditor, cursor_pos);

    [self addSubview:m_RenamingEditor];
    [self.window makeFirstResponder:m_RenamingEditor];
}

- (void)cancelFieldEditor
{
    if(m_RenamingEditor)
    {
        [self.window makeFirstResponder:self];
        [m_RenamingEditor removeFromSuperview];
    }
}

- (BOOL)textShouldEndEditing:(NSText *)textObject
{
    assert(m_RenamingEditor != nil);
    NSTextView *tv = m_RenamingEditor.documentView;
    [self.delegate PanelViewRenamingFieldEditorFinished:self text:tv.string];
    return true;
}

- (void)textDidEndEditing:(NSNotification *)notification
{
    [m_RenamingEditor removeFromSuperview];
    m_RenamingEditor = nil;
    
    if(self.window.firstResponder == nil || self.window.firstResponder == self.window)
        [self.window makeFirstResponder:self];
}

- (NSArray *)textView:(NSTextView *)textView completions:(NSArray *)words forPartialWordRange:(NSRange)charRange indexOfSelectedItem:(NSInteger *)index
{
    return nil;
}

- (BOOL)textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector
{
    if(commandSelector == NSSelectorFromString(@"cancelOperation:"))
    {
        [self cancelFieldEditor];
        return true;
    }
    return false;
}

@end

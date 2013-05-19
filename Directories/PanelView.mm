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

#import "QuickPreview.h"
#import "PanelController.h"

#define ISUNICODECOMBININGCHARACTER(a) (\
    ((a) >= 0x0300 && (a) <= 0x036F) || \
    ((a) >= 0x1DC0 && (a) <= 0x1DFF) || \
    ((a) >= 0x20D0 && (a) <= 0x20FF) || \
    ((a) >= 0xFE20 && (a) <= 0xFE2F) )

struct CursorSelectionState
{
    enum Type
    {
        No,
        Selection,
        Unselection
    };
};

////////////////////////////////////////////////////////////////////////////////

@implementation PanelView
{
    __strong PanelController *m_Controller;

    unsigned long   m_KeysModifiersFlags;
    
    // Exists during mouse drag operations only.
    NSTimer *m_DragScrollTimer;
    // Possible values: -1, 0, 1.
    int m_DragScrollDirection;
    
    CursorSelectionState::Type m_CursorSelectionType;
    
    PanelViewPresentation *m_Presentation;
    PanelViewState m_State;
}

- (BOOL)isFlipped
{
    return YES;
}

- (BOOL)isOpaque
{
    return YES;
}

- (void) Activate
{
    if(m_State.Active == false)
    {
        m_State.Active = true;
        [self setNeedsDisplay:true];
    }
}

- (void) Disactivate
{
    if(m_State.Active == true)
    {
        m_State.Active = false;
        [self setNeedsDisplay:true];
    }
}

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        m_KeysModifiersFlags = 0;

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(frameDidChange)
                                                     name:NSViewFrameDidChangeNotification
                                                   object:self];
        [self frameDidChange];
    }
    
    return self;
}

-(void) dealloc
{
    if (m_Presentation) delete m_Presentation;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)drawRect:(NSRect)dirtyRect
{
    if (!m_State.Data || !m_Presentation) return;
    
    m_Presentation->Draw(dirtyRect);
}

- (void)frameDidChange
{
    if (m_Presentation)
        m_Presentation->OnFrameChanged([self frame]);
}

- (void) SetPanelController:(PanelController *)_controller
{
    m_Controller = _controller;
}

- (void) SetPanelData: (PanelData*) _data
{
    m_State.Data = _data;
    [self setNeedsDisplay:true];
}

- (void) DirectoryChanged:(PanelViewDirectoryChangeType)_type newcursor:(int)_cursor
{
    if (m_Presentation) m_Presentation->DirectoryChanged(_type, _cursor);
    [self setNeedsDisplay:true];
}

- (void) SetPresentation:(PanelViewPresentation *)_presentation
{
    if (m_Presentation) delete m_Presentation;
    m_Presentation = _presentation;
    if (m_Presentation)
    {
        m_Presentation->SetState(&m_State);
        [self frameDidChange];
        [self setNeedsDisplay:true];
    }
}

- (void)UpdateQuickPreview
{
    if ([QuickPreview IsVisible])
    {
        int rawpos = m_State.Data->SortedDirectoryEntries()[m_State.CursorPos];
        char path[__DARWIN_MAXPATHLEN];
        m_State.Data->ComposeFullPathForEntry(rawpos, path);
        NSString *nspath = [NSString stringWithUTF8String:path];
        [QuickPreview PreviewItem:nspath sender:self];
    }
}

- (void) HandlePrevFile
{
    int origpos = m_State.CursorPos;
    
    m_Presentation->MoveCursorToPrevItem();
    
    if(m_CursorSelectionType != CursorSelectionState::No)
        [self SelectUnselectInRange:origpos last_included:origpos];
    
    [self setNeedsDisplay:true];
    [self UpdateQuickPreview];
}

- (void) HandleNextFile
{
    int origpos = m_State.CursorPos;
    m_Presentation->MoveCursorToNextItem();
    
    if(m_CursorSelectionType != CursorSelectionState::No)
        [self SelectUnselectInRange:origpos last_included:origpos];
    
    [self setNeedsDisplay:true];
    [self UpdateQuickPreview];
}

- (void) HandlePrevPage
{
    int origpos = m_State.CursorPos;
    m_Presentation->MoveCursorToPrevPage();

    if(m_CursorSelectionType != CursorSelectionState::No)
        [self SelectUnselectInRange:origpos last_included:m_State.CursorPos];

    [self setNeedsDisplay:true];
    [self UpdateQuickPreview];
}

- (void) HandleNextPage
{
    int origpos = m_State.CursorPos;
    m_Presentation->MoveCursorToNextPage();

    if(m_CursorSelectionType != CursorSelectionState::No)
        [self SelectUnselectInRange:origpos last_included:m_State.CursorPos];    

    [self setNeedsDisplay:true];
    [self UpdateQuickPreview];
}

- (void) HandlePrevColumn
{
    int origpos = m_State.CursorPos;
    m_Presentation->MoveCursorToPrevColumn();
    
    if(m_CursorSelectionType != CursorSelectionState::No)
        [self SelectUnselectInRange:origpos last_included:m_State.CursorPos];
    
    [self setNeedsDisplay:true];
    [self UpdateQuickPreview];
}

- (void) HandleNextColumn
{
    int origpos = m_State.CursorPos;
    m_Presentation->MoveCursorToNextColumn();

    if(m_CursorSelectionType != CursorSelectionState::No)
        [self SelectUnselectInRange:origpos last_included:m_State.CursorPos];

    [self setNeedsDisplay:true];
    [self UpdateQuickPreview];
}

- (void) HandleFirstFile;
{
    int origpos = m_State.CursorPos;
    m_Presentation->MoveCursorToFirstItem();

    if(m_CursorSelectionType != CursorSelectionState::No)
        [self SelectUnselectInRange:origpos last_included:m_State.CursorPos];
    
    [self setNeedsDisplay:true];
    [self UpdateQuickPreview];
}

- (void) HandleLastFile;
{
    int origpos = m_State.CursorPos;
    m_Presentation->MoveCursorToLastItem();

    if(m_CursorSelectionType != CursorSelectionState::No)
        [self SelectUnselectInRange:origpos last_included: m_State.CursorPos];    

    [self setNeedsDisplay:true];
    [self UpdateQuickPreview];
}

- (void) SetCursorPosition:(int)_pos
{
    assert(_pos >= 0 && _pos < m_State.Data->SortedDirectoryEntries().size());
    
    if (m_State.CursorPos == _pos) return;

    m_Presentation->SetCursorPos(_pos);

    [self setNeedsDisplay:true];
    [self UpdateQuickPreview];
}

- (int) GetCursorPosition
{
    return m_State.CursorPos;
}

- (void) ModifierFlagsChanged:(unsigned long)_flags
{
    m_KeysModifiersFlags = _flags; // ??
    if((m_KeysModifiersFlags & NSShiftKeyMask) == 0)
    { // clear selection type when user releases SHIFT button
        m_CursorSelectionType = CursorSelectionState::No;
    }
    else
    {
        if(m_CursorSelectionType == CursorSelectionState::No)
        { // lets decide if we need to select or unselect files when user will use navigation arrows
            const auto *item = [self CurrentItem];
            if(item)
            {
                if(!item->isdotdot())
                { // regular case
                    if(item->cf_isselected()) m_CursorSelectionType = CursorSelectionState::Unselection;
                    else                     m_CursorSelectionType = CursorSelectionState::Selection;
                }
                else
                { // need to look at a first file (next to dotdot) for current representation if any.
                    if(m_State.Data->SortedDirectoryEntries().size() > 1)
                    { // using [1] item
                        const auto &item = m_State.Data->DirectoryEntries()[ m_State.Data->SortedDirectoryEntries()[1] ];
                        if(item.cf_isselected()) m_CursorSelectionType = CursorSelectionState::Unselection;
                        else                     m_CursorSelectionType = CursorSelectionState::Selection;
                    }
                    else
                    { // singular case - selection doesn't matter - nothing to select
                        m_CursorSelectionType = CursorSelectionState::Selection;
                    }
                }
            }
        }
    }
}

- (void) mouseDown:(NSEvent *)_event
{
    if (!m_State.Active)
        [m_Controller RequestActivation];
    
    NSPoint event_location = [_event locationInWindow];
    NSPoint local_point = [self convertPoint:event_location fromView:nil];
    
    int cursor_pos = m_Presentation->GetItemIndexByPointInView(local_point);
    if (cursor_pos == -1) return;
    
    NSUInteger modifier_flags = _event.modifierFlags & NSDeviceIndependentModifierFlagsMask;
    if ((modifier_flags & NSShiftKeyMask) == NSShiftKeyMask)
    {
        // Select range of items with shift+click.
        // If clicked item is selected, then deselect the range instead.
        assert(cursor_pos < m_State.Data->SortedDirectoryEntries().size());
        int raw_pos = m_State.Data->SortedDirectoryEntries()[cursor_pos];
        assert(raw_pos < m_State.Data->DirectoryEntries().size());
        const DirectoryEntryInformation &click_entry = m_State.Data->DirectoryEntries()[raw_pos];
        
        bool deselect = click_entry.cf_isselected();
        if (m_State.CursorPos == -1) m_State.CursorPos = 0;
        [self SelectUnselectInRange:m_State.CursorPos last_included:cursor_pos select:!deselect];
    }
    
    m_Presentation->SetCursorPos(cursor_pos);
    
    if ((modifier_flags & NSCommandKeyMask) == NSCommandKeyMask)
    {
        // Select or deselect a single item with cmd+click.
        const DirectoryEntryInformation *entry = [self CurrentItem];
        assert(entry);
        BOOL select = !entry->cf_isselected();
        [self SelectUnselectInRange:m_State.CursorPos last_included:m_State.CursorPos
                             select:select];
    }
    
    [self setNeedsDisplay:true];
    [self UpdateQuickPreview];
}

- (void) UpdateDragScroll
{
    assert(m_DragScrollDirection >= -1 && m_DragScrollDirection <= 1);
    
    if (m_DragScrollDirection == 0 || m_State.CursorPos == -1) return;
    
    int new_pos = m_State.CursorPos + m_DragScrollDirection;
    
    int max_pos = (int)m_State.Data->SortedDirectoryEntries().size();
    if (new_pos < 0) new_pos = 0;
    else if (new_pos >= max_pos) new_pos = max_pos - 1;
    
    [self SetCursorPosition:new_pos];
}

- (void) mouseDragged:(NSEvent *)_event
{
    NSPoint event_location = [_event locationInWindow];
    NSPoint local_point = [self convertPoint:event_location fromView:nil];
    
    // Check if mouse cursor position is inside or outside of files columns.
    NSRect columns_rect = m_Presentation->GetItemColumnsRect();
    if (local_point.y >= columns_rect.origin.y
        && local_point.y <= columns_rect.origin.y + columns_rect.size.height)
    {
        // Mouse cursor is inside files columns. Set cursor position.
        int cursor_pos = m_Presentation->GetItemIndexByPointInView(local_point);
        if (cursor_pos == -1) return;
        
        m_Presentation->SetCursorPos(cursor_pos);
        [self setNeedsDisplay:true];
        [self UpdateQuickPreview];
        
        // Stop cursor scrolling.
        m_DragScrollDirection = 0;
        
        return;
    }
    
    // Mouse cursor is outside file columns. Initiate cursor scrolling.
    m_DragScrollDirection = (local_point.y < columns_rect.origin.y ? -1 : 1);
    if (!m_DragScrollTimer)
    {
        m_DragScrollTimer = [NSTimer scheduledTimerWithTimeInterval:0.033
                                                             target:self
                                                           selector:@selector(UpdateDragScroll)
                                                           userInfo:nil
                                                            repeats:YES];
    }
}

- (void) mouseUp:(NSEvent *)_event
{
    // Reset drag scroll (release timer).
    if (m_DragScrollTimer)
    {
        [m_DragScrollTimer invalidate];
        m_DragScrollTimer = nil;
        m_DragScrollDirection = 0;
    }
    
    if ([_event clickCount] == 2)
    {
        // Handle double click.
        NSPoint event_location = [_event locationInWindow];
        NSPoint local_point = [self convertPoint:event_location fromView:nil];
        
        int cursor_pos = m_Presentation->GetItemIndexByPointInView(local_point);
        if (cursor_pos == -1 || cursor_pos != m_State.CursorPos) return;
        [m_Controller HandleReturnButton];
    }
}

- (void)scrollWheel:(NSEvent *)theEvent
{
    if (!m_State.Active) // will react only on active panels
        return;
    
    int idy = int([theEvent deltaY]);
    int idx = int([theEvent deltaX]/2.0); // less sensitive than vertical scrolling
    
    int old_curpos = m_State.CursorPos, old_offset = m_State.ItemsDisplayOffset;
    if(idy != 0)
        m_Presentation->ScrollCursor(0, idy);
    else if(idx != 0)
        m_Presentation->ScrollCursor(idx, 0);

    if(old_curpos != m_State.CursorPos || old_offset != m_State.ItemsDisplayOffset)
        [self setNeedsDisplay:true];
}

- (const DirectoryEntryInformation*) CurrentItem
{
    if(m_State.CursorPos < 0) return nullptr;
    assert(m_State.CursorPos < (int)m_State.Data->SortedDirectoryEntries().size());
    assert(m_State.Data->DirectoryEntries().size() >= m_State.Data->SortedDirectoryEntries().size());
    return &m_State.Data->DirectoryEntries()[ m_State.Data->SortedDirectoryEntries()[m_State.CursorPos] ];
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
    
    if(m_State.Data->DirectoryEntries()[m_State.Data->SortedDirectoryEntries()[_start]].isdotdot())
        ++_start; // we don't want to select or unselect a dotdot entry - they are higher than that stuff
    
    for(int i = _start; i <= _end; ++i)
        m_State.Data->CustomFlagsSelect(m_State.Data->SortedDirectoryEntries()[i], _select);
}

- (void) SelectUnselectInRange:(int)_start last_included:(int)_end
{
    assert(m_CursorSelectionType != CursorSelectionState::No);
    [self SelectUnselectInRange:_start last_included:_end
                         select:m_CursorSelectionType == CursorSelectionState::Selection];
}

- (void) ToggleViewType:(PanelViewType)_type
{
    m_State.ViewType = _type;
    if (m_Presentation) m_Presentation->EnsureCursorIsVisible();
    [self setNeedsDisplay:true];
}

- (PanelViewType) GetCurrentViewType
{
    return m_State.ViewType;
}

@end

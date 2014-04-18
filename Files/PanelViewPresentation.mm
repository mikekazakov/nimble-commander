//
//  PanelViewPresentation.cpp
//  Files
//
//  Created by Pavel Dogurevich on 06.05.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "PanelViewPresentation.h"
#import "PanelView.h"
#import "PanelData.h"
#import "Common.h"

PanelViewPresentation::~PanelViewPresentation()
{
    m_StatFSQueue->Wait();
}

void PanelViewPresentation::SetState(PanelViewState *_state)
{
    m_State = _state;
}

void PanelViewPresentation::SetView(PanelView *_view)
{
    m_View = _view;
}

void PanelViewPresentation::SetCursorPos(int _pos)
{
    m_State->CursorPos = -1;
    if(m_State->Data->SortedDirectoryEntries().size() > 0 &&
       _pos >= 0 &&
       _pos < m_State->Data->SortedDirectoryEntries().size())
        m_State->CursorPos = _pos;
    
    EnsureCursorIsVisible();
}

void PanelViewPresentation::ScrollCursor(int _idx, int _idy)
{
    if(m_State->Data->SortedDirectoryEntries().empty()) return;
    
    int total_items = (int)m_State->Data->SortedDirectoryEntries().size();
    int max_visible_items = GetMaxVisibleItems();
    int per_col = GetMaxItemsPerColumn();

    if (_idy != 0)
    {
        if(_idy > 0)
        {
            if(m_State->ItemsDisplayOffset > 0)
                m_State->ItemsDisplayOffset--;
            if(m_State->CursorPos > 0)
                m_State->CursorPos--;
        }
        else
        {
            if(m_State->ItemsDisplayOffset + max_visible_items < total_items)
                m_State->ItemsDisplayOffset++;
            if(m_State->CursorPos < total_items-1)
                m_State->CursorPos++;
        }
    }
    
    if (_idx != 0)
    {
        if(_idx > 0)
        {
            if(m_State->ItemsDisplayOffset > per_col)
                m_State->ItemsDisplayOffset -= per_col;
            else if(m_State->ItemsDisplayOffset > 0)
                m_State->ItemsDisplayOffset = 0;
            
            if(m_State->CursorPos > per_col)
                m_State->CursorPos -= per_col;
            else if(m_State->CursorPos > 0)
                m_State->CursorPos = 0;
        }
        else
        {
            if(m_State->ItemsDisplayOffset + max_visible_items < total_items)
                m_State->ItemsDisplayOffset += per_col;
            
            if(m_State->CursorPos + per_col < total_items - 1)
                m_State->CursorPos += per_col;
            else if(m_State->CursorPos < total_items - 1)
                m_State->CursorPos = total_items - 1;
        }
    }
}

void PanelViewPresentation::MoveCursorToNextItem()
{
    if(m_State->Data->SortedDirectoryEntries().empty()) return;
    
    if(m_State->CursorPos + 1 < m_State->Data->SortedDirectoryEntries().size())
        m_State->CursorPos++;
    EnsureCursorIsVisible();
}

void PanelViewPresentation::MoveCursorToPrevItem()
{
    if(m_State->Data->SortedDirectoryEntries().empty()) return;
    
    if(m_State->CursorPos > 0)
        m_State->CursorPos--;
    EnsureCursorIsVisible();
}

void PanelViewPresentation::MoveCursorToNextPage()
{
    if(m_State->Data->SortedDirectoryEntries().empty()) return;
    
    int total_items = (int)m_State->Data->SortedDirectoryEntries().size();
    int max_visible_items = GetMaxVisibleItems();
    
    if(m_State->CursorPos + max_visible_items < total_items)
        m_State->CursorPos += max_visible_items;
    else
        m_State->CursorPos = total_items - 1;
    
    if(m_State->ItemsDisplayOffset + max_visible_items*2 < total_items)
        m_State->ItemsDisplayOffset += max_visible_items;
    else if(total_items - max_visible_items > 0)
        m_State->ItemsDisplayOffset = total_items - max_visible_items;
}


void PanelViewPresentation::MoveCursorToPrevPage()
{
    if(m_State->Data->SortedDirectoryEntries().empty()) return;
    
    int max_visible_items = GetMaxVisibleItems();
    if(m_State->CursorPos > max_visible_items)
        m_State->CursorPos -=  max_visible_items;
    else
        m_State->CursorPos = 0;

    if(m_State->ItemsDisplayOffset > max_visible_items)
        m_State->ItemsDisplayOffset -= max_visible_items;
    else
        m_State->ItemsDisplayOffset = 0;
}

void PanelViewPresentation::MoveCursorToNextColumn()
{
    if(m_State->Data->SortedDirectoryEntries().empty()) return;
    
    int total_items = (int)m_State->Data->SortedDirectoryEntries().size();
    int items_per_column = GetMaxItemsPerColumn();
    int max_visible_items = GetMaxVisibleItems();
    
    if(m_State->CursorPos + items_per_column < total_items)
        m_State->CursorPos += items_per_column;
    else
        m_State->CursorPos = total_items - 1;
    
    if(m_State->ItemsDisplayOffset + max_visible_items <= m_State->CursorPos)
    {
        if(m_State->ItemsDisplayOffset + items_per_column + max_visible_items < total_items)
            m_State->ItemsDisplayOffset += items_per_column;
        else if(total_items - max_visible_items > 0)
            m_State->ItemsDisplayOffset = total_items - max_visible_items;
    }
}

void PanelViewPresentation::MoveCursorToPrevColumn()
{
    if(m_State->Data->SortedDirectoryEntries().empty()) return;
    
    int items_per_column = GetMaxItemsPerColumn();
    if(m_State->CursorPos > items_per_column)
        m_State->CursorPos -= items_per_column;
    else
        m_State->CursorPos = 0;

    if(m_State->CursorPos < m_State->ItemsDisplayOffset)
    {
        if(m_State->ItemsDisplayOffset > items_per_column)
            m_State->ItemsDisplayOffset -= items_per_column;
        else
            m_State->ItemsDisplayOffset = 0;
    }
}

void PanelViewPresentation::MoveCursorToFirstItem()
{
    if(m_State->Data->SortedDirectoryEntries().empty()) return;
    
    m_State->CursorPos = 0;
    m_State->ItemsDisplayOffset = 0;
}

void PanelViewPresentation::MoveCursorToLastItem()
{
    if(m_State->Data->SortedDirectoryEntries().empty()) return;
    
    int total_items = (int)m_State->Data->SortedDirectoryEntries().size();
    int max_visible_items = GetMaxVisibleItems();
    m_State->CursorPos = total_items - 1;

    if(total_items > max_visible_items)
        m_State->ItemsDisplayOffset = total_items - max_visible_items;
}

void PanelViewPresentation::EnsureCursorIsVisible()
{
    if(m_State->CursorPos < 0) return;
    
    int max_visible_items = GetMaxVisibleItems();
    
    // Check if cursor is above
    if(m_State->CursorPos < m_State->ItemsDisplayOffset)
    {
        m_State->ItemsDisplayOffset = m_State->CursorPos;
    }
    // check if cursor is below
    else if(m_State->CursorPos >= m_State->ItemsDisplayOffset + max_visible_items)
    {
        m_State->ItemsDisplayOffset = m_State->CursorPos - max_visible_items + 1;
    }
}

int PanelViewPresentation::GetMaxVisibleItems()
{
    return GetNumberOfItemColumns() * GetMaxItemsPerColumn();
}

void PanelViewPresentation::SetViewNeedsDisplay()
{
    [m_View setNeedsDisplay:YES];
}

void PanelViewPresentation::UpdateStatFS()
{
    // in usual redrawings - update not more that in 5 secs
    uint64_t now = GetTimeInNanoseconds();
    if(m_StatFSLastUpdate + 5*NSEC_PER_SEC < now ||
       m_StatFSLastHost != m_State->Data->Host().get() ||
       m_StatFSLastPath != m_State->Data->Listing()->RelativePath()
       )
    {
        m_StatFSLastUpdate = now;
        m_StatFSLastHost = m_State->Data->Host().get();
        m_StatFSLastPath = m_State->Data->Listing()->RelativePath();
        
        if(!m_StatFSQueue->Empty())
            return;

        auto host = m_State->Data->Host();
        auto listing = m_State->Data->Listing();
        m_StatFSQueue->Run(^{
            VFSStatFS stat;
            if(host->StatFS(listing->RelativePath(), stat, 0) == 0 &&
               stat != m_StatFS // force redrawing only if statfs has in fact changed
               )
            {
                assert(dispatch_is_main_queue() == false);
                dispatch_sync(dispatch_get_main_queue(), ^{
                    m_StatFS = stat;
                    SetViewNeedsDisplay();
                });
            }
        });
    }
}

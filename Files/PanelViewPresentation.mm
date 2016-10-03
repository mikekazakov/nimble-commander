//
//  PanelViewPresentation.cpp
//  Files
//
//  Created by Pavel Dogurevich on 06.05.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include <Habanero/CommonPaths.h>
#include <Utility/NSView+Sugar.h>
#include <VFS/Native.h>
#include "PanelViewPresentation.h"
#include "PanelView.h"
#include "PanelData.h"

static const auto g_ConfigFileSizeFormat = "filePanel.general.fileSizeFormat";
static const auto g_ConfigSelectionSizeFormat = "filePanel.general.selectionSizeFormat";
static const auto g_ConfigTrimmingMode = "filePanel.presentation.filenamesTrimmingMode";

PanelViewPresentation::PanelViewPresentation(PanelView *_parent_view, PanelViewState *_view_state):
    m_View(_parent_view),
    m_State(_view_state)
{
    auto reload_fmts = [=]{
        LoadSizeFormats();
        SetViewNeedsDisplay();
    };
    reload_fmts();
    m_ConfigObservations.emplace_back( GlobalConfig().Observe(g_ConfigFileSizeFormat, reload_fmts) );
    m_ConfigObservations.emplace_back( GlobalConfig().Observe(g_ConfigSelectionSizeFormat, reload_fmts) );
    
    auto reload_trim = [=]{
        SetTrimming( (PanelViewFilenameTrimming)GlobalConfig().GetInt(g_ConfigTrimmingMode) );
        SetViewNeedsDisplay();
    };
    reload_trim();
    m_ConfigObservations.emplace_back( GlobalConfig().Observe(g_ConfigTrimmingMode, reload_trim) );
}

PanelViewPresentation::~PanelViewPresentation()
{
    m_StatFSQueue->Wait();
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
    EnsureCursorIsVisible();
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
    int total_items = (int)m_State->Data->SortedDirectoryEntries().size();
    
    // Check if cursor is above
    if(m_State->CursorPos < m_State->ItemsDisplayOffset)
        m_State->ItemsDisplayOffset = m_State->CursorPos;
    // check if cursor is below
    else if(m_State->CursorPos >= m_State->ItemsDisplayOffset + max_visible_items)
        m_State->ItemsDisplayOffset = m_State->CursorPos - max_visible_items + 1;
    
    
    // check if there's a free space below cursor position and there are item above it
    if( total_items - m_State->ItemsDisplayOffset < max_visible_items)
        m_State->ItemsDisplayOffset = max(total_items - max_visible_items, 0);
    
    assert(m_State->CursorPos >= 0);
    assert(m_State->ItemsDisplayOffset >= 0);
}

int PanelViewPresentation::GetMaxVisibleItems() const
{
    return GetNumberOfItemColumns() * GetMaxItemsPerColumn();
}

void PanelViewPresentation::SetViewNeedsDisplay()
{
    [m_View setNeedsDisplay];
}

void PanelViewPresentation::UpdateStatFS()
{
    // in usual redrawings - update not more that in 5 secs
    nanoseconds now = machtime();

    VFSHostPtr current_host;
    string current_path;
    if( m_State->Data->Type() == PanelData::PanelType::Directory ) {
        // we're in regular directory somewhere
        current_host = m_State->Data->Host();
        current_path = m_State->Data->Listing().Directory();
    }
    else {
        // we're in temporary directory so there may be not common path and common host.
        // as current solution - display information about first item's directory
        if( auto i = m_State->Data->EntryAtRawPosition(0) ){
            current_host = i.Host();
            current_path = i.Directory();
        }
        else {
            // there's no first item (no items at all) - display information about home directory
            current_host = VFSNativeHost::SharedHost();
            current_path = CommonPaths::Home();
        }
    }
    
    if(m_StatFSLastUpdate + 5s < now ||
       m_StatFSLastHost != current_host.get() ||
       m_StatFSLastPath != current_path)
    {
        m_StatFSLastUpdate = now;
        m_StatFSLastHost = current_host.get();
        m_StatFSLastPath = current_path;
        
        if( !m_StatFSQueue->Empty() )
            return;

        m_StatFSQueue->Run([=](const shared_ptr<SerialQueueT> &_que){
            VFSStatFS stat;
            if( current_host->StatFS(current_path.c_str(), stat, 0) == 0 &&
                stat != m_StatFS // force redrawing only if statfs has in fact changed
                ) {
                assert( dispatch_is_main_queue() == false );
                if( _que->IsStopped() )
                    return;
                dispatch_sync(dispatch_get_main_queue(), ^{
                    m_StatFS = stat;
                    SetViewNeedsDisplay();
                });
            }
        });
    }
}

int PanelViewPresentation::GetNumberOfItemColumns() const
{
    switch(m_State->ViewType)
    {
        case PanelViewType::Short: return 3;
        case PanelViewType::Medium: return 2;
        case PanelViewType::Wide: return 1;
        case PanelViewType::Full: return 1;
    }
    assert(0);
    return 0;
}

bool PanelViewPresentation::IsItemVisible(int _item_no) const
{
    if(_item_no < 0) return false;
    return _item_no - m_State->ItemsDisplayOffset >= 0 &&
        _item_no - m_State->ItemsDisplayOffset < GetMaxVisibleItems();
}

void PanelViewPresentation::LoadSizeFormats()
{
    m_FileSizeFormat = (ByteCountFormatter::Type) GlobalConfig().GetInt(g_ConfigFileSizeFormat);
    m_SelectionSizeFormat = (ByteCountFormatter::Type) GlobalConfig().GetInt(g_ConfigSelectionSizeFormat);
}

void PanelViewPresentation::OnDirectoryChanged()
{
}

void PanelViewPresentation::OnPanelTitleChanged()
{
}

void PanelViewPresentation::SetTrimming(PanelViewFilenameTrimming _mode)
{
    m_Trimming = _mode;
}

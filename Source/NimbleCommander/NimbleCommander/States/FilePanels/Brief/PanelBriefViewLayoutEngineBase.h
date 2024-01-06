// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>
#include <vector>

namespace nc::panel::view::brief {

class LayoutEngineBase
{
public:
    int ItemsNumber() const noexcept;
    int ItemHeight() const noexcept;
    int RowsNumber() const noexcept;
    int ColumnsNumber() const noexcept;
    NSSize ContentSize() const noexcept;
    NSCollectionViewLayoutAttributes* AttributesForItemNumber(int _number) const noexcept;
    const std::vector<int> &ColumnsPositions() const noexcept;
    const std::vector<int> &ColumnsWidths() const noexcept;
    
protected:
    static int NumberOfRowsForViewHeight(double _view_height, int _item_height) noexcept;    
    NSArray<NSCollectionViewLayoutAttributes*> *
        LogarithmicSearchForItemsInRect(NSRect _rect) const noexcept;
    
    // input data:
    int m_ItemsNumber = 0;
    int m_ItemHeight = 20;    
    
    // inferred grid: 
    int m_RowsNumber = 0;
    int m_ColumnsNumber = 0;
    NSSize m_ContentSize = {0.0, 0.0};
    
    // inferred items layout: 
    std::vector<NSCollectionViewLayoutAttributes*> m_Attributes;
    std::vector<int> m_ColumnsPositions;
    std::vector<int> m_ColumnsWidths;
};

inline int LayoutEngineBase::ItemsNumber() const noexcept
{
    return m_ItemsNumber;
}
    
inline int LayoutEngineBase::ItemHeight() const noexcept
{
    return m_ItemHeight;
}
    
inline int LayoutEngineBase::RowsNumber() const noexcept
{
    return m_RowsNumber;
}

inline int LayoutEngineBase::ColumnsNumber() const noexcept
{
    return m_ColumnsNumber;
}
    
inline NSSize LayoutEngineBase::ContentSize() const noexcept
{
    return m_ContentSize;
}

inline NSCollectionViewLayoutAttributes*
    LayoutEngineBase::AttributesForItemNumber(int _number) const noexcept
{
    assert( _number >= 0 && _number < m_ItemsNumber );
    return m_Attributes[_number];
}

inline const std::vector<int> &
    LayoutEngineBase::ColumnsPositions() const noexcept
{
    return m_ColumnsPositions;        
}
    
inline const std::vector<int> &
    LayoutEngineBase::ColumnsWidths() const noexcept
{
    return m_ColumnsWidths;
}
    
}

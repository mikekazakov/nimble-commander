// Copyright (C) 2018-2026 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>
#include <vector>

namespace nc::panel::view::brief {

class LayoutEngineBase
{
public:
    [[nodiscard]] int ItemsNumber() const noexcept;
    [[nodiscard]] int ItemHeight() const noexcept;
    [[nodiscard]] int RowsNumber() const noexcept;
    [[nodiscard]] int ColumnsNumber() const noexcept;
    [[nodiscard]] NSSize ContentSize() const noexcept;
    [[nodiscard]] NSCollectionViewLayoutAttributes *AttributesForItemNumber(int _number) const noexcept;
    [[nodiscard]] const std::vector<int> &ColumnsPositions() const noexcept;
    [[nodiscard]] const std::vector<int> &ColumnsWidths() const noexcept;

protected:
    static int NumberOfRowsForViewHeight(double _view_height, int _item_height) noexcept;
    [[nodiscard]] NSArray<NSCollectionViewLayoutAttributes *> *
    LogarithmicSearchForItemsInRect(NSRect _rect) const noexcept;

    // NOLINTBEGIN(misc-non-private-member-variables-in-classes)

    // input data:
    int m_ItemsNumber = 0;
    int m_ItemHeight = 20;

    // inferred grid:
    int m_RowsNumber = 0;
    int m_ColumnsNumber = 0;
    NSSize m_ContentSize = {0.0, 0.0};

    // inferred items layout:
    std::vector<NSCollectionViewLayoutAttributes *> m_Attributes;
    std::vector<int> m_ColumnsPositions;
    std::vector<int> m_ColumnsWidths;

    // NOLINTEND(misc-non-private-member-variables-in-classes)
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

inline NSCollectionViewLayoutAttributes *LayoutEngineBase::AttributesForItemNumber(int _number) const noexcept
{
    assert(_number >= 0 && _number < m_ItemsNumber);
    return m_Attributes[_number];
}

inline const std::vector<int> &LayoutEngineBase::ColumnsPositions() const noexcept
{
    return m_ColumnsPositions;
}

inline const std::vector<int> &LayoutEngineBase::ColumnsWidths() const noexcept
{
    return m_ColumnsWidths;
}

} // namespace nc::panel::view::brief

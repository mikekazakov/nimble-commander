// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "PanelBriefViewLayoutEngineBase.h"

namespace nc::panel::view::brief {

class DynamicWidthLayoutEngine : public LayoutEngineBase
{
public:
    struct Params {
        int items_number = 0;
        int item_height = 20;
        int item_min_width = 50;
        int item_max_width = 200;
        const std::vector<short> *items_intrinsic_widths;
        NSRect clip_view_bounds = {{0.0, 0.0}, {0.0, 0.0}};
    };

    void Layout( const Params &_params );
    
    bool ShouldRelayoutForNewBounds(const NSRect clip_view_bounds) const noexcept;
    int ItemMinWidth() const noexcept;
    int ItemMaxWidth() const noexcept;
    NSArray<NSCollectionViewLayoutAttributes*> *
        AttributesForItemsInRect(NSRect _rect) const noexcept;
    
private:
    void CopyInputData( const Params &_params );
    void PerformNormalLayout( const Params &_params );
    void PerformSingularLayout( const Params &_params );
    
    // input data:    
    int m_ItemMinWidth = 50;
    int m_ItemMaxWidth = 200;
    // + intrinsic items widths, which we don't copy inside
};

    
inline int DynamicWidthLayoutEngine::ItemMinWidth() const noexcept
{
    return m_ItemMinWidth;
}

inline int DynamicWidthLayoutEngine::ItemMaxWidth() const noexcept
{
    return m_ItemMaxWidth;
}

}

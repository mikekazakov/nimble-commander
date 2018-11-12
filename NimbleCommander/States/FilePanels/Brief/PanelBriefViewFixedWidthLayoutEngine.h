// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "PanelBriefViewLayoutEngineBase.h"

namespace nc::panel::view::brief {

class FixedWidthLayoutEngine : public LayoutEngineBase
{
public:
    struct Params {
        int items_number = 0;
        int item_width = 100;
        int item_height = 20;
        NSRect clip_view_bounds = {{0.0, 0.0}, {0.0, 0.0}};
    };
    
    void Layout( const Params &_params );
    
    bool ShouldRelayoutForNewBounds(const NSRect clip_view_bounds) const noexcept;
    int ItemWidth() const noexcept;
    NSArray<NSCollectionViewLayoutAttributes*> *
        AttributesForItemsInRect(NSRect _rect) const noexcept;
    
private:
    void CopyInputData(const Params &_params);
    void BuildGrid(const Params &_params);
    void BuildItemsLayout();
        
    // input data:        
    int m_ItemWidth = 100;
};

inline int FixedWidthLayoutEngine::ItemWidth() const noexcept
{
    return m_ItemWidth;
}
    
}

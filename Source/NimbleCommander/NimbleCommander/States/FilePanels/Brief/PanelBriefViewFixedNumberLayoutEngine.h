// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "PanelBriefViewLayoutEngineBase.h"

namespace nc::panel::view::brief {

class FixedNumberLayoutEngine : public LayoutEngineBase
{
public:
    struct Params {
        int items_number = 0;
        int item_height = 20;
        int columns_per_screen = 3;
        NSRect clip_view_bounds = {{0.0, 0.0}, {0.0, 0.0}};
    };

    void Layout( const Params &_params );
    
    bool ShouldRelayoutForNewBounds(const NSRect clip_view_bounds) const noexcept;
    int ColumnsPerScreen() const noexcept;
    NSArray<NSCollectionViewLayoutAttributes*> *
        AttributesForItemsInRect(NSRect _rect) const noexcept;
    
private:
    void CopyInput( const Params &_params );
    void BuildGrid( const Params &_params );
    void PerformNormalLayout();
    void PerformSingularLayout();
        
    int m_ColumnsPerScreen = 3;
    int m_ClipViewWidth = 0;    
    int m_BaseColumnWidth = 100;
    int m_ScreenRemainder = 0;
    
};
/**  
 * We distrubute the remaining width in the following manner:
 * Screen size = 11;
 * Columns = 3;
 * Base column width = 3;
 * Widths:
 * |  4 |  4 | 3 | = 11 
 */

inline int FixedNumberLayoutEngine::ColumnsPerScreen() const noexcept
{
    return m_ColumnsPerScreen; 
}

}

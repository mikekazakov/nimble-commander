#pragma once

#include "PanelViewKeystrokeSink.h"

class GenericConfig;

namespace nc::panel {
namespace data {
class Model;
}
    
namespace QuickSearch {

enum class KeyModif { // persistancy-bound values, don't change it
    WithAlt         = 0,
    WithCtrlAlt     = 1,
    WithShiftAlt    = 2,
    WithoutModif    = 3,
    Disabled        = 4
};
    
constexpr auto g_ConfigQuickSearchWhereToFind   = "filePanel.quickSearch.whereToFind";
constexpr auto g_ConfigQuickSearchSoftFiltering = "filePanel.quickSearch.softFiltering";
constexpr auto g_ConfigQuickSearchTypingView    = "filePanel.quickSearch.typingView";
constexpr auto g_ConfigQuickSearchKeyOption     = "filePanel.quickSearch.keyOption";
}
}

@interface NCPanelQuickSearch : NSObject<NCPanelViewKeystrokeSink>

- (instancetype)initWithView:(PanelView*)_view
                        data:(nc::panel::data::Model&)_data
                      config:(GenericConfig&)_config;

- (void)setSearchCriteria:(NSString*)_request; // pass nil to discard filtering
- (NSString*)searchCriteria; // will return nil if there's no filtering

@end

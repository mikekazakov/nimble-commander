// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Config/Config.h>
#include "PanelViewKeystrokeSink.h"


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
    
constexpr auto g_ConfigWhereToFind      = "filePanel.quickSearch.whereToFind";
constexpr auto g_ConfigIsSoftFiltering  = "filePanel.quickSearch.softFiltering";
constexpr auto g_ConfigTypingView       = "filePanel.quickSearch.typingView";
constexpr auto g_ConfigKeyOption        = "filePanel.quickSearch.keyOption";

}
}

@class NCPanelQuickSearch;

@protocol NCPanelQuickSearchDelegate<NSObject>
@required

- (int) quickSearchNeedsCursorPosition:(NCPanelQuickSearch*)_qs;
- (void) quickSearch:(NCPanelQuickSearch*)_qs wantsToSetCursorPosition:(int)_cursor_position;
- (void) quickSearchHasChangedVolatileData:(NCPanelQuickSearch*)_qs;
- (void) quickSearchHasUpdatedData:(NCPanelQuickSearch*)_qs;
- (void) quickSearch:(NCPanelQuickSearch*)_qs
wantsToSetSearchPrompt:(NSString*)_prompt
    withMatchesCount:(int)_count;

@end

@interface NCPanelQuickSearch : NSObject<NCPanelViewKeystrokeSink>

- (instancetype)initWithData:(nc::panel::data::Model&)_data
                    delegate:(NSObject<NCPanelQuickSearchDelegate>*)_delegate
                      config:(nc::config::Config&)_config;

- (void)setSearchCriteria:(NSString*)_request; // pass nil to discard filtering
- (NSString*)searchCriteria; // will return nil if there's no filtering

@end

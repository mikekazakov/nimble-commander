// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "PanelViewPresentationItemsColoringFilter.h"
#include <Config/Config.h>

namespace nc::panel {

class PresentationItemsColoringFilterPersitence
{
public:
    static config::Value ToJSON(const PresentationItemsColoringFilter &_filter);
    static PresentationItemsColoringFilter FromJSON(const config::Value &_value);
};

class PresentationItemsColoringRulePersistence
{
public:
    static config::Value ToJSON(const PresentationItemsColoringRule &_rule);
    static PresentationItemsColoringRule FromJSON(const config::Value &_value);
};

} // namespace nc::panel

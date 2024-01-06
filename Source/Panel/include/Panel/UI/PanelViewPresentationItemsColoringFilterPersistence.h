// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "PanelViewPresentationItemsColoringFilter.h"
#include <Config/Config.h>

namespace nc::panel {
    
class PresentationItemsColoringFilterPersitence
{
public:
    config::Value ToJSON(const PresentationItemsColoringFilter& _filter) const;
    PresentationItemsColoringFilter FromJSON(const config::Value& _value) const;
};
    
class PresentationItemsColoringRulePersistence
{
public:
    config::Value ToJSON(const PresentationItemsColoringRule& _rule) const;
    PresentationItemsColoringRule FromJSON(const config::Value& _value) const;
};
    
    
}

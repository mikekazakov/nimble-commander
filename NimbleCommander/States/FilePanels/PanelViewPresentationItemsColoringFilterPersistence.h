// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "PanelViewPresentationItemsColoringFilter.h" 

// TODO: reroute this dependency:
#include "../../Bootstrap/Config.h"

namespace nc::panel {
    
class PresentationItemsColoringFilterPersitence
{
public:
    GenericConfig::ConfigValue ToJSON(const PresentationItemsColoringFilter& _filter) const;
    PresentationItemsColoringFilter FromJSON(const GenericConfig::ConfigValue& _value) const;
};
    
class PresentationItemsColoringRulePersistence
{
public:
    GenericConfig::ConfigValue ToJSON(const PresentationItemsColoringRule& _rule) const;
    PresentationItemsColoringRule FromJSON(const GenericConfig::ConfigValue& _value) const;
};
    
    
}

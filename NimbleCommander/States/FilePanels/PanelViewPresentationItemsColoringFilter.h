// Copyright (C) 2014-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>
#include "../../Core/FileMask.h"
#include "PanelDataItemVolatileData.h"
#include "../../Bootstrap/Config.h"

struct PanelViewPresentationItemsColoringFilter
{
    // consider optimizing FileMask for trivial cases or write a different mech for extensions specifically,
    // since NSRegularExpression is too heavy mech for real-time(on draw) usage
    FileMask mask      = "";            // based on VFSListingItem.NSDisplayName
    tribool executable = indeterminate; // based on unix exec flag
    tribool hidden     = indeterminate; // based on VFSListingItem.IsHidden
    tribool directory  = indeterminate; // based on VFSListingItem.IsDir
    tribool symlink    = indeterminate; // based on VFSListingItem.IsSymlink
    tribool reg        = indeterminate; // based on VFSListingItem.IsReg
    tribool selected   = indeterminate; // based on VFSListingItem.CFIsSelected
    
    /**
     * Return true if all filtering options are in non-set state.
     */
    bool IsEmpty() const;
    
    /**
     * Will return true if no defined filters fail to accept _item.
     * If any defined filter disagree with _item - will return false immediately.
     * Any empty coloring filter will return true on any _item.
     */
    bool Filter(const VFSListingItem& _item, const nc::panel::data::ItemVolatileData &_item_vd) const;
    
    /**
     * Persistance support - store values in a dictionary.
     */
    GenericConfig::ConfigValue ToJSON() const;
    
    /**
     * Persistance support - build filter from a dictionary.
     */
    static PanelViewPresentationItemsColoringFilter FromJSON(const GenericConfig::ConfigValue& _v);
    
    bool operator==(const PanelViewPresentationItemsColoringFilter&_rhs) const noexcept;
    bool operator!=(const PanelViewPresentationItemsColoringFilter&_rhs) const noexcept;
};

struct PanelViewPresentationItemsColoringRule
{
    string                                      name;
    NSColor                                     *regular = NSColor.blackColor; // all others state text color
    NSColor                                     *focused = NSColor.blackColor; // focused text color
    PanelViewPresentationItemsColoringFilter    filter;
    
    GenericConfig::ConfigValue ToJSON() const;
    static PanelViewPresentationItemsColoringRule FromJSON(const GenericConfig::ConfigValue& _v);
    bool operator==(const PanelViewPresentationItemsColoringRule&_rhs) const noexcept;
    bool operator!=(const PanelViewPresentationItemsColoringRule&_rhs) const noexcept;
};

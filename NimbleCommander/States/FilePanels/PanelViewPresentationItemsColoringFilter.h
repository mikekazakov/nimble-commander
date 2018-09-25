// Copyright (C) 2014-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>
#include <Habanero/tribool.h>
#include "../../Core/FileMask.h"
#include "PanelDataItemVolatileData.h"
#include "../../Bootstrap/Config.h"

namespace nc::panel {

struct PresentationItemsColoringFilter
{
    // consider optimizing FileMask for trivial cases or write a different mech for extensions specifically,
    // since NSRegularExpression is too heavy mech for real-time(on draw) usage
    FileMask mask      = "";            // based on VFSListingItem.NSDisplayName
    hbn::tribool executable = hbn::indeterminate; // based on unix exec flag
    hbn::tribool hidden     = hbn::indeterminate; // based on VFSListingItem.IsHidden
    hbn::tribool directory  = hbn::indeterminate; // based on VFSListingItem.IsDir
    hbn::tribool symlink    = hbn::indeterminate; // based on VFSListingItem.IsSymlink
    hbn::tribool reg        = hbn::indeterminate; // based on VFSListingItem.IsReg
    hbn::tribool selected   = hbn::indeterminate; // based on VFSListingItem.CFIsSelected
    
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
    static PresentationItemsColoringFilter FromJSON(const GenericConfig::ConfigValue& _v);
    
    bool operator==(const PresentationItemsColoringFilter&_rhs) const noexcept;
    bool operator!=(const PresentationItemsColoringFilter&_rhs) const noexcept;
};

struct PresentationItemsColoringRule
{
    string                                      name;
    NSColor                                     *regular = NSColor.blackColor; // all others state text color
    NSColor                                     *focused = NSColor.blackColor; // focused text color
    PresentationItemsColoringFilter             filter;
    
    GenericConfig::ConfigValue ToJSON() const;
    static PresentationItemsColoringRule FromJSON(const GenericConfig::ConfigValue& _v);
    bool operator==(const PresentationItemsColoringRule&_rhs) const noexcept;
    bool operator!=(const PresentationItemsColoringRule&_rhs) const noexcept;
};

}

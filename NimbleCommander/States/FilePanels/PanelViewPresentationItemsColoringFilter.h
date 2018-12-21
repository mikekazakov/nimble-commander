// Copyright (C) 2014-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>
#include <Habanero/tribool.h>
#include <Utility/FileMask.h>
#include "PanelDataItemVolatileData.h"
#include <Cocoa/Cocoa.h>

namespace nc::panel {

struct PresentationItemsColoringFilter
{
    utility::FileMask mask  = "";                 // based on VFSListingItem.NSDisplayName
    hbn::tribool executable = hbn::indeterminate; // based on unix exec flag
    hbn::tribool hidden     = hbn::indeterminate; // based on VFSListingItem.IsHidden
    hbn::tribool directory  = hbn::indeterminate; // based on VFSListingItem.IsDir
    hbn::tribool symlink    = hbn::indeterminate; // based on VFSListingItem.IsSymlink
    hbn::tribool reg        = hbn::indeterminate; // based on VFSListingItem.IsReg
    hbn::tribool selected   = hbn::indeterminate; // based on ItemVolatileData.flag_selected
    
    /**
     * Return true if all filtering options are in non-set state.
     */
    bool IsEmpty() const;
    
    /**
     * Will return true if no defined filters fail to accept _item.
     * If any defined filter disagree with _item - will return false immediately.
     * Any empty coloring filter will return true on any _item.
     */
    bool Filter(const VFSListingItem& _item,
                const data::ItemVolatileData &_item_vd) const;
    
};
    
bool operator==(const PresentationItemsColoringFilter&_lhs,
                const PresentationItemsColoringFilter&_rhs) noexcept;
bool operator!=(const PresentationItemsColoringFilter&_lhs,
                const PresentationItemsColoringFilter&_rhs) noexcept;

struct PresentationItemsColoringRule
{
    std::string                     name;
    NSColor                        *regular = NSColor.blackColor; // all others state text color
    NSColor                        *focused = NSColor.blackColor; // focused text color
    PresentationItemsColoringFilter filter;    
};
    
bool operator==(const PresentationItemsColoringRule&_lhs,
                const PresentationItemsColoringRule&_rhs) noexcept;
bool operator!=(const PresentationItemsColoringRule&_lhs,
                const PresentationItemsColoringRule&_rhs) noexcept;

}

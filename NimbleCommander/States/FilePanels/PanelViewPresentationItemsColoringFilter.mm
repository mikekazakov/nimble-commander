// Copyright (C) 2014-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include <sys/stat.h>
#include "PanelViewPresentationItemsColoringFilter.h"

namespace nc::panel {
    
using hbn::tribool;
using hbn::indeterminate;

bool PresentationItemsColoringFilter::IsEmpty() const
{
    return
        mask.IsEmpty() &&
        indeterminate(executable) &&
        indeterminate(hidden) &&
        indeterminate(directory) &&
        indeterminate(symlink) &&
        indeterminate(reg) &&
        indeterminate(selected);
}

bool PresentationItemsColoringFilter::Filter(const VFSListingItem& _item,
                                             const data::ItemVolatileData &_item_vd) const
{
    if( !mask.IsEmpty() &&
        !mask.MatchName(_item.DisplayName()) )
        return false;
    
    if( !indeterminate(executable) &&
        executable != ((_item.UnixMode() & (S_IXUSR | S_IXGRP | S_IXOTH)) != 0) )
        return false;
    
    if( !indeterminate(hidden) &&
        hidden != _item.IsHidden() )
        return false;
    
    if( !indeterminate(directory) &&
        directory != _item.IsDir() )
        return false;

    if( !indeterminate(symlink) &&
        symlink != _item.IsSymlink() )
        return false;
    
    if( !indeterminate(reg) &&
        reg != _item.IsReg() )
        return false;
    
    if( !indeterminate(selected) &&
       selected != _item_vd.is_selected() )
        return false;
    
    return true;
}

bool operator==(const PresentationItemsColoringFilter&_lhs,
                const PresentationItemsColoringFilter&_rhs) noexcept
{
    return
    _lhs.mask == _rhs.mask &&
    _lhs.executable.value == _rhs.executable.value &&
    _lhs.hidden.value == _rhs.hidden.value &&
    _lhs.directory.value == _rhs.directory.value &&
    _lhs.symlink.value == _rhs.symlink.value &&
    _lhs.reg.value == _rhs.reg.value &&
    _lhs.selected.value == _rhs.selected.value;
}

bool operator!=(const PresentationItemsColoringFilter&_lhs,
                const PresentationItemsColoringFilter&_rhs) noexcept
{
    return !(_lhs == _rhs);
}
 
bool operator==(const PresentationItemsColoringRule&_lhs,
                const PresentationItemsColoringRule&_rhs) noexcept    
{
    return
    _lhs.name == _rhs.name &&
    _lhs.regular == _rhs.regular &&
    _lhs.focused == _rhs.focused &&
    _lhs.filter == _rhs.filter;
}
    
bool operator!=(const PresentationItemsColoringRule&_lhs,
                const PresentationItemsColoringRule&_rhs) noexcept
{
    return !(_lhs == _rhs);
}

}

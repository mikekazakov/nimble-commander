//
//  PanelViewPresentationItemsColoringFilter.mm
//  Files
//
//  Created by Michael G. Kazakov on 04/08/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import <sys/stat.h>
#import "PanelViewPresentationItemsColoringFilter.h"

static tribool to_tribool(NSNumber *_n)
{
    if(_n.intValue == 0)
        return false;
    if(_n.intValue == 1)
        return true;
    return indeterminate;
}

bool PanelViewPresentationItemsColoringFilter::IsEmpty() const
{
    return
        mask.IsEmpty() &&
        indeterminate(executable) &&
        indeterminate(hidden) &&
        indeterminate(directory) &&
        indeterminate(symlink) &&
        indeterminate(reg);
}

bool PanelViewPresentationItemsColoringFilter::Filter(const VFSListingItem& _item) const
{
    if( !mask.IsEmpty() &&
        !mask.MatchName(_item.NSDisplayName()) )
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
    
    return true;
}

NSDictionary *PanelViewPresentationItemsColoringFilter::Archive() const
{
    return @{@"mask"        : (mask.Mask() ? mask.Mask() : @""),
             @"executable"  : @(executable.value),
             @"hidden"      : @(hidden.value),
             @"directory"   : @(directory.value),
             @"symlink"     : @(symlink.value),
             @"reg"         : @(reg.value)
             };
}

PanelViewPresentationItemsColoringFilter PanelViewPresentationItemsColoringFilter::Unarchive(NSDictionary *_dict)
{
    PanelViewPresentationItemsColoringFilter f;

    if(!_dict)
        return f;
    
    if([_dict objectForKey:@"mask"] &&
       [[_dict objectForKey:@"mask"] isKindOfClass:NSString.class])
        f.mask = FileMask([_dict objectForKey:@"mask"]);
    
    if([_dict objectForKey:@"executable"] &&
       [[_dict objectForKey:@"executable"] isKindOfClass:NSNumber.class])
        f.executable = to_tribool([_dict objectForKey:@"executable"]);

    if([_dict objectForKey:@"hidden"] &&
       [[_dict objectForKey:@"hidden"] isKindOfClass:NSNumber.class])
        f.hidden = to_tribool([_dict objectForKey:@"hidden"]);

    if([_dict objectForKey:@"directory"] &&
       [[_dict objectForKey:@"directory"] isKindOfClass:NSNumber.class])
        f.directory = to_tribool([_dict objectForKey:@"directory"]);

    if([_dict objectForKey:@"symlink"] &&
       [[_dict objectForKey:@"symlink"] isKindOfClass:NSNumber.class])
        f.symlink = to_tribool([_dict objectForKey:@"symlink"]);

    if([_dict objectForKey:@"reg"] &&
       [[_dict objectForKey:@"reg"] isKindOfClass:NSNumber.class])
        f.reg = to_tribool([_dict objectForKey:@"reg"]);
    
    return f;
}

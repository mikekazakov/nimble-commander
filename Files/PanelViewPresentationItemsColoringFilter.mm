//
//  PanelViewPresentationItemsColoringFilter.mm
//  Files
//
//  Created by Michael G. Kazakov on 04/08/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#include <sys/stat.h>
#include "Utility/HexadecimalColor.h"
#include "PanelViewPresentationItemsColoringFilter.h"

static tribool to_tribool(NSNumber *_n)
{
    if(_n.intValue == 0)
        return false;
    if(_n.intValue == 1)
        return true;
    return indeterminate;
}

static tribool to_tribool(const GenericConfig::ConfigValue &_val)
{
    switch( _val.GetType() ) {
        case rapidjson::kTrueType:  return true;
        case rapidjson::kFalseType: return false;
        default:                    return indeterminate;
    }
}

static GenericConfig::ConfigValue to_json(tribool _b)
{
    if( indeterminate(_b) )
        return GenericConfig::ConfigValue( rapidjson::kNullType );
    if( _b )
        return GenericConfig::ConfigValue( rapidjson::kTrueType );
    else
        return GenericConfig::ConfigValue( rapidjson::kFalseType );
}

static NSColor *ColorFromJSON(const GenericConfig::ConfigValue& _v)
{
    return [NSColor colorWithHexStdString:_v.IsString() ? _v.GetString() : ""];
}

bool PanelViewPresentationItemsColoringFilter::IsEmpty() const
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

bool PanelViewPresentationItemsColoringFilter::Filter(const VFSListingItem& _item, const PanelVolatileData &_item_vd) const
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
    
    if( !indeterminate(selected) &&
       selected != _item_vd.is_selected() )
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
             @"reg"         : @(reg.value),
             @"selected"    : @(selected.value)
             };
}

GenericConfig::ConfigValue PanelViewPresentationItemsColoringFilter::ToJSON() const
{
    GenericConfig::ConfigValue v( rapidjson::kObjectType );
    if( mask.Mask() && mask.Mask().length > 0 )
        v.AddMember("mask", GenericConfig::ConfigValue( mask.Mask().UTF8String, GenericConfig::g_CrtAllocator), GenericConfig::g_CrtAllocator );
    if( !indeterminate(executable) )
        v.AddMember("executable", to_json(executable), GenericConfig::g_CrtAllocator);
    if( !indeterminate(hidden) )
        v.AddMember("hidden", to_json(hidden), GenericConfig::g_CrtAllocator);
    if( !indeterminate(directory) )
        v.AddMember("directory", to_json(directory), GenericConfig::g_CrtAllocator);
    if( !indeterminate(symlink) )
        v.AddMember("symlink", to_json(symlink), GenericConfig::g_CrtAllocator);
    if( !indeterminate(reg) )
        v.AddMember("reg", to_json(reg), GenericConfig::g_CrtAllocator);
    if( !indeterminate(selected) )
        v.AddMember("selected", to_json(selected), GenericConfig::g_CrtAllocator);
    return v;
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

    if([_dict objectForKey:@"selected"] &&
       [[_dict objectForKey:@"selected"] isKindOfClass:NSNumber.class])
        f.selected = to_tribool([_dict objectForKey:@"selected"]);
    
    return f;
}

PanelViewPresentationItemsColoringFilter PanelViewPresentationItemsColoringFilter::FromJSON(const GenericConfig::ConfigValue& _v)
{
    PanelViewPresentationItemsColoringFilter f;

    if( _v.GetType() != rapidjson::kObjectType )
        return f;
    
    if( _v.HasMember("mask") && _v["mask"].IsString() ) {
        auto &m = _v["mask"];
        if( m.IsString() )
            f.mask = FileMask( [NSString stringWithUTF8String:m.GetString()] );
    }
    
    if( _v.HasMember("executable") )    f.executable    = to_tribool( _v["executable"] );
    if( _v.HasMember("hidden") )        f.hidden        = to_tribool( _v["hidden"] );
    if( _v.HasMember("directory") )     f.directory     = to_tribool( _v["directory"] );
    if( _v.HasMember("symlink") )       f.symlink       = to_tribool( _v["symlink"] );
    if( _v.HasMember("reg") )           f.reg           = to_tribool( _v["reg"] );
    if( _v.HasMember("selected") )      f.selected      = to_tribool( _v["selected"] );
    return f;
}

GenericConfig::ConfigValue PanelViewPresentationItemsColoringRule::ToJSON() const
{
    GenericConfig::ConfigValue v( rapidjson::kObjectType );
    v.AddMember("name", GenericConfig::ConfigValue(name.c_str(), GenericConfig::g_CrtAllocator), GenericConfig::g_CrtAllocator );
    v.AddMember("regular", GenericConfig::ConfigValue(regular.toHexStdString.c_str(), GenericConfig::g_CrtAllocator), GenericConfig::g_CrtAllocator );
    v.AddMember("focused", GenericConfig::ConfigValue(focused.toHexStdString.c_str(), GenericConfig::g_CrtAllocator), GenericConfig::g_CrtAllocator );
    auto f = filter.ToJSON();
    if( !f.ObjectEmpty() )
        v.AddMember("filter", f, GenericConfig::g_CrtAllocator);
    return v;
}

PanelViewPresentationItemsColoringRule PanelViewPresentationItemsColoringRule::FromJSON(const GenericConfig::ConfigValue& _v)
{
    PanelViewPresentationItemsColoringRule f;
    
    if( _v.GetType() != rapidjson::kObjectType )
        return f;
    
    if( _v.HasMember("filter") ) f.filter = PanelViewPresentationItemsColoringFilter::FromJSON( _v["filter"] );
    if( _v.HasMember("name") && _v["name"].IsString() ) f.name = _v["name"].GetString();
    if( _v.HasMember("regular") ) f.regular = ColorFromJSON( _v["regular"] );
    if( _v.HasMember("focused") ) f.focused = ColorFromJSON( _v["focused"] );
    
    return f;
}

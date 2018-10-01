// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelViewPresentationItemsColoringFilterPersistence.h"
#include <Utility/HexadecimalColor.h>
#include <Config/RapidJSON.h>

namespace nc::panel {

using hbn::tribool;
using hbn::indeterminate;

static tribool to_tribool(const config::Value &_val)
{
    switch( _val.GetType() ) {
        case rapidjson::kTrueType:  return true;
        case rapidjson::kFalseType: return false;
        default:                    return indeterminate;
    }
}

static config::Value to_json(tribool _b)
{
    if( indeterminate(_b) )
        return config::Value( rapidjson::kNullType );
    if( _b )
        return config::Value( rapidjson::kTrueType );
    else
        return config::Value( rapidjson::kFalseType );
}
    
static NSColor *ColorFromJSON(const config::Value& _v)
{
    return [NSColor colorWithHexStdString:_v.IsString() ? _v.GetString() : ""];
}

config::Value
    PresentationItemsColoringFilterPersitence::
    ToJSON(const PresentationItemsColoringFilter& _filter) const
{
    auto &allocator = config::g_CrtAllocator;
    config::Value v( rapidjson::kObjectType );
    if( !_filter.mask.Mask().empty() )
        v.AddMember("mask", config::Value(_filter.mask.Mask().c_str(), allocator), allocator);
    if( !indeterminate(_filter.executable) )
        v.AddMember("executable", to_json(_filter.executable), allocator);
    if( !indeterminate(_filter.hidden) )
        v.AddMember("hidden", to_json(_filter.hidden), allocator);
    if( !indeterminate(_filter.directory) )
        v.AddMember("directory", to_json(_filter.directory), allocator);
    if( !indeterminate(_filter.symlink) )
        v.AddMember("symlink", to_json(_filter.symlink), allocator);
    if( !indeterminate(_filter.reg) )
        v.AddMember("reg", to_json(_filter.reg), allocator);
    if( !indeterminate(_filter.selected) )
        v.AddMember("selected", to_json(_filter.selected), allocator);
    return v;    
}
        
PresentationItemsColoringFilter
PresentationItemsColoringFilterPersitence::FromJSON(const config::Value& _v) const
{
    PresentationItemsColoringFilter f;
    
    if( _v.GetType() != rapidjson::kObjectType )
        return f;
    
    if( _v.HasMember("mask") && _v["mask"].IsString() ) {
        auto &m = _v["mask"];
        if( m.IsString() )
            f.mask = nc::utility::FileMask( m.GetString() );
    }
    
    if( _v.HasMember("executable") )    f.executable    = to_tribool( _v["executable"] );
    if( _v.HasMember("hidden") )        f.hidden        = to_tribool( _v["hidden"] );
    if( _v.HasMember("directory") )     f.directory     = to_tribool( _v["directory"] );
    if( _v.HasMember("symlink") )       f.symlink       = to_tribool( _v["symlink"] );
    if( _v.HasMember("reg") )           f.reg           = to_tribool( _v["reg"] );
    if( _v.HasMember("selected") )      f.selected      = to_tribool( _v["selected"] );
    return f;    
}
 
config::Value
PresentationItemsColoringRulePersistence::ToJSON(const PresentationItemsColoringRule& _rule) const
{
    using Value = config::Value;
    auto &allocator = config::g_CrtAllocator;
    Value v( rapidjson::kObjectType );
    v.AddMember( "name", Value(_rule.name.c_str(), allocator), allocator );
    v.AddMember( "regular", Value(_rule.regular.toHexStdString.c_str(), allocator), allocator );
    v.AddMember( "focused", Value(_rule.focused.toHexStdString.c_str(), allocator), allocator );
    auto f = PresentationItemsColoringFilterPersitence{}.ToJSON(_rule.filter);
    if( !f.ObjectEmpty() )
        v.AddMember("filter", f, allocator);
    return v;        
}
    
PresentationItemsColoringRule
PresentationItemsColoringRulePersistence::FromJSON(const config::Value& _v) const
{
    PresentationItemsColoringRule f;
    
    if( _v.GetType() != rapidjson::kObjectType )
        return f;
    
    if( _v.HasMember("filter") )
        f.filter = PresentationItemsColoringFilterPersitence{}.FromJSON(_v["filter"]);
    if( _v.HasMember("name") && _v["name"].IsString() )
        f.name = _v["name"].GetString();
    if( _v.HasMember("regular") )
        f.regular = ColorFromJSON( _v["regular"] );
    if( _v.HasMember("focused") )
        f.focused = ColorFromJSON( _v["focused"] );
    
    return f;        
}
    
}

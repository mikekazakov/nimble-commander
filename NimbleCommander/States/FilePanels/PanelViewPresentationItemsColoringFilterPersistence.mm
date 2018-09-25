// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelViewPresentationItemsColoringFilterPersistence.h"
#include <NimbleCommander/Core/rapidjson.h>
#include <Utility/HexadecimalColor.h>

namespace nc::panel {

using hbn::tribool;
using hbn::indeterminate;

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

GenericConfig::ConfigValue
    PresentationItemsColoringFilterPersitence::
    ToJSON(const PresentationItemsColoringFilter& _filter) const
{
    GenericConfig::ConfigValue v( rapidjson::kObjectType );
    if( !_filter.mask.Mask().empty() )
        v.AddMember("mask",
                    GenericConfig::ConfigValue(_filter.mask.Mask().c_str(),
                                               GenericConfig::g_CrtAllocator),
                    GenericConfig::g_CrtAllocator );
    if( !indeterminate(_filter.executable) )
        v.AddMember("executable", to_json(_filter.executable), GenericConfig::g_CrtAllocator);
    if( !indeterminate(_filter.hidden) )
        v.AddMember("hidden", to_json(_filter.hidden), GenericConfig::g_CrtAllocator);
    if( !indeterminate(_filter.directory) )
        v.AddMember("directory", to_json(_filter.directory), GenericConfig::g_CrtAllocator);
    if( !indeterminate(_filter.symlink) )
        v.AddMember("symlink", to_json(_filter.symlink), GenericConfig::g_CrtAllocator);
    if( !indeterminate(_filter.reg) )
        v.AddMember("reg", to_json(_filter.reg), GenericConfig::g_CrtAllocator);
    if( !indeterminate(_filter.selected) )
        v.AddMember("selected", to_json(_filter.selected), GenericConfig::g_CrtAllocator);
    return v;    
}
        
PresentationItemsColoringFilter
PresentationItemsColoringFilterPersitence::FromJSON(const GenericConfig::ConfigValue& _v) const
{
    PresentationItemsColoringFilter f;
    
    if( _v.GetType() != rapidjson::kObjectType )
        return f;
    
    if( _v.HasMember("mask") && _v["mask"].IsString() ) {
        auto &m = _v["mask"];
        if( m.IsString() )
            f.mask = FileMask( m.GetString() );
    }
    
    if( _v.HasMember("executable") )    f.executable    = to_tribool( _v["executable"] );
    if( _v.HasMember("hidden") )        f.hidden        = to_tribool( _v["hidden"] );
    if( _v.HasMember("directory") )     f.directory     = to_tribool( _v["directory"] );
    if( _v.HasMember("symlink") )       f.symlink       = to_tribool( _v["symlink"] );
    if( _v.HasMember("reg") )           f.reg           = to_tribool( _v["reg"] );
    if( _v.HasMember("selected") )      f.selected      = to_tribool( _v["selected"] );
    return f;    
}
 
GenericConfig::ConfigValue
PresentationItemsColoringRulePersistence::ToJSON(const PresentationItemsColoringRule& _rule) const
{
    GenericConfig::ConfigValue v( rapidjson::kObjectType );
    v.AddMember("name",
                GenericConfig::ConfigValue(_rule.name.c_str(), GenericConfig::g_CrtAllocator),
                GenericConfig::g_CrtAllocator );
    v.AddMember("regular",
                GenericConfig::ConfigValue(_rule.regular.toHexStdString.c_str(),
                                           GenericConfig::g_CrtAllocator),
                GenericConfig::g_CrtAllocator );
    v.AddMember("focused",
                GenericConfig::ConfigValue(_rule.focused.toHexStdString.c_str(),
                                           GenericConfig::g_CrtAllocator),
                GenericConfig::g_CrtAllocator );
    auto f = PresentationItemsColoringFilterPersitence{}.ToJSON(_rule.filter);
    if( !f.ObjectEmpty() )
        v.AddMember("filter", f, GenericConfig::g_CrtAllocator);
    return v;
        
}
    
PresentationItemsColoringRule
PresentationItemsColoringRulePersistence::FromJSON(const GenericConfig::ConfigValue& _v) const
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
//
//
//GenericConfig::ConfigValue PresentationItemsColoringFilter::ToJSON() const
//{

//}
//
//PresentationItemsColoringFilter PresentationItemsColoringFilter::FromJSON(const GenericConfig::ConfigValue& _v)
//{

//}

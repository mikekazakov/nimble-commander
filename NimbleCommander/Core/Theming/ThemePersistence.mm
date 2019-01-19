// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ThemePersistence.h"
#include <Utility/HexadecimalColor.h>
#include <Utility/FontExtras.h>
#include <NimbleCommander/States/FilePanels/PanelViewPresentationItemsColoringFilterPersistence.h>
#include <Config/RapidJSON.h>

NSColor *ThemePersistence::ExtractColor( const Value & _doc, const char *_path)
{
    auto cr = _doc.FindMember(_path);
    if( cr == _doc.MemberEnd() )
        return nil;
    
    if( !cr->value.IsString() )
        return nil;

    return [NSColor colorWithHexStdString:cr->value.GetString()];
}

NSFont *ThemePersistence::ExtractFont( const Value& _doc, const char *_path)
{
    auto cr = _doc.FindMember(_path);
    if( cr == _doc.MemberEnd() )
        return nil;
    
    if( !cr->value.IsString() )
        return nil;

    return [NSFont fontWithStringDescription:[NSString stringWithUTF8String:cr->value.GetString()]];
}

std::vector<nc::panel::PresentationItemsColoringRule> ThemePersistence::
    ExtractRules( const Value & _doc, const char*_path )
{
    std::vector<nc::panel::PresentationItemsColoringRule> r;
    auto cr = &_doc.FindMember(_path)->value;
    if( cr->IsArray() )
        for( auto i = cr->Begin(), e = cr->End(); i != e; ++i ) {
            r.emplace_back( nc::panel::PresentationItemsColoringRulePersistence{}.FromJSON(*i) );
        }
    return r;
}

ThemePersistence::Value ThemePersistence::EncodeColor( NSColor *_color )
{
    return Value([_color toHexStdString].c_str(), nc::config::g_CrtAllocator);
}

ThemePersistence::Value ThemePersistence::EncodeFont( NSFont *_font )
{
    return Value([_font toStringDescription].UTF8String, nc::config::g_CrtAllocator);
}

ThemePersistence::Value ThemePersistence::EncodeRules
    (const std::vector<nc::panel::PresentationItemsColoringRule> &_rules )
{
    Value cr(rapidjson::kArrayType);
    cr.Reserve((unsigned)_rules.size(), nc::config::g_CrtAllocator);
    for( const auto &r: _rules )
        cr.PushBack(nc::panel::PresentationItemsColoringRulePersistence{}.ToJSON(r),
                    nc::config::g_CrtAllocator );
    return cr;
}

ThemePersistence::Value ThemePersistence::EncodeAppearance( ThemeAppearance _appearance )
{
    const auto v = _appearance == ThemeAppearance::Dark ? "dark" : "aqua";
    return Value(v, nc::config::g_CrtAllocator);
}

ThemeAppearance ThemePersistence::ExtractAppearance( const Value &_doc, const char *_path  )
{
    using namespace std::literals;
    
    auto cr = _doc.FindMember(_path);
    if( cr == _doc.MemberEnd() )
        return ThemeAppearance::Light;
    
    if( !cr->value.IsString() )
        return ThemeAppearance::Light;
    
    if( "aqua"s == cr->value.GetString() )
        return ThemeAppearance::Light;
    if( "dark"s == cr->value.GetString() )
        return ThemeAppearance::Dark;
    // vibrant light some day maybe
    return ThemeAppearance::Light;
}

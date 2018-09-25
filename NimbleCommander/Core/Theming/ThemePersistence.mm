// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Utility/HexadecimalColor.h>
#include <Utility/FontExtras.h>
#include "ThemePersistence.h"
#include <NimbleCommander/States/FilePanels/PanelViewPresentationItemsColoringFilterPersistence.h>

NSColor *ThemePersistence::ExtractColor( v _doc, const char *_path)
{
    auto cr = _doc.FindMember(_path);
    if( cr == _doc.MemberEnd() )
        return nil;
    
    if( !cr->value.IsString() )
        return nil;

    return [NSColor colorWithHexStdString:cr->value.GetString()];
}

NSFont *ThemePersistence::ExtractFont( v _doc, const char *_path)
{
    auto cr = _doc.FindMember(_path);
    if( cr == _doc.MemberEnd() )
        return nil;
    
    if( !cr->value.IsString() )
        return nil;

    return [NSFont fontWithStringDescription:[NSString stringWithUTF8String:cr->value.GetString()]];
}

vector<nc::panel::PresentationItemsColoringRule> ThemePersistence::
    ExtractRules( v _doc, const char*_path )
{
    vector<nc::panel::PresentationItemsColoringRule> r;
    auto cr = &_doc.FindMember(_path)->value;
    if( cr->IsArray() )
        for( auto i = cr->Begin(), e = cr->End(); i != e; ++i ) {
            auto v = GenericConfig::ConfigValue( *i, rapidjson::g_CrtAllocator );
            r.emplace_back( nc::panel::PresentationItemsColoringRulePersistence{}.FromJSON(v) );
        }
    return r;
}

rapidjson::StandaloneValue ThemePersistence::EncodeColor( NSColor *_color )
{
    return rapidjson::StandaloneValue([_color toHexStdString].c_str(),
                                      rapidjson::g_CrtAllocator);
}

rapidjson::StandaloneValue ThemePersistence::EncodeFont( NSFont *_font )
{
    return rapidjson::StandaloneValue([_font toStringDescription].UTF8String,
                                      rapidjson::g_CrtAllocator);
}

rapidjson::StandaloneValue ThemePersistence::EncodeRules
    (const vector<nc::panel::PresentationItemsColoringRule> &_rules )
{
    rapidjson::StandaloneValue cr(rapidjson::kArrayType);
    cr.Reserve((unsigned)_rules.size(), rapidjson::g_CrtAllocator);
    for( const auto &r: _rules )
        cr.PushBack(nc::panel::PresentationItemsColoringRulePersistence{}.ToJSON(r),
                    rapidjson::g_CrtAllocator );
    return cr;
}

rapidjson::StandaloneValue ThemePersistence::EncodeAppearance( ThemeAppearance _appearance )
{
    const auto v = _appearance == ThemeAppearance::Dark ? "dark" : "aqua";
    return rapidjson::StandaloneValue(v, rapidjson::g_CrtAllocator);
}

ThemeAppearance ThemePersistence::ExtractAppearance( v _doc, const char *_path  )
{
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

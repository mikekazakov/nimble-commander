// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <NimbleCommander/Core/rapidjson.h>
#include <NimbleCommander/States/FilePanels/PanelViewPresentationItemsColoringFilter.h>

#include "Theme.h"

struct ThemePersistence
{
    using v = const rapidjson::StandaloneValue &;
    
    /**
    * May return nil;
    */
    static NSColor *ExtractColor( v _doc, const char *_path );
    static rapidjson::StandaloneValue EncodeColor( NSColor *_color );

    /**
    * May return nil;
    */
    static NSFont *ExtractFont( v _doc, const char *_path );
    static rapidjson::StandaloneValue EncodeFont( NSFont *_font );
    
    static vector<PanelViewPresentationItemsColoringRule> ExtractRules( v _doc, const char *_path );
    static rapidjson::StandaloneValue EncodeRules(
        const vector<PanelViewPresentationItemsColoringRule> &_rules );
    
    static ThemeAppearance ExtractAppearance( v _doc, const char *_path  );
    static rapidjson::StandaloneValue EncodeAppearance(
        ThemeAppearance _appearance );
    
};


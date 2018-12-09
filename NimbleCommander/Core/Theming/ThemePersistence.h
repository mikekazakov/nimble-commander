// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Config/RapidJSON_fwd.h>
#include <NimbleCommander/States/FilePanels/PanelViewPresentationItemsColoringFilter.h>

#include "Theme.h"

struct ThemePersistence
{
    using Value = nc::config::Value;
    
    /**
    * May return nil;
    */
    static NSColor *ExtractColor( const Value &_doc, const char *_path );
    static Value EncodeColor( NSColor *_color );

    /**
    * May return nil;
    */
    static NSFont *ExtractFont( const Value &_doc, const char *_path );
    static Value EncodeFont( NSFont *_font );
    
    using ColoringRulesT = std::vector<nc::panel::PresentationItemsColoringRule>;
    static ColoringRulesT ExtractRules(const Value& _doc, const char *_path );
    static Value EncodeRules( const ColoringRulesT &_rules );
    
    static ThemeAppearance ExtractAppearance( const Value &_doc, const char *_path  );
    static Value EncodeAppearance( ThemeAppearance _appearance );
    
};


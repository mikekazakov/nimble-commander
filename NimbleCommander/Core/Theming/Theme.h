#pragma once

class ThemesManager;
struct PanelViewPresentationItemsColoringRule;

enum class ThemeAppearance : int8_t
{
    Light   =   0,  // NSAppearanceNameVibrantLight
    Dark    =   1   // NSAppearanceNameVibrantDark
};

class Theme
{
public:
    Theme();

    
    ThemeAppearance AppearanceType() const;
    NSAppearance *Appearance() const;

    // File Panels --> General appearance
    const vector<PanelViewPresentationItemsColoringRule>& FilePanelsItemsColoringRules() const;
    NSColor *FilePanelsGeneralDropBorderColor() const;
    
    // File Panels --> List presentation
    NSFont  *FilePanelsListFont() const;
    NSColor *FilePanelsListSelectedActiveRowBackgroundColor() const;
    NSColor *FilePanelsListSelectedInactiveRowBackgroundColor() const;
    NSColor *FilePanelsListRegularEvenRowBackgroundColor() const;    
    NSColor *FilePanelsListRegularOddRowBackgroundColor() const;
    

private:
    vector<PanelViewPresentationItemsColoringRule> m_ColoringRules;
    NSColor *m_FilePanelsGeneralDropBorderColor;
    NSColor *m_FilePanelsListSelectedActiveRowBackgroundColor;
    NSColor *m_FilePanelsListSelectedInactiveRowBackgroundColor;
    NSColor *m_FilePanelsListRegularEvenRowBackgroundColor;
    NSColor *m_FilePanelsListRegularOddRowBackgroundColor;
    
};

const Theme &CurrentTheme();

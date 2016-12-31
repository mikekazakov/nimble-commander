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

    // File Panels --> General appearance //////////////////////////////////////////////////////////
    const vector<PanelViewPresentationItemsColoringRule>& FilePanelsItemsColoringRules() const;
    NSColor *FilePanelsGeneralDropBorderColor() const;
    
    // File Panels --> Footer settings /////////////////////////////////////////////////////////////
    NSFont  *FilePanelsFooterFont() const;
    NSColor *FilePanelsFooterTextColor() const;
    NSColor *FilePanelsFooterActiveTextColor() const;
    NSColor *FilePanelsFooterSeparatorsColor() const;
    NSColor *FilePanelsFooterActiveBackgroundColor() const;
    NSColor *FilePanelsFooterInactiveBackgroundColor() const;
    
    // File Panels --> List presentation ///////////////////////////////////////////////////////////
    NSFont  *FilePanelsListFont() const;
    NSColor *FilePanelsListGridColor() const;
    NSFont  *FilePanelsListHeaderFont() const;
    NSColor *FilePanelsListHeaderBackgroundColor() const;
    NSColor *FilePanelsListHeaderTextColor() const;
    NSColor *FilePanelsListSelectedActiveRowBackgroundColor() const;
    NSColor *FilePanelsListSelectedInactiveRowBackgroundColor() const;
    NSColor *FilePanelsListRegularEvenRowBackgroundColor() const;    
    NSColor *FilePanelsListRegularOddRowBackgroundColor() const;
    

private:
    vector<PanelViewPresentationItemsColoringRule> m_ColoringRules;
    NSColor *m_FilePanelsGeneralDropBorderColor;
    
    NSFont  *m_FilePanelsFooterFont;
    NSColor *m_FilePanelsFooterTextColor;
    NSColor *m_FilePanelsFooterActiveTextColor;
    NSColor *m_FilePanelsFooterSeparatorsColor;
    NSColor *m_FilePanelsFooterActiveBackgroundColor;
    NSColor *m_FilePanelsFooterInactiveBackgroundColor;
    
    NSFont  *m_FilePanelsListFont;
    NSColor *m_FilePanelsListGridColor;
    NSFont  *m_FilePanelsListHeaderFont;
    NSColor *m_FilePanelsListHeaderBackgroundColor;
    NSColor *m_FilePanelsListHeaderTextColor;
    NSColor *m_FilePanelsListSelectedActiveRowBackgroundColor;
    NSColor *m_FilePanelsListSelectedInactiveRowBackgroundColor;
    NSColor *m_FilePanelsListRegularEvenRowBackgroundColor;
    NSColor *m_FilePanelsListRegularOddRowBackgroundColor;
};

const Theme &CurrentTheme();

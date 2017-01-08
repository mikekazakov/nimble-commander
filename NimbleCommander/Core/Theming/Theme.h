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
    ~Theme();

    
    ThemeAppearance AppearanceType() const;
    NSAppearance *Appearance() const;

    // File Panels --> General appearance //////////////////////////////////////////////////////////
    const vector<PanelViewPresentationItemsColoringRule>& FilePanelsItemsColoringRules() const;
    NSColor *FilePanelsGeneralDropBorderColor() const;
    
    // File Panels --> Header settings /////////////////////////////////////////////////////////////
    NSFont  *FilePanelsHeaderFont() const;
    NSColor *FilePanelsHeaderTextColor() const;
    NSColor *FilePanelsHeaderActiveTextColor() const;
    NSColor *FilePanelsHeaderActiveBackgroundColor() const;
    NSColor *FilePanelsHeaderInactiveBackgroundColor() const;
    NSColor *FilePanelsHeaderSeparatorColor() const;
    
    // File Panels --> Footer settings /////////////////////////////////////////////////////////////
    NSFont  *FilePanelsFooterFont() const;
    NSColor *FilePanelsFooterTextColor() const;
    NSColor *FilePanelsFooterActiveTextColor() const;
    NSColor *FilePanelsFooterSeparatorsColor() const;
    NSColor *FilePanelsFooterActiveBackgroundColor() const;
    NSColor *FilePanelsFooterInactiveBackgroundColor() const;
    
    // File Panels --> Tabs ////////////////////////////////////////////////////////////////////////
    NSFont  *FilePanelsTabsFont() const;
    NSColor *FilePanelsTabsTextColor() const;
    NSColor *FilePanelsTabsSelectedKeyWndActiveBackgroundColor() const;
    NSColor *FilePanelsTabsSelectedKeyWndInactiveBackgroundColor() const;
    NSColor *FilePanelsTabsSelectedNotKeyWndBackgroundColor() const;    
    NSColor *FilePanelsTabsRegularKeyWndHoverBackgroundColor() const;
    NSColor *FilePanelsTabsRegularKeyWndRegularBackgroundColor() const;
    NSColor *FilePanelsTabsRegularNotKeyWndBackgroundColor() const;
    NSColor *FilePanelsTabsSeparatorColor() const;
    NSColor *FilePanelsTabsPictogramColor() const;
    
    // File Panels --> List presentation ///////////////////////////////////////////////////////////
    NSFont  *FilePanelsListFont() const;
    NSColor *FilePanelsListGridColor() const;
    NSFont  *FilePanelsListHeaderFont() const;
    NSColor *FilePanelsListHeaderBackgroundColor() const;
    NSColor *FilePanelsListHeaderTextColor() const;
    NSColor *FilePanelsListHeaderSeparatorColor() const;
    NSColor *FilePanelsListSelectedActiveRowBackgroundColor() const;
    NSColor *FilePanelsListSelectedInactiveRowBackgroundColor() const;
    NSColor *FilePanelsListRegularEvenRowBackgroundColor() const;    
    NSColor *FilePanelsListRegularOddRowBackgroundColor() const;
    
private:
    vector<PanelViewPresentationItemsColoringRule> m_ColoringRules;
    NSColor *m_FilePanelsGeneralDropBorderColor;
    
    NSFont  *m_FilePanelsHeaderFont;
    NSColor *m_FilePanelsHeaderTextColor;
    NSColor *m_FilePanelsHeaderActiveTextColor;
    NSColor *m_FilePanelsHeaderActiveBackgroundColor;
    NSColor *m_FilePanelsHeaderInactiveBackgroundColor;
    NSColor *m_FilePanelsHeaderSeparatorColor;
    
    NSFont  *m_FilePanelsFooterFont;
    NSColor *m_FilePanelsFooterTextColor;
    NSColor *m_FilePanelsFooterActiveTextColor;
    NSColor *m_FilePanelsFooterSeparatorsColor;
    NSColor *m_FilePanelsFooterActiveBackgroundColor;
    NSColor *m_FilePanelsFooterInactiveBackgroundColor;
    
    NSFont  *m_FilePanelsTabsFont;
    NSColor *m_FilePanelsTabsTextColor;
    NSColor *m_FilePanelsTabsSelectedKeyWndActiveBackgroundColor;
    NSColor *m_FilePanelsTabsSelectedKeyWndInactiveBackgroundColor;
    NSColor *m_FilePanelsTabsSelectedNotKeyWndBackgroundColor;
    NSColor *m_FilePanelsTabsRegularKeyWndHoverBackgroundColor;
    NSColor *m_FilePanelsTabsRegularKeyWndRegularBackgroundColor;
    NSColor *m_FilePanelsTabsRegularNotKeyWndBackgroundColor;
    NSColor *m_FilePanelsTabsSeparatorColor;
    NSColor *m_FilePanelsTabsPictogramColor;
    
    NSFont  *m_FilePanelsListFont;
    NSColor *m_FilePanelsListGridColor;
    NSFont  *m_FilePanelsListHeaderFont;
    NSColor *m_FilePanelsListHeaderBackgroundColor;
    NSColor *m_FilePanelsListHeaderTextColor;
    NSColor *m_FilePanelsListHeaderSeparatorColor;
    NSColor *m_FilePanelsListSelectedActiveRowBackgroundColor;
    NSColor *m_FilePanelsListSelectedInactiveRowBackgroundColor;
    NSColor *m_FilePanelsListRegularEvenRowBackgroundColor;
    NSColor *m_FilePanelsListRegularOddRowBackgroundColor;
};

const Theme &CurrentTheme();

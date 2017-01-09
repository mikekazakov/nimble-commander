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
    // foolproof constructor against accidental calling Theme() instead of CurrentTheme()  
    Theme(void*_dont_call_me_exclamation_mark);
    ~Theme();

    // General appearance settings /////////////////////////////////////////////////////////////////
    ThemeAppearance AppearanceType() const noexcept;
    NSAppearance *Appearance() const noexcept;

    // File Panels --> General appearance //////////////////////////////////////////////////////////
    using ColoringRules = PanelViewPresentationItemsColoringRule;
    const vector<ColoringRules>& FilePanelsItemsColoringRules() const noexcept;
    NSColor *FilePanelsGeneralDropBorderColor() const noexcept;
    
    // File Panels --> Tabs bar settings ///////////////////////////////////////////////////////////
    NSFont  *FilePanelsTabsFont() const noexcept;
    NSColor *FilePanelsTabsTextColor() const noexcept;
    NSColor *FilePanelsTabsSelectedKeyWndActiveBackgroundColor() const noexcept;
    NSColor *FilePanelsTabsSelectedKeyWndInactiveBackgroundColor() const noexcept;
    NSColor *FilePanelsTabsSelectedNotKeyWndBackgroundColor() const noexcept;
    NSColor *FilePanelsTabsRegularKeyWndHoverBackgroundColor() const noexcept;
    NSColor *FilePanelsTabsRegularKeyWndRegularBackgroundColor() const noexcept;
    NSColor *FilePanelsTabsRegularNotKeyWndBackgroundColor() const noexcept;
    NSColor *FilePanelsTabsSeparatorColor() const noexcept;
    NSColor *FilePanelsTabsPictogramColor() const noexcept;
    
    // File Panels --> Header bar settings /////////////////////////////////////////////////////////
    NSFont  *FilePanelsHeaderFont() const noexcept;
    NSColor *FilePanelsHeaderTextColor() const noexcept;
    NSColor *FilePanelsHeaderActiveTextColor() const noexcept;
    NSColor *FilePanelsHeaderActiveBackgroundColor() const noexcept;
    NSColor *FilePanelsHeaderInactiveBackgroundColor() const noexcept;
    NSColor *FilePanelsHeaderSeparatorColor() const noexcept;
    
    // File Panels --> Footer bar settings /////////////////////////////////////////////////////////
    NSFont  *FilePanelsFooterFont() const noexcept;
    NSColor *FilePanelsFooterTextColor() const noexcept;
    NSColor *FilePanelsFooterActiveTextColor() const noexcept;
    NSColor *FilePanelsFooterSeparatorsColor() const noexcept;
    NSColor *FilePanelsFooterActiveBackgroundColor() const noexcept;
    NSColor *FilePanelsFooterInactiveBackgroundColor() const noexcept;
    
    // File Panels --> List presentation settings //////////////////////////////////////////////////
    NSFont  *FilePanelsListFont() const noexcept;
    NSColor *FilePanelsListGridColor() const noexcept;
    NSFont  *FilePanelsListHeaderFont() const noexcept;
    NSColor *FilePanelsListHeaderBackgroundColor() const noexcept;
    NSColor *FilePanelsListHeaderTextColor() const noexcept;
    NSColor *FilePanelsListHeaderSeparatorColor() const noexcept;
    NSColor *FilePanelsListSelectedActiveRowBackgroundColor() const noexcept;
    NSColor *FilePanelsListSelectedInactiveRowBackgroundColor() const noexcept;
    NSColor *FilePanelsListRegularEvenRowBackgroundColor() const noexcept;
    NSColor *FilePanelsListRegularOddRowBackgroundColor() const noexcept;
    
    // File Panels --> Brief presentation settings /////////////////////////////////////////////////
    NSFont  *FilePanelsBriefFont() const noexcept;
    NSColor *FilePanelsBriefRegularEvenRowBackgroundColor() const noexcept;
    NSColor *FilePanelsBriefRegularOddRowBackgroundColor() const noexcept;
    NSColor *FilePanelsBriefSelectedActiveItemBackgroundColor() const noexcept;
    NSColor *FilePanelsBriefSelectedInactiveItemBackgroundColor() const noexcept;
    
private:
    struct Internals;
    unique_ptr<Internals> I;
};

const Theme &CurrentTheme();

// Copyright (C) 2016-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <stdint.h>
#include <memory>
#include <vector>
#include <Cocoa/Cocoa.h>

class Theme;
class ThemesManager;
namespace nc::panel {
    struct PresentationItemsColoringRule;
}

enum class ThemeAppearance : int8_t
{
    Light   =   0,  // NSAppearanceNameAqua
    Dark    =   1   // NSAppearanceNameVibrantDark
};

/**
 * Thread-safe.
 * Returned reference should not be stored.
 */
const Theme &CurrentTheme() noexcept;

class Theme
{
public:
    // workaround to exclude rapidjson from header
    Theme(const /*nc::config::Value*/ void *_1,
          const /*nc::config::Value*/ void *_2);
    ~Theme();

    // General info querying ///////////////////////////////////////////////////////////////////////
    uint64_t Generation() const noexcept; // monotonically increasing starting with 1
    
    // General appearance settings /////////////////////////////////////////////////////////////////
    ThemeAppearance AppearanceType() const noexcept;
    NSAppearance *Appearance() const noexcept;

////////////////////////////////////////////////////////////////////////////////////////////////////
//  File Panels section
////////////////////////////////////////////////////////////////////////////////////////////////////
    
    // File Panels --> General appearance //////////////////////////////////////////////////////////
    using ColoringRule = nc::panel::PresentationItemsColoringRule;
    const std::vector<ColoringRule>& FilePanelsItemsColoringRules() const noexcept;
    NSColor *FilePanelsGeneralDropBorderColor() const noexcept;
    NSColor *FilePanelsGeneralOverlayColor() const noexcept;
    NSColor *FilePanelsGeneralSplitterColor() const noexcept;
    NSColor *FilePanelsGeneralTopSeparatorColor() const noexcept;
    
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
    NSColor *FilePanelsListRegularEvenRowBackgroundColor() const noexcept;
    NSColor *FilePanelsListRegularOddRowBackgroundColor() const noexcept;
    NSColor *FilePanelsListFocusedActiveRowBackgroundColor() const noexcept;
    NSColor *FilePanelsListFocusedInactiveRowBackgroundColor() const noexcept;
    NSColor *FilePanelsListSelectedRowBackgroundColor() const noexcept;
    
    // File Panels --> Brief presentation settings /////////////////////////////////////////////////
    NSFont  *FilePanelsBriefFont() const noexcept;
    NSColor *FilePanelsBriefGridColor() const noexcept;
    NSColor *FilePanelsBriefRegularEvenRowBackgroundColor() const noexcept;
    NSColor *FilePanelsBriefRegularOddRowBackgroundColor() const noexcept;
    NSColor *FilePanelsBriefFocusedActiveItemBackgroundColor() const noexcept;
    NSColor *FilePanelsBriefFocusedInactiveItemBackgroundColor() const noexcept;
    NSColor *FilePanelsBriefSelectedItemBackgroundColor() const noexcept;

    
////////////////////////////////////////////////////////////////////////////////////////////////////
//  Terminal Emulator section
////////////////////////////////////////////////////////////////////////////////////////////////////

    // Terminal --> General appearance /////////////////////////////////////////////////////////////
    NSFont  *TerminalFont() const noexcept;
    NSColor *TerminalOverlayColor() const noexcept;
    NSColor *TerminalForegroundColor() const noexcept;
    NSColor *TerminalBoldForegroundColor() const noexcept;
    NSColor *TerminalBackgroundColor() const noexcept;
    NSColor *TerminalSelectionColor() const noexcept;
    NSColor *TerminalCursorColor() const noexcept;
    NSColor *TerminalAnsiColor0() const noexcept;
    NSColor *TerminalAnsiColor1() const noexcept;
    NSColor *TerminalAnsiColor2() const noexcept;
    NSColor *TerminalAnsiColor3() const noexcept;
    NSColor *TerminalAnsiColor4() const noexcept;
    NSColor *TerminalAnsiColor5() const noexcept;
    NSColor *TerminalAnsiColor6() const noexcept;
    NSColor *TerminalAnsiColor7() const noexcept;
    NSColor *TerminalAnsiColor8() const noexcept;
    NSColor *TerminalAnsiColor9() const noexcept;
    NSColor *TerminalAnsiColorA() const noexcept;
    NSColor *TerminalAnsiColorB() const noexcept;
    NSColor *TerminalAnsiColorC() const noexcept;
    NSColor *TerminalAnsiColorD() const noexcept;
    NSColor *TerminalAnsiColorE() const noexcept;
    NSColor *TerminalAnsiColorF() const noexcept;
    
////////////////////////////////////////////////////////////////////////////////////////////////////
//  Internal Viewer section
////////////////////////////////////////////////////////////////////////////////////////////////////

    // Viewer --> General appearance ///////////////////////////////////////////////////////////////
    NSFont  *ViewerFont() const noexcept;
    NSColor *ViewerOverlayColor() const noexcept;
    NSColor *ViewerTextColor() const noexcept;
    NSColor *ViewerSelectionColor() const noexcept;
    NSColor *ViewerBackgroundColor() const noexcept;
    
private:
    struct Internals;
    std::unique_ptr<Internals> I;
};

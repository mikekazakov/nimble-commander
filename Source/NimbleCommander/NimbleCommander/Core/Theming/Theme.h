// Copyright (C) 2016-2026 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <stdint.h>
#include <memory>
#include <vector>
#include <Cocoa/Cocoa.h>
#include "Appearance.h"
#include <swift/bridging>

namespace rapidjson {
template <typename E, typename A>
class GenericValue;
template <typename C>
struct UTF8;
class CrtAllocator;
} // namespace rapidjson

namespace nc::config {
using Value = rapidjson::GenericValue<rapidjson::UTF8<char>, rapidjson::CrtAllocator>;
}

namespace nc::panel {
struct PresentationItemsColoringRule;
}

namespace nc {

class Theme;
class ThemesManager;

/**
 * Thread-safe.
 * Returned reference should not be stored.
 */
const Theme &CurrentTheme() noexcept;

class SWIFT_UNSAFE_REFERENCE Theme
{
public:
    Theme(const nc::config::Value &_theme_data, const nc::config::Value &_backup_theme_data);
    ~Theme();

    // General info querying ///////////////////////////////////////////////////////////////////////
    [[nodiscard]] uint64_t Generation() const noexcept; // monotonically increasing starting with 1

    // General appearance settings /////////////////////////////////////////////////////////////////
    [[nodiscard]] ThemeAppearance AppearanceType() const noexcept;
    [[nodiscard]] NSAppearance *Appearance() const noexcept;

    ////////////////////////////////////////////////////////////////////////////////////////////////////
    //  File Panels section
    ////////////////////////////////////////////////////////////////////////////////////////////////////

    // File Panels --> General appearance //////////////////////////////////////////////////////////
    using ColoringRule = nc::panel::PresentationItemsColoringRule;
    [[nodiscard]] const std::vector<ColoringRule> &FilePanelsItemsColoringRules() const noexcept;
    [[nodiscard]] NSColor *FilePanelsGeneralDropBorderColor() const noexcept;
    [[nodiscard]] NSColor *FilePanelsGeneralOverlayColor() const noexcept;
    [[nodiscard]] NSColor *FilePanelsGeneralSplitterColor() const noexcept;
    [[nodiscard]] NSColor *FilePanelsGeneralTopSeparatorColor() const noexcept;

    // File Panels --> Tabs bar settings ///////////////////////////////////////////////////////////
    [[nodiscard]] NSFont *FilePanelsTabsFont() const noexcept;
    [[nodiscard]] NSColor *FilePanelsTabsTextColor() const noexcept;
    [[nodiscard]] NSColor *FilePanelsTabsSelectedKeyWndActiveBackgroundColor() const noexcept;
    [[nodiscard]] NSColor *FilePanelsTabsSelectedKeyWndInactiveBackgroundColor() const noexcept;
    [[nodiscard]] NSColor *FilePanelsTabsSelectedNotKeyWndBackgroundColor() const noexcept;
    [[nodiscard]] NSColor *FilePanelsTabsRegularKeyWndHoverBackgroundColor() const noexcept;
    [[nodiscard]] NSColor *FilePanelsTabsRegularKeyWndRegularBackgroundColor() const noexcept;
    [[nodiscard]] NSColor *FilePanelsTabsRegularNotKeyWndBackgroundColor() const noexcept;
    [[nodiscard]] NSColor *FilePanelsTabsSeparatorColor() const noexcept;
    [[nodiscard]] NSColor *FilePanelsTabsPictogramColor() const noexcept;

    // File Panels --> Header bar settings /////////////////////////////////////////////////////////
    [[nodiscard]] NSFont *FilePanelsHeaderFont() const noexcept;
    [[nodiscard]] NSColor *FilePanelsHeaderTextColor() const noexcept;
    [[nodiscard]] NSColor *FilePanelsHeaderActiveTextColor() const noexcept;
    [[nodiscard]] NSColor *FilePanelsHeaderActiveBackgroundColor() const noexcept;
    [[nodiscard]] NSColor *FilePanelsHeaderInactiveBackgroundColor() const noexcept;
    [[nodiscard]] NSColor *FilePanelsHeaderSeparatorColor() const noexcept;

    // File Panels --> Footer bar settings /////////////////////////////////////////////////////////
    [[nodiscard]] NSFont *FilePanelsFooterFont() const noexcept;
    [[nodiscard]] NSColor *FilePanelsFooterTextColor() const noexcept;
    [[nodiscard]] NSColor *FilePanelsFooterActiveTextColor() const noexcept;
    [[nodiscard]] NSColor *FilePanelsFooterSeparatorsColor() const noexcept;
    [[nodiscard]] NSColor *FilePanelsFooterActiveBackgroundColor() const noexcept;
    [[nodiscard]] NSColor *FilePanelsFooterInactiveBackgroundColor() const noexcept;

    // File Panels --> List presentation settings //////////////////////////////////////////////////
    [[nodiscard]] NSFont *FilePanelsListFont() const noexcept;
    [[nodiscard]] unsigned FilePanelsListRowVerticalPadding() const noexcept;
    [[nodiscard]] unsigned FilePanelsListSecondaryColumnsOpacity() const noexcept;
    [[nodiscard]] NSColor *FilePanelsListGridColor() const noexcept;
    [[nodiscard]] NSFont *FilePanelsListHeaderFont() const noexcept;
    [[nodiscard]] NSColor *FilePanelsListHeaderBackgroundColor() const noexcept;
    [[nodiscard]] NSColor *FilePanelsListHeaderTextColor() const noexcept;
    [[nodiscard]] NSColor *FilePanelsListHeaderSeparatorColor() const noexcept;
    [[nodiscard]] NSColor *FilePanelsListRegularEvenRowBackgroundColor() const noexcept;
    [[nodiscard]] NSColor *FilePanelsListRegularOddRowBackgroundColor() const noexcept;
    [[nodiscard]] NSColor *FilePanelsListFocusedActiveRowBackgroundColor() const noexcept;
    [[nodiscard]] NSColor *FilePanelsListFocusedInactiveRowBackgroundColor() const noexcept;
    [[nodiscard]] NSColor *FilePanelsListSelectedRowBackgroundColor() const noexcept;

    // File Panels --> Brief presentation settings /////////////////////////////////////////////////
    [[nodiscard]] NSFont *FilePanelsBriefFont() const noexcept;
    [[nodiscard]] unsigned FilePanelsBriefRowVerticalPadding() const noexcept;
    [[nodiscard]] NSColor *FilePanelsBriefGridColor() const noexcept;
    [[nodiscard]] NSColor *FilePanelsBriefRegularEvenRowBackgroundColor() const noexcept;
    [[nodiscard]] NSColor *FilePanelsBriefRegularOddRowBackgroundColor() const noexcept;
    [[nodiscard]] NSColor *FilePanelsBriefFocusedActiveItemBackgroundColor() const noexcept;
    [[nodiscard]] NSColor *FilePanelsBriefFocusedInactiveItemBackgroundColor() const noexcept;
    [[nodiscard]] NSColor *FilePanelsBriefSelectedItemBackgroundColor() const noexcept;

    // File Panels --> Gallery presentation settings /////////////////////////////////////////////////
    [[nodiscard]] NSFont *FilePanelsGalleryFont() const noexcept;
    [[nodiscard]] NSColor *FilePanelsGalleryBackgroundColor() const noexcept;
    [[nodiscard]] NSColor *FilePanelsGalleryFocusedActiveItemBackgroundColor() const noexcept;
    [[nodiscard]] NSColor *FilePanelsGalleryFocusedInactiveItemBackgroundColor() const noexcept;
    [[nodiscard]] NSColor *FilePanelsGallerySelectedItemBackgroundColor() const noexcept;

    ////////////////////////////////////////////////////////////////////////////////////////////////////
    //  Terminal Emulator section
    ////////////////////////////////////////////////////////////////////////////////////////////////////

    // Terminal --> General appearance /////////////////////////////////////////////////////////////
    [[nodiscard]] NSFont *TerminalFont() const noexcept;
    [[nodiscard]] NSColor *TerminalOverlayColor() const noexcept;
    [[nodiscard]] NSColor *TerminalForegroundColor() const noexcept;
    [[nodiscard]] NSColor *TerminalBoldForegroundColor() const noexcept;
    [[nodiscard]] NSColor *TerminalBackgroundColor() const noexcept;
    [[nodiscard]] NSColor *TerminalSelectionColor() const noexcept;
    [[nodiscard]] NSColor *TerminalCursorColor() const noexcept;
    [[nodiscard]] NSColor *TerminalAnsiColor0() const noexcept;
    [[nodiscard]] NSColor *TerminalAnsiColor1() const noexcept;
    [[nodiscard]] NSColor *TerminalAnsiColor2() const noexcept;
    [[nodiscard]] NSColor *TerminalAnsiColor3() const noexcept;
    [[nodiscard]] NSColor *TerminalAnsiColor4() const noexcept;
    [[nodiscard]] NSColor *TerminalAnsiColor5() const noexcept;
    [[nodiscard]] NSColor *TerminalAnsiColor6() const noexcept;
    [[nodiscard]] NSColor *TerminalAnsiColor7() const noexcept;
    [[nodiscard]] NSColor *TerminalAnsiColor8() const noexcept;
    [[nodiscard]] NSColor *TerminalAnsiColor9() const noexcept;
    [[nodiscard]] NSColor *TerminalAnsiColorA() const noexcept;
    [[nodiscard]] NSColor *TerminalAnsiColorB() const noexcept;
    [[nodiscard]] NSColor *TerminalAnsiColorC() const noexcept;
    [[nodiscard]] NSColor *TerminalAnsiColorD() const noexcept;
    [[nodiscard]] NSColor *TerminalAnsiColorE() const noexcept;
    [[nodiscard]] NSColor *TerminalAnsiColorF() const noexcept;

    ////////////////////////////////////////////////////////////////////////////////////////////////////
    //  Internal Viewer section
    ////////////////////////////////////////////////////////////////////////////////////////////////////

    // Viewer --> General appearance ///////////////////////////////////////////////////////////////
    [[nodiscard]] NSFont *ViewerFont() const noexcept;
    [[nodiscard]] NSColor *ViewerOverlayColor() const noexcept;
    [[nodiscard]] NSColor *ViewerTextColor() const noexcept;
    [[nodiscard]] NSColor *ViewerTextSyntaxCommentColor() const noexcept;
    [[nodiscard]] NSColor *ViewerTextSyntaxPreprocessorColor() const noexcept;
    [[nodiscard]] NSColor *ViewerTextSyntaxKeywordColor() const noexcept;
    [[nodiscard]] NSColor *ViewerTextSyntaxOperatorColor() const noexcept;
    [[nodiscard]] NSColor *ViewerTextSyntaxIdentifierColor() const noexcept;
    [[nodiscard]] NSColor *ViewerTextSyntaxNumberColor() const noexcept;
    [[nodiscard]] NSColor *ViewerTextSyntaxStringColor() const noexcept;
    [[nodiscard]] NSColor *ViewerSelectionColor() const noexcept;
    [[nodiscard]] NSColor *ViewerBackgroundColor() const noexcept;

private:
    struct Internals;
    std::unique_ptr<Internals> I;
};

} // namespace nc

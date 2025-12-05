// Copyright (C) 2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Viewer/Localizable.h>
#include "Internal.h"

// NB! Do NOT include this file into the unity build lest it break Xcode's automatic extraction of localizable strings.

namespace nc::viewer::localizable {

NSString *FooterSyntaxPlainText()
{
    return NSLocalizedString(@"Plain Text", "Menu element of language selection");
}

NSString *FooterModeTextTitle()
{
    return NSLocalizedString(@"Text", "Tooltip for menu element");
}

NSString *FooterModeHexTitle()
{
    return NSLocalizedString(@"Hex", "Tooltip for menu element");
}

NSString *FooterModePreviewTitle()
{
    return NSLocalizedString(@"Preview", "Tooltip for menu element");
}

NSString *FooterModeTooltip()
{
    return NSLocalizedString(@"View mode", "Tooltip for the footer element");
}

NSString *FooterEncodingTooltip()
{
    return NSLocalizedString(@"File encoding", "Tooltip for the footer element");
}

NSString *FooterLanguageHighlightingTooltip()
{
    return NSLocalizedString(@"Language highlighting", "Tooltip for the footer element");
}

NSString *FooterWrapLinesTooltip()
{
    return NSLocalizedString(@"Wrap lines", "Tooltip for the footer element");
}

NSString *FooterFileSizeTooltip()
{
    return NSLocalizedString(@"File size", "Tooltip for the footer element");
}

NSString *FooterFilePositionTooltip()
{
    return NSLocalizedString(@"File position", "Tooltip for the footer element");
}

NSString *ViewControllerSearchInFilePlaceholder()
{
    return NSLocalizedString(@"Search in file", "Placeholder for search text field in internal viewer");
}

NSString *ViewControllerCaseSensitiveSearchMenuTitle()
{
    return NSLocalizedString(@"Case-sensitive search", "Menu item option in internal viewer search");
}

NSString *ViewControllerFindWholePhraseMenuTitle()
{
    return NSLocalizedString(@"Find whole phrase", "Menu item option in internal viewer search");
}

NSString *ViewControllerClearRecentsMenuTitle()
{
    return NSLocalizedString(@"Clear Recents", "Menu item title in internal viewer search");
}

NSString *ViewControllerRecentSearchesMenuTitle()
{
    return NSLocalizedString(@"Recent Searches", "Menu item title in internal viewer search");
}

NSString *ViewControllerRecentsMenuTitle()
{
    return NSLocalizedString(@"Recents", "Menu item title in internal viewer search");
}

NSString *ViewControllerTitleFormat()
{
    return NSLocalizedString(@"File View - %@", "Window title for internal file viewer");
}

NSString *ViewControllerOpeningFileTitle()
{
    return NSLocalizedString(@"Opening file...", "Title for process sheet when opening a vfs file");
}

} // namespace nc::viewer::localizable

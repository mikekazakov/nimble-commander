// Copyright (C) 2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

@class NSString;

namespace nc::viewer::localizable {

NSString *FooterSyntaxPlainText();
NSString *FooterModeTextTitle();
NSString *FooterModeHexTitle();
NSString *FooterModePreviewTitle();
NSString *FooterModeTooltip();
NSString *FooterEncodingTooltip();
NSString *FooterLanguageHighlightingTooltip();
NSString *FooterWrapLinesTooltip();
NSString *FooterFileSizeTooltip();
NSString *FooterFilePositionTooltip();
NSString *ViewControllerSearchInFilePlaceholder();
NSString *ViewControllerCaseSensitiveSearchMenuTitle();
NSString *ViewControllerFindWholePhraseMenuTitle();
NSString *ViewControllerClearRecentsMenuTitle();
NSString *ViewControllerRecentSearchesMenuTitle();
NSString *ViewControllerRecentsMenuTitle();
NSString *ViewControllerTitleFormat();
NSString *ViewControllerOpeningFileTitle();

// NSLocalizedString(@"Opening file...", "Title for process sheet when opening a vfs file")

// NSLocalizedString(@"File View - %@", "Window title for internal file viewer")

// NSLocalizedString(@"Recents", "Menu item title in internal viewer search")

// NSLocalizedString(@"Recent Searches", "Menu item title in internal viewer search")

} // namespace nc::viewer::localizable

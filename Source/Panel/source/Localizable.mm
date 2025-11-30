// Copyright (C) 2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Panel/Localizable.h>
#include <Panel/Internal.h>

// NB! Do NOT include this file into the unity build lest it break Xcode's automatic extraction of localizable strings.

namespace nc::panel::localizable {

NSString *ExternalToolsStorageNewToolPlaceholderTitle()
{
    return NSLocalizedString(@"New Tool", "A placeholder title for a new external tool");
}

NSString *SelectFilesByMaskPopupSelectTitle()
{
    return NSLocalizedString(@"Select files by mask:", "Title for selection by mask popup");
}

NSString *SelectFilesByMaskPopupDeselectTitle()
{
    return NSLocalizedString(@"Deselect files by mask:", "Title for deselection by mask popup");
}

NSString *SelectFilesByMaskPopupOptionsTitle()
{
    return NSLocalizedString(@"Options", "Title for options menu item in selection by mask popup");
}

NSString *SelectFilesByMaskPopupRegularExpressionTitle()
{
    return NSLocalizedString(@"Regular Expression", "Title for regular expression option in selection by mask popup");
}

NSString *SelectFilesByMaskPopupRegularRecentSearchesTitle()
{
    return NSLocalizedString(@"Recent Searches", "Title for recent searches menu item in selection by mask popup");
}

NSString *SelectFilesByMaskPopupHistoryMaskFormat()
{
    return NSLocalizedString(@"Mask \u201c%@\u201d", "Find file masks history - plain mask");
}

NSString *SelectFilesByMaskPopupHistoryRegExFormat()
{
    return NSLocalizedString(@"RegEx \u201c%@\u201d", "Find file masks history - regex");
}

NSString *SelectFilesByMaskPopupRegularClearRecentsTitle()
{
    return NSLocalizedString(@"Clear Recents", "Title for clear recents menu item in selection by mask popup");
}

NSString *SelectFilesByMaskPopupMaskPlaceholder()
{
    return NSLocalizedString(@"Mask: *, or *.t?t, or *.txt,*.jpg", "Placeholder prompt for a filemask");
}

NSString *SelectFilesByMaskPopupMaskTooltip()
{
    return NSLocalizedString(@"Use \"*\" for multiple-character wildcard, \"?\" for single-character wildcard and "
                             @"\",\" to specify more than one mask.",
                             "Tooltip for mask filename match");
}

NSString *SelectFilesByMaskPopupRegExPlaceholder()
{
    return NSLocalizedString(@"Regular expression", "Placeholder prompt for a regex");
}

NSString *SelectFilesByMaskPopupRegExTooltip()
{
    return NSLocalizedString(@"Specify a regular expression to match filenames with.",
                             "Tooltip for a regex filename match");
}

} // namespace nc::panel::localizable

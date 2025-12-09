// Copyright (C) 2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Operations/Localizable.h>
#include "Internal.h"

// NB! Do NOT include this file into the unity build lest it break Xcode's automatic extraction of localizable strings.

namespace nc::ops::localizable {

NSString *BriefOperationViewControllerWaitingInTheQueueTitle()
{
    return NSLocalizedString(@"Waiting in the queue...", "");
}

NSString *GenericErrorDialogCloseTitle()
{
    return NSLocalizedString(@"Close", "");
}

NSString *GenericErrorDialogAbortTitle()
{
    return NSLocalizedString(@"Abort", "");
}

NSString *GenericErrorDialogSkipTitle()
{
    return NSLocalizedString(@"Skip", "");
}

NSString *GenericErrorDialogSkipAllTitle()
{
    return NSLocalizedString(@"Skip All", "");
}

NSString *AttrChangingAlteringFileAttributesTitle()
{
    return NSLocalizedString(@"Altering file attributes", "Title for attributes changing operation");
}

NSString *AttrChangingFailedToAccessAnItemMessage()
{
    return NSLocalizedString(@"Failed to access an item", "");
}

NSString *AttrChangingFailedToPerformChmodMessage()
{
    return NSLocalizedString(@"Failed to perform chmod", "");
}

NSString *AttrChangingFailedToPerformChownMessage()
{
    return NSLocalizedString(@"Failed to perform chown", "");
}

NSString *AttrChangingFailedToPerformChflagsMessage()
{
    return NSLocalizedString(@"Failed to perform chflags", "");
}

NSString *AttrChangingFailedToPerformSetTimeMessage()
{
    return NSLocalizedString(@"Failed to set file time", "");
}

} // namespace nc::ops::localizable

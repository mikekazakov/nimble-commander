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

} // namespace nc::ops::localizable

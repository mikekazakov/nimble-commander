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

NSString *BatchRenamingFailedToRenameMessage()
{
    return NSLocalizedString(@"Failed to rename an item", "");
}

NSString *BatchRenamingBatchRenamingTitle()
{
    return NSLocalizedString(@"Batch renaming %@ items", "Operation title batch renaming");
}

NSString *BatchRenamingCantRemoveLastItemMessage()
{
    return NSLocalizedString(@"Cannot remove the last item being renamed",
                             "Alert shown when a user tries to remove all item from a Batch Rename dialog");
}

NSString *CompressionFailedToWriteArchiveMessage()
{
    return NSLocalizedString(@"Failed to write an archive", "");
}

NSString *CompressionFailedToReadFileMessage()
{
    return NSLocalizedString(@"Failed to read a file", "");
}

NSString *CompressionFailedToAccessFileMessage()
{
    return NSLocalizedString(@"Failed to access an item", "");
}

NSString *CompressionCompressingItemsTitle()
{
    return NSLocalizedString(@"Compressing %d items", "Compressing %d items");
}

NSString *CompressionCompressingItemTitle()
{
    return NSLocalizedString(@"Compressing \u201c%@\u201d", "Compressing \u201c%@\u201d");
}

NSString *CompressionCompressingToTitle()
{
    return NSLocalizedString(@"%@ to \u201c%@\u201d", "Compressing \u201c%@\u201d");
}

NSString *CompressionDiaglogCompressItemsToTitle()
{
    return NSLocalizedString(@"Compress %@ items to:", "Compress files sheet prompt, compressing many files");
}

NSString *CompressionDiaglogCompressItemToTitle()
{
    return NSLocalizedString(@"Compress \u201c%@\u201d to:", "Compress files sheet prompt, compressing single file");
}

} // namespace nc::ops::localizable

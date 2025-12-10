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

NSString *AttrChangingSingleTitle()
{
    return NSLocalizedString(@"Change file attributes for \u201c%@\u201d",
                             "Title for file attributes sheet, single item");
}

NSString *AttrChangingMultiTitle()
{
    return NSLocalizedString(@"Change file attributes for %@ selected items",
                             "Title for file attributes sheet, multiple items");
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

NSString *OperationAbortTitle()
{

    return NSLocalizedString(@"Abort", "");
}

NSString *OperationRetryTitle()
{
    return NSLocalizedString(@"Retry", "");
}

NSString *OperationContinueTitle()
{
    return NSLocalizedString(@"Continue", "");
}

NSString *OperationSkipTitle()
{
    return NSLocalizedString(@"Skip", "");
}

NSString *OperationSkipAllTitle()
{
    return NSLocalizedString(@"Skip All", "");
}

NSString *OperationOverwriteTitle()
{
    return NSLocalizedString(@"Overwrite", "");
}

NSString *OperationUnlockTitle()
{
    return NSLocalizedString(@"Unlock", "");
}

NSString *StatisticsFormatterVolOfVolPaused()
{
    return NSLocalizedString(@"%@ of %@ - Paused", "");
}

NSString *StatisticsFormatterVolOfVol()
{
    return NSLocalizedString(@"%@ of %@", "");
}

NSString *StatisticsFormatterVolOfVolEta()
{
    return NSLocalizedString(@"%@ of %@, %@", "");
}

NSString *StatisticsFormatterVolOfVolSpeed()
{
    return NSLocalizedString(@"%@ of %@ - %@/s", "");
}

NSString *StatisticsFormatterVolOfVolSpeedEta()
{
    return NSLocalizedString(@"%@ of %@ - %@/s, %@", "");
}

NSString *CopyingFailedToAccessFileMessage()
{
    return NSLocalizedString(@"Failed to access a file", "");
}

NSString *CopyingFailedToOpenDestFileMessage()
{
    return NSLocalizedString(@"Failed to open a destination file", "");
}

NSString *CopyingFailedToReadSourceFileMessage()
{
    return NSLocalizedString(@"Failed to read a source file", "");
}

NSString *CopyingFailedToReadDestFileMessage()
{
    return NSLocalizedString(@"Failed to read a destination file", "");
}

NSString *CopyingFailedToWriteDestFileMessage()
{
    return NSLocalizedString(@"Failed to write a file", "");
}

NSString *CopyingFailedToCreateDirectoryMessage()
{
    return NSLocalizedString(@"Failed to create a directory", "");
}

NSString *CopyingFailedToDeleteDestFileMessage()
{
    return NSLocalizedString(@"Failed to delete a destination file", "");
}

NSString *CopyingChecksumVerificationFailedMessage()
{
    return NSLocalizedString(@"Checksum verification failed", "");
}

NSString *CopyingFailedToDeleteSourceFileMessage()
{
    return NSLocalizedString(@"Failed to delete a source item", "");
}

NSString *CopyingItemNotDirMessage()
{

    return NSLocalizedString(@"Item is not a directory", "");
}

NSString *CopyingCantRenameLockedMessage()
{
    return NSLocalizedString(@"Cannot rename a locked item", "");
}

NSString *CopyingCantDeleteLockedMessage()
{
    return NSLocalizedString(@"Cannot delete a locked item", "");
}

NSString *CopyingCantOpenLockedMessage()
{
    return NSLocalizedString(@"Cannot open a locked item", "");
}

NSString *CopyingFailedToUnlockMessage()
{
    return NSLocalizedString(@"Failed to unlock an item", "");
}

NSString *CopyingDialogCopyItemsToTitle()
{
    return NSLocalizedString(@"Copy %@ items to:", "Copy files sheet prompt, copying many files");
}

NSString *CopyingDialogCopyItemToTitle()
{
    return NSLocalizedString(@"Copy \u201c%@\u201d to:", "Copy files sheet prompt, copying single file");
}

NSString *CopyingDialogMoveItemsToTitle()
{
    return NSLocalizedString(@"Rename/move %@ items to:", "Move files sheet prompt, moving many files");
}

NSString *CopyingDialogMoveItemToTitle()
{
    return NSLocalizedString(@"Rename/move \u201c%@\u201d to:", "Move files sheet prompt, moving single file");
}

NSString *CopyingTitleCopyingPrefix()
{
    return NSLocalizedString(@"Copying", "Prefix of a file operation");
}

NSString *CopyingTitleMovingPrefix()
{
    return NSLocalizedString(@"Moving", "Prefix of a file operation");
}

NSString *CopyingTitleSingleSuffix()
{
    return NSLocalizedString(@"%@ \u201c%@\u201d to \u201c%@\u201d", "");
}

NSString *CopyingTitleMultiSuffix()
{
    return NSLocalizedString(@"%@ %@ items to \u201c%@\u201d", "");
}

NSString *CopyingTitlePreparingToCopySingle()
{
    return NSLocalizedString(@"Preparing to copy \u201c%@\u201d", "");
}

NSString *CopyingTitlePreparingToMoveSingle()
{
    return NSLocalizedString(@"Preparing to move \u201c%@\u201d", "");
}

NSString *CopyingTitlePreparingToCopyMulti()
{
    return NSLocalizedString(@"Preparing to copy %@ items", "");
}

NSString *CopyingTitlePreparingToMoveMulti()
{
    return NSLocalizedString(@"Preparing to move %@ items", "");
}

NSString *CopyingTitleVerifyingResult()
{
    return NSLocalizedString(@"Verifying operation result..", "");
}

NSString *CopyingTitleCleaningUp()
{
    return NSLocalizedString(@"Cleaning up..", "");
}

NSString *DeletionFailedToAccessDirectoryMessage()
{
    return NSLocalizedString(@"Failed to access a directory", "");
}

NSString *DeletionFailedToDeleteFileMessage()
{
    return NSLocalizedString(@"Failed to delete a file", "");
}

NSString *DeletionFailedToDeleteDirectoryMessage()
{
    return NSLocalizedString(@"Failed to delete a directory", "");
}

NSString *DeletionFailedToMoveToTrashMessage()
{
    return NSLocalizedString(@"Failed to move an item to Trash", "");
}

NSString *DeletionDeletePermanentlyTitle()
{
    return NSLocalizedString(@"Delete Permanently", "");
}

NSString *DeletionCannotDeleteLockedMessage()
{
    return NSLocalizedString(@"Cannot delete a locked item", "");
}

NSString *DeletionCannotTrashLockedMessage()
{
    return NSLocalizedString(@"Cannot move a locked item to Trash", "");
}

NSString *DeletionUnlockTitle()
{
    return NSLocalizedString(@"Unlock", "");
}

NSString *DeletionFailedToUnlockMessage()
{
    return NSLocalizedString(@"Failed to unlock an item", "");
}

NSString *DeletionSingleTitle()
{
    return NSLocalizedString(@"Deleting \u201c%@\u201d", "Operation title for single item deletion");
}

NSString *DeletionMultiTitle()
{
    return NSLocalizedString(@"Deleting %@ items", "Operation title for multiple items deletion");
}

NSString *DeletionDialogMoveToTrashTitle()
{
    return NSLocalizedString(@"Move to Trash", "Menu item title in file deletion sheet");
}

NSString *DeletionDialogDeletePermanentlyTitle()
{
    return NSLocalizedString(@"Delete Permanently", "Menu item title in file deletion sheet");
}

NSString *DeletionDialogDoYouWantToDeleteSingleMessage()
{
    return NSLocalizedString(@"Do you want to delete “%@”?", "Asking user to delete a file");
}

NSString *DeletionDialogDoYouWantToDeleteMultiMessage()
{
    return NSLocalizedString(@"Do you want to delete %@ items?", "Asking user to delete multiple files");
}

} // namespace nc::ops::localizable

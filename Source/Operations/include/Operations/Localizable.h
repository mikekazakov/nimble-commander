// Copyright (C) 2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

@class NSString;

namespace nc::ops::localizable {

NSString *BriefOperationViewControllerWaitingInTheQueueTitle();
NSString *GenericErrorDialogCloseTitle();
NSString *GenericErrorDialogAbortTitle();
NSString *GenericErrorDialogSkipTitle();
NSString *GenericErrorDialogSkipAllTitle();
NSString *AttrChangingAlteringFileAttributesTitle();
NSString *AttrChangingFailedToAccessAnItemMessage();
NSString *AttrChangingFailedToPerformChmodMessage();
NSString *AttrChangingFailedToPerformChownMessage();
NSString *AttrChangingFailedToPerformChflagsMessage();
NSString *AttrChangingFailedToPerformSetTimeMessage();
NSString *BatchRenamingFailedToRenameMessage();
NSString *BatchRenamingBatchRenamingTitle();
NSString *BatchRenamingCantRemoveLastItemMessage();
NSString *CompressionFailedToWriteArchiveMessage();
NSString *CompressionFailedToReadFileMessage();
NSString *CompressionFailedToAccessFileMessage();
NSString *CompressionCompressingItemsTitle();
NSString *CompressionCompressingItemTitle();
NSString *CompressionCompressingToTitle();
NSString *CompressionDiaglogCompressItemsToTitle();
NSString *CompressionDiaglogCompressItemToTitle();

} // namespace nc::ops::localizable

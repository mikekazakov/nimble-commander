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
NSString *AttrChangingSingleTitle();
NSString *AttrChangingMultiTitle();
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
NSString *OperationAbortTitle();
NSString *OperationRetryTitle();
NSString *OperationContinueTitle();
NSString *OperationSkipTitle();
NSString *OperationSkipAllTitle();
NSString *OperationOverwriteTitle();
NSString *StatisticsFormatterVolOfVolPaused();
NSString *StatisticsFormatterVolOfVol();
NSString *StatisticsFormatterVolOfVolEta();
NSString *StatisticsFormatterVolOfVolSpeed();
NSString *StatisticsFormatterVolOfVolSpeedEta();

} // namespace nc::ops::localizable

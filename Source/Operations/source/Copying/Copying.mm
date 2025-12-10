// Copyright (C) 2017-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Copying.h"
#include "CopyingJob.h"
#include <Operations/Localizable.h>
#include "../AsyncDialogResponse.h"
#include "../Internal.h"
#include "../GenericErrorDialog.h"
#include "FileAlreadyExistDialog.h"
#include "CopyingTitleBuilder.h"
#include <sys/stat.h>

#include <memory>

namespace nc::ops {

Copying::Copying(std::vector<VFSListingItem> _source_files,
                 const std::string &_destination_path,
                 const std::shared_ptr<VFSHost> &_destination_host,
                 const CopyingOptions &_options)
{
    m_ExistBehavior = _options.exist_behavior;
    m_LockedBehaviour = _options.locked_items_behaviour;

    m_Job = std::make_unique<CopyingJob>(_source_files, _destination_path, _destination_host, _options);
    SetupCallbacks();
    OnStageChanged();
}

Copying::~Copying()
{
    Wait();
}

void Copying::SetupCallbacks()
{
    auto &j = *m_Job;
    j.m_OnCopyDestinationAlreadyExists =
        [this](const struct stat &_src, const struct stat &_dst, const std::string &_path) {
            return OnCopyDestExists(_src, _dst, _path);
        };
    j.m_OnRenameDestinationAlreadyExists =
        [this](const struct stat &_src, const struct stat &_dst, const std::string &_path) {
            return OnRenameDestExists(_src, _dst, _path);
        };
    j.m_OnCantAccessSourceItem = [this](Error _1, const std::string &_2, VFSHost &_3) {
        return OnCantAccessSourceItem(_1, _2, _3);
    };
    j.m_OnCantOpenDestinationFile = [this](Error _1, const std::string &_2, VFSHost &_3) {
        return OnCantOpenDestinationFile(_1, _2, _3);
    };
    j.m_OnSourceFileReadError = [this](Error _1, const std::string &_2, VFSHost &_3) {
        return OnSourceFileReadError(_1, _2, _3);
    };
    j.m_OnDestinationFileReadError = [this](Error _1, const std::string &_2, VFSHost &_3) {
        return OnDestinationFileReadError(_1, _2, _3);
    };
    j.m_OnDestinationFileWriteError = [this](Error _1, const std::string &_2, VFSHost &_3) {
        return OnDestinationFileWriteError(_1, _2, _3);
    };
    j.m_OnCantCreateDestinationRootDir = [this](Error _1, const std::string &_2, VFSHost &_3) {
        return OnCantCreateDestinationRootDir(_1, _2, _3);
    };
    j.m_OnCantCreateDestinationDir = [this](Error _1, const std::string &_2, VFSHost &_3) {
        return OnCantCreateDestinationDir(_1, _2, _3);
    };
    j.m_OnCantDeleteDestinationFile = [this](Error _1, const std::string &_2, VFSHost &_3) {
        return OnCantDeleteDestinationFile(_1, _2, _3);
    };
    j.m_OnCantDeleteSourceItem = [this](Error _1, const std::string &_2, VFSHost &_3) {
        return OnCantDeleteSourceItem(_1, _2, _3);
    };
    j.m_OnCantRenameLockedItem = [this](Error _1, const std::string &_2, VFSHost &_3) {
        return OnLockedItemIssue(_1, _2, _3, LockedItemCause::Moving);
    };
    j.m_OnCantDeleteLockedItem = [this](Error _1, const std::string &_2, VFSHost &_3) {
        return OnLockedItemIssue(_1, _2, _3, LockedItemCause::Deletion);
    };
    j.m_OnCantOpenLockedItem = [this](Error _1, const std::string &_2, VFSHost &_3) {
        return OnLockedItemIssue(_1, _2, _3, LockedItemCause::Opening);
    };
    j.m_OnUnlockError = [this](Error _1, const std::string &_2, VFSHost &_3) { return OnUnlockError(_1, _2, _3); };
    j.m_OnNotADirectory = [this](const std::string &_1, VFSHost &_2) { return OnNotADirectory(_1, _2); };
    j.m_OnFileVerificationFailed = [this](const std::string &_1, VFSHost &_2) { OnFileVerificationFailed(_1, _2); };
    j.m_OnStageChanged = [this]() { OnStageChanged(); };
}

Job *Copying::GetJob() noexcept
{
    return m_Job.get();
}

Copying::CB::CopyDestExistsResolution
Copying::OnCopyDestExists(const struct stat &_src, const struct stat &_dst, const std::string &_path)
{
    if( m_CallbackHooks && m_CallbackHooks->m_OnCopyDestinationAlreadyExists )
        return m_CallbackHooks->m_OnCopyDestinationAlreadyExists(_src, _dst, _path);

    switch( m_ExistBehavior ) {
        case CopyingOptions::ExistBehavior::SkipAll:
            return CB::CopyDestExistsResolution::Skip;
        case CopyingOptions::ExistBehavior::Stop:
            return CB::CopyDestExistsResolution::Stop;
        case CopyingOptions::ExistBehavior::AppendAll:
            return CB::CopyDestExistsResolution::Append;
        case CopyingOptions::ExistBehavior::OverwriteAll:
            return CB::CopyDestExistsResolution::Overwrite;
        case CopyingOptions::ExistBehavior::OverwriteOld:
            return CB::CopyDestExistsResolution::OverwriteOld;
        case CopyingOptions::ExistBehavior::KeepBoth:
            return CB::CopyDestExistsResolution::KeepBoth;
        default:
            break;
    }

    if( !IsInteractive() )
        return CB::CopyDestExistsResolution::Stop;

    const auto ctx = std::make_shared<AsyncDialogResponse>();
    dispatch_to_main_queue([=, this] { OnCopyDestExistsUI(_src, _dst, _path, ctx); });
    WaitForDialogResponse(ctx);

    if( ctx->response == NSModalResponseSkip ) {
        if( ctx->IsApplyToAllSet() )
            m_ExistBehavior = CopyingOptions::ExistBehavior::SkipAll;
        return CB::CopyDestExistsResolution::Skip;
    }
    if( ctx->response == NSModalResponseAppend ) {
        if( ctx->IsApplyToAllSet() )
            m_ExistBehavior = CopyingOptions::ExistBehavior::AppendAll;
        return CB::CopyDestExistsResolution::Append;
    }
    if( ctx->response == NSModalResponseOverwrite ) {
        if( ctx->IsApplyToAllSet() )
            m_ExistBehavior = CopyingOptions::ExistBehavior::OverwriteAll;
        return CB::CopyDestExistsResolution::Overwrite;
    }
    if( ctx->response == NSModalResponseOverwriteOld ) {
        if( ctx->IsApplyToAllSet() )
            m_ExistBehavior = CopyingOptions::ExistBehavior::OverwriteOld;
        return CB::CopyDestExistsResolution::OverwriteOld;
    }
    if( ctx->response == NSModalResponseKeepBoth ) {
        if( ctx->IsApplyToAllSet() )
            m_ExistBehavior = CopyingOptions::ExistBehavior::KeepBoth;
        return CB::CopyDestExistsResolution::KeepBoth;
    }
    return CB::CopyDestExistsResolution::Stop;
}

void Copying::OnCopyDestExistsUI(const struct stat &_src,
                                 const struct stat &_dst,
                                 const std::string &_path,
                                 std::shared_ptr<AsyncDialogResponse> _ctx)
{
    const auto sheet = [[NCOpsFileAlreadyExistDialog alloc] initWithDestPath:_path
                                                              withSourceStat:_src
                                                         withDestinationStat:_dst
                                                                  andContext:_ctx];
    sheet.allowAppending = true;
    sheet.allowKeepingBoth = true;
    sheet.singleItem = m_Job->IsSingleScannedItemProcessing();
    Show(sheet.window, _ctx);
}

Copying::CB::RenameDestExistsResolution
Copying::OnRenameDestExists(const struct stat &_src, const struct stat &_dst, const std::string &_path)
{
    if( m_CallbackHooks && m_CallbackHooks->m_OnRenameDestinationAlreadyExists )
        return m_CallbackHooks->m_OnRenameDestinationAlreadyExists(_src, _dst, _path);

    switch( m_ExistBehavior ) {
        case CopyingOptions::ExistBehavior::SkipAll:
            return CB::RenameDestExistsResolution::Skip;
        case CopyingOptions::ExistBehavior::Stop:
            return CB::RenameDestExistsResolution::Stop;
        case CopyingOptions::ExistBehavior::OverwriteAll:
            return CB::RenameDestExistsResolution::Overwrite;
        case CopyingOptions::ExistBehavior::OverwriteOld:
            return CB::RenameDestExistsResolution::OverwriteOld;
        case CopyingOptions::ExistBehavior::KeepBoth:
            return CB::RenameDestExistsResolution::KeepBoth;
        default:
            break;
    }

    if( !IsInteractive() )
        return CB::RenameDestExistsResolution::Stop;

    const auto ctx = std::make_shared<AsyncDialogResponse>();
    dispatch_to_main_queue([=, this] { OnRenameDestExistsUI(_src, _dst, _path, ctx); });
    WaitForDialogResponse(ctx);

    if( ctx->response == NSModalResponseSkip ) {
        if( ctx->IsApplyToAllSet() )
            m_ExistBehavior = CopyingOptions::ExistBehavior::SkipAll;
        return CB::RenameDestExistsResolution::Skip;
    }
    if( ctx->response == NSModalResponseOverwrite ) {
        if( ctx->IsApplyToAllSet() )
            m_ExistBehavior = CopyingOptions::ExistBehavior::OverwriteAll;
        return CB::RenameDestExistsResolution::Overwrite;
    }
    if( ctx->response == NSModalResponseOverwriteOld ) {
        if( ctx->IsApplyToAllSet() )
            m_ExistBehavior = CopyingOptions::ExistBehavior::OverwriteOld;
        return CB::RenameDestExistsResolution::OverwriteOld;
    }
    if( ctx->response == NSModalResponseKeepBoth ) {
        if( ctx->IsApplyToAllSet() )
            m_ExistBehavior = CopyingOptions::ExistBehavior::KeepBoth;
        return CB::RenameDestExistsResolution::KeepBoth;
    }
    return CB::RenameDestExistsResolution::Stop;
}

void Copying::OnRenameDestExistsUI(const struct stat &_src,
                                   const struct stat &_dst,
                                   const std::string &_path,
                                   std::shared_ptr<AsyncDialogResponse> _ctx)
{
    const auto sheet = [[NCOpsFileAlreadyExistDialog alloc] initWithDestPath:_path
                                                              withSourceStat:_src
                                                         withDestinationStat:_dst
                                                                  andContext:_ctx];
    sheet.singleItem = m_Job->IsSingleScannedItemProcessing();
    sheet.allowAppending = false;
    sheet.allowKeepingBoth = true;
    Show(sheet.window, _ctx);
}

Copying::CB::CantAccessSourceItemResolution
Copying::OnCantAccessSourceItem(Error _error, const std::string &_path, VFSHost &_vfs)
{
    if( m_CallbackHooks && m_CallbackHooks->m_OnCantAccessSourceItem )
        return m_CallbackHooks->m_OnCantAccessSourceItem(_error, _path, _vfs);

    if( m_SkipAll )
        return CB::CantAccessSourceItemResolution::Skip;
    if( !IsInteractive() )
        return CB::CantAccessSourceItemResolution::Stop;

    const auto ctx = std::make_shared<AsyncDialogResponse>();
    ShowGenericDialog(GenericDialog::AbortSkipSkipAllRetry,
                      localizable::CopyingFailedToAccessFileMessage(),
                      _error,
                      {_vfs, _path},
                      ctx);
    WaitForDialogResponse(ctx);

    if( ctx->response == NSModalResponseSkip )
        return CB::CantAccessSourceItemResolution::Skip;
    else if( ctx->response == NSModalResponseSkipAll ) {
        m_SkipAll = true;
        return CB::CantAccessSourceItemResolution::Skip;
    }
    else if( ctx->response == NSModalResponseRetry )
        return CB::CantAccessSourceItemResolution::Retry;
    else
        return CB::CantAccessSourceItemResolution::Stop;
}

Copying::CB::CantOpenDestinationFileResolution
Copying::OnCantOpenDestinationFile(Error _error, const std::string &_path, VFSHost &_vfs)
{
    if( m_CallbackHooks && m_CallbackHooks->m_OnCantOpenDestinationFile )
        return m_CallbackHooks->m_OnCantOpenDestinationFile(_error, _path, _vfs);

    if( m_SkipAll )
        return CB::CantOpenDestinationFileResolution::Skip;
    if( !IsInteractive() )
        return CB::CantOpenDestinationFileResolution::Stop;

    const auto ctx = std::make_shared<AsyncDialogResponse>();
    ShowGenericDialog(GenericDialog::AbortSkipSkipAllRetry,
                      localizable::CopyingFailedToOpenDestFileMessage(),
                      _error,
                      {_vfs, _path},
                      ctx);
    WaitForDialogResponse(ctx);

    if( ctx->response == NSModalResponseSkip )
        return CB::CantOpenDestinationFileResolution::Skip;
    else if( ctx->response == NSModalResponseSkipAll ) {
        m_SkipAll = true;
        return CB::CantOpenDestinationFileResolution::Skip;
    }
    else if( ctx->response == NSModalResponseRetry )
        return CB::CantOpenDestinationFileResolution::Retry;
    else
        return CB::CantOpenDestinationFileResolution::Stop;
}

Copying::CB::SourceFileReadErrorResolution
Copying::OnSourceFileReadError(Error _error, const std::string &_path, VFSHost &_vfs)
{
    if( m_CallbackHooks && m_CallbackHooks->m_OnSourceFileReadError )
        return m_CallbackHooks->m_OnSourceFileReadError(_error, _path, _vfs);

    if( m_SkipAll )
        return CB::SourceFileReadErrorResolution::Skip;
    if( !IsInteractive() )
        return CB::SourceFileReadErrorResolution::Stop;

    const auto ctx = std::make_shared<AsyncDialogResponse>();
    ShowGenericDialog(GenericDialog::AbortSkipSkipAllRetry,
                      localizable::CopyingFailedToReadSourceFileMessage(),
                      _error,
                      {_vfs, _path},
                      ctx);
    WaitForDialogResponse(ctx);

    if( ctx->response == NSModalResponseSkip )
        return CB::SourceFileReadErrorResolution::Skip;
    else if( ctx->response == NSModalResponseSkipAll ) {
        m_SkipAll = true;
        return CB::SourceFileReadErrorResolution::Skip;
    }
    else if( ctx->response == NSModalResponseRetry )
        return CB::SourceFileReadErrorResolution::Retry;
    else
        return CB::SourceFileReadErrorResolution::Stop;
}

Copying::CB::DestinationFileReadErrorResolution
Copying::OnDestinationFileReadError(Error _error, const std::string &_path, VFSHost &_vfs)
{
    if( m_CallbackHooks && m_CallbackHooks->m_OnDestinationFileReadError )
        return m_CallbackHooks->m_OnDestinationFileReadError(_error, _path, _vfs);

    if( m_SkipAll )
        return CB::DestinationFileReadErrorResolution::Skip;
    if( !IsInteractive() )
        return CB::DestinationFileReadErrorResolution::Stop;

    const auto ctx = std::make_shared<AsyncDialogResponse>();
    ShowGenericDialog(
        GenericDialog::AbortSkipSkipAll, localizable::CopyingFailedToReadDestFileMessage(), _error, {_vfs, _path}, ctx);
    WaitForDialogResponse(ctx);

    if( ctx->response == NSModalResponseSkip )
        return CB::DestinationFileReadErrorResolution::Skip;
    else if( ctx->response == NSModalResponseSkipAll ) {
        m_SkipAll = true;
        return CB::DestinationFileReadErrorResolution::Skip;
    }
    else
        return CB::DestinationFileReadErrorResolution::Stop;
}

Copying::CB::DestinationFileWriteErrorResolution
Copying::OnDestinationFileWriteError(Error _error, const std::string &_path, VFSHost &_vfs)
{
    if( m_CallbackHooks && m_CallbackHooks->m_OnDestinationFileWriteError )
        return m_CallbackHooks->m_OnDestinationFileWriteError(_error, _path, _vfs);

    if( m_SkipAll )
        return CB::DestinationFileWriteErrorResolution::Skip;
    if( !IsInteractive() )
        return CB::DestinationFileWriteErrorResolution::Stop;

    const auto ctx = std::make_shared<AsyncDialogResponse>();
    ShowGenericDialog(GenericDialog::AbortSkipSkipAllRetry,
                      localizable::CopyingFailedToWriteDestFileMessage(),
                      _error,
                      {_vfs, _path},
                      ctx);
    WaitForDialogResponse(ctx);

    if( ctx->response == NSModalResponseSkip )
        return CB::DestinationFileWriteErrorResolution::Skip;
    else if( ctx->response == NSModalResponseSkipAll ) {
        m_SkipAll = true;
        return CB::DestinationFileWriteErrorResolution::Skip;
    }
    else if( ctx->response == NSModalResponseRetry )
        return CB::DestinationFileWriteErrorResolution::Retry;
    else
        return CB::DestinationFileWriteErrorResolution::Stop;
}

Copying::CB::CantCreateDestinationRootDirResolution
Copying::OnCantCreateDestinationRootDir(Error _error, const std::string &_path, VFSHost &_vfs)
{
    const auto ctx = std::make_shared<AsyncDialogResponse>();
    ShowGenericDialog(
        GenericDialog::AbortRetry, localizable::CopyingFailedToCreateDirectoryMessage(), _error, {_vfs, _path}, ctx);
    WaitForDialogResponse(ctx);

    if( ctx->response == NSModalResponseRetry )
        return CB::CantCreateDestinationRootDirResolution::Retry;
    else
        return CB::CantCreateDestinationRootDirResolution::Stop;
}

Copying::CB::CantCreateDestinationDirResolution
Copying::OnCantCreateDestinationDir(Error _error, const std::string &_path, VFSHost &_vfs)
{
    if( m_CallbackHooks && m_CallbackHooks->m_OnCantCreateDestinationDir )
        return m_CallbackHooks->m_OnCantCreateDestinationDir(_error, _path, _vfs);

    if( m_SkipAll )
        return CB::CantCreateDestinationDirResolution::Skip;
    if( !IsInteractive() )
        return CB::CantCreateDestinationDirResolution::Stop;

    const auto ctx = std::make_shared<AsyncDialogResponse>();
    ShowGenericDialog(GenericDialog::AbortSkipSkipAllRetry,
                      localizable::CopyingFailedToCreateDirectoryMessage(),
                      _error,
                      {_vfs, _path},
                      ctx);
    WaitForDialogResponse(ctx);

    if( ctx->response == NSModalResponseSkip )
        return CB::CantCreateDestinationDirResolution::Skip;
    else if( ctx->response == NSModalResponseSkipAll ) {
        m_SkipAll = true;
        return CB::CantCreateDestinationDirResolution::Skip;
    }
    else if( ctx->response == NSModalResponseRetry )
        return CB::CantCreateDestinationDirResolution::Retry;
    else
        return CB::CantCreateDestinationDirResolution::Stop;
}

Copying::CB::CantDeleteDestinationFileResolution
Copying::OnCantDeleteDestinationFile(Error _error, const std::string &_path, VFSHost &_vfs)
{
    if( m_CallbackHooks && m_CallbackHooks->m_OnCantDeleteDestinationFile )
        return m_CallbackHooks->m_OnCantDeleteDestinationFile(_error, _path, _vfs);

    if( m_SkipAll )
        return CB::CantDeleteDestinationFileResolution::Skip;
    if( !IsInteractive() )
        return CB::CantDeleteDestinationFileResolution::Stop;

    const auto ctx = std::make_shared<AsyncDialogResponse>();
    ShowGenericDialog(GenericDialog::AbortSkipSkipAllRetry,
                      localizable::CopyingFailedToDeleteDestFileMessage(),
                      _error,
                      {_vfs, _path},
                      ctx);
    WaitForDialogResponse(ctx);

    if( ctx->response == NSModalResponseSkip )
        return CB::CantDeleteDestinationFileResolution::Skip;
    else if( ctx->response == NSModalResponseSkipAll ) {
        m_SkipAll = true;
        return CB::CantDeleteDestinationFileResolution::Skip;
    }
    else if( ctx->response == NSModalResponseRetry )
        return CB::CantDeleteDestinationFileResolution::Retry;
    else
        return CB::CantDeleteDestinationFileResolution::Stop;
}

void Copying::OnFileVerificationFailed(const std::string &_path, VFSHost &_vfs)
{
    if( m_CallbackHooks && m_CallbackHooks->m_OnFileVerificationFailed ) {
        m_CallbackHooks->m_OnFileVerificationFailed(_path, _vfs);
        return;
    }

    const auto ctx = std::make_shared<AsyncDialogResponse>();
    ShowGenericDialog(GenericDialog::Continue,
                      localizable::CopyingChecksumVerificationFailedMessage(),
                      Error{Error::POSIX, EIO},
                      {_vfs, _path},
                      ctx);
    WaitForDialogResponse(ctx);
}

Copying::CB::CantDeleteSourceFileResolution
Copying::OnCantDeleteSourceItem(Error _error, const std::string &_path, VFSHost &_vfs)
{
    if( m_CallbackHooks && m_CallbackHooks->m_OnCantDeleteSourceItem )
        return m_CallbackHooks->m_OnCantDeleteSourceItem(_error, _path, _vfs);

    if( m_SkipAll )
        return CB::CantDeleteSourceFileResolution::Skip;
    if( !IsInteractive() )
        return CB::CantDeleteSourceFileResolution::Stop;

    const auto ctx = std::make_shared<AsyncDialogResponse>();
    ShowGenericDialog(GenericDialog::AbortSkipSkipAllRetry,
                      localizable::CopyingFailedToDeleteSourceFileMessage(),
                      _error,
                      {_vfs, _path},
                      ctx);
    WaitForDialogResponse(ctx);

    if( ctx->response == NSModalResponseSkip )
        return CB::CantDeleteSourceFileResolution::Skip;
    else if( ctx->response == NSModalResponseSkipAll ) {
        m_SkipAll = true;
        return CB::CantDeleteSourceFileResolution::Skip;
    }
    else if( ctx->response == NSModalResponseRetry )
        return CB::CantDeleteSourceFileResolution::Retry;
    else
        return CB::CantDeleteSourceFileResolution::Stop;
}

Copying::CB::NotADirectoryResolution Copying::OnNotADirectory(const std::string &_path, VFSHost &_vfs)
{
    if( m_CallbackHooks && m_CallbackHooks->m_OnNotADirectory )
        return m_CallbackHooks->m_OnNotADirectory(_path, _vfs);

    if( m_SkipAll )
        return CB::NotADirectoryResolution::Skip;
    if( m_ExistBehavior == CopyingOptions::ExistBehavior::OverwriteAll )
        return CB::NotADirectoryResolution::Overwrite;
    if( !IsInteractive() )
        return CB::NotADirectoryResolution::Stop;

    const auto ctx = std::make_shared<AsyncDialogResponse>();
    ShowGenericDialog(GenericDialog::AbortSkipSkipAllOverwrite,
                      localizable::CopyingItemNotDirMessage(),
                      Error{Error::POSIX, EEXIST},
                      {_vfs, _path},
                      ctx);
    WaitForDialogResponse(ctx);

    if( ctx->response == NSModalResponseSkip )
        return CB::NotADirectoryResolution::Skip;
    else if( ctx->response == NSModalResponseSkipAll ) {
        m_SkipAll = true;
        return CB::NotADirectoryResolution::Skip;
    }
    else if( ctx->response == NSModalResponseOverwrite )
        return CB::NotADirectoryResolution::Overwrite;
    else
        return CB::NotADirectoryResolution::Stop;
}

Copying::CB::LockedItemResolution
Copying::OnLockedItemIssue(Error _error, const std::string &_path, VFSHost &_vfs, LockedItemCause _cause)
{
    // NOT YET WIRED TO m_CallbackHooks

    if( m_SkipAll )
        return CB::LockedItemResolution::Skip;
    switch( m_LockedBehaviour ) {
        case CopyingOptions::LockedItemBehavior::UnlockAll:
            return CB::LockedItemResolution::Unlock;
        case CopyingOptions::LockedItemBehavior::SkipAll:
            return CB::LockedItemResolution::Skip;
        case CopyingOptions::LockedItemBehavior::Stop:
            return CB::LockedItemResolution::Stop;
        case CopyingOptions::LockedItemBehavior::Ask:
            break;
    }
    if( !IsInteractive() )
        return CB::LockedItemResolution::Stop;

    const auto ctx = std::make_shared<AsyncDialogResponse>();
    dispatch_to_main_queue(
        [=, this, vfs = _vfs.shared_from_this()] { OnLockedItemIssueUI(_error, _path, vfs, _cause, ctx); });
    WaitForDialogResponse(ctx);

    if( ctx->response == NSModalResponseSkip ) {
        if( ctx->IsApplyToAllSet() )
            m_LockedBehaviour = CopyingOptions::LockedItemBehavior::SkipAll;
        return CB::LockedItemResolution::Skip;
    }
    else if( ctx->response == NSModalResponseRetry ) {
        return CB::LockedItemResolution::Retry;
    }
    else if( ctx->response == NSModalResponseUnlock ) {
        if( ctx->IsApplyToAllSet() )
            m_LockedBehaviour = CopyingOptions::LockedItemBehavior::UnlockAll;
        return CB::LockedItemResolution::Unlock;
    }
    else {
        return CB::LockedItemResolution::Stop;
    }
}

void Copying::OnLockedItemIssueUI(Error _err,
                                  const std::string &_path,
                                  [[maybe_unused]] std::shared_ptr<VFSHost> _vfs,
                                  LockedItemCause _cause,
                                  std::shared_ptr<AsyncDialogResponse> _ctx)
{
    const auto sheet = [[NCOpsGenericErrorDialog alloc] initWithContext:_ctx];
    sheet.style = GenericErrorDialogStyle::Caution;
    switch( _cause ) {
        case LockedItemCause::Moving:
            sheet.message = localizable::CopyingCantRenameLockedMessage();
            break;
        case LockedItemCause::Deletion:
            sheet.message = localizable::CopyingCantDeleteLockedMessage();
            break;
        case LockedItemCause::Opening:
            sheet.message = localizable::CopyingCantOpenLockedMessage();
            break;
    }
    sheet.path = [NSString stringWithUTF8String:_path.c_str()];
    sheet.showApplyToAll = !m_Job->IsSingleScannedItemProcessing();
    sheet.error = _err;
    [sheet addButtonWithTitle:localizable::OperationAbortTitle() responseCode:NSModalResponseStop];
    [sheet addButtonWithTitle:localizable::OperationUnlockTitle() responseCode:NSModalResponseUnlock];
    [sheet addButtonWithTitle:localizable::OperationSkipTitle() responseCode:NSModalResponseSkip];
    [sheet addButtonWithTitle:localizable::OperationRetryTitle() responseCode:NSModalResponseRetry];
    Show(sheet.window, _ctx);
}

Copying::CB::UnlockErrorResolution Copying::OnUnlockError(Error _error, const std::string &_path, VFSHost &_vfs)
{
    if( m_SkipAll )
        return CB::UnlockErrorResolution::Skip;
    if( !IsInteractive() )
        return CB::UnlockErrorResolution::Stop;

    const auto ctx = std::make_shared<AsyncDialogResponse>();
    ShowGenericDialog(
        GenericDialog::AbortSkipSkipAllRetry, localizable::CopyingFailedToUnlockMessage(), _error, {_vfs, _path}, ctx);
    WaitForDialogResponse(ctx);

    if( ctx->response == NSModalResponseSkip )
        return CB::UnlockErrorResolution::Skip;
    else if( ctx->response == NSModalResponseSkipAll ) {
        m_SkipAll = true;
        return CB::UnlockErrorResolution::Skip;
    }
    else if( ctx->response == NSModalResponseRetry )
        return CB::UnlockErrorResolution::Retry;
    else
        return CB::UnlockErrorResolution::Stop;
}

void Copying::OnStageChanged()
{
    const CopyingTitleBuilder b{m_Job->SourceItems(), m_Job->DestinationPath(), m_Job->Options()};
    std::string title;
    switch( m_Job->Stage() ) {
        case CopyingJob::Stage::Default:
        case CopyingJob::Stage::Process:
            title = b.TitleForProcessing();
            break;
        case CopyingJob::Stage::Preparing:
            title = b.TitleForPreparing();
            break;
        case CopyingJob::Stage::Verify:
            title = nc::ops::CopyingTitleBuilder::TitleForVerifying();
            break;
        case CopyingJob::Stage::Cleaning:
            title = nc::ops::CopyingTitleBuilder::TitleForCleanup();
            break;
    }
    SetTitle(std::move(title));
}

void Copying::SetCallbackHooks(const CopyingJobCallbacks *_callbacks)
{
    m_CallbackHooks = _callbacks;
}

} // namespace nc::ops

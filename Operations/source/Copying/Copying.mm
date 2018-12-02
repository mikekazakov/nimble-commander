// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Copying.h"
#include "CopyingJob.h"
#include "../AsyncDialogResponse.h"
#include "../Internal.h"
#include "FileAlreadyExistDialog.h"
#include "CopyingTitleBuilder.h"
#include <sys/stat.h>

namespace nc::ops {

using Callbacks = CopyingJobCallbacks;

Copying::Copying(std::vector<VFSListingItem> _source_files,
                 const std::string& _destination_path,
                 const std::shared_ptr<VFSHost> &_destination_host,
                 const CopyingOptions &_options)
{
    m_ExistBehavior = _options.exist_behavior;
    
    m_Job.reset( new CopyingJob(_source_files,
                                _destination_path,
                                _destination_host,
                                _options) );
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
    using С = CopyingJobCallbacks;
    j.m_OnCopyDestinationAlreadyExists =
    [this](const struct stat &_src, const struct stat &_dst, const std::string &_path) {
        return (С::CopyDestExistsResolution)OnCopyDestExists(_src, _dst, _path);
    };
    j.m_OnRenameDestinationAlreadyExists =
    [this](const struct stat &_src, const struct stat &_dst, const std::string &_path) {
        return (С::RenameDestExistsResolution)OnRenameDestExists(_src, _dst, _path);
    };
    j.m_OnCantAccessSourceItem = [this](int _1, const std::string &_2, VFSHost &_3) {
        return (С::CantAccessSourceItemResolution)OnCantAccessSourceItem(_1, _2, _3);
    };
    j.m_OnCantOpenDestinationFile = [this](int _1, const std::string &_2, VFSHost &_3) {
        return (С::CantOpenDestinationFileResolution)OnCantOpenDestinationFile(_1, _2, _3);
    };
    j.m_OnSourceFileReadError = [this](int _1, const std::string &_2, VFSHost &_3) {
        return (С::SourceFileReadErrorResolution)OnSourceFileReadError(_1, _2, _3);
    };
    j.m_OnDestinationFileReadError = [this](int _1, const std::string &_2, VFSHost &_3) {
        return (С::DestinationFileReadErrorResolution)OnDestinationFileReadError(_1, _2, _3);
    };
    j.m_OnDestinationFileWriteError = [this](int _1, const std::string &_2, VFSHost &_3) {
        return (С::DestinationFileWriteErrorResolution)OnDestinationFileWriteError(_1, _2, _3);
    };
    j.m_OnCantCreateDestinationRootDir = [this](int _1, const std::string &_2, VFSHost &_3) {
        return (С::CantCreateDestinationRootDirResolution)OnCantCreateDestinationRootDir(_1, _2, _3);
    };
    j.m_OnCantCreateDestinationDir = [this](int _1, const std::string &_2, VFSHost &_3) {
        return (С::CantCreateDestinationDirResolution)OnCantCreateDestinationDir(_1, _2, _3);
    };
    j.m_OnCantDeleteDestinationFile = [this](int _1, const std::string &_2, VFSHost &_3) {
        return (С::CantDeleteDestinationFileResolution)OnCantDeleteDestinationFile(_1, _2, _3);
    };
    j.m_OnCantDeleteSourceItem = [this](int _1, const std::string &_2, VFSHost &_3) {
        return (С::CantDeleteSourceFileResolution)OnCantDeleteSourceItem(_1, _2, _3);
    };
    j.m_OnNotADirectory = [this](const std::string &_1, VFSHost &_2) {
        return (С::NotADirectoryResolution)OnNotADirectory(_1, _2);
    };
    j.m_OnFileVerificationFailed = [this](const std::string &_1, VFSHost &_2) {
        OnFileVerificationFailed(_1, _2);
    };
    j.m_OnStageChanged = [this]() {
        OnStageChanged();
    };
}

Job *Copying::GetJob() noexcept
{
    return m_Job.get();
}

int Copying::OnCopyDestExists(const struct stat &_src, const struct stat &_dst, const std::string &_path)
{
    switch( m_ExistBehavior ) {
        case CopyingOptions::ExistBehavior::SkipAll:
            return (int)Callbacks::CopyDestExistsResolution::Skip;
        case CopyingOptions::ExistBehavior::Stop:
            return (int)Callbacks::CopyDestExistsResolution::Stop;
        case CopyingOptions::ExistBehavior::AppendAll:
            return (int)Callbacks::CopyDestExistsResolution::Append;
        case CopyingOptions::ExistBehavior::OverwriteAll:
            return (int)Callbacks::CopyDestExistsResolution::Overwrite;
        case CopyingOptions::ExistBehavior::OverwriteOld:
            return (int)Callbacks::CopyDestExistsResolution::OverwriteOld;
        case CopyingOptions::ExistBehavior::KeepBoth:
            return (int)Callbacks::CopyDestExistsResolution::KeepBoth;
        default:
            break;
    }

    if( !IsInteractive() )
        return (int)Callbacks::CopyDestExistsResolution::Stop;
    
    const auto ctx = std::make_shared<AsyncDialogResponse>();
    dispatch_to_main_queue([=]{ OnCopyDestExistsUI(_src, _dst, _path, ctx); });
    WaitForDialogResponse(ctx);
    
    if( ctx->response == NSModalResponseSkip ) {
        if( ctx->IsApplyToAllSet() )
            m_ExistBehavior = CopyingOptions::ExistBehavior::SkipAll;
        return (int)Callbacks::CopyDestExistsResolution::Skip;
    }
    if( ctx->response == NSModalResponseAppend ) {
        if( ctx->IsApplyToAllSet() )
            m_ExistBehavior = CopyingOptions::ExistBehavior::AppendAll;
        return (int)Callbacks::CopyDestExistsResolution::Append;
    }
    if( ctx->response == NSModalResponseOverwrite ) {
        if( ctx->IsApplyToAllSet() )
            m_ExistBehavior = CopyingOptions::ExistBehavior::OverwriteAll;
        return (int)Callbacks::CopyDestExistsResolution::Overwrite;
    }
    if( ctx->response == NSModalResponseOverwriteOld ) {
        if( ctx->IsApplyToAllSet() )
            m_ExistBehavior = CopyingOptions::ExistBehavior::OverwriteOld;
        return (int)Callbacks::CopyDestExistsResolution::OverwriteOld;
    }
    if( ctx->response == NSModalResponseKeepBoth ) {
        if( ctx->IsApplyToAllSet() )
            m_ExistBehavior = CopyingOptions::ExistBehavior::KeepBoth;
        return (int)Callbacks::CopyDestExistsResolution::KeepBoth;
    }    
    return (int)Callbacks::CopyDestExistsResolution::Stop;
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

int Copying::OnRenameDestExists(const struct stat &_src, const struct stat &_dst,
                                const std::string &_path)
{
    switch( m_ExistBehavior ) {
        case CopyingOptions::ExistBehavior::SkipAll:
            return (int)Callbacks::RenameDestExistsResolution::Skip;
        case CopyingOptions::ExistBehavior::Stop:
            return (int)Callbacks::RenameDestExistsResolution::Stop;
        case CopyingOptions::ExistBehavior::OverwriteAll:
            return (int)Callbacks::RenameDestExistsResolution::Overwrite;
        case CopyingOptions::ExistBehavior::OverwriteOld:
            return (int)Callbacks::RenameDestExistsResolution::OverwriteOld;
        case CopyingOptions::ExistBehavior::KeepBoth:
            return (int)Callbacks::RenameDestExistsResolution::KeepBoth;
        default:
            break;
    }
    
    if( !IsInteractive() )
        return (int)Callbacks::RenameDestExistsResolution::Stop;
    
    const auto ctx = std::make_shared<AsyncDialogResponse>();
    dispatch_to_main_queue([=]{ OnRenameDestExistsUI(_src, _dst, _path, ctx); });
    WaitForDialogResponse(ctx);

    if( ctx->response == NSModalResponseSkip ) {
        if( ctx->IsApplyToAllSet() )
            m_ExistBehavior = CopyingOptions::ExistBehavior::SkipAll;
        return (int)Callbacks::RenameDestExistsResolution::Skip;
    }
    if( ctx->response == NSModalResponseOverwrite ) {
        if( ctx->IsApplyToAllSet() )
            m_ExistBehavior = CopyingOptions::ExistBehavior::OverwriteAll;
        return (int)Callbacks::RenameDestExistsResolution::Overwrite;
    }
    if( ctx->response == NSModalResponseOverwriteOld ) {
        if( ctx->IsApplyToAllSet() )
            m_ExistBehavior = CopyingOptions::ExistBehavior::OverwriteOld;
        return (int)Callbacks::RenameDestExistsResolution::OverwriteOld;
    }
    if( ctx->response == NSModalResponseKeepBoth ) {
        if( ctx->IsApplyToAllSet() )
            m_ExistBehavior = CopyingOptions::ExistBehavior::KeepBoth;
        return (int)Callbacks::RenameDestExistsResolution::KeepBoth;
    }        
    return (int)Callbacks::RenameDestExistsResolution::Stop;
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

int Copying::OnCantAccessSourceItem(int _err,
                                    const std::string &_path,
                                    VFSHost &_vfs)
{
    if( m_SkipAll )
        return (int)Callbacks::CantAccessSourceItemResolution::Skip;
    if( !IsInteractive() )
        return (int)Callbacks::CantAccessSourceItemResolution::Stop;
    
    const auto ctx = std::make_shared<AsyncDialogResponse>();
    ShowGenericDialog(GenericDialog::AbortSkipSkipAllRetry,
                      NSLocalizedString(@"Failed to access a file", ""),
                      _err, {_vfs, _path}, ctx);
    WaitForDialogResponse(ctx);

    if( ctx->response == NSModalResponseSkip )
        return (int)Callbacks::CantAccessSourceItemResolution::Skip;
    else if( ctx->response == NSModalResponseSkipAll ) {
        m_SkipAll = true;
        return (int)Callbacks::CantAccessSourceItemResolution::Skip;
    }
    else if( ctx->response == NSModalResponseRetry )
        return (int)Callbacks::CantAccessSourceItemResolution::Retry;
    else
        return (int)Callbacks::CantAccessSourceItemResolution::Stop;
}

int Copying::OnCantOpenDestinationFile(int _err, const std::string &_path, VFSHost &_vfs)
{
    if( m_SkipAll )
        return (int)Callbacks::CantOpenDestinationFileResolution::Skip;
    if( !IsInteractive() )
        return (int)Callbacks::CantOpenDestinationFileResolution::Stop;
    
    const auto ctx = std::make_shared<AsyncDialogResponse>();
    ShowGenericDialog(GenericDialog::AbortSkipSkipAllRetry,
                      NSLocalizedString(@"Failed to open a destination file", ""),
                      _err, {_vfs, _path}, ctx);
    WaitForDialogResponse(ctx);

    if( ctx->response == NSModalResponseSkip )
        return (int)Callbacks::CantOpenDestinationFileResolution::Skip;
    else if( ctx->response == NSModalResponseSkipAll ) {
        m_SkipAll = true;
        return (int)Callbacks::CantOpenDestinationFileResolution::Skip;
    }
    else if( ctx->response == NSModalResponseRetry )
        return (int)Callbacks::CantOpenDestinationFileResolution::Retry;
    else
        return (int)Callbacks::CantOpenDestinationFileResolution::Stop;
}

int Copying::OnSourceFileReadError(int _err, const std::string &_path, VFSHost &_vfs)
{
    if( m_SkipAll )
        return (int)Callbacks::SourceFileReadErrorResolution::Skip;
    if( !IsInteractive() )
        return (int)Callbacks::SourceFileReadErrorResolution::Stop;
    
    const auto ctx = std::make_shared<AsyncDialogResponse>();
    ShowGenericDialog(GenericDialog::AbortSkipSkipAllRetry,
                      NSLocalizedString(@"Failed to read a source file", ""),
                      _err, {_vfs, _path}, ctx);
    WaitForDialogResponse(ctx);

    if( ctx->response == NSModalResponseSkip )
        return (int)Callbacks::SourceFileReadErrorResolution::Skip;
    else if( ctx->response == NSModalResponseSkipAll ) {
        m_SkipAll = true;
        return (int)Callbacks::SourceFileReadErrorResolution::Skip;
    }
    else if( ctx->response == NSModalResponseRetry )
        return (int)Callbacks::SourceFileReadErrorResolution::Retry;
    else
        return (int)Callbacks::SourceFileReadErrorResolution::Stop;
}

int Copying::OnDestinationFileReadError(int _err, const std::string &_path, VFSHost &_vfs)
{
    if( m_SkipAll )
        return (int)Callbacks::DestinationFileReadErrorResolution::Skip;
    if( !IsInteractive() )
        return (int)Callbacks::DestinationFileReadErrorResolution::Stop;
    
    const auto ctx = std::make_shared<AsyncDialogResponse>();
    ShowGenericDialog(GenericDialog::AbortSkipSkipAll,
                      NSLocalizedString(@"Failed to read a destination file", ""),
                      _err, {_vfs, _path}, ctx);
    WaitForDialogResponse(ctx);

    if( ctx->response == NSModalResponseSkip )
        return (int)Callbacks::DestinationFileReadErrorResolution::Skip;
    else if( ctx->response == NSModalResponseSkipAll ) {
        m_SkipAll = true;
        return (int)Callbacks::DestinationFileReadErrorResolution::Skip;
    }
    else
        return (int)Callbacks::DestinationFileReadErrorResolution::Stop;
}

int Copying::OnDestinationFileWriteError(int _err, const std::string &_path, VFSHost &_vfs)
{
    if( m_SkipAll )
        return (int)Callbacks::DestinationFileWriteErrorResolution::Skip;
    if( !IsInteractive() )
        return (int)Callbacks::DestinationFileWriteErrorResolution::Stop;
    
    const auto ctx = std::make_shared<AsyncDialogResponse>();
    ShowGenericDialog(GenericDialog::AbortSkipSkipAllRetry,
                      NSLocalizedString(@"Failed to write a file", ""),
                      _err, {_vfs, _path}, ctx);
    WaitForDialogResponse(ctx);

    if( ctx->response == NSModalResponseSkip )
        return (int)Callbacks::DestinationFileWriteErrorResolution::Skip;
    else if( ctx->response == NSModalResponseSkipAll ) {
        m_SkipAll = true;
        return (int)Callbacks::DestinationFileWriteErrorResolution::Skip;
    }
    else if( ctx->response == NSModalResponseRetry )
        return (int)Callbacks::DestinationFileWriteErrorResolution::Retry;
    else
        return (int)Callbacks::DestinationFileWriteErrorResolution::Stop;
}

int Copying::OnCantCreateDestinationRootDir(int _err, const std::string &_path, VFSHost &_vfs)
{
    const auto ctx = std::make_shared<AsyncDialogResponse>();
    ShowGenericDialog(GenericDialog::AbortRetry,
                      NSLocalizedString(@"Failed to create a directory", ""),
                      _err, {_vfs, _path}, ctx);
    WaitForDialogResponse(ctx);
    
    if( ctx->response == NSModalResponseRetry )
        return (int)Callbacks::CantCreateDestinationRootDirResolution::Retry;
    else
        return (int)Callbacks::CantCreateDestinationRootDirResolution::Stop;
}

int Copying::OnCantCreateDestinationDir(int _err, const std::string &_path, VFSHost &_vfs)
{
    if( m_SkipAll )
        return (int)Callbacks::CantCreateDestinationDirResolution::Skip;
    if( !IsInteractive() )
        return (int)Callbacks::CantCreateDestinationDirResolution::Stop;
    
    const auto ctx = std::make_shared<AsyncDialogResponse>();
    ShowGenericDialog(GenericDialog::AbortSkipSkipAllRetry,
                      NSLocalizedString(@"Failed to create a directory", ""),
                      _err, {_vfs, _path}, ctx);
    WaitForDialogResponse(ctx);

    if( ctx->response == NSModalResponseSkip )
        return (int)Callbacks::CantCreateDestinationDirResolution::Skip;
    else if( ctx->response == NSModalResponseSkipAll ) {
        m_SkipAll = true;
        return (int)Callbacks::CantCreateDestinationDirResolution::Skip;
    }
    else if( ctx->response == NSModalResponseRetry )
        return (int)Callbacks::CantCreateDestinationDirResolution::Retry;
    else
        return (int)Callbacks::CantCreateDestinationDirResolution::Stop;
}

int Copying::OnCantDeleteDestinationFile(int _err, const std::string &_path, VFSHost &_vfs)
{
    if( m_SkipAll )
        return (int)Callbacks::CantDeleteDestinationFileResolution::Skip;
    if( !IsInteractive() )
        return (int)Callbacks::CantDeleteDestinationFileResolution::Stop;
    
    const auto ctx = std::make_shared<AsyncDialogResponse>();
    ShowGenericDialog(GenericDialog::AbortSkipSkipAllRetry,
                      NSLocalizedString(@"Failed to delete a destination file", ""),
                      _err, {_vfs, _path}, ctx);
    WaitForDialogResponse(ctx);
    
    if( ctx->response == NSModalResponseSkip )
        return (int)Callbacks::CantDeleteDestinationFileResolution::Skip;
    else if( ctx->response == NSModalResponseSkipAll ) {
        m_SkipAll = true;
        return (int)Callbacks::CantDeleteDestinationFileResolution::Skip;
    }
    else if( ctx->response == NSModalResponseRetry )
        return (int)Callbacks::CantDeleteDestinationFileResolution::Retry;
    else
        return (int)Callbacks::CantDeleteDestinationFileResolution::Stop;
}
    
void Copying::OnFileVerificationFailed(const std::string &_path, VFSHost &_vfs)
{
    const auto ctx = std::make_shared<AsyncDialogResponse>();
    ShowGenericDialog(GenericDialog::Continue,
                      NSLocalizedString(@"Checksum verification failed", ""),
                      VFSError::FromErrno(EIO), {_vfs, _path}, ctx);
    WaitForDialogResponse(ctx);
}

int Copying::OnCantDeleteSourceItem(int _err, const std::string &_path, VFSHost &_vfs)
{
     if( m_SkipAll )
        return (int)Callbacks::CantDeleteSourceFileResolution::Skip;
    if( !IsInteractive() )
        return (int)Callbacks::CantDeleteSourceFileResolution::Stop;
    
    const auto ctx = std::make_shared<AsyncDialogResponse>();
    ShowGenericDialog(GenericDialog::AbortSkipSkipAllRetry,
                      NSLocalizedString(@"Failed to delete a source item", ""),
                      _err, {_vfs, _path}, ctx);
    WaitForDialogResponse(ctx);
    
    if( ctx->response == NSModalResponseSkip )
        return (int)Callbacks::CantDeleteSourceFileResolution::Skip;
    else if( ctx->response == NSModalResponseSkipAll ) {
        m_SkipAll = true;
        return (int)Callbacks::CantDeleteSourceFileResolution::Skip;
    }
    else if( ctx->response == NSModalResponseRetry )
        return (int)Callbacks::CantDeleteSourceFileResolution::Retry;
    else
        return (int)Callbacks::CantDeleteSourceFileResolution::Stop;
}
    
int Copying::OnNotADirectory(const std::string &_path, VFSHost &_vfs)
{
    if( m_SkipAll )
        return (int)Callbacks::NotADirectoryResolution::Skip;
    if( m_ExistBehavior == CopyingOptions::ExistBehavior::OverwriteAll )
        return (int)Callbacks::NotADirectoryResolution::Overwrite;
    if( !IsInteractive() )
        return (int)Callbacks::NotADirectoryResolution::Stop;

    const auto ctx = std::make_shared<AsyncDialogResponse>();
    ShowGenericDialog(GenericDialog::AbortSkipSkipAllOverwrite,
                      NSLocalizedString(@"Item is not a directory", ""),
                      VFSError::FromErrno(EEXIST), {_vfs, _path}, ctx);
    WaitForDialogResponse(ctx);
    
    if( ctx->response == NSModalResponseSkip )
        return (int)Callbacks::NotADirectoryResolution::Skip;
    else if( ctx->response == NSModalResponseSkipAll ) {
        m_SkipAll = true;
        return (int)Callbacks::NotADirectoryResolution::Skip;
    }
    else if( ctx->response == NSModalResponseOverwrite )
        return (int)Callbacks::NotADirectoryResolution::Overwrite;
    else
        return (int)Callbacks::NotADirectoryResolution::Stop;
}

void Copying::OnStageChanged()
{
    CopyingTitleBuilder b{m_Job->SourceItems(),
                          m_Job->DestinationPath(),
                          m_Job->Options()};
    std::string title = "";
    switch( m_Job->Stage() ) {
        case CopyingJob::Stage::Default:
        case CopyingJob::Stage::Process:    title = b.TitleForProcessing(); break;
        case CopyingJob::Stage::Preparing:  title = b.TitleForPreparing();  break;
        case CopyingJob::Stage::Verify:     title = b.TitleForVerifying();  break;
        case CopyingJob::Stage::Cleaning:   title = b.TitleForCleanup();    break;
    }
    SetTitle( std::move(title) );
}

}

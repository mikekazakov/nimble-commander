#include "Copying.h"
#include "CopyingJob.h"
#include "../AsyncDialogResponse.h"
#include "FileAlreadyExistDialog.h"

namespace nc::ops {

using Callbacks = CopyingJobCallbacks;

Copying::Copying(vector<VFSListingItem> _source_files,
                 const string& _destination_path,
                 const shared_ptr<VFSHost> &_destination_host,
                 const FileCopyOperationOptions &_options)
{
    m_ExistBehavior = _options.exist_behavior;
    m_Job.reset( new CopyingJob(_source_files,
                                _destination_path,
                                _destination_host,
                                _options) );
    m_Job->m_OnCopyDestinationAlreadyExists =
    [this](const struct stat &_src, const struct stat &_dst, const string &_path) {
        return (Callbacks::CopyDestExistsResolution)OnCopyDestExists(_src, _dst, _path);
    };
    m_Job->m_OnRenameDestinationAlreadyExists =
    [this](const struct stat &_src, const struct stat &_dst, const string &_path) {
        return (Callbacks::RenameDestExistsResolution)OnRenameDestExists(_src, _dst, _path);
    };
    m_Job->m_OnCantAccessSourceItem =
    [this](int _vfs_error, const string &_path, VFSHost &_vfs) {
        return (Callbacks::CantAccessSourceItemResolution)OnCantAccessSourceItem(_vfs_error, _path, _vfs);
    };
    m_Job->m_OnCantOpenDestinationFile =
    [this](int _1, const string &_2, VFSHost &_3) {
        return (Callbacks::CantOpenDestinationFileResolution)OnCantOpenDestinationFile(_1, _2, _3);
    };
}


Copying::~Copying()
{
    Wait();
}

Job *Copying::GetJob() noexcept
{
    return m_Job.get();
}

int Copying::OnCopyDestExists(const struct stat &_src, const struct stat &_dst, const string &_path)
{
    switch( m_ExistBehavior ) {
        case FileCopyOperationOptions::ExistBehavior::SkipAll:
            return (int)Callbacks::CopyDestExistsResolution::Skip;
        case FileCopyOperationOptions::ExistBehavior::Stop:
            return (int)Callbacks::CopyDestExistsResolution::Stop;
        case FileCopyOperationOptions::ExistBehavior::AppendAll:
            return (int)Callbacks::CopyDestExistsResolution::Append;
        case FileCopyOperationOptions::ExistBehavior::OverwriteAll:
            return (int)Callbacks::CopyDestExistsResolution::Overwrite;
        case FileCopyOperationOptions::ExistBehavior::OverwriteOld:
            return (int)Callbacks::CopyDestExistsResolution::OverwriteOld;
        default:
            break;
    }

    if( !IsInteractive() )
        return (int)Callbacks::CopyDestExistsResolution::Stop;
    
    const auto ctx = make_shared<AsyncDialogResponse>();
    dispatch_to_main_queue([=]{ OnCopyDestExistsUI(_src, _dst, _path, ctx); });
    WaitForDialogResponse(ctx);
    
    if( ctx->response == NSModalResponseSkip ) {
        if( ctx->IsApplyToAllSet() )
            m_ExistBehavior = FileCopyOperationOptions::ExistBehavior::SkipAll;
        return (int)Callbacks::CopyDestExistsResolution::Skip;
    }
    if( ctx->response == NSModalResponseAppend ) {
        if( ctx->IsApplyToAllSet() )
            m_ExistBehavior = FileCopyOperationOptions::ExistBehavior::AppendAll;
        return (int)Callbacks::CopyDestExistsResolution::Append;
    }
    if( ctx->response == NSModalResponseOverwrite ) {
        if( ctx->IsApplyToAllSet() )
            m_ExistBehavior = FileCopyOperationOptions::ExistBehavior::OverwriteAll;
        return (int)Callbacks::CopyDestExistsResolution::Overwrite;
    }
    if( ctx->response == NSModalResponseOverwriteOld ) {
        if( ctx->IsApplyToAllSet() )
            m_ExistBehavior = FileCopyOperationOptions::ExistBehavior::OverwriteOld;
        return (int)Callbacks::CopyDestExistsResolution::OverwriteOld;
    }
    return (int)Callbacks::CopyDestExistsResolution::Stop;
}

void Copying::OnCopyDestExistsUI(const struct stat &_src, const struct stat &_dst,
                                 const string &_path, shared_ptr<AsyncDialogResponse> _ctx)
{
    const auto sheet = [[NCOpsFileAlreadyExistDialog alloc] initWithDestPath:_path
                                                              withSourceStat:_src
                                                         withDestinationStat:_dst
                                                                  andContext:_ctx];
    sheet.singleItem = m_Job->IsSingleScannedItemProcessing();
    Show(sheet.window, _ctx);
}

int Copying::OnRenameDestExists(const struct stat &_src, const struct stat &_dst,
                                const string &_path)
{
    switch( m_ExistBehavior ) {
        case FileCopyOperationOptions::ExistBehavior::SkipAll:
            return (int)Callbacks::RenameDestExistsResolution::Skip;
        case FileCopyOperationOptions::ExistBehavior::Stop:
            return (int)Callbacks::RenameDestExistsResolution::Stop;
        case FileCopyOperationOptions::ExistBehavior::OverwriteAll:
            return (int)Callbacks::RenameDestExistsResolution::Overwrite;
        case FileCopyOperationOptions::ExistBehavior::OverwriteOld:
            return (int)Callbacks::RenameDestExistsResolution::OverwriteOld;
        default:
            break;
    }
    
    if( !IsInteractive() )
        return (int)Callbacks::RenameDestExistsResolution::Stop;
    
    const auto ctx = make_shared<AsyncDialogResponse>();
    dispatch_to_main_queue([=]{ OnRenameDestExistsUI(_src, _dst, _path, ctx); });
    WaitForDialogResponse(ctx);

    if( ctx->response == NSModalResponseSkip ) {
        if( ctx->IsApplyToAllSet() )
            m_ExistBehavior = FileCopyOperationOptions::ExistBehavior::SkipAll;
        return (int)Callbacks::RenameDestExistsResolution::Skip;
    }
    if( ctx->response == NSModalResponseOverwrite ) {
        if( ctx->IsApplyToAllSet() )
            m_ExistBehavior = FileCopyOperationOptions::ExistBehavior::OverwriteAll;
        return (int)Callbacks::RenameDestExistsResolution::Overwrite;
    }
    if( ctx->response == NSModalResponseOverwriteOld ) {
        if( ctx->IsApplyToAllSet() )
            m_ExistBehavior = FileCopyOperationOptions::ExistBehavior::OverwriteOld;
        return (int)Callbacks::RenameDestExistsResolution::OverwriteOld;
    }
    return (int)Callbacks::RenameDestExistsResolution::Stop;
}

void Copying::OnRenameDestExistsUI(const struct stat &_src, const struct stat &_dst,
                                   const string &_path, shared_ptr<AsyncDialogResponse> _ctx)
{
    const auto sheet = [[NCOpsFileAlreadyExistDialog alloc] initWithDestPath:_path
                                                              withSourceStat:_src
                                                         withDestinationStat:_dst
                                                                  andContext:_ctx];
    sheet.singleItem = m_Job->IsSingleScannedItemProcessing();
    sheet.allowAppending = false;
    Show(sheet.window, _ctx);
}

int Copying::OnCantAccessSourceItem(int _err, const string &_path, VFSHost &_vfs)
{
    if( m_SkipAll )
        return (int)Callbacks::CantAccessSourceItemResolution::Skip;
    if( !IsInteractive() )
        return (int)Callbacks::CantAccessSourceItemResolution::Stop;
    
    const auto ctx = make_shared<AsyncDialogResponse>();
    ShowGenericDialogWithAbortSkipAndSkipAllButtons(@"Failed to access a file",
                                                    _err,
                                                    _path,
                                                    _vfs.shared_from_this(),
                                                    ctx);
    WaitForDialogResponse(ctx);

    
    if( ctx->response == NSModalResponseSkip )
        return (int)Callbacks::CantAccessSourceItemResolution::Skip;
    else if( ctx->response == NSModalResponseSkipAll ) {
        m_SkipAll = true;
        return (int)Callbacks::CantAccessSourceItemResolution::Skip;
    }
    else
        return (int)Callbacks::CantAccessSourceItemResolution::Stop;
}

int Copying::OnCantOpenDestinationFile(int _err, const string &_path, VFSHost &_vfs)
{
    if( m_SkipAll )
        return (int)Callbacks::CantOpenDestinationFileResolution::Skip;
    if( !IsInteractive() )
        return (int)Callbacks::CantOpenDestinationFileResolution::Stop;
    
    const auto ctx = make_shared<AsyncDialogResponse>();
    ShowGenericDialogWithAbortSkipAndSkipAllButtons(@"Failed to open a destination file",
                                                    _err,
                                                    _path,
                                                    _vfs.shared_from_this(),
                                                    ctx);
    WaitForDialogResponse(ctx);

    if( ctx->response == NSModalResponseSkip )
        return (int)Callbacks::CantOpenDestinationFileResolution::Skip;
    else if( ctx->response == NSModalResponseSkipAll ) {
        m_SkipAll = true;
        return (int)Callbacks::CantOpenDestinationFileResolution::Skip;
    }
    else
        return (int)Callbacks::CantOpenDestinationFileResolution::Stop;
}



}

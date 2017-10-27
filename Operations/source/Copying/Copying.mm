// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Copying.h"
#include "CopyingJob.h"
#include "../AsyncDialogResponse.h"
#include "../Internal.h"
#include "FileAlreadyExistDialog.h"
#include <Utility/PathManip.h>

namespace nc::ops {

using Callbacks = CopyingJobCallbacks;

static string BuildTitle(const vector<VFSListingItem> &_source_files,
                         const string& _destination_path,
                         const CopyingOptions &_options);

Copying::Copying(vector<VFSListingItem> _source_files,
                 const string& _destination_path,
                 const shared_ptr<VFSHost> &_destination_host,
                 const CopyingOptions &_options)
{
    SetTitle( BuildTitle(_source_files, _destination_path, _options) );
    m_ExistBehavior = _options.exist_behavior;
    
    m_Job.reset( new CopyingJob(_source_files,
                                _destination_path,
                                _destination_host,
                                _options) );
    SetupCallbacks();
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
    [this](const struct stat &_src, const struct stat &_dst, const string &_path) {
        return (С::CopyDestExistsResolution)OnCopyDestExists(_src, _dst, _path);
    };
    j.m_OnRenameDestinationAlreadyExists =
    [this](const struct stat &_src, const struct stat &_dst, const string &_path) {
        return (С::RenameDestExistsResolution)OnRenameDestExists(_src, _dst, _path);
    };
    j.m_OnCantAccessSourceItem = [this](int _1, const string &_2, VFSHost &_3) {
        return (С::CantAccessSourceItemResolution)OnCantAccessSourceItem(_1, _2, _3);
    };
    j.m_OnCantOpenDestinationFile = [this](int _1, const string &_2, VFSHost &_3) {
        return (С::CantOpenDestinationFileResolution)OnCantOpenDestinationFile(_1, _2, _3);
    };
    j.m_OnSourceFileReadError = [this](int _1, const string &_2, VFSHost &_3) {
        return (С::SourceFileReadErrorResolution)OnSourceFileReadError(_1, _2, _3);
    };
    j.m_OnDestinationFileReadError = [this](int _1, const string &_2, VFSHost &_3) {
        return (С::DestinationFileReadErrorResolution)OnDestinationFileReadError(_1, _2, _3);
    };
    j.m_OnDestinationFileWriteError = [this](int _1, const string &_2, VFSHost &_3) {
        return (С::DestinationFileWriteErrorResolution)OnDestinationFileWriteError(_1, _2, _3);
    };
    j.m_OnCantCreateDestinationRootDir = [this](int _1, const string &_2, VFSHost &_3) {
        return (С::CantCreateDestinationRootDirResolution)OnCantCreateDestinationRootDir(_1, _2, _3);
    };
    j.m_OnCantCreateDestinationDir = [this](int _1, const string &_2, VFSHost &_3) {
        return (С::CantCreateDestinationDirResolution)OnCantCreateDestinationDir(_1, _2, _3);
    };
    j.m_OnCantDeleteDestinationFile = [this](int _1, const string &_2, VFSHost &_3) {
        return (С::CantDeleteDestinationFileResolution)OnCantDeleteDestinationFile(_1, _2, _3);
    };
    j.m_OnFileVerificationFailed = [this](const string &_1, VFSHost &_2) {
        OnFileVerificationFailed(_1, _2);
    };
}

Job *Copying::GetJob() noexcept
{
    return m_Job.get();
}

int Copying::OnCopyDestExists(const struct stat &_src, const struct stat &_dst, const string &_path)
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
        case CopyingOptions::ExistBehavior::SkipAll:
            return (int)Callbacks::RenameDestExistsResolution::Skip;
        case CopyingOptions::ExistBehavior::Stop:
            return (int)Callbacks::RenameDestExistsResolution::Stop;
        case CopyingOptions::ExistBehavior::OverwriteAll:
            return (int)Callbacks::RenameDestExistsResolution::Overwrite;
        case CopyingOptions::ExistBehavior::OverwriteOld:
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

int Copying::OnCantOpenDestinationFile(int _err, const string &_path, VFSHost &_vfs)
{
    if( m_SkipAll )
        return (int)Callbacks::CantOpenDestinationFileResolution::Skip;
    if( !IsInteractive() )
        return (int)Callbacks::CantOpenDestinationFileResolution::Stop;
    
    const auto ctx = make_shared<AsyncDialogResponse>();
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

int Copying::OnSourceFileReadError(int _err, const string &_path, VFSHost &_vfs)
{
    if( m_SkipAll )
        return (int)Callbacks::SourceFileReadErrorResolution::Skip;
    if( !IsInteractive() )
        return (int)Callbacks::SourceFileReadErrorResolution::Stop;
    
    const auto ctx = make_shared<AsyncDialogResponse>();
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

int Copying::OnDestinationFileReadError(int _err, const string &_path, VFSHost &_vfs)
{
    if( m_SkipAll )
        return (int)Callbacks::DestinationFileReadErrorResolution::Skip;
    if( !IsInteractive() )
        return (int)Callbacks::DestinationFileReadErrorResolution::Stop;
    
    const auto ctx = make_shared<AsyncDialogResponse>();
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

int Copying::OnDestinationFileWriteError(int _err, const string &_path, VFSHost &_vfs)
{
    if( m_SkipAll )
        return (int)Callbacks::DestinationFileWriteErrorResolution::Skip;
    if( !IsInteractive() )
        return (int)Callbacks::DestinationFileWriteErrorResolution::Stop;
    
    const auto ctx = make_shared<AsyncDialogResponse>();
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

int Copying::OnCantCreateDestinationRootDir(int _err, const string &_path, VFSHost &_vfs)
{
    const auto ctx = make_shared<AsyncDialogResponse>();
    ShowGenericDialog(GenericDialog::AbortRetry,
                      NSLocalizedString(@"Failed to create a directory", ""),
                      _err, {_vfs, _path}, ctx);
    WaitForDialogResponse(ctx);
    
    if( ctx->response == NSModalResponseRetry )
        return (int)Callbacks::CantCreateDestinationRootDirResolution::Retry;
    else
        return (int)Callbacks::CantCreateDestinationRootDirResolution::Stop;
}

int Copying::OnCantCreateDestinationDir(int _err, const string &_path, VFSHost &_vfs)
{
    if( m_SkipAll )
        return (int)Callbacks::CantCreateDestinationDirResolution::Skip;
    if( !IsInteractive() )
        return (int)Callbacks::CantCreateDestinationDirResolution::Stop;
    
    const auto ctx = make_shared<AsyncDialogResponse>();
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

int Copying::OnCantDeleteDestinationFile(int _err, const string &_path, VFSHost &_vfs)
{
    if( m_SkipAll )
        return (int)Callbacks::CantDeleteDestinationFileResolution::Skip;
    if( !IsInteractive() )
        return (int)Callbacks::CantDeleteDestinationFileResolution::Stop;
    
    const auto ctx = make_shared<AsyncDialogResponse>();
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
    
void Copying::OnFileVerificationFailed(const string &_path, VFSHost &_vfs)
{
    const auto ctx = make_shared<AsyncDialogResponse>();
    ShowGenericDialog(GenericDialog::Continue,
                      NSLocalizedString(@"Checksum verification failed", ""),
                      VFSError::FromErrno(EIO), {_vfs, _path}, ctx);
    WaitForDialogResponse(ctx);
}

static NSString *OpTitlePreffix(bool _copying)
{
    return _copying ?
        NSLocalizedString(@"Copying", "Prefix of a file operation") :
        NSLocalizedString(@"Moving", "Prefix of a file operation") ;
}

static NSString *OpTitleForSingleItem(bool _copying, NSString *_item, NSString *_to)
{
    auto fmt = NSLocalizedString(@"%@ \u201c%@\u201d to \u201c%@\u201d", "");
    return [NSString stringWithFormat:fmt,
            OpTitlePreffix(_copying),
            _item,
            _to];
}

static NSString *OpTitleForMultipleItems(bool _copying, int _items, NSString *_to)
{
    auto fmt = NSLocalizedString(@"%@ %@ items to \u201c%@\u201d", "");
    return [NSString stringWithFormat:fmt,
            OpTitlePreffix(_copying),
            [NSNumber numberWithInt:_items],
            _to];
}

static NSString *ExtractCopyToName(const string&_s)
{
    char buff[MAXPATHLEN] = {0};
    bool use_buff = GetDirectoryNameFromPath(_s.c_str(), buff, MAXPATHLEN);
    NSString *to = [NSString stringWithUTF8String:(use_buff ? buff : _s.c_str())];
    return to;
}

static string BuildTitle(const vector<VFSListingItem> &_source_files,
                         const string& _destination_path,
                         const CopyingOptions &_options)
{
    if ( _source_files.size() == 1)
        return OpTitleForSingleItem(_options.docopy,
                                    _source_files.front().FilenameNS(),
                                    ExtractCopyToName(_destination_path)).UTF8String;
    else
        return OpTitleForMultipleItems(_options.docopy,
                                       (int)_source_files.size(),
                                       ExtractCopyToName(_destination_path)).UTF8String;
}

}

// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Compression.h"
#include "CompressionJob.h"
#include "../HaltReasonDialog.h"
#include "../GenericErrorDialog.h"
#include "../AsyncDialogResponse.h"
#include "../Internal.h"
#include "../ModalDialogResponses.h"

namespace nc::ops
{

using Callbacks = CompressionJobCallbacks;

Compression::Compression(vector<VFSListingItem> _src_files,
                         string _dst_root,
                         VFSHostPtr _dst_vfs)
{
    m_InitialSourceItemsAmount = (int)_src_files.size();
    m_InitialSingleItemFilename = m_InitialSourceItemsAmount == 1 ?
        _src_files.front().DisplayName() : "";
    m_Job.reset( new CompressionJob{move(_src_files),
                                    _dst_root,
                                    _dst_vfs} );
    m_Job->m_TargetPathDefined = [this]{
        OnTargetPathDefined();
    };
    m_Job->m_TargetWriteError = [this](int _err, const string &_path, VFSHost &_vfs) {
        OnTargetWriteError(_err, _path, _vfs);
    };
    m_Job->m_SourceReadError = [this](int _err, const string &_path, VFSHost &_vfs) {
        return (Callbacks::SourceReadErrorResolution)OnSourceReadError(_err, _path, _vfs);
    };
    m_Job->m_SourceScanError = [this](int _err, const string &_path, VFSHost &_vfs) {
        return (Callbacks::SourceScanErrorResolution)OnSourceScanError(_err, _path, _vfs);
    };
    m_Job->m_SourceAccessError = [this](int _err, const string &_path, VFSHost &_vfs) {
        return (Callbacks::SourceAccessErrorResolution)OnSourceAccessError(_err, _path, _vfs);
    };
    
    SetTitle( BuildInitialTitle() );
}

Compression::~Compression()
{
    Wait();
}
    
Job *Compression::GetJob() noexcept
{
    return m_Job.get();
}

string Compression::ArchivePath() const
{
    return m_Job->TargetArchivePath();
}

void Compression::OnTargetWriteError(int _err, const string &_path, VFSHost &_vfs)
{
    ReportHaltReason(NSLocalizedString(@"Failed to write an archive", ""),
                     _err, _path, _vfs);
}

int Compression::OnSourceReadError(int _err, const string &_path, VFSHost &_vfs)
{
    if( m_SkipAll || !IsInteractive() )
        return m_SkipAll ?
            (int)Callbacks::SourceReadErrorResolution::Skip :
            (int)Callbacks::SourceReadErrorResolution::Stop;

    const auto ctx = make_shared<AsyncDialogResponse>();
    ShowGenericDialog(GenericDialog::AbortSkipSkipAll,
                      NSLocalizedString(@"Failed to read a file", ""),
                      _err, {_vfs, _path}, ctx);
    WaitForDialogResponse(ctx);

    if( ctx->response == NSModalResponseSkip )
        return (int)Callbacks::SourceReadErrorResolution::Skip;
    else if( ctx->response == NSModalResponseSkipAll ) {
        m_SkipAll = true;
        return (int)Callbacks::SourceReadErrorResolution::Skip;
    }
    else
        return (int)Callbacks::SourceReadErrorResolution::Stop;
}

int Compression::OnSourceScanError(int _err, const string &_path, VFSHost &_vfs)
{
    if( m_SkipAll || !IsInteractive() )
        return m_SkipAll ?
            (int)Callbacks::SourceScanErrorResolution::Skip :
            (int)Callbacks::SourceScanErrorResolution::Stop;
    const auto ctx = make_shared<AsyncDialogResponse>();
    ShowGenericDialog(GenericDialog::AbortSkipSkipAllRetry,
                      NSLocalizedString(@"Failed to access an item", ""),
                      _err, {_vfs, _path}, ctx);
    WaitForDialogResponse(ctx);
    
    if( ctx->response == NSModalResponseSkip  )
        return (int)Callbacks::SourceScanErrorResolution::Skip;
    else if( ctx->response == NSModalResponseSkipAll ) {
        m_SkipAll = true;
        return (int)Callbacks::SourceScanErrorResolution::Skip;
    }
    else if( ctx->response == NSModalResponseRetry )
        return (int)Callbacks::SourceScanErrorResolution::Retry;
    else
        return (int)Callbacks::SourceScanErrorResolution::Stop;
}

int Compression::OnSourceAccessError(int _err, const string &_path, VFSHost &_vfs)
{
    if( m_SkipAll || !IsInteractive() )
        return m_SkipAll ?
            (int)Callbacks::SourceAccessErrorResolution::Skip :
            (int)Callbacks::SourceAccessErrorResolution::Stop;
    const auto ctx = make_shared<AsyncDialogResponse>();
    ShowGenericDialog(GenericDialog::AbortSkipSkipAllRetry,
                      NSLocalizedString(@"Failed to access an item", ""),
                      _err, {_vfs, _path}, ctx);
    WaitForDialogResponse(ctx);
    
    if( ctx->response == NSModalResponseSkip )
        return (int)Callbacks::SourceAccessErrorResolution::Skip;
    else if( ctx->response == NSModalResponseSkipAll ) {
        m_SkipAll = true;
        return (int)Callbacks::SourceAccessErrorResolution::Skip;
    }
    else if( ctx->response == NSModalResponseRetry )
        return (int)Callbacks::SourceAccessErrorResolution::Retry;
    else
        return (int)Callbacks::SourceAccessErrorResolution::Stop;
}

void Compression::OnTargetPathDefined()
{
    SetTitle( BuildTitleWithArchiveFilename() );
}

NSString *Compression::BuildTitlePrefix() const
{
    if( m_InitialSingleItemFilename.empty() )
        return [NSString localizedStringWithFormat:
                NSLocalizedString(@"Compressing %d items", "Compressing %d items"),
                m_InitialSourceItemsAmount];
    else
        return [NSString localizedStringWithFormat:
                NSLocalizedString(@"Compressing \u201c%@\u201d", "Compressing \u201c%@\u201d"),
                [NSString stringWithUTF8StdString:m_InitialSingleItemFilename]];
}

string Compression::BuildInitialTitle() const
{
    return BuildTitlePrefix().UTF8String;
}

string Compression::BuildTitleWithArchiveFilename() const
{
    auto p = path(m_Job->TargetArchivePath());
    return [NSString localizedStringWithFormat:
                NSLocalizedString(@"%@ to \u201c%@\u201d", "Compressing \u201c%@\u201d"),
                BuildTitlePrefix(),
                [NSString stringWithUTF8StdString:p.filename().native()]].UTF8String;
}

}

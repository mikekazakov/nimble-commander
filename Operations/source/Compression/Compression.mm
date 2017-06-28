#include "Compression.h"
#include "CompressionJob.h"
#include "../HaltReasonDialog.h"
#include "../GenericErrorDialog.h"
#include "../AsyncDialogResponse.h"

namespace nc::ops
{

using Callbacks = CompressionJobCallbacks;

Compression::Compression(vector<VFSListingItem> _src_files,
                         string _dst_root,
                         VFSHostPtr _dst_vfs)
{
    m_Job.reset( new CompressionJob{_src_files,
                                    _dst_root,
                                    _dst_vfs} );
    
    m_Job->m_TargetWriteError = [this](int _err, const string &_path, VFSHost &_vfs) {
        OnTargetWriteError(_err, _path, _vfs);
    };
    m_Job->m_SourceReadError = [this](int _err, const string &_path, VFSHost &_vfs) {
        OnSourceReadError(_err, _path, _vfs);
    };
    m_Job->m_SourceScanError = [this](int _err, const string &_path, VFSHost &_vfs) {
        return (Callbacks::SourceScanErrorResolution)OnSourceScanError(_err, _path, _vfs);
    };
    m_Job->m_SourceAccessError = [this](int _err, const string &_path, VFSHost &_vfs) {
        return (Callbacks::SourceAccessErrorResolution)OnSourceAccessError(_err, _path, _vfs);
    };
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
    ReportHaltReason(@"Failed to write an archive", _err, _path, _vfs);
}

void Compression::OnSourceReadError(int _err, const string &_path, VFSHost &_vfs)
{
    ReportHaltReason(@"Failed to read a file", _err, _path, _vfs);
}

int Compression::OnSourceScanError(int _err, const string &_path, VFSHost &_vfs)
{
    if( m_SkipAll || !IsInteractive() )
        return m_SkipAll ?
            (int)Callbacks::SourceScanErrorResolution::Skip :
            (int)Callbacks::SourceScanErrorResolution::Stop;
    auto ctx = make_shared<AsyncDialogResponse>();
    dispatch_to_main_queue([=,vfs=_vfs.shared_from_this()]{
        OnSourceScanErrorUI(_err, _path, vfs, ctx);
    });
    WaitForDialogResponse(ctx);
    
    if( ctx->response == NSModalResponseSkip  )
        return (int)Callbacks::SourceScanErrorResolution::Skip;
    else if( ctx->response == NSModalResponseSkipAll ) {
        m_SkipAll = true;
        return (int)Callbacks::SourceScanErrorResolution::Skip;
    }
    else
        return (int)Callbacks::SourceScanErrorResolution::Stop;
}

void Compression::OnSourceScanErrorUI(int _err, const string &_path, VFSHostPtr _vfs,
                                      shared_ptr<AsyncDialogResponse> _ctx)
{
    auto sheet = [[NCOpsGenericErrorDialog alloc] init];

    sheet.style = GenericErrorDialogStyle::Caution;
    sheet.message = @"Failed to access an item";
    sheet.path = [NSString stringWithUTF8String:_path.c_str()];
    sheet.errorNo = _err;
    [sheet addButtonWithTitle:@"Abort" responseCode:NSModalResponseStop];
    [sheet addButtonWithTitle:@"Skip" responseCode:NSModalResponseSkip];
    [sheet addButtonWithTitle:@"Skip All" responseCode:NSModalResponseSkipAll];

    Show(sheet.window, _ctx);
}

int Compression::OnSourceAccessError(int _err, const string &_path, VFSHost &_vfs)
{
    if( m_SkipAll || !IsInteractive() )
        return m_SkipAll ?
            (int)Callbacks::SourceAccessErrorResolution::Skip :
            (int)Callbacks::SourceAccessErrorResolution::Stop;
    auto ctx = make_shared<AsyncDialogResponse>();
    dispatch_to_main_queue([=,vfs=_vfs.shared_from_this()]{
        OnSourceScanErrorUI(_err, _path, vfs, ctx);
    });
    WaitForDialogResponse(ctx);
    
    if( ctx->response == NSModalResponseSkip )
        return (int)Callbacks::SourceAccessErrorResolution::Skip;
    else if( ctx->response == NSModalResponseSkipAll ) {
        m_SkipAll = true;
        return (int)Callbacks::SourceAccessErrorResolution::Skip;
    }
    else
        return (int)Callbacks::SourceAccessErrorResolution::Stop;
}

}

#include "Compression.h"
#include "CompressionJob.h"
#include "../HaltReasonDialog.h"

namespace nc::ops
{

Compression::Compression(vector<VFSListingItem> _src_files,
                         string _dst_root,
                         VFSHostPtr _dst_vfs)
{
    m_Job.reset( new CompressionJob{_src_files,
                                    _dst_root,
                                    _dst_vfs} );
    
    m_Job->m_TargetWriteError = [this](int _err, const string &_path, VFSHost &_vfs){
        OnTargetWriteError(_err, _path, _vfs);
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
    if( !IsInteractive() )
        return;
    auto ctx = make_shared<AsyncDialogResponse>();
    dispatch_to_main_queue([=,vfs=_vfs.shared_from_this()]{
        OnTargetWriteErrorUI(_err, _path, vfs, ctx);
    });
    ctx->Wait();
}

void Compression::OnTargetWriteErrorUI(int _err, const string &_path, VFSHostPtr _vfs, shared_ptr<AsyncDialogResponse> _ctx)
{
    auto sheet = [[NCOpsHaltReasonDialog alloc] init];
    sheet.message = @"Failed to write an archive";
    sheet.path = [NSString stringWithUTF8String:_path.c_str()];
    sheet.errorNo = _err;
    Show(sheet.window, _ctx);
}

}

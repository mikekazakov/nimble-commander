#include "BatchRenaming.h"
#include "BatchRenamingJob.h"
#include <VFS/VFS.h>
#include "../AsyncDialogResponse.h"
#include "../ModalDialogResponses.h"
#include "../GenericErrorDialog.h"
#include "../Internal.h"

namespace nc::ops {

using Callbacks = BatchRenamingJobCallbacks;

static string Caption( const vector<string> &_paths );

BatchRenaming::BatchRenaming(vector<string> _src_paths,
                             vector<string> _dst_paths,
                             shared_ptr<VFSHost> _vfs)
{
    if( _src_paths.size() != _dst_paths.size() )
        throw logic_error("BatchRenaming: invalid parameters");
    
    SetTitle(Caption(_src_paths));
    
    m_Job.reset( new BatchRenamingJob( move(_src_paths), move(_dst_paths), _vfs ) );
    m_Job->m_OnRenameError = [this](int _err, const string &_path, VFSHost &_vfs){
        return (Callbacks::RenameErrorResolution) OnRenameError(_err, _path, _vfs);
    };
}

BatchRenaming::~BatchRenaming()
{
    Wait();
}

Job *BatchRenaming::GetJob() noexcept
{
    return m_Job.get();
}

int BatchRenaming::OnRenameError(int _err, const string &_path, VFSHost &_vfs)
{
    if( m_SkipAll || !IsInteractive() )
        return m_SkipAll ?
            (int)Callbacks::RenameErrorResolution::Skip :
            (int)Callbacks::RenameErrorResolution::Stop;
    
    const auto ctx = make_shared<AsyncDialogResponse>();
    dispatch_to_main_queue([=,vfs=_vfs.shared_from_this()]{
        OnRenameErrorUI(_err, _path, vfs, ctx);
    });
    WaitForDialogResponse(ctx);

    if( ctx->response == NSModalResponseSkip  )
        return (int)Callbacks::RenameErrorResolution::Skip;
    else if( ctx->response == NSModalResponseSkipAll ) {
        m_SkipAll = true;
        return (int)Callbacks::RenameErrorResolution::Skip;
    }
    else
        return (int)Callbacks::RenameErrorResolution::Stop;
}

void BatchRenaming::OnRenameErrorUI(int _err, const string &_path, shared_ptr<VFSHost> _vfs,
                                    shared_ptr<AsyncDialogResponse> _ctx)
{
    const auto sheet = [[NCOpsGenericErrorDialog alloc] init];

    sheet.style = GenericErrorDialogStyle::Caution;
    sheet.message = NSLocalizedString(@"Failed to rename an item", "");
    sheet.path = [NSString stringWithUTF8String:_path.c_str()];
    sheet.errorNo = _err;
    [sheet addAbortButton];
    [sheet addSkipButton];
    [sheet addSkipAllButton];

    Show(sheet.window, _ctx);
}

static string Caption( const vector<string> &_paths )
{
    return [NSString localizedStringWithFormat:
            NSLocalizedString(@"Batch renaming %@ items", "Operation title batch renaming"),
            [NSNumber numberWithUnsignedLong:_paths.size()]].UTF8String;
}

}


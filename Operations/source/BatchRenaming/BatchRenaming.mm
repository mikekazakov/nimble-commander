// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "BatchRenaming.h"
#include "BatchRenamingJob.h"
#include <VFS/VFS.h>
#include "../AsyncDialogResponse.h"
#include "../ModalDialogResponses.h"
#include "../GenericErrorDialog.h"
#include "../Internal.h"

namespace nc::ops {

using Callbacks = BatchRenamingJobCallbacks;

static std::string Caption( const std::vector<std::string> &_paths );

BatchRenaming::BatchRenaming(std::vector<std::string> _src_paths,
                             std::vector<std::string> _dst_paths,
                             std::shared_ptr<VFSHost> _vfs)
{
    if( _src_paths.size() != _dst_paths.size() )
        throw std::logic_error("BatchRenaming: invalid parameters");
    
    SetTitle(Caption(_src_paths));
    
    m_Job.reset( new BatchRenamingJob( move(_src_paths), move(_dst_paths), _vfs ) );
    m_Job->m_OnRenameError = [this](int _err, const std::string &_path, VFSHost &_vfs){
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

int BatchRenaming::OnRenameError(int _err, const std::string &_path, VFSHost &_vfs)
{
    if( m_SkipAll || !IsInteractive() )
        return m_SkipAll ?
            (int)Callbacks::RenameErrorResolution::Skip :
            (int)Callbacks::RenameErrorResolution::Stop;
    
    const auto ctx = std::make_shared<AsyncDialogResponse>();
    ShowGenericDialog(GenericDialog::AbortSkipSkipAllRetry,
                      NSLocalizedString(@"Failed to rename an item", ""),
                      _err, {_vfs, _path}, ctx);
    WaitForDialogResponse(ctx);

    if( ctx->response == NSModalResponseSkip  )
        return (int)Callbacks::RenameErrorResolution::Skip;
    else if( ctx->response == NSModalResponseSkipAll ) {
        m_SkipAll = true;
        return (int)Callbacks::RenameErrorResolution::Skip;
    }
    else if( ctx->response == NSModalResponseRetry  )
        return (int)Callbacks::RenameErrorResolution::Retry;
    else
        return (int)Callbacks::RenameErrorResolution::Stop;
}

static std::string Caption( const std::vector<std::string> &_paths )
{
    return [NSString localizedStringWithFormat:
            NSLocalizedString(@"Batch renaming %@ items", "Operation title batch renaming"),
            [NSNumber numberWithUnsignedLong:_paths.size()]].UTF8String;
}

}


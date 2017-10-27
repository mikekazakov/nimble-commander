// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Deletion.h"
#include "DeletionJob.h"
#include "../Internal.h"
#include "../AsyncDialogResponse.h"
#include "../ModalDialogResponses.h"
#include "../GenericErrorDialog.h"

namespace nc::ops {

static NSString *Caption(const vector<VFSListingItem> &_files);

using Callbacks = DeletionJobCallbacks;

Deletion::Deletion( vector<VFSListingItem> _items, DeletionType _type )
{
    SetTitle(Caption(_items).UTF8String);
    
    m_Job.reset( new DeletionJob(move(_items), _type) );
    m_Job->m_OnReadDirError = [this](int _err, const string &_path, VFSHost &_vfs){
        return (Callbacks::ReadDirErrorResolution)OnReadDirError(_err, _path, _vfs);
    };
    m_Job->m_OnUnlinkError = [this](int _err, const string &_path, VFSHost &_vfs){
        return (Callbacks::UnlinkErrorResolution)OnUnlinkError(_err, _path, _vfs);
    };
    m_Job->m_OnRmdirError = [this](int _err, const string &_path, VFSHost &_vfs){
        return (Callbacks::RmdirErrorResolution)OnRmdirError(_err, _path, _vfs);
    };
    m_Job->m_OnTrashError = [this](int _err, const string &_path, VFSHost &_vfs){
        return (Callbacks::TrashErrorResolution)OnTrashError(_err, _path, _vfs);
    };
}

Deletion::~Deletion()
{
}

Job *Deletion::GetJob() noexcept
{
    return m_Job.get();
}

int Deletion::OnReadDirError(int _err, const string &_path, VFSHost &_vfs)
{
    if( m_SkipAll || !IsInteractive() )
        return m_SkipAll ?
            (int)Callbacks::ReadDirErrorResolution::Skip :
            (int)Callbacks::ReadDirErrorResolution::Stop;
    
    const auto ctx = make_shared<AsyncDialogResponse>();
    dispatch_to_main_queue([=,vfs=_vfs.shared_from_this()]{
        OnReadDirErrorUI(_err, _path, vfs, ctx);
    });
    WaitForDialogResponse(ctx);

    if( ctx->response == NSModalResponseSkip  )
        return (int)Callbacks::ReadDirErrorResolution::Skip;
    else if( ctx->response == NSModalResponseSkipAll ) {
        m_SkipAll = true;
        return (int)Callbacks::ReadDirErrorResolution::Skip;
    }
    else if( ctx->response == NSModalResponseRetry )
        return (int)Callbacks::ReadDirErrorResolution::Retry;
    else
        return (int)Callbacks::ReadDirErrorResolution::Stop;
}

void Deletion::OnReadDirErrorUI(int _err, const string &_path, shared_ptr<VFSHost> _vfs,
                                shared_ptr<AsyncDialogResponse> _ctx)
{
    const auto sheet = [[NCOpsGenericErrorDialog alloc] init];

    sheet.style = GenericErrorDialogStyle::Caution;
    sheet.message = NSLocalizedString(@"Failed to access a directory", "");
    sheet.path = [NSString stringWithUTF8String:_path.c_str()];
    sheet.errorNo = _err;
    [sheet addButtonWithTitle:NSLocalizedString(@"Abort", "")
                 responseCode:NSModalResponseStop];
    [sheet addButtonWithTitle:NSLocalizedString(@"Skip", "")
                 responseCode:NSModalResponseSkip];
    if( m_Job->ItemsInScript() > 0 )
        [sheet addButtonWithTitle:NSLocalizedString(@"Skip All", "")
                     responseCode:NSModalResponseSkipAll];
    [sheet addButtonWithTitle:NSLocalizedString(@"Retry", "")
                 responseCode:NSModalResponseRetry];

    Show(sheet.window, _ctx);
}

int Deletion::OnUnlinkError(int _err, const string &_path, VFSHost &_vfs)
{
    if( m_SkipAll || !IsInteractive() )
        return m_SkipAll ?
            (int)Callbacks::UnlinkErrorResolution::Skip :
            (int)Callbacks::UnlinkErrorResolution::Stop;
    
    const auto ctx = make_shared<AsyncDialogResponse>();
    dispatch_to_main_queue([=,vfs=_vfs.shared_from_this()]{
        OnUnlinkErrorUI(_err, _path, vfs, ctx);
    });
    WaitForDialogResponse(ctx);

    if( ctx->response == NSModalResponseSkip  )
        return (int)Callbacks::UnlinkErrorResolution::Skip;
    else if( ctx->response == NSModalResponseRetry  )
        return (int)Callbacks::UnlinkErrorResolution::Retry;
    else if( ctx->response == NSModalResponseSkipAll ) {
        m_SkipAll = true;
        return (int)Callbacks::UnlinkErrorResolution::Skip;
    }
    else
        return (int)Callbacks::UnlinkErrorResolution::Stop;
}

void Deletion::OnUnlinkErrorUI(int _err, const string &_path, shared_ptr<VFSHost> _vfs,
                               shared_ptr<AsyncDialogResponse> _ctx)
{
    const auto sheet = [[NCOpsGenericErrorDialog alloc] init];

    sheet.style = GenericErrorDialogStyle::Caution;
    sheet.message = NSLocalizedString(@"Failed to delete a file", "");
    sheet.path = [NSString stringWithUTF8String:_path.c_str()];
    sheet.errorNo = _err;
    [sheet addButtonWithTitle:NSLocalizedString(@"Abort", "")
                 responseCode:NSModalResponseStop];
    [sheet addButtonWithTitle:NSLocalizedString(@"Skip", "")
                 responseCode:NSModalResponseSkip];
    if( m_Job->ItemsInScript() > 0 )
        [sheet addButtonWithTitle:NSLocalizedString(@"Skip All", "")
                     responseCode:NSModalResponseSkipAll];
    [sheet addButtonWithTitle:NSLocalizedString(@"Retry", "")
                 responseCode:NSModalResponseRetry];

    Show(sheet.window, _ctx);                     
}

int Deletion::OnRmdirError(int _err, const string &_path, VFSHost &_vfs)
{
    if( m_SkipAll || !IsInteractive() )
        return m_SkipAll ?
            (int)Callbacks::RmdirErrorResolution::Skip :
            (int)Callbacks::RmdirErrorResolution::Stop;
    
    const auto ctx = make_shared<AsyncDialogResponse>();
    dispatch_to_main_queue([=,vfs=_vfs.shared_from_this()]{
        OnRmdirErrorUI(_err, _path, vfs, ctx);
    });
    WaitForDialogResponse(ctx);

    if( ctx->response == NSModalResponseSkip )
        return (int)Callbacks::RmdirErrorResolution::Skip;
    else if( ctx->response == NSModalResponseRetry )
            return (int)Callbacks::RmdirErrorResolution::Retry;
    else if( ctx->response == NSModalResponseSkipAll ) {
        m_SkipAll = true;
        return (int)Callbacks::RmdirErrorResolution::Skip;
    }
    else
        return (int)Callbacks::RmdirErrorResolution::Stop;
}

void Deletion::OnRmdirErrorUI(int _err, const string &_path, shared_ptr<VFSHost> _vfs,
                        shared_ptr<AsyncDialogResponse> _ctx)
{
    const auto sheet = [[NCOpsGenericErrorDialog alloc] init];

    sheet.style = GenericErrorDialogStyle::Caution;
    sheet.message = NSLocalizedString(@"Failed to delete a directory", "");
    sheet.path = [NSString stringWithUTF8String:_path.c_str()];
    sheet.errorNo = _err;
    [sheet addButtonWithTitle:NSLocalizedString(@"Abort", "")
                 responseCode:NSModalResponseStop];
    [sheet addButtonWithTitle:NSLocalizedString(@"Skip", "")
                 responseCode:NSModalResponseSkip];
    if( m_Job->ItemsInScript() > 0 )
        [sheet addButtonWithTitle:NSLocalizedString(@"Skip All", "")
                     responseCode:NSModalResponseSkipAll];
    [sheet addButtonWithTitle:NSLocalizedString(@"Retry", "")
                 responseCode:NSModalResponseRetry];

    Show(sheet.window, _ctx);
}

int Deletion::OnTrashError(int _err, const string &_path, VFSHost &_vfs)
{
    if( m_DeleteAllOnTrashError )
        return (int)Callbacks::TrashErrorResolution::DeletePermanently;

    if( m_SkipAll || !IsInteractive() )
        return m_SkipAll ?
            (int)Callbacks::TrashErrorResolution::Skip :
            (int)Callbacks::TrashErrorResolution::Stop;
    
    const auto ctx = make_shared<AsyncDialogResponse>();
    dispatch_to_main_queue([=,vfs=_vfs.shared_from_this()]{
        OnTrashErrorUI(_err, _path, vfs, ctx);
    });
    WaitForDialogResponse(ctx);
    
    if( ctx->response == NSModalResponseSkip  ) {
        if( ctx->IsApplyToAllSet() )
            m_SkipAll = true;
        return (int)Callbacks::TrashErrorResolution::Skip;
    }
    else if( ctx->response == NSModalResponseRetry )
        return (int)Callbacks::TrashErrorResolution::Retry;
    else if( ctx->response == NSModalResponseDeletePermanently  ) {
        if( ctx->IsApplyToAllSet() )
            m_DeleteAllOnTrashError = true;
        return (int)Callbacks::TrashErrorResolution::DeletePermanently;
    }
    else
        return (int)Callbacks::TrashErrorResolution::Stop;
}

void Deletion::OnTrashErrorUI(int _err, const string &_path, shared_ptr<VFSHost> _vfs,
                              shared_ptr<AsyncDialogResponse> _ctx)
{
    const auto sheet = [[NCOpsGenericErrorDialog alloc] initWithContext:_ctx];

    sheet.style = GenericErrorDialogStyle::Caution;
    sheet.message = NSLocalizedString(@"Failed to move an item to Trash", "");
    sheet.path = [NSString stringWithUTF8String:_path.c_str()];
    sheet.showApplyToAll = m_Job->ItemsInScript() > 0;
    sheet.errorNo = _err;
    [sheet addButtonWithTitle:NSLocalizedString(@"Abort", "")
                 responseCode:NSModalResponseStop];
    [sheet addButtonWithTitle:NSLocalizedString(@"Delete Permanently", "")
                 responseCode:NSModalResponseDeletePermanently];
    [sheet addButtonWithTitle:NSLocalizedString(@"Skip", "")
                 responseCode:NSModalResponseSkip];
    [sheet addButtonWithTitle:NSLocalizedString(@"Retry", "")
                 responseCode:NSModalResponseRetry];
    Show(sheet.window, _ctx);
}

static NSString *Caption(const vector<VFSListingItem> &_files)
{
    if( _files.size() == 1 )
        return  [NSString localizedStringWithFormat:
                 NSLocalizedString(@"Deleting \u201c%@\u201d",
                                   "Operation title for single item deletion"),
                 _files.front().DisplayNameNS()];
    else
        return [NSString localizedStringWithFormat:
                NSLocalizedString(@"Deleting %@ items",
                                  "Operation title for multiple items deletion"),
                [NSNumber numberWithUnsignedLong:_files.size()]];
}

}

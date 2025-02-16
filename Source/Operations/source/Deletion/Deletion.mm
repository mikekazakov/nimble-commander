// Copyright (C) 2017-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Deletion.h"
#include "DeletionJob.h"
#include "../Internal.h"
#include "../AsyncDialogResponse.h"
#include "../ModalDialogResponses.h"
#include "../GenericErrorDialog.h"
#include <Base/dispatch_cpp.h>

#include <memory>

namespace nc::ops {

static NSString *Caption(const std::vector<VFSListingItem> &_files);

using Callbacks = DeletionJobCallbacks;

Deletion::Deletion(std::vector<VFSListingItem> _items, DeletionOptions _options) : m_OrigOptions(_options)
{
    SetTitle(Caption(_items).UTF8String);
    m_LockedItemBehaviour = m_OrigOptions.locked_items_behaviour;

    m_Job = std::make_unique<DeletionJob>(std::move(_items), _options.type);
    m_Job->m_OnReadDirError = [this](Error _err, const std::string &_path, VFSHost &_vfs) {
        return OnReadDirError(_err, _path, _vfs);
    };
    m_Job->m_OnUnlinkError = [this](Error _err, const std::string &_path, VFSHost &_vfs) {
        return OnUnlinkError(_err, _path, _vfs);
    };
    m_Job->m_OnRmdirError = [this](Error _err, const std::string &_path, VFSHost &_vfs) {
        return OnRmdirError(_err, _path, _vfs);
    };
    m_Job->m_OnTrashError = [this](Error _err, const std::string &_path, VFSHost &_vfs) {
        return OnTrashError(_err, _path, _vfs);
    };
    m_Job->m_OnLockedItem = [this](Error _err, const std::string &_path, VFSHost &_vfs, DeletionType _type) {
        return OnLockedItem(_err, _path, _vfs, _type);
    };
    m_Job->m_OnUnlockError = [this](Error _err, const std::string &_path, VFSHost &_vfs) {
        return OnUnlockError(_err, _path, _vfs);
    };
}

Deletion::~Deletion() = default;

Job *Deletion::GetJob() noexcept
{
    return m_Job.get();
}

Callbacks::ReadDirErrorResolution Deletion::OnReadDirError(Error _err, const std::string &_path, VFSHost &_vfs)
{
    if( m_SkipAll || !IsInteractive() )
        return m_SkipAll ? Callbacks::ReadDirErrorResolution::Skip : Callbacks::ReadDirErrorResolution::Stop;

    const auto ctx = std::make_shared<AsyncDialogResponse>();
    dispatch_to_main_queue([=, this, vfs = _vfs.shared_from_this()] { OnReadDirErrorUI(_err, _path, vfs, ctx); });
    WaitForDialogResponse(ctx);

    if( ctx->response == NSModalResponseSkip )
        return Callbacks::ReadDirErrorResolution::Skip;
    else if( ctx->response == NSModalResponseSkipAll ) {
        m_SkipAll = true;
        return Callbacks::ReadDirErrorResolution::Skip;
    }
    else if( ctx->response == NSModalResponseRetry )
        return Callbacks::ReadDirErrorResolution::Retry;
    else
        return Callbacks::ReadDirErrorResolution::Stop;
}

void Deletion::OnReadDirErrorUI(Error _err,
                                const std::string &_path,
                                [[maybe_unused]] std::shared_ptr<VFSHost> _vfs,
                                std::shared_ptr<AsyncDialogResponse> _ctx)
{
    const auto sheet = [[NCOpsGenericErrorDialog alloc] init];

    sheet.style = GenericErrorDialogStyle::Caution;
    sheet.message = NSLocalizedString(@"Failed to access a directory", "");
    sheet.path = [NSString stringWithUTF8String:_path.c_str()];
    sheet.error = _err;
    [sheet addButtonWithTitle:NSLocalizedString(@"Abort", "") responseCode:NSModalResponseStop];
    [sheet addButtonWithTitle:NSLocalizedString(@"Skip", "") responseCode:NSModalResponseSkip];
    if( m_Job->ItemsInScript() > 0 )
        [sheet addButtonWithTitle:NSLocalizedString(@"Skip All", "") responseCode:NSModalResponseSkipAll];
    [sheet addButtonWithTitle:NSLocalizedString(@"Retry", "") responseCode:NSModalResponseRetry];

    Show(sheet.window, _ctx);
}

Callbacks::UnlinkErrorResolution Deletion::OnUnlinkError(Error _err, const std::string &_path, VFSHost &_vfs)
{
    if( m_SkipAll || !IsInteractive() )
        return m_SkipAll ? Callbacks::UnlinkErrorResolution::Skip : Callbacks::UnlinkErrorResolution::Stop;

    const auto ctx = std::make_shared<AsyncDialogResponse>();
    dispatch_to_main_queue([=, this, vfs = _vfs.shared_from_this()] { OnUnlinkErrorUI(_err, _path, vfs, ctx); });
    WaitForDialogResponse(ctx);

    if( ctx->response == NSModalResponseSkip )
        return Callbacks::UnlinkErrorResolution::Skip;
    else if( ctx->response == NSModalResponseRetry )
        return Callbacks::UnlinkErrorResolution::Retry;
    else if( ctx->response == NSModalResponseSkipAll ) {
        m_SkipAll = true;
        return Callbacks::UnlinkErrorResolution::Skip;
    }
    else
        return Callbacks::UnlinkErrorResolution::Stop;
}

void Deletion::OnUnlinkErrorUI(Error _err,
                               const std::string &_path,
                               [[maybe_unused]] std::shared_ptr<VFSHost> _vfs,
                               std::shared_ptr<AsyncDialogResponse> _ctx)
{
    const auto sheet = [[NCOpsGenericErrorDialog alloc] init];

    sheet.style = GenericErrorDialogStyle::Caution;
    sheet.message = NSLocalizedString(@"Failed to delete a file", "");
    sheet.path = [NSString stringWithUTF8String:_path.c_str()];
    sheet.error = _err;
    [sheet addButtonWithTitle:NSLocalizedString(@"Abort", "") responseCode:NSModalResponseStop];
    [sheet addButtonWithTitle:NSLocalizedString(@"Skip", "") responseCode:NSModalResponseSkip];
    if( m_Job->ItemsInScript() > 0 )
        [sheet addButtonWithTitle:NSLocalizedString(@"Skip All", "") responseCode:NSModalResponseSkipAll];
    [sheet addButtonWithTitle:NSLocalizedString(@"Retry", "") responseCode:NSModalResponseRetry];

    Show(sheet.window, _ctx);
}

Callbacks::RmdirErrorResolution Deletion::OnRmdirError(Error _err, const std::string &_path, VFSHost &_vfs)
{
    if( m_SkipAll || !IsInteractive() )
        return m_SkipAll ? Callbacks::RmdirErrorResolution::Skip : Callbacks::RmdirErrorResolution::Stop;

    const auto ctx = std::make_shared<AsyncDialogResponse>();
    dispatch_to_main_queue([=, this, vfs = _vfs.shared_from_this()] { OnRmdirErrorUI(_err, _path, vfs, ctx); });
    WaitForDialogResponse(ctx);

    if( ctx->response == NSModalResponseSkip )
        return Callbacks::RmdirErrorResolution::Skip;
    else if( ctx->response == NSModalResponseRetry )
        return Callbacks::RmdirErrorResolution::Retry;
    else if( ctx->response == NSModalResponseSkipAll ) {
        m_SkipAll = true;
        return Callbacks::RmdirErrorResolution::Skip;
    }
    else
        return Callbacks::RmdirErrorResolution::Stop;
}

void Deletion::OnRmdirErrorUI(Error _err,
                              const std::string &_path,
                              [[maybe_unused]] std::shared_ptr<VFSHost> _vfs,
                              std::shared_ptr<AsyncDialogResponse> _ctx)
{
    const auto sheet = [[NCOpsGenericErrorDialog alloc] init];

    sheet.style = GenericErrorDialogStyle::Caution;
    sheet.message = NSLocalizedString(@"Failed to delete a directory", "");
    sheet.path = [NSString stringWithUTF8String:_path.c_str()];
    sheet.error = _err;
    [sheet addButtonWithTitle:NSLocalizedString(@"Abort", "") responseCode:NSModalResponseStop];
    [sheet addButtonWithTitle:NSLocalizedString(@"Skip", "") responseCode:NSModalResponseSkip];
    if( m_Job->ItemsInScript() > 0 )
        [sheet addButtonWithTitle:NSLocalizedString(@"Skip All", "") responseCode:NSModalResponseSkipAll];
    [sheet addButtonWithTitle:NSLocalizedString(@"Retry", "") responseCode:NSModalResponseRetry];

    Show(sheet.window, _ctx);
}

Callbacks::TrashErrorResolution Deletion::OnTrashError(const Error _err, const std::string &_path, VFSHost &_vfs)
{
    if( m_DeleteAllOnTrashError )
        return Callbacks::TrashErrorResolution::DeletePermanently;

    if( m_SkipAll || !IsInteractive() )
        return m_SkipAll ? Callbacks::TrashErrorResolution::Skip : Callbacks::TrashErrorResolution::Stop;

    const auto ctx = std::make_shared<AsyncDialogResponse>();
    dispatch_to_main_queue([=, this, vfs = _vfs.shared_from_this()] { OnTrashErrorUI(_err, _path, vfs, ctx); });
    WaitForDialogResponse(ctx);

    if( ctx->response == NSModalResponseSkip ) {
        if( ctx->IsApplyToAllSet() )
            m_SkipAll = true;
        return Callbacks::TrashErrorResolution::Skip;
    }
    else if( ctx->response == NSModalResponseRetry )
        return Callbacks::TrashErrorResolution::Retry;
    else if( ctx->response == NSModalResponseDeletePermanently ) {
        if( ctx->IsApplyToAllSet() )
            m_DeleteAllOnTrashError = true;
        return Callbacks::TrashErrorResolution::DeletePermanently;
    }
    else
        return Callbacks::TrashErrorResolution::Stop;
}

void Deletion::OnTrashErrorUI(const Error _err,
                              const std::string &_path,
                              [[maybe_unused]] std::shared_ptr<VFSHost> _vfs,
                              std::shared_ptr<AsyncDialogResponse> _ctx)
{
    const auto sheet = [[NCOpsGenericErrorDialog alloc] initWithContext:_ctx];

    sheet.style = GenericErrorDialogStyle::Caution;
    sheet.message = NSLocalizedString(@"Failed to move an item to Trash", "");
    sheet.path = [NSString stringWithUTF8String:_path.c_str()];
    sheet.showApplyToAll = m_Job->ItemsInScript() > 0;
    sheet.error = _err;
    [sheet addButtonWithTitle:NSLocalizedString(@"Abort", "") responseCode:NSModalResponseStop];
    [sheet addButtonWithTitle:NSLocalizedString(@"Delete Permanently", "")
                 responseCode:NSModalResponseDeletePermanently];
    [sheet addButtonWithTitle:NSLocalizedString(@"Skip", "") responseCode:NSModalResponseSkip];
    [sheet addButtonWithTitle:NSLocalizedString(@"Retry", "") responseCode:NSModalResponseRetry];
    Show(sheet.window, _ctx);
}

Callbacks::LockedItemResolution
Deletion::OnLockedItem(const Error _err, const std::string &_path, VFSHost &_vfs, DeletionType _type)
{
    switch( m_LockedItemBehaviour ) {
        case DeletionOptions::LockedItemBehavior::Ask:
            if( !IsInteractive() )
                return DeletionJobCallbacks::LockedItemResolution::Stop;
            break;
        case DeletionOptions::LockedItemBehavior::SkipAll:
            return DeletionJobCallbacks::LockedItemResolution::Skip;
        case DeletionOptions::LockedItemBehavior::UnlockAll:
            return DeletionJobCallbacks::LockedItemResolution::Unlock;
        case DeletionOptions::LockedItemBehavior::Stop:
            return DeletionJobCallbacks::LockedItemResolution::Stop;
    }

    const auto ctx = std::make_shared<AsyncDialogResponse>();
    dispatch_to_main_queue([=, this, vfs = _vfs.shared_from_this()] { OnLockedItemUI(_err, _path, vfs, _type, ctx); });
    WaitForDialogResponse(ctx);

    if( ctx->response == NSModalResponseSkip ) {
        if( ctx->IsApplyToAllSet() )
            m_LockedItemBehaviour = DeletionOptions::LockedItemBehavior::SkipAll;
        return Callbacks::LockedItemResolution::Skip;
    }
    else if( ctx->response == NSModalResponseRetry ) {
        return Callbacks::LockedItemResolution::Retry;
    }
    else if( ctx->response == NSModalResponseUnlock ) {
        if( ctx->IsApplyToAllSet() )
            m_LockedItemBehaviour = DeletionOptions::LockedItemBehavior::UnlockAll;
        return Callbacks::LockedItemResolution::Unlock;
    }
    else {
        return Callbacks::LockedItemResolution::Stop;
    }
}

void Deletion::OnLockedItemUI(const Error _err,
                              const std::string &_path,
                              [[maybe_unused]] std::shared_ptr<VFSHost> _vfs,
                              DeletionType _type,
                              std::shared_ptr<AsyncDialogResponse> _ctx)
{
    const auto sheet = [[NCOpsGenericErrorDialog alloc] initWithContext:_ctx];

    sheet.style = GenericErrorDialogStyle::Caution;
    sheet.message = _type == DeletionType::Permanent ? NSLocalizedString(@"Cannot delete a locked item", "")
                                                     : NSLocalizedString(@"Cannot move a locked item to Trash", "");
    sheet.path = [NSString stringWithUTF8String:_path.c_str()];
    sheet.showApplyToAll = m_Job->ItemsInScript() > 0;
    sheet.error = _err;
    [sheet addButtonWithTitle:NSLocalizedString(@"Abort", "") responseCode:NSModalResponseStop];
    [sheet addButtonWithTitle:NSLocalizedString(@"Unlock", "") responseCode:NSModalResponseUnlock];
    [sheet addButtonWithTitle:NSLocalizedString(@"Skip", "") responseCode:NSModalResponseSkip];
    [sheet addButtonWithTitle:NSLocalizedString(@"Retry", "") responseCode:NSModalResponseRetry];
    Show(sheet.window, _ctx);
}

DeletionJobCallbacks::UnlockErrorResolution Deletion::OnUnlockError(Error _err, const std::string &_path, VFSHost &_vfs)
{
    if( m_SkipAll || !IsInteractive() )
        return m_SkipAll ? Callbacks::UnlockErrorResolution::Skip : Callbacks::UnlockErrorResolution::Stop;

    const auto ctx = std::make_shared<AsyncDialogResponse>();
    dispatch_to_main_queue([=, this, vfs = _vfs.shared_from_this()] { OnUnlockErrorUI(_err, _path, vfs, ctx); });
    WaitForDialogResponse(ctx);

    if( ctx->response == NSModalResponseSkip )
        return Callbacks::UnlockErrorResolution::Skip;
    else if( ctx->response == NSModalResponseRetry )
        return Callbacks::UnlockErrorResolution::Retry;
    else if( ctx->response == NSModalResponseSkipAll ) {
        m_SkipAll = true;
        return Callbacks::UnlockErrorResolution::Skip;
    }
    else
        return Callbacks::UnlockErrorResolution::Stop;
}

void Deletion::OnUnlockErrorUI(Error _err,
                               const std::string &_path,
                               [[maybe_unused]] std::shared_ptr<VFSHost> _vfs,
                               std::shared_ptr<AsyncDialogResponse> _ctx)
{
    const auto sheet = [[NCOpsGenericErrorDialog alloc] init];

    sheet.style = GenericErrorDialogStyle::Caution;
    sheet.message = NSLocalizedString(@"Failed to unlock an item", "");
    sheet.path = [NSString stringWithUTF8String:_path.c_str()];
    sheet.error = _err;
    [sheet addButtonWithTitle:NSLocalizedString(@"Abort", "") responseCode:NSModalResponseStop];
    [sheet addButtonWithTitle:NSLocalizedString(@"Skip", "") responseCode:NSModalResponseSkip];
    if( m_Job->ItemsInScript() > 0 )
        [sheet addButtonWithTitle:NSLocalizedString(@"Skip All", "") responseCode:NSModalResponseSkipAll];
    [sheet addButtonWithTitle:NSLocalizedString(@"Retry", "") responseCode:NSModalResponseRetry];

    Show(sheet.window, _ctx);
}

static NSString *Caption(const std::vector<VFSListingItem> &_files)
{
    if( _files.size() == 1 )
        return [NSString localizedStringWithFormat:NSLocalizedString(@"Deleting \u201c%@\u201d",
                                                                     "Operation title for single item deletion"),
                                                   _files.front().DisplayNameNS()];
    else
        return [NSString localizedStringWithFormat:NSLocalizedString(@"Deleting %@ items",
                                                                     "Operation title for multiple items deletion"),
                                                   [NSNumber numberWithUnsignedLong:_files.size()]];
}

} // namespace nc::ops

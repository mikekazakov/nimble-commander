// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>
#include "../Operation.h"
#include "Options.h"

namespace nc::ops {

class DeletionJob;

class Deletion final : public Operation
{
public:
    Deletion( vector<VFSListingItem> _items, DeletionType _type );
    ~Deletion();

private:
    virtual Job *GetJob() noexcept override;
    int OnReadDirError(int _err, const string &_path, VFSHost &_vfs);
    void OnReadDirErrorUI(int _err, const string &_path, shared_ptr<VFSHost> _vfs,
                         shared_ptr<AsyncDialogResponse> _ctx);
    int OnUnlinkError(int _err, const string &_path, VFSHost &_vfs);
    void OnUnlinkErrorUI(int _err, const string &_path, shared_ptr<VFSHost> _vfs,
                         shared_ptr<AsyncDialogResponse> _ctx);
    int OnRmdirError(int _err, const string &_path, VFSHost &_vfs);
    void OnRmdirErrorUI(int _err, const string &_path, shared_ptr<VFSHost> _vfs,
                        shared_ptr<AsyncDialogResponse> _ctx);
    int OnTrashError(int _err, const string &_path, VFSHost &_vfs);
    void OnTrashErrorUI(int _err, const string &_path, shared_ptr<VFSHost> _vfs,
                        shared_ptr<AsyncDialogResponse> _ctx);
    
    
    unique_ptr<DeletionJob> m_Job;
    bool m_SkipAll = false;
    bool m_DeleteAllOnTrashError = false;
};

}

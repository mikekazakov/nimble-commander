#pragma once

#include "../Operation.h"
#include <VFS/VFS.h>



/*
+TODO:
- dialogs
- adjusting stats on skips

*/


namespace nc::ops
{

class CompressionJob;

class Compression : public Operation
{
public:
    Compression(vector<VFSListingItem> _src_files,
                string _dst_root,
                VFSHostPtr _dst_vfs);
    virtual ~Compression();

    string ArchivePath() const;

protected:
    virtual Job *GetJob() noexcept override;

private:
    void OnTargetWriteError(int _err, const string &_path, VFSHost &_vfs);
    void OnSourceReadError(int _err, const string &_path, VFSHost &_vfs);
//    void OnTargetWriteErrorUI(int _err, const string &_path, VFSHostPtr _vfs,
//                              shared_ptr<AsyncDialogResponse> _ctx);

    int OnSourceScanError(int _err, const string &_path, VFSHost &_vfs);
    void OnSourceScanErrorUI(int _err, const string &_path, VFSHostPtr _vfs,
                             shared_ptr<AsyncDialogResponse> _ctx);

    int OnSourceAccessError(int _err, const string &_path, VFSHost &_vfs);
//    void OnSourceReadAccessErrorUI(int _err, const string &_path, VFSHostPtr _vfs,
//                             shared_ptr<AsyncDialogResponse> _ctx);

//function< SourceScanErrorResolution(int _err, const string &_path, VFSHost &_vfs) >

    unique_ptr<CompressionJob> m_Job;
    bool m_SkipAll = false;
};

}

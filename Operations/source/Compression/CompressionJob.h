// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "../Job.h"
#include <VFS/VFS.h>
#include <Habanero/chained_strings.h>

struct archive;

namespace nc::ops
{

struct CompressionJobCallbacks
{
    function< void() >
    m_TargetPathDefined =
    []{};

    enum class SourceScanErrorResolution { Stop, Skip, Retry };
    function< SourceScanErrorResolution(int _err, const string &_path, VFSHost &_vfs) >
    m_SourceScanError =
    [](int _err, const string &_path,VFSHost &_vfs){ return SourceScanErrorResolution::Stop; };
    
    enum class SourceAccessErrorResolution { Stop, Skip, Retry };
    function< SourceAccessErrorResolution(int _err, const string &_path, VFSHost &_vfs) >
    m_SourceAccessError =
    [](int _err, const string &_path, VFSHost &_vfs){ return SourceAccessErrorResolution::Stop; };

    enum class SourceReadErrorResolution { Stop, Skip };
    function< SourceReadErrorResolution(int _err, const string &_path, VFSHost &_vfs) >
    m_SourceReadError =
    [](int _err, const string &_path, VFSHost &_vfs){ return  SourceReadErrorResolution::Stop; };

    function< void(int _err, const string &_path, VFSHost &_vfs) >
    m_TargetWriteError =
    [](int _err, const string &_path, VFSHost &_vfs){};
};

class CompressionJob final: public Job, public CompressionJobCallbacks
{
public:
    CompressionJob(vector<VFSListingItem> _src_files,
                   string _dst_root,
                   VFSHostPtr _dst_vfs);
    ~CompressionJob();

    const string &TargetArchivePath() const;
    
private:
    struct Source;

    virtual void Perform() override;
    optional<Source> ScanItems();
    bool ScanItem(const VFSListingItem &_item, Source &_ctx);
    bool ScanItem(const string &_full_path,
                  const string &_filename,
                  unsigned _vfs_no,
                  unsigned _basepath_no,
                  const chained_strings::node *_prefix,
                  Source &_ctx);
    bool BuildArchive();
    void ProcessItems();
    void ProcessItem(const chained_strings::node &_node, int _index);
    void ProcessDirectoryItem(const chained_strings::node &_node, int _index);
    void ProcessRegularItem(const chained_strings::node &_node, int _index);
    void ProcessSymlinkItem(const chained_strings::node &_node, int _index);

    string FindSuitableFilename(const string& _proposed_arcname) const;

    static ssize_t WriteCallback(struct archive *,
                                 void *_client_data,
                                 const void *_buffer,
                                 size_t _length);


    vector<VFSListingItem>  m_InitialListingItems;
    string                  m_DstRoot;
    VFSHostPtr              m_DstVFS;
    string                  m_TargetArchivePath;
    
    struct ::archive          *m_Archive = nullptr;
    shared_ptr<VFSFile>     m_TargetFile;
    
    unique_ptr<const Source>m_Source;
};

}

#pragma once

#include "../VFSHost.h"

class VFSXAttrFile;

class VFSXAttrHost final: public VFSHost
{
public:
    VFSXAttrHost( const string &_file_path, const VFSHostPtr& _host ); // _host must be native currently
    VFSXAttrHost(const VFSHostPtr &_parent, const VFSConfiguration &_config);
    ~VFSXAttrHost();

    static const char *Tag;
    virtual VFSConfiguration Configuration() const override;
    static VFSMeta Meta();
    
    virtual bool IsWriteable() const override;
    
    virtual int CreateFile(const char* _path,
                           shared_ptr<VFSFile> &_target,
                           VFSCancelChecker _cancel_checker) override;

    virtual int FetchFlexibleListing(const char *_path,
                                     shared_ptr<VFSListing> &_target,
                                     int _flags,
                                     VFSCancelChecker _cancel_checker) override;
    
    virtual int Stat(const char *_path, VFSStat &_st, int _flags, VFSCancelChecker _cancel_checker) override;
    
    virtual int Unlink(const char *_path, VFSCancelChecker _cancel_checker) override;
    virtual int Rename(const char *_old_path, const char *_new_path, VFSCancelChecker _cancel_checker) override;
    
    virtual bool ShouldProduceThumbnails() const override;

    
    void    ReportChange(); // will cause host to reload xattrs list
    
private:
    int     Fetch();
    
    VFSConfiguration                m_Configuration;    
    int                             m_FD = -1;
    struct stat                     m_Stat;
    spinlock                        m_AttrsLock;
    vector< pair<string, unsigned>> m_Attrs;
};


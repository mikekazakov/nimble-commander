#pragma once

#include "../VFSHost.h"

class VFSXAttrFile;

class VFSXAttrHost final: public VFSHost
{
public:
    VFSXAttrHost( const string &_file_path, const VFSHostPtr& _host ); // _host must be native currently
    ~VFSXAttrHost();

    static const char *Tag;
    virtual VFSConfiguration Configuration() const override;
    static VFSMeta Meta();
    
    virtual int CreateFile(const char* _path,
                           shared_ptr<VFSFile> &_target,
                           VFSCancelChecker _cancel_checker) override;

    virtual int FetchFlexibleListing(const char *_path,
                                     shared_ptr<VFSFlexibleListing> &_target,
                                     int _flags,
                                     VFSCancelChecker _cancel_checker) override;
    
    virtual int Stat(const char *_path, VFSStat &_st, int _flags, VFSCancelChecker _cancel_checker) override;    
    
private:
    VFSConfiguration                m_Configuration;    
    int                             m_FD = -1;
    struct stat                     m_Stat;
    vector< pair<string, unsigned>> m_Attrs;
};


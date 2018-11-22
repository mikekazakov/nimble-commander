// Copyright (C) 2016-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <sys/stat.h>
#include <VFS/Host.h>
#include <Habanero/spinlock.h>

namespace nc::vfs {

class XAttrHost final: public Host
{
public:
    XAttrHost( const std::string &_file_path, const VFSHostPtr& _host ); // _host must be native currently
    XAttrHost(const VFSHostPtr &_parent, const VFSConfiguration &_config);
    ~XAttrHost();

    static const char *UniqueTag;
    virtual VFSConfiguration Configuration() const override;
    static VFSMeta Meta();
    
    virtual bool IsWritable() const override;
    
    virtual int CreateFile(const char* _path,
                           std::shared_ptr<VFSFile> &_target,
                           const VFSCancelChecker &_cancel_checker) override;

    virtual int FetchDirectoryListing(const char *_path,
                                      std::shared_ptr<VFSListing> &_target,
                                      unsigned long _flags,
                                      const VFSCancelChecker &_cancel_checker) override;
    
    virtual int Stat(const char *_path, VFSStat &_st, unsigned long _flags, const VFSCancelChecker &_cancel_checker) override;
    
    virtual int Unlink(const char *_path, const VFSCancelChecker &_cancel_checker) override;
    virtual int Rename(const char *_old_path, const char *_new_path, const VFSCancelChecker &_cancel_checker) override;
        
    void    ReportChange(); // will cause host to reload xattrs list
    
private:
    int     Fetch();
    
    VFSConfiguration                m_Configuration;    
    int                             m_FD = -1;
    struct stat                     m_Stat;
    spinlock                        m_AttrsLock;
    std::vector< std::pair<std::string, unsigned>> m_Attrs;
};

}

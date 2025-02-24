// Copyright (C) 2016-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <sys/stat.h>
#include <VFS/Host.h>
#include <Base/spinlock.h>

namespace nc::vfs {

class XAttrHost final : public Host
{
public:
    XAttrHost(std::string_view _file_path, const VFSHostPtr &_host); // _host must be native currently
    XAttrHost(const VFSHostPtr &_parent, const VFSConfiguration &_config);
    ~XAttrHost();

    static const char *UniqueTag;

    VFSConfiguration Configuration() const override;

    static VFSMeta Meta();

    bool IsWritable() const override;

    std::expected<std::shared_ptr<VFSFile>, Error> CreateFile(std::string_view _path,
                                                              const VFSCancelChecker &_cancel_checker) override;

    std::expected<VFSListingPtr, Error> FetchDirectoryListing(std::string_view _path,
                                                              unsigned long _flags,
                                                              const VFSCancelChecker &_cancel_checker) override;

    std::expected<VFSStat, Error>
    Stat(std::string_view _path, unsigned long _flags, const VFSCancelChecker &_cancel_checker) override;

    std::expected<void, Error> Unlink(std::string_view _path, const VFSCancelChecker &_cancel_checker) override;

    std::expected<void, Error>
    Rename(std::string_view _old_path, std::string_view _new_path, const VFSCancelChecker &_cancel_checker) override;

    void ReportChange(); // will cause host to reload xattrs list

private:
    int Fetch();

    VFSConfiguration m_Configuration;
    int m_FD = -1;
    struct stat m_Stat;
    spinlock m_AttrsLock;
    std::vector<std::pair<std::string, unsigned>> m_Attrs;
};

} // namespace nc::vfs

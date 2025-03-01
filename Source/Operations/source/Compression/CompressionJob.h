// Copyright (C) 2017-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "../Job.h"
#include <VFS/VFS.h>
#include <Base/chained_strings.h>

struct archive;

namespace nc::ops {

struct CompressionJobCallbacks {
    std::function<void()> m_TargetPathDefined = [] {};

    enum class SourceScanErrorResolution {
        Stop,
        Skip,
        Retry
    };
    std::function<SourceScanErrorResolution(Error _err, const std::string &_path, VFSHost &_vfs)> m_SourceScanError =
        [](Error, const std::string &, VFSHost &) { return SourceScanErrorResolution::Stop; };

    enum class SourceAccessErrorResolution {
        Stop,
        Skip,
        Retry
    };
    std::function<SourceAccessErrorResolution(Error _err, const std::string &_path, VFSHost &_vfs)>
        m_SourceAccessError = [](Error, const std::string &, VFSHost &) { return SourceAccessErrorResolution::Stop; };

    enum class SourceReadErrorResolution {
        Stop,
        Skip
    };
    std::function<SourceReadErrorResolution(int _err, const std::string &_path, VFSHost &_vfs)> m_SourceReadError =
        [](int, const std::string &, VFSHost &) { return SourceReadErrorResolution::Stop; };

    std::function<void(Error _err, const std::string &_path, VFSHost &_vfs)> m_TargetWriteError =
        [](Error, const std::string &, VFSHost &) {};
};

class CompressionJob final : public Job, public CompressionJobCallbacks
{
public:
    CompressionJob(std::vector<VFSListingItem> _src_files,
                   std::string _dst_root,
                   VFSHostPtr _dst_vfs,
                   std::string _password);
    ~CompressionJob();

    const std::string &TargetArchivePath() const;

private:
    struct Source;
    enum class StepResult {
        Stopped,
        Done,
        Skipped
    };

    virtual void Perform() override;
    std::optional<Source> ScanItems();
    bool ScanItem(const VFSListingItem &_item, Source &_ctx);
    bool ScanItem(const std::string &_full_path,
                  const std::string &_filename,
                  unsigned _vfs_no,
                  unsigned _basepath_no,
                  const base::chained_strings::node *_prefix,
                  Source &_ctx);
    bool BuildArchive();
    void ProcessItems();
    void ProcessItem(const base::chained_strings::node &_node, int _index);
    StepResult ProcessDirectoryItem(int _index, const std::string &_relative_path, const std::string &_full_path);
    StepResult ProcessRegularItem(int _index, const std::string &_relative_path, const std::string &_full_path);
    StepResult ProcessSymlinkItem(int _index, const std::string &_relative_path, const std::string &_full_path);

    std::string FindSuitableFilename(const std::string &_proposed_arcname) const;
    bool IsEncrypted() const noexcept;

    static ssize_t WriteCallback(struct archive *_archive, void *_client_data, const void *_buffer, size_t _length);

    std::vector<VFSListingItem> m_InitialListingItems;
    std::string m_DstRoot;
    VFSHostPtr m_DstVFS;
    std::string m_TargetArchivePath;
    std::string m_Password;

    struct ::archive *m_Archive = nullptr;
    std::shared_ptr<VFSFile> m_TargetFile;

    std::unique_ptr<const Source> m_Source;
};

} // namespace nc::ops

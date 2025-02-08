// Copyright (C) 2017-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Base/algo.h>
#include <Base/SerialQueue.h>
#include <Base/DispatchGroup.h>
#include <Utility/NativeFSManager.h>
#include <VFS/VFS.h>
#include <VFS/Native.h>
#include "Options.h"
#include "../Job.h"
#include "SourceItems.h"
#include "ChecksumExpectation.h"
#include "CopyingJobCallbacks.h"

namespace nc::ops {

class CopyingJob : public Job, public CopyingJobCallbacks
{
public:
    CopyingJob(std::vector<VFSListingItem> _source_items,
               const std::string &_dest_path,
               const VFSHostPtr &_dest_host,
               CopyingOptions _opts);
    ~CopyingJob();

    enum class Stage {
        Default,
        Preparing,
        Process,
        Verify,
        Cleaning
    };

    enum Stage Stage() const noexcept;
    bool IsSingleInitialItemProcessing() const noexcept;
    bool IsSingleScannedItemProcessing() const noexcept;
    const std::vector<VFSListingItem> &SourceItems() const noexcept;
    const std::string &DestinationPath() const noexcept;
    const CopyingOptions &Options() const noexcept;

private:
    using ChecksumVerification = CopyingOptions::ChecksumVerification;

    enum class StepResult {
        // operation was successful
        Ok = 0,

        // user asked us to stop
        Stop,

        // an error has occured, but current step was skipped since user asked us to do so
        Skipped,
    };

    enum class PathCompositionType {
        PathPreffix, // path = dest_path + source_rel_path
        FixedPath    // path = dest_path
    };

    enum class SourceItemAftermath {
        NoChanges,
        Moved,
        NeedsToBeDeleted
    };

    using RequestNonexistentDst = std::function<void()>;

    struct PermissionFixup {
        std::filesystem::path path;
        mode_t mode = 0;
    };

    struct TimestampFixup {
        std::filesystem::path path;
        timespec atime = {0, 0};
        timespec mtime = {0, 0};
        timespec ctime = {0, 0};
        timespec btime = {0, 0};
    };

    void Perform() override;
    void ProcessItems();
    StepResult ProcessItemNo(int _item_number);
    StepResult ProcessSymlinkItem(VFSHost &_source_host,
                                  const std::string &_source_path,
                                  const std::string &_destination_path,
                                  const RequestNonexistentDst &_new_dst_callback);
    StepResult ProcessDirectoryItem(VFSHost &_source_host,
                                    const std::string &_source_path,
                                    int _source_index,
                                    const std::string &_destination_path);

    PathCompositionType AnalyzeInitialDestination(std::string &_result_destination, bool &_need_to_build);
    StepResult BuildDestinationDirectory() const;
    std::tuple<StepResult, copying::SourceItems> ScanSourceItems();
    std::string ComposeDestinationNameForItem(int _src_item_index) const;
    std::string ComposeDestinationNameForItemInDB(int _src_item_index, const copying::SourceItems &_db) const;

    // will be used for checksum calculation when copying verifiyng is enabled
    using SourceDataFeedback = std::function<void(const void *_data, unsigned _sz)>;

    StepResult CopyNativeFileToNativeFile(vfs::NativeHost &_native_host,
                                          const std::string &_src_path,
                                          const std::string &_dst_path,
                                          const SourceDataFeedback &_source_data_feedback,
                                          const RequestNonexistentDst &_new_dst_callback);
    StepResult CopyVFSFileToNativeFile(VFSHost &_src_vfs,
                                       const std::string &_src_path,
                                       vfs::NativeHost &_dst_host,
                                       const std::string &_dst_path,
                                       const SourceDataFeedback &_source_data_feedback,
                                       const RequestNonexistentDst &_new_dst_callback);
    StepResult CopyVFSFileToVFSFile(VFSHost &_src_vfs,
                                    const std::string &_src_path,
                                    const std::string &_dst_path,
                                    const SourceDataFeedback &_source_data_feedback,
                                    const RequestNonexistentDst &_new_dst_callback);

    StepResult CopyNativeDirectoryToNativeDirectory(vfs::NativeHost &_native_host,
                                                    const std::string &_src_path,
                                                    const std::string &_dst_path) const;
    StepResult CopyVFSDirectoryToNativeDirectory(VFSHost &_src_vfs,
                                                 const std::string &_src_path,
                                                 vfs::NativeHost &_dst_host,
                                                 const std::string &_dst_path) const;
    StepResult
    CopyVFSDirectoryToVFSDirectory(VFSHost &_src_vfs, const std::string &_src_path, const std::string &_dst_path) const;
    StepResult CopyNativeSymlinkToNative(vfs::NativeHost &_native_host,
                                         const std::string &_src_path,
                                         const std::string &_dst_path,
                                         const RequestNonexistentDst &_new_dst_callback) const;
    StepResult CopyVFSSymlinkToNative(VFSHost &_src_vfs,
                                      const std::string &_src_path,
                                      vfs::NativeHost &_dst_host,
                                      const std::string &_dst_path,
                                      const RequestNonexistentDst &_new_dst_callback) const;
    StepResult CopyVFSSymlinkToVFS(VFSHost &_src_vfs,
                                   const std::string &_src_path,
                                   const std::string &_dst_path,
                                   const RequestNonexistentDst &_new_dst_callback) const;

    StepResult RenameNativeFile(vfs::NativeHost &_native_host,
                                const std::string &_src_path,
                                const std::string &_dst_path,
                                const RequestNonexistentDst &_new_dst_callback) const;

    std::pair<StepResult, SourceItemAftermath> RenameNativeDirectory(vfs::NativeHost &_native_host,
                                                                     const std::string &_src_path,
                                                                     const std::string &_dst_path) const;

    std::pair<StepResult, SourceItemAftermath>
    RenameVFSDirectory(VFSHost &_common_host, const std::string &_src_path, const std::string &_dst_path) const;

    StepResult RenameVFSFile(VFSHost &_common_host,
                             const std::string &_src_path,
                             const std::string &_dst_path,
                             const RequestNonexistentDst &_new_dst_callback) const;
    StepResult VerifyCopiedFile(const copying::ChecksumExpectation &_exp, bool &_matched);
    void ClearSourceItems();
    void ClearSourceItem(const std::string &_path, mode_t _mode, VFSHost &_host);
    void ApplyPermissionFixups();
    void ApplyTimestampsFixups();

    void SetStage(enum Stage _stage);

    void EraseXattrsFromNativeFD(int _fd_in) const;
    void CopyXattrsFromNativeFDToNativeFD(int _fd_from, int _fd_to) const;
    void CopyXattrsFromVFSFileToNativeFD(VFSFile &_source, int _fd_to) const;
    void CopyXattrsFromVFSFileToPath(VFSFile &_file, const char *_fn_to) const;

    static bool IsNativeLockedItemNoFollow(const Error &_error, const std::string &_path);
    StepResult UnlockNativeItemNoFollow(const std::string &_path, vfs::NativeHost &_native_host) const;

    StepResult OnCantOpenDestinationFile(int _vfs_error, const std::string &_path, VFSHost &_vfs);

    const std::vector<VFSListingItem> m_VFSListingItems;
    copying::SourceItems m_SourceItems;
    int m_CurrentlyProcessingSourceItemIndex = -1;
    std::vector<copying::ChecksumExpectation> m_Checksums;
    std::vector<unsigned> m_SourceItemsToDelete;
    mutable std::vector<PermissionFixup> m_TargetPermissionsFixupEpilogue;
    mutable std::vector<TimestampFixup> m_TargetTimestampFixupEpilogue;
    const VFSHostPtr m_DestinationHost;
    const bool m_IsDestinationHostNative;
    std::shared_ptr<const utility::NativeFileSystemInfo> m_DestinationNativeFSInfo; // used only for native vfs
    const std::string m_InitialDestinationPath; // must be an absolute path, used solely in AnalizeDestination()
    std::string m_DestinationPath;
    PathCompositionType m_PathCompositionType;
    nc::utility::NativeFSManager *const m_NativeFSManager;

    // buffers are allocated once in job init and are used to manupulate files' bytes.
    // thus no parallel routines should run using these buffers
    static const int m_BufferSize = 2 * 1024 * 1024;
    const std::unique_ptr<uint8_t[]> m_Buffers[2] = {std::make_unique<uint8_t[]>(m_BufferSize),
                                                     std::make_unique<uint8_t[]>(m_BufferSize)};

    const base::DispatchGroup m_IOGroup;
    bool m_IsSingleInitialItemProcessing = false;
    bool m_IsSingleScannedItemProcessing = false;
    bool m_IsSingleDirectoryCaseRenaming = false;
    enum Stage m_Stage = Stage::Default;

    CopyingOptions m_Options;
};

} // namespace nc::ops

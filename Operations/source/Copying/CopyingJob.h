// Copyright (C) 2017-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Habanero/algo.h>
#include <Habanero/SerialQueue.h>
#include <Habanero/DispatchGroup.h>
#include <Utility/NativeFSManager.h>
#include <VFS/VFS.h>
#include "Options.h"
#include "../Job.h"
#include "SourceItems.h"
#include "ChecksumExpectation.h"

namespace nc::ops {

struct CopyingJobCallbacks
{
    enum class CantAccessSourceItemResolution { Stop, Skip, Retry };
    std::function<CantAccessSourceItemResolution(int _vfs_error,
                                                 const std::string &_path,
                                                 VFSHost &_vfs)>
    m_OnCantAccessSourceItem
    = [](int, const std::string &, VFSHost &)    
    { return CantAccessSourceItemResolution::Stop; };

    enum class CopyDestExistsResolution { Stop, Skip, Overwrite, OverwriteOld, Append, KeepBoth };
    std::function<CopyDestExistsResolution(const struct stat &_src,
                                           const struct stat &_dst,
                                           const std::string &_path)>
    m_OnCopyDestinationAlreadyExists
    = [](const struct stat &, const struct stat &, const std::string &)
    { return CopyDestExistsResolution::Stop; };
    
    enum class RenameDestExistsResolution { Stop, Skip, Overwrite, OverwriteOld, KeepBoth };
    std::function<RenameDestExistsResolution(const struct stat &_src,
                                             const struct stat &_dst,
                                             const std::string &_path)>
    m_OnRenameDestinationAlreadyExists
    = [](const struct stat &, const struct stat &, const std::string &)
    { return RenameDestExistsResolution::Stop; };
    
    enum class CantOpenDestinationFileResolution { Stop, Skip, Retry };
    std::function<CantOpenDestinationFileResolution(int _vfs_error,
                                                    const std::string &_path,
                                                    VFSHost &_vfs)>
    m_OnCantOpenDestinationFile
    = [](int, const std::string &, VFSHost &)
    { return CantOpenDestinationFileResolution::Stop; };
    
    enum class SourceFileReadErrorResolution { Stop, Skip, Retry };
    std::function<SourceFileReadErrorResolution(int _vfs_error,
                                                const std::string &_path,
                                                VFSHost &_vfs)>
    m_OnSourceFileReadError
    = [](int, const std::string &, VFSHost &)
    { return SourceFileReadErrorResolution::Stop; };

    enum class DestinationFileReadErrorResolution { Stop, Skip };
    std::function<DestinationFileReadErrorResolution(int _vfs_error,
                                                     const std::string &_path,
                                                     VFSHost &_vfs)>
    m_OnDestinationFileReadError
    = [](int, const std::string &, VFSHost &)
    { return DestinationFileReadErrorResolution::Stop; };
    
    enum class DestinationFileWriteErrorResolution { Stop, Skip, Retry };
    std::function<DestinationFileWriteErrorResolution(int _vfs_error,
                                                      const std::string &_path,
                                                      VFSHost &_vfs)>
    m_OnDestinationFileWriteError
    = [](int, const std::string &, VFSHost &)
    { return DestinationFileWriteErrorResolution::Stop; };

    enum class CantCreateDestinationRootDirResolution { Stop, Retry };
    std::function<CantCreateDestinationRootDirResolution(int _vfs_error,
                                                         const std::string &_path,
                                                         VFSHost &_vfs)>
    m_OnCantCreateDestinationRootDir
    = [](int, const std::string &, VFSHost &)
    { return CantCreateDestinationRootDirResolution::Stop; };

    enum class CantCreateDestinationDirResolution { Stop, Skip, Retry };
    std::function<CantCreateDestinationDirResolution(int _vfs_error,
                                                     const std::string &_path,
                                                     VFSHost &_vfs)>
    m_OnCantCreateDestinationDir
    = [](int, const std::string &, VFSHost &)
    { return CantCreateDestinationDirResolution::Stop; };
    
    enum class CantDeleteDestinationFileResolution { Stop, Skip, Retry };
    std::function<CantDeleteDestinationFileResolution(int _vfs_error,
                                                      const std::string &_path,
                                                      VFSHost &_vfs)>
    m_OnCantDeleteDestinationFile
    = [](int, const std::string &, VFSHost &)
    { return CantDeleteDestinationFileResolution::Stop; };

    enum class CantDeleteSourceFileResolution { Stop, Skip, Retry };
    std::function<CantDeleteSourceFileResolution(int _vfs_error,
                                                 const std::string &_path,
                                                 VFSHost &_vfs)>
    m_OnCantDeleteSourceItem
    = [](int, const std::string &, VFSHost &)
    { return CantDeleteSourceFileResolution::Stop; };

    enum class NotADirectoryResolution { Stop, Skip, Overwrite };
    std::function<NotADirectoryResolution(const std::string &_path,
                                          VFSHost &_vfs)>
    m_OnNotADirectory
    = [](const std::string &, VFSHost &)
    { return NotADirectoryResolution::Stop; };
    
    std::function<void(const std::string &_path, VFSHost &_vfs)>
    m_OnFileVerificationFailed
    = [](const std::string &, VFSHost &)
    {};

    std::function<void()>
    m_OnStageChanged
    = []()
    {};
};

class CopyingJob : public Job, public CopyingJobCallbacks
{
public:
    CopyingJob(std::vector<VFSListingItem> _source_items,
               const std::string &_dest_path,
               const VFSHostPtr &_dest_host,
               CopyingOptions _opts
               );
    ~CopyingJob();
    
    enum class Stage
    {
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
    virtual void Perform() override;
    
    using ChecksumVerification = CopyingOptions::ChecksumVerification;
    
    enum class StepResult
    {
        // operation was successful
        Ok = 0,
        
        // user asked us to stop
        Stop,
        
        // an error has occured, but current step was skipped since user asked us to do so
        Skipped,
    };
    
    enum class PathCompositionType
    {
        PathPreffix, // path = dest_path + source_rel_path
        FixedPath    // path = dest_path
    };
    
    enum class SourceItemAftermath
    {
        NoChanges,
        Moved,
        NeedsToBeDeleted
    };
    
    using RequestNonexistentDst = std::function<void()>;    
    
    void        ProcessItems();
    StepResult  ProcessItemNo(int _item_number);
    StepResult  ProcessSymlinkItem(VFSHost& _source_host,
                                   const std::string &_source_path,
                                   const std::string &_destination_path,
                                   const RequestNonexistentDst &_new_dst_callback);
    StepResult  ProcessDirectoryItem(VFSHost& _source_host,
                                     const std::string &_source_path,
                                     int _source_index,
                                     const std::string &_destination_path);
    
    PathCompositionType     AnalyzeInitialDestination(std::string &_result_destination,
                                                      bool &_need_to_build);
    StepResult              BuildDestinationDirectory() const;
    std::tuple<StepResult, copying::SourceItems> ScanSourceItems();
    std::string ComposeDestinationNameForItem( int _src_item_index ) const;
    std::string ComposeDestinationNameForItemInDB(int _src_item_index,
                                             const copying::SourceItems &_db ) const;
    
    // will be used for checksum calculation when copying verifiyng is enabled
    using SourceDataFeedback = std::function<void(const void *_data, unsigned _sz)>;
     
    StepResult CopyNativeFileToNativeFile(const std::string& _src_path,
                                          const std::string& _dst_path,
                                          const SourceDataFeedback &_source_data_feedback,
                                          const RequestNonexistentDst &_new_dst_callback);
    StepResult CopyVFSFileToNativeFile(VFSHost &_src_vfs,
                                       const std::string& _src_path,
                                       const std::string& _dst_path,
                                       const SourceDataFeedback &_source_data_feedback,
                                       const RequestNonexistentDst &_new_dst_callback);
    StepResult CopyVFSFileToVFSFile(VFSHost &_src_vfs,
                                    const std::string& _src_path,
                                    const std::string& _dst_path,
                                    const SourceDataFeedback &_source_data_feedback,
                                    const RequestNonexistentDst &_new_dst_callback);

    StepResult CopyNativeDirectoryToNativeDirectory(const std::string& _src_path,
                                                    const std::string& _dst_path) const;
    StepResult CopyVFSDirectoryToNativeDirectory(VFSHost &_src_vfs,
                                                 const std::string& _src_path,
                                                 const std::string& _dst_path) const;
    StepResult CopyVFSDirectoryToVFSDirectory(VFSHost &_src_vfs,
                                              const std::string& _src_path,
                                              const std::string& _dst_path) const;
    StepResult CopyNativeSymlinkToNative(const std::string& _src_path,
                                         const std::string& _dst_path,
                                         const RequestNonexistentDst &_new_dst_callback) const;
    StepResult CopyVFSSymlinkToNative(VFSHost &_src_vfs,
                                      const std::string& _src_path,
                                      const std::string& _dst_path,
                                      const RequestNonexistentDst &_new_dst_callback) const;
    StepResult CopyVFSSymlinkToVFS(VFSHost &_src_vfs,
                                   const std::string& _src_path,
                                   const std::string& _dst_path,
                                   const RequestNonexistentDst &_new_dst_callback) const;
    
    StepResult RenameNativeFile(const std::string& _src_path,
                                const std::string& _dst_path,
                                const RequestNonexistentDst &_new_dst_callback) const;

    std::pair<StepResult, SourceItemAftermath>
    RenameNativeDirectory(const std::string& _src_path,
                          const std::string& _dst_path) const;

    std::pair<StepResult, SourceItemAftermath>
    RenameVFSDirectory(VFSHost &_common_host,
                       const std::string& _src_path,
                       const std::string& _dst_path) const;
    
    StepResult RenameVFSFile(VFSHost &_common_host,
                             const std::string& _src_path,
                             const std::string& _dst_path,
                             const RequestNonexistentDst &_new_dst_callback) const;
    StepResult VerifyCopiedFile(const copying::ChecksumExpectation& _exp, bool &_matched);
    void        ClearSourceItems();
    void        ClearSourceItem( const std::string &_path, mode_t _mode, VFSHost &_host );
    void        SetStage(enum Stage _stage);
    
    
    void                    EraseXattrsFromNativeFD(int _fd_in) const;
    void                    CopyXattrsFromNativeFDToNativeFD(int _fd_from, int _fd_to) const;
    void                    CopyXattrsFromVFSFileToNativeFD(VFSFile& _source, int _fd_to) const;
    void                    CopyXattrsFromVFSFileToPath(VFSFile& _file, const char *_fn_to) const;
    
    const std::vector<VFSListingItem>           m_VFSListingItems;
    copying::SourceItems                        m_SourceItems;
    int                                         m_CurrentlyProcessingSourceItemIndex = -1;
    std::vector<copying::ChecksumExpectation>   m_Checksums;
    std::vector<unsigned>                       m_SourceItemsToDelete;
    const VFSHostPtr                            m_DestinationHost;
    const bool                                  m_IsDestinationHostNative;
    std::shared_ptr<const utility::NativeFileSystemInfo>m_DestinationNativeFSInfo; // used only for native vfs
    const std::string                           m_InitialDestinationPath; // must be an absolute path, used solely in AnalizeDestination()
    std::string                                 m_DestinationPath;
    PathCompositionType                         m_PathCompositionType;
    class nc::utility::NativeFSManager         &m_NativeFSManager;
    
    // buffers are allocated once in job init and are used to manupulate files' bytes.
    // thus no parallel routines should run using these buffers
    static const int                            m_BufferSize    = 2*1024*1024;
    const std::unique_ptr<uint8_t[]>            m_Buffers[2]    =
        { std::make_unique<uint8_t[]>(m_BufferSize), std::make_unique<uint8_t[]>(m_BufferSize) };
    
    const DispatchGroup                         m_IOGroup;
    bool                                        m_IsSingleInitialItemProcessing = false;
    bool                                        m_IsSingleScannedItemProcessing = false;
    bool                                        m_IsSingleDirectoryCaseRenaming = false;
    enum Stage                                  m_Stage = Stage::Default;
    
    CopyingOptions                              m_Options;
};

}

// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
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
    function<CantAccessSourceItemResolution(int _vfs_error, const string &_path, VFSHost &_vfs)>
    m_OnCantAccessSourceItem
    = [](int _vfs_error, const string &_path, VFSHost &_vfs)
    { return CantAccessSourceItemResolution::Stop; };

    enum class CopyDestExistsResolution { Stop, Skip, Overwrite, OverwriteOld, Append };
    function<CopyDestExistsResolution(const struct stat &_src, const struct stat &_dst, const string &_path)>
    m_OnCopyDestinationAlreadyExists
    = [](const struct stat &_src, const struct stat &_dst, const string &_path)
    { return CopyDestExistsResolution::Stop; };
    
    enum class RenameDestExistsResolution { Stop, Skip, Overwrite, OverwriteOld };
    function<RenameDestExistsResolution(const struct stat &_src, const struct stat &_dst, const string &_path)>
    m_OnRenameDestinationAlreadyExists
    = [](const struct stat &_src_stat, const struct stat &_dst_stat, const string &_path)
    { return RenameDestExistsResolution::Stop; };
    
    enum class CantOpenDestinationFileResolution { Stop, Skip, Retry };
    function<CantOpenDestinationFileResolution(int _vfs_error, const string &_path, VFSHost &_vfs)>
    m_OnCantOpenDestinationFile
    = [](int _vfs_error, const string &_path, VFSHost &_vfs)
    { return CantOpenDestinationFileResolution::Stop; };
    
    enum class SourceFileReadErrorResolution { Stop, Skip, Retry };
    function<SourceFileReadErrorResolution(int _vfs_error, const string &_path, VFSHost &_vfs)>
    m_OnSourceFileReadError
    = [](int _vfs_error, const string &_path, VFSHost &_vfs)
    { return SourceFileReadErrorResolution::Stop; };

    enum class DestinationFileReadErrorResolution { Stop, Skip };
    function<DestinationFileReadErrorResolution(int _vfs_error, const string &_path, VFSHost &_vfs)>
    m_OnDestinationFileReadError
    = [](int _vfs_error, const string &_path, VFSHost &_vfs)
    { return DestinationFileReadErrorResolution::Stop; };
    
    enum class DestinationFileWriteErrorResolution { Stop, Skip, Retry };
    function<DestinationFileWriteErrorResolution(int _vfs_error, const string &_path, VFSHost &_vfs)>
    m_OnDestinationFileWriteError
    = [](int _vfs_error, const string &_path, VFSHost &_vfs)
    { return DestinationFileWriteErrorResolution::Stop; };

    enum class CantCreateDestinationRootDirResolution { Stop, Retry };
    function<CantCreateDestinationRootDirResolution(int _vfs_error, const string &_path, VFSHost &_vfs)>
    m_OnCantCreateDestinationRootDir
    = [](int _vfs_error, const string &_path, VFSHost &_vfs)
    { return CantCreateDestinationRootDirResolution::Stop; };

    enum class CantCreateDestinationDirResolution { Stop, Skip, Retry };
    function<CantCreateDestinationDirResolution(int _vfs_error, const string &_path, VFSHost &_vfs)>
    m_OnCantCreateDestinationDir
    = [](int _vfs_error, const string &_path, VFSHost &_vfs)
    { return CantCreateDestinationDirResolution::Stop; };
    
    enum class CantDeleteDestinationFileResolution { Stop, Skip, Retry };
    function<CantDeleteDestinationFileResolution(int _vfs_error, const string &_path, VFSHost &_vfs)>
    m_OnCantDeleteDestinationFile
    = [](int _vfs_error, const string &_path, VFSHost &_vfs)
    { return CantDeleteDestinationFileResolution::Stop; };

    enum class CantDeleteSourceFileResolution { Stop, Skip, Retry };
    function<CantDeleteSourceFileResolution(int _vfs_error, const string &_path, VFSHost &_vfs)>
    m_OnCantDeleteSourceItem
    = [](int _vfs_error, const string &_path, VFSHost &_vfs)
    { return CantDeleteSourceFileResolution::Stop; };

    enum class NotADirectoryResolution { Stop, Skip, Overwrite };
    function<NotADirectoryResolution(const string &_path, VFSHost &_vfs)>
    m_OnNotADirectory
    = [](const string &_path, VFSHost &_vfs)
    { return NotADirectoryResolution::Stop; };
    
    function<void(const string &_path, VFSHost &_vfs)>
    m_OnFileVerificationFailed
    = [](const string &_path, VFSHost &_vfs)
    {};

    function<void()>
    m_OnStageChanged
    = []()
    {};
};

class CopyingJob : public Job, public CopyingJobCallbacks
{
public:
    CopyingJob(vector<VFSListingItem> _source_items,
               const string &_dest_path,
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
    const vector<VFSListingItem> &SourceItems() const noexcept;
    const string &DestinationPath() const noexcept;
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
    
    void        ProcessItems();
    StepResult  ProcessSymlinkItem(VFSHost& _source_host,
                                   const string &_source_path,
                                   const string &_destination_path);
    StepResult  ProcessDirectoryItem(VFSHost& _source_host,
                                     const string &_source_path,
                                     int _source_index,
                                     const string &_destination_path);
    
    PathCompositionType     AnalyzeInitialDestination(string &_result_destination, bool &_need_to_build);
    StepResult              BuildDestinationDirectory() const;
    tuple<StepResult, copying::SourceItems> ScanSourceItems();
    string ComposeDestinationNameForItem( int _src_item_index ) const;
    string ComposeDestinationNameForItemInDB(int _src_item_index,
                                             const copying::SourceItems &_db ) const;
    
    // + stats callback
    StepResult CopyNativeFileToNativeFile(const string& _src_path,
                                          const string& _dst_path,
                                          function<void(const void *_data, unsigned _sz)> _source_data_feedback // will be used for checksum calculation for copying verifiyng
                                          );
    StepResult CopyVFSFileToNativeFile(VFSHost &_src_vfs,
                                       const string& _src_path,
                                       const string& _dst_path,
                                       function<void(const void *_data, unsigned _sz)> _source_data_feedback // will be used for checksum calculation for copying verifiyng
                                        );
    StepResult CopyVFSFileToVFSFile(VFSHost &_src_vfs,
                                    const string& _src_path,
                                    const string& _dst_path,
                                    function<void(const void *_data, unsigned _sz)> _source_data_feedback // will be used for checksum calculation for copying verifiyng
                                    );

    StepResult CopyNativeDirectoryToNativeDirectory(const string& _src_path,
                                                    const string& _dst_path) const;
    StepResult CopyVFSDirectoryToNativeDirectory(VFSHost &_src_vfs,
                                                 const string& _src_path,
                                                 const string& _dst_path) const;
    StepResult CopyVFSDirectoryToVFSDirectory(VFSHost &_src_vfs,
                                              const string& _src_path,
                                              const string& _dst_path) const;
    StepResult CopyNativeSymlinkToNative(const string& _src_path,
                                 const string& _dst_path) const;
    StepResult CopyVFSSymlinkToNative(VFSHost &_src_vfs,
                                      const string& _src_path,
                                      const string& _dst_path) const;
    StepResult CopyVFSSymlinkToVFS(VFSHost &_src_vfs,
                                   const string& _src_path,
                                   const string& _dst_path) const;
    StepResult RenameNativeSymlinkToNative(const string& _src_path,
                                           const string& _dst_path) const;
    
    StepResult RenameNativeFile(const string& _src_path,
                                const string& _dst_path) const;

    pair<StepResult, SourceItemAftermath> RenameNativeDirectory(const string& _src_path,
                                                                const string& _dst_path) const;

    pair<StepResult, SourceItemAftermath> RenameVFSDirectory(VFSHost &_common_host,
                                                             const string& _src_path,
                                                             const string& _dst_path) const;
    
    StepResult RenameVFSFile(VFSHost &_common_host,
                             const string& _src_path,
                             const string& _dst_path) const;
    StepResult VerifyCopiedFile(const copying::ChecksumExpectation& _exp, bool &_matched);
    void        ClearSourceItems();
    void        ClearSourceItem( const string &_path, mode_t _mode, VFSHost &_host );
    void        SetStage(enum Stage _stage);
    
    
    void                    EraseXattrsFromNativeFD(int _fd_in) const;
    void                    CopyXattrsFromNativeFDToNativeFD(int _fd_from, int _fd_to) const;
    void                    CopyXattrsFromVFSFileToNativeFD(VFSFile& _source, int _fd_to) const;
    void                    CopyXattrsFromVFSFileToPath(VFSFile& _file, const char *_fn_to) const;
    
    const vector<VFSListingItem>                m_VFSListingItems;
    copying::SourceItems                        m_SourceItems;
    int                                         m_CurrentlyProcessingSourceItemIndex = -1;
    vector<copying::ChecksumExpectation>        m_Checksums;
    vector<unsigned>                            m_SourceItemsToDelete;
    const VFSHostPtr                            m_DestinationHost;
    const bool                                  m_IsDestinationHostNative;
    shared_ptr<const NativeFileSystemInfo>      m_DestinationNativeFSInfo; // used only for native vfs
    const string                                m_InitialDestinationPath; // must be an absolute path, used solely in AnalizeDestination()
    string                                      m_DestinationPath;
    PathCompositionType                         m_PathCompositionType;
    class NativeFSManager                      &m_NativeFSManager;
    
    // buffers are allocated once in job init and are used to manupulate files' bytes.
    // thus no parallel routines should run using these buffers
    static const int                            m_BufferSize    = 2*1024*1024;
    const unique_ptr<uint8_t[]>                 m_Buffers[2]    = { make_unique<uint8_t[]>(m_BufferSize), make_unique<uint8_t[]>(m_BufferSize) };
    
    const DispatchGroup                         m_IOGroup;
    bool                                        m_IsSingleInitialItemProcessing = false;
    bool                                        m_IsSingleScannedItemProcessing = false;
    bool                                        m_IsSingleDirectoryCaseRenaming = false;
    enum Stage                                  m_Stage = Stage::Default;
    
    CopyingOptions                              m_Options;
};

}

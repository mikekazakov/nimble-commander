#pragma once

#include <Habanero/algo.h>
#include <Habanero/SerialQueue.h>
#include <Habanero/DispatchGroup.h>
#include <Utility/NativeFSManager.h>
#include <VFS/VFS.h>
#include "Options.h"
#include "DialogResults.h"
#include "../Job.h"
#include "SourceItems.h"

namespace nc::ops {

struct CopyingJobCallbacks
{
    enum class CantAccessSourceItemResolution { Stop, Skip };
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
    
    enum class CantOpenDestinationFileResolution { Stop, Skip };
    function<CantOpenDestinationFileResolution(int _vfs_error, const string &_path, VFSHost &_vfs)>
    m_OnCantOpenDestinationFile
    = [](int _vfs_error, const string &_path, VFSHost &_vfs)
    { return CantOpenDestinationFileResolution::Stop; };
    
    // expect: FileCopyOperationDR::Retry, FileCopyOperationDR::Skip, FileCopyOperationDR::SkipAll, FileCopyOperationDR::Stop
    function<int(int _vfs_error, string _path)> m_OnSourceFileReadError
        = [](int _vfs_error, string _path){ return FileCopyOperationDR::Stop; };

    // expect: FileCopyOperationDR::Retry, FileCopyOperationDR::Skip, FileCopyOperationDR::SkipAll, FileCopyOperationDR::Stop
    function<int(int _vfs_error, string _path)> m_OnDestinationFileReadError
        = [](int _vfs_error, string _path){ return FileCopyOperationDR::Stop; };
    
    // expect: FileCopyOperationDR::Retry, FileCopyOperationDR::Skip, FileCopyOperationDR::SkipAll, FileCopyOperationDR::Stop
    function<int(int _vfs_error, string _path)> m_OnDestinationFileWriteError
        = [](int _vfs_error, string _path){ return FileCopyOperationDR::Stop; };

    // expect: FileCopyOperationDR::Retry, FileCopyOperationDR::Stop
    function<int(int _vfs_error, string _path)> m_OnCantCreateDestinationRootDir
        = [](int _vfs_error, string _path){ return FileCopyOperationDR::Stop; };

    // expect: FileCopyOperationDR::Retry, FileCopyOperationDR::Skip, FileCopyOperationDR::SkipAll, FileCopyOperationDR::Stop
    function<int(int _vfs_error, string _path)> m_OnCantCreateDestinationDir
        = [](int _vfs_error, string _path){ return FileCopyOperationDR::Stop; };
    
    // expects: FileCopyOperationDR::Continue
    function<int(string _path)> m_OnFileVerificationFailed
        = [](string _path){ return FileCopyOperationDR::Continue; };
};

class CopyingJob : public Job, public CopyingJobCallbacks
{
public:
    CopyingJob(vector<VFSListingItem> _source_items,
               const string &_dest_path,
               const VFSHostPtr &_dest_host,
               FileCopyOperationOptions _opts
               );
    ~CopyingJob();
    
//    enum class Notify
//    {
//        Stage
//    };
    
    enum class JobStage
    {
        None,
        Preparing,
        Process,
        Verify,
        Cleaning
    };
    

    
    JobStage Stage() const noexcept;
    bool IsSingleInitialItemProcessing() const noexcept;
    bool IsSingleScannedItemProcessing() const noexcept;
//    void ToggleSkipAll();
    void ToggleExistBehaviorSkipAll();
    void ToggleExistBehaviorOverwriteAll();
    void ToggleExistBehaviorOverwriteOld();
    void ToggleExistBehaviorAppendAll();
    
private:
    virtual void Perform() override;
    
    using ChecksumVerification = FileCopyOperationOptions::ChecksumVerification;
    
    enum class StepResult
    {
        // operation was successful
        Ok = 0,
        
        // user asked us to stop
        Stop,
        
        // an error has occured, but current step was skipped since user asked us to do so or if SkipAll flag is on
        Skipped,
        
        // an error has occured, but current step was skipped since user asked us to do so and to skip any other errors
        SkipAll
    };
    
    enum class PathCompositionType
    {
        PathPreffix, // path = dest_path + source_rel_path
        FixedPath    // path = dest_path
    };
    
    struct ChecksumExpectation
    {
        ChecksumExpectation( int _source_ind, string _destination, const vector<uint8_t> &_md5 );
        string destination_path;
        int original_item;        
        struct {
            uint8_t buf[16];
        } md5;
    };
    

    void                    ProcessItems();
    
    PathCompositionType     AnalyzeInitialDestination(string &_result_destination, bool &_need_to_build) const;
    StepResult              BuildDestinationDirectory() const;
    tuple<StepResult, copying::SourceItems> ScanSourceItems();
    string                  ComposeDestinationNameForItem( int _src_item_index ) const;
    
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
    
    StepResult RenameNativeFile(const string& _src_path,
                                const string& _dst_path) const;
    StepResult RenameVFSFile(VFSHost &_common_host,
                             const string& _src_path,
                             const string& _dst_path) const;
    StepResult VerifyCopiedFile(const ChecksumExpectation& _exp, bool &_matched);
    void        CleanSourceItems() const;
    void        SetState(JobStage _state);
    
    
    void                    EraseXattrsFromNativeFD(int _fd_in) const;
    void                    CopyXattrsFromNativeFDToNativeFD(int _fd_from, int _fd_to) const;
    void                    CopyXattrsFromVFSFileToNativeFD(VFSFile& _source, int _fd_to) const;
    void                    CopyXattrsFromVFSFileToPath(VFSFile& _file, const char *_fn_to) const;
    
    vector<VFSListingItem>                      m_VFSListingItems;
    copying::SourceItems                        m_SourceItems;
    vector<ChecksumExpectation>                 m_Checksums;
    vector<unsigned>                            m_SourceItemsToDelete;
    VFSHostPtr                                  m_DestinationHost;
    shared_ptr<const NativeFileSystemInfo>      m_DestinationNativeFSInfo; // used only for native vfs
    string                                      m_InitialDestinationPath; // must be an absolute path, used solely in AnalizeDestination()
    string                                      m_DestinationPath;
    PathCompositionType                         m_PathCompositionType;
    
    // buffers are allocated once in job init and are used to manupulate files' bytes.
    // thus no parallel routines should run using these buffers
    static const int                            m_BufferSize    = 2*1024*1024;
    const unique_ptr<uint8_t[]>                 m_Buffers[2]    = { make_unique<uint8_t[]>(m_BufferSize), make_unique<uint8_t[]>(m_BufferSize) };
    
    const DispatchGroup                         m_IOGroup;
    bool                                        m_IsSingleInitialItemProcessing = false;
    bool                                        m_IsSingleScannedItemProcessing = false;
//    bool                                        m_SkipAll       = false;
    JobStage                                    m_Stage         = JobStage::None;
    
    FileCopyOperationOptions                    m_Options;
};

}

//
//  FileCopyOperationNew.hpp
//  Files
//
//  Created by Michael G. Kazakov on 25/09/15.
//  Copyright © 2015 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include <Habanero/algo.h>
#include <Habanero/SerialQueue.h>
#include <Habanero/DispatchGroup.h>
#include <Utility/NativeFSManager.h>
#include <VFS/VFS.h>
#include <NimbleCommander/Operations/OperationJob.h>
#include <NimbleCommander/Operations/OperationDialogProtocol.h>
#include "Options.h"
#include "DialogResults.h"

class FileCopyOperationJob : public OperationJob
{
public:
    
    enum class Notify
    {
        Stage
    };
    
    enum class JobStage
    {
        None,
        Preparing,
        Process,
        Verify,
        Cleaning
    };
    
    void Init(vector<VFSListingItem> _source_items,
              const string &_dest_path,
              const VFSHostPtr &_dest_host,
              FileCopyOperationOptions _opts
              );
    
    JobStage Stage() const noexcept;
    bool IsSingleInitialItemProcessing() const noexcept;
    bool IsSingleScannedItemProcessing() const noexcept;
    void ToggleSkipAll();
    void ToggleExistBehaviorSkipAll();
    void ToggleExistBehaviorOverwriteAll();
    void ToggleExistBehaviorOverwriteOld();
    void ToggleExistBehaviorAppendAll();
    
private:
    virtual void Do() override;
    
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
    
    class SourceItems
    {
    public:
        int             InsertItem( uint16_t _host_index, unsigned _base_dir_index, int _parent_index, string _item_name, const VFSStat &_stat );

        uint64_t        TotalRegBytes() const noexcept;
        int             ItemsAmount() const noexcept;
        
        string          ComposeFullPath( int _item_no ) const;
        string          ComposeRelativePath( int _item_no ) const;
        const string&   ItemName( int _item_no ) const;
        mode_t          ItemMode( int _item_no ) const;
        uint64_t        ItemSize( int _item_no ) const;
        dev_t           ItemDev( int _item_no ) const; // meaningful only for native vfs (yet?)
        VFSHost        &ItemHost( int _item_no ) const;
        
        VFSHost &Host( uint16_t _host_ind ) const;
        uint16_t InsertOrFindHost( const VFSHostPtr &_host );

        const string &BaseDir( unsigned _base_dir_ind ) const;
        unsigned InsertOrFindBaseDir( const string &_dir );

        
    private:
        struct SourceItem
        {
            // full path = m_SourceItemsBaseDirectories[base_dir_index] + ... + m_Items[m_Items[parent_index].parent_index].item_name +  m_Items[parent_index].item_name + item_name;
            string      item_name;
            uint64_t    item_size;
            int         parent_index;
            unsigned    base_dir_index;
            uint16_t    host_index;
            uint16_t    mode;
            dev_t       dev_num;
        };
        
        vector<SourceItem>                      m_Items;
        vector<VFSHostPtr>                      m_SourceItemsHosts;
        vector<string>                          m_SourceItemsBaseDirectories;
        uint64_t                                m_TotalRegBytes = 0;
    };
    
    void                    ProcessItems();
    
    PathCompositionType     AnalyzeInitialDestination(string &_result_destination, bool &_need_to_build) const;
    StepResult              BuildDestinationDirectory() const;
    tuple<StepResult, SourceItems> ScanSourceItems() const;
    string                  ComposeDestinationNameForItem( int _src_item_index ) const;
    
    // + stats callback
    StepResult CopyNativeFileToNativeFile(const string& _src_path,
                                          const string& _dst_path,
                                          function<void(const void *_data, unsigned _sz)> _source_data_feedback // will be used for checksum calculation for copying verifiyng
                                          ) const;
    StepResult CopyVFSFileToNativeFile(VFSHost &_src_vfs,
                                       const string& _src_path,
                                       const string& _dst_path,
                                       function<void(const void *_data, unsigned _sz)> _source_data_feedback // will be used for checksum calculation for copying verifiyng
                                        ) const;
    StepResult CopyVFSFileToVFSFile(VFSHost &_src_vfs,
                                    const string& _src_path,
                                    const string& _dst_path,
                                    function<void(const void *_data, unsigned _sz)> _source_data_feedback // will be used for checksum calculation for copying verifiyng
                                    ) const;

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
    StepResult VerifyCopiedFile(const ChecksumExpectation& _exp, bool &_matched) const;
    void        CleanSourceItems() const;
    void        SetState(JobStage _state);
    
    
    void                    EraseXattrsFromNativeFD(int _fd_in) const;
    void                    CopyXattrsFromNativeFDToNativeFD(int _fd_from, int _fd_to) const;
    void                    CopyXattrsFromVFSFileToNativeFD(VFSFile& _source, int _fd_to) const;
    void                    CopyXattrsFromVFSFileToPath(VFSFile& _file, const char *_fn_to) const;
    
    vector<VFSListingItem>              m_VFSListingItems;
    SourceItems                                 m_SourceItems;
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
    bool                                        m_SkipAll       = false;
    JobStage                                    m_Stage         = JobStage::None;
    
    FileCopyOperationOptions                    m_Options;
    
public: // yep, ITS VERY BAD to open access to object members, but adding trivial setters makes no sense here
    
    function<int(int _vfs_error, string _path)> m_OnCantAccessSourceItem
        = [](...){ return OperationDialogResult::Stop; };

    // expect: FileCopyOperationDR::Skip, FileCopyOperationDR::Stop, FileCopyOperationDR::Overwrite, FileCopyOperationDR::OverwriteOld, FileCopyOperationDR::Append
    function<int(const struct stat &_src_stat, const struct stat &_dst_stat, string _path)> m_OnCopyDestinationAlreadyExists
        = [](...) { return FileCopyOperationDR::Stop; };
    
    // expects: FileCopyOperationDR::Skip, FileCopyOperationDR::Stop, FileCopyOperationDR::Overwrite, FileCopyOperationDR::OverwriteOld
    function<int(const struct stat &_src_stat, const struct stat &_dst_stat, string _path)> m_OnRenameDestinationAlreadyExists
        = [](...){ return FileCopyOperationDR::Stop; };
    
    // expect: FileCopyOperationDR::Retry, FileCopyOperationDR::Skip, FileCopyOperationDR::SkipAll, FileCopyOperationDR::Stop
    function<int(int _vfs_error, string _path)> m_OnCantOpenDestinationFile
        = [](...){ return FileCopyOperationDR::Stop; };
    
    // expect: FileCopyOperationDR::Retry, FileCopyOperationDR::Skip, FileCopyOperationDR::SkipAll, FileCopyOperationDR::Stop
    function<int(int _vfs_error, string _path)> m_OnSourceFileReadError
        = [](...){ return FileCopyOperationDR::Stop; };

    // expect: FileCopyOperationDR::Retry, FileCopyOperationDR::Skip, FileCopyOperationDR::SkipAll, FileCopyOperationDR::Stop
    function<int(int _vfs_error, string _path)> m_OnDestinationFileReadError
        = [](...){ return FileCopyOperationDR::Stop; };
    
    // expect: FileCopyOperationDR::Retry, FileCopyOperationDR::Skip, FileCopyOperationDR::SkipAll, FileCopyOperationDR::Stop
    function<int(int _vfs_error, string _path)> m_OnDestinationFileWriteError
        = [](...){ return FileCopyOperationDR::Stop; };

    // expect: FileCopyOperationDR::Retry, FileCopyOperationDR::Stop
    function<int(int _vfs_error, string _path)> m_OnCantCreateDestinationRootDir
        = [](...){ return FileCopyOperationDR::Stop; };

    // expect: FileCopyOperationDR::Retry, FileCopyOperationDR::Skip, FileCopyOperationDR::SkipAll, FileCopyOperationDR::Stop
    function<int(int _vfs_error, string _path)> m_OnCantCreateDestinationDir
        = [](...){ return FileCopyOperationDR::Stop; };
    
    // expects: FileCopyOperationDR::Continue
    function<int(string _path)> m_OnFileVerificationFailed
        = [](...){ return FileCopyOperationDR::Continue; };
};

//
//  FileCopyOperationNew.hpp
//  Files
//
//  Created by Michael G. Kazakov on 25/09/15.
//  Copyright © 2015 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include <Habanero/algo.h>
#include "NativeFSManager.h"
#include "DispatchQueue.h"
#include "Options.h"
#include "OperationJob.h"
#include "OperationDialogProtocol.h"


class FileCopyOperationJobNew : public OperationJob
{
public:
    
    void Init(vector<VFSFlexibleListingItem> _source_items,
              const string &_dest_path,
              const VFSHostPtr &_dest_host,
              FileCopyOperationOptions _opts
              );
    
    bool IsSingleItemProcessing() const noexcept { return m_IsSingleItemProcessing; }
    
    void ToggleSkipAll() { m_SkipAll = true; }
    void ToggleOverwriteAll() { m_OverwriteAll = true; }
    void ToggleAppendAll() { m_AppendAll = true; }
    
    
    void test(string _from, string _to);
    void test2(string _dest, VFSHostPtr _host);
    
    void test3(string _dir, string _filename, VFSHostPtr _host);
   
    void Do_Hack();
    
    
private:
    virtual void Do() override;
    
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
        int original_item;
        string destination_path;
        struct {
            uint8_t buf[16];
        } md5;
    };
    
    class SourceItems
    {
    public:
        int InsertItem( uint16_t _host_index, unsigned _base_dir_index, int _parent_index, string _item_name, const VFSStat &_stat );

        int ItemsAmount() const noexcept;
        
        string          ComposeFullPath( int _item_no ) const;
        string          ComposeRelativePath( int _item_no ) const;
        mode_t          ItemMode( int _item_no ) const;
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
            int         parent_index;
            unsigned    base_dir_index;
            uint16_t    host_index;
            uint16_t    mode;
            dev_t       dev_num;
        };
        
        vector<SourceItem>                      m_Items;
        vector<VFSHostPtr>                      m_SourceItemsHosts;
        vector<string>                          m_SourceItemsBaseDirectories;
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
    StepResult CopyNativeDirectoryToNativeDirectory(const string& _src_path,
                                                    const string& _dst_path) const;
    StepResult RenameNativeFile(const string& _src_path,
                                const string& _dst_path) const;
    StepResult VerifyCopiedFile(const ChecksumExpectation& _exp, bool &_matched) const;
    void        CleanSourceItems() const;
    
    
    void                    EraseXattrsFromNativeFD(int _fd_in) const;
    void                    CopyXattrsFromNativeFDToNativeFD(int _fd_from, int _fd_to) const;
    
    vector<VFSFlexibleListingItem>  m_VFSListingItems;
    SourceItems                     m_SourceItems;
    vector<ChecksumExpectation>     m_Checksums;
    vector<unsigned>                m_SourceItemsToDelete;
    VFSHostPtr                      m_DestinationHost;
    shared_ptr<const NativeFileSystemInfo> m_DestinationNativeFSInfo; // used only for native vfs
    string                          m_InitialDestinationPath; // must be an absolute path, used solely in AnalizeDestination()
    string                          m_DestinationPath;
    PathCompositionType             m_PathCompositionType;
    
    // buffers are allocated once in job init and are used to manupulate files' bytes.
    // thus no parallel routines should run using these buffers
    static const int        m_BufferSize    = 2*1024*1024;
    unique_ptr<uint8_t[]>   m_Buffers[2]    = { make_unique<uint8_t[]>(m_BufferSize), make_unique<uint8_t[]>(m_BufferSize) };
    
    DispatchGroup           m_IOGroup;
    bool                    m_IsSingleItemProcessing = false;
    bool                    m_SkipAll       = false;
    bool                    m_OverwriteAll  = false;
    bool                    m_AppendAll     = false;
    
    
    FileCopyOperationOptions m_Options;
    
    function<int(int _vfs_error, string _path)> m_OnCantAccessSourceItem
        = [](int, string){ return OperationDialogResult::Stop; };

    function<int(const struct stat &_src_stat, const struct stat &_dst_stat, string _path)> m_OnFileAlreadyExist
        = [](const struct stat&, const struct stat&, string) { return OperationDialogResult::Stop; };

    function<int(int _vfs_error, string _path)> m_OnCantOpenDestinationFile
        = [](int, string){ return OperationDialogResult::Stop; };

    function<int(int _vfs_error, string _path)> m_OnSourceFileReadError
        = [](int, string){ return OperationDialogResult::Stop; };

    function<int(int _vfs_error, string _path)> m_OnDestinationFileReadError
        = [](int, string){ return OperationDialogResult::Stop; };
    
    function<int(int _vfs_error, string _path)> m_OnDestinationFileWriteError
        = [](int, string){ return OperationDialogResult::Stop; };

    function<int(int _vfs_error, string _path)> m_OnCantCreateDestinationRootDir
        = [](int, string){ return OperationDialogResult::Stop; };
    
    function<int(int _vfs_error, string _path)> m_OnCantCreateDestinationDir
        = [](int, string){ return OperationDialogResult::Stop; };
    
    function<int(string _source, string _destination)> m_OnRenameDestinationAlreadyExists
        = [](string, string){ return OperationDialogResult::Stop; };
    
    
//            int result = [[m_Operation OnCopyWriteError:ErrnoToNSError() ForFile:_dest] WaitForResult];
    
//        int result = [[m_Operation OnCopyCantOpenDestFile:ErrnoToNSError() ForFile:_dest] WaitForResult];
    
    //        result = [[m_Operation OnFileExist:_dest
    //                                   newsize:src_stat_buffer.st_size
    //                                   newtime:src_stat_buffer.st_mtimespec.tv_sec
    //                                   exisize:dst_stat_buffer.st_size
    //                                   exitime:dst_stat_buffer.st_mtimespec.tv_sec
    //                                  remember:&remember_choice] WaitForResult];
    
//        int result = [[m_Operation OnCopyCantAccessSrcFile:ErrnoToNSError() ForFile:_src] WaitForResult];
};

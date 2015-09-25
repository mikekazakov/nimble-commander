//
//  FileCopyOperationNew.hpp
//  Files
//
//  Created by Michael G. Kazakov on 25/09/15.
//  Copyright © 2015 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include "NativeFSManager.h"
#include "DispatchQueue.h"
#include "OperationJob.h"
#include "OperationDialogProtocol.h"

class FileCopyOperationJobNew : public OperationJob
{
public:
    
    void ToggleSkipAll() { m_SkipAll = true; }
    void ToggleOverwriteAll() { m_OverwriteAll = true; }
    void ToggleAppendAll() { m_AppendAll = true; }
    
    
private:
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
    
    
    
    // + stats callback
    StepResult CopyNativeFileToNativeFile(const string& _src_path,
                                          const NativeFileSystemInfo &_src_fs_info,
                                          const string& _dst_path,
                                          const NativeFileSystemInfo &_dst_fs_info) const;
    
    // buffers are allocated once in job init and are used to manupulate files' bytes.
    // thus no parallel routines should run using these buffers
    static const int        m_BufferSize    = 4*1024*1024;
    unique_ptr<uint8_t[]>   m_Buffers[2]    = { make_unique<uint8_t[]>(m_BufferSize), make_unique<uint8_t[]>(m_BufferSize) };
    
    DispatchGroup           m_IOGroup;
    bool                    m_SkipAll       = false;
    bool                    m_OverwriteAll  = false;
    bool                    m_AppendAll     = false;
    
    
    
    
    function<int(int _vfs_error, string _path)> m_OnCantAccessSourceItem =
        [](int, string){ return OperationDialogResult::Stop; };
    function<int(const struct stat &_src_stat, const struct stat &_dst_stat, string _path)> m_OnFileAlreadyExist =
        [](const struct stat&, const struct stat&, string) { return OperationDialogResult::Stop; };
    
    //        result = [[m_Operation OnFileExist:_dest
    //                                   newsize:src_stat_buffer.st_size
    //                                   newtime:src_stat_buffer.st_mtimespec.tv_sec
    //                                   exisize:dst_stat_buffer.st_size
    //                                   exitime:dst_stat_buffer.st_mtimespec.tv_sec
    //                                  remember:&remember_choice] WaitForResult];
    
//        int result = [[m_Operation OnCopyCantAccessSrcFile:ErrnoToNSError() ForFile:_src] WaitForResult];
};

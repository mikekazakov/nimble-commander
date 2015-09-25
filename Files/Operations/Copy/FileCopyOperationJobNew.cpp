//
//  FileCopyOperationNew.cpp
//  Files
//
//  Created by Michael G. Kazakov on 25/09/15.
//  Copyright © 2015 Michael G. Kazakov. All rights reserved.
//

#include <Habanero/algo.h>
#include "VFS.h"
#include "RoutedIO.h"
#include "FileCopyOperationJobNew.h"
#include "DialogResults.h"

FileCopyOperationJobNew::StepResult FileCopyOperationJobNew::CopyNativeFileToNativeFile(const string& _src_path,
                                                                                        const NativeFileSystemInfo &_src_fs_info,
                                                                                        const string& _dst_path,
                                                                                        const NativeFileSystemInfo &_dst_fs_info) const
{
    auto &io = RoutedIO::Default;

//    // TODO: need to ask about destination volume info to exclude meaningless operations for attrs which are not supported
//    // TODO: need to adjust buffer sizes and writing calls to preffered volume's I/O size
//    struct stat src_stat_buffer, dst_stat_buffer;
//    char *readbuf = (char*)m_Buffer1.get(), *writebuf = (char*)m_Buffer2.get();
//    int dstopenflags=0, sourcefd=-1, destinationfd=-1, fcntlret;
//    int64_t preallocate_delta = 0;
//    unsigned long startwriteoff = 0, totaldestsize = 0, dest_sz_on_stop = 0;
//    bool adjust_dst_time = true, copy_xattrs = true, erase_xattrs = false, remember_choice = false,
//    was_successful = false, unlink_on_stop = false;
//    mode_t oldumask;
//    unsigned long io_leftwrite = 0, io_totalread = 0, io_totalwrote = 0;
//    bool io_docancel = false;
//    bool need_dst_truncate = false;
//    
//    m_Stats.SetCurrentItem(_src);
//    
//    // getting fs_info for every single file is suboptimal. need to optimize it.
//    auto src_fs_info = NativeFSManager::Instance().VolumeFromPath(_src);
//
//opensource:

    // we initially open source file in non-blocking mode, so we can fail early and not to cause a hang. (hi, apple!)
    int src_open_flags = O_RDONLY|O_NONBLOCK;
    if( _src_fs_info.interfaces.file_lock )
        src_open_flags |= O_SHLOCK;
    
    int source_fd = -1;
    while( (source_fd = io.open(_src_path.c_str(), src_open_flags)) == -1 ) {
        // failed to open source file
        if( m_SkipAll ) return StepResult::Skipped;
        switch( m_OnCantAccessSourceItem( VFSError::FromErrno(), _src_path ) ) {
            case OperationDialogResult::Skip:       return StepResult::Skipped;
            case OperationDialogResult::SkipAll:    return StepResult::SkipAll;
            case OperationDialogResult::Stop:       return StepResult::Stop;
        }
    }

    // be sure to close source file descriptor
    auto close_source_fd = at_scope_end([&]{
        if( source_fd >= 0 )
            close( source_fd );
    });

    // do not waste OS file cache with one-way data
    fcntl(source_fd, F_NOCACHE, 1);

    // get current file descriptor's open flags
    {
        int fcntl_ret = fcntl(source_fd, F_GETFL);
        if( fcntl_ret < 0 )
            throw runtime_error("fcntl(source_fd, F_GETFL) returned a negative value"); // <- if this happens then we're deeply in asshole

        // exclude non-blocking flag for current descriptor, so we will go straight blocking sync next
        fcntl_ret = fcntl(source_fd, F_SETFL, fcntl_ret & ~O_NONBLOCK);
        if( fcntl_ret < 0 )
            throw runtime_error("fcntl(source_fd, F_SETFL, fcntl_ret & ~O_NONBLOCK) returned a negative value"); // <- -""-
    }
    
    // get information about source file
    struct stat src_stat_buffer;
    while( fstat(source_fd, &src_stat_buffer) == -1 ) {
        // failed to stat source
        if( m_SkipAll ) return StepResult::Skipped;
        switch( m_OnCantAccessSourceItem( VFSError::FromErrno(), _src_path ) ) {
            case OperationDialogResult::Skip:       return StepResult::Skipped;
            case OperationDialogResult::SkipAll:    return StepResult::SkipAll;
            case OperationDialogResult::Stop:       return StepResult::Stop;
        }
    }
    
    // stat destination
    struct stat dst_stat_buffer;
    if( io.stat(_dst_path.c_str(), &dst_stat_buffer) != -1 ) {
        // file already exist. what should we do now?
        
        if( m_SkipAll )
            return StepResult::Skipped;
        
        auto setup_overwrite = [&]{
            // ...
        };
        auto setup_append = [&]{
            // ...
        };
        
        if( m_OverwriteAll )
            setup_overwrite();
        else if( m_AppendAll )
            setup_append();
        else switch( m_OnFileAlreadyExist( src_stat_buffer, dst_stat_buffer, _dst_path) ) {
                case FileCopyOperationDR::Overwrite:    setup_overwrite(); break;
                case FileCopyOperationDR::Append:       setup_append(); break;
                case OperationDialogResult::Skip:       return StepResult::Skipped;
                default:                                return StepResult::Stop;
        }
    }
    else {
        // no dest file - just create it
        
        
    }
                
                

//    
//    // stat destination
//    totaldestsize = src_stat_buffer.st_size;
//    if(io.stat(_dest, &dst_stat_buffer) != -1)
//    { // file already exist. what should we do now?
//        int result;
//        if(m_SkipAll) goto cleanup;
//        if(m_OverwriteAll) goto decoverwrite;
//        if(m_AppendAll) goto decappend;
//        
//        result = [[m_Operation OnFileExist:_dest
//                                   newsize:src_stat_buffer.st_size
//                                   newtime:src_stat_buffer.st_mtimespec.tv_sec
//                                   exisize:dst_stat_buffer.st_size
//                                   exitime:dst_stat_buffer.st_mtimespec.tv_sec
//                                  remember:&remember_choice] WaitForResult];
//        if(result == FileCopyOperationDR::Overwrite){ if(remember_choice) m_OverwriteAll = true;  goto decoverwrite; }
//        if(result == FileCopyOperationDR::Append)   { if(remember_choice) m_AppendAll = true;     goto decappend;    }
//        if(result == OperationDialogResult::Skip)     { if(remember_choice) m_SkipAll = true;       goto cleanup;      }
//        if(result == OperationDialogResult::Stop)   { RequestStop(); goto cleanup; }
//        
//        // decisions about what to do with existing destination
//    decoverwrite:
//        dstopenflags = O_WRONLY;
//        erase_xattrs = true;
//        unlink_on_stop = true;
//        dest_sz_on_stop = 0;
//        preallocate_delta = src_stat_buffer.st_size - dst_stat_buffer.st_size;
//        if(src_stat_buffer.st_size < dst_stat_buffer.st_size)
//            need_dst_truncate = true;
//        goto decend;
//    decappend:
//        dstopenflags = O_WRONLY;
//        totaldestsize += dst_stat_buffer.st_size;
//        startwriteoff = dst_stat_buffer.st_size;
//        dest_sz_on_stop = dst_stat_buffer.st_size;
//        preallocate_delta = src_stat_buffer.st_size;
//        adjust_dst_time = false;
//        copy_xattrs = false;
//        unlink_on_stop = false;
//        goto decend;
//    decend:;
//    }
//    else
//    { // no dest file - just create it
//        dstopenflags = O_WRONLY|O_CREAT;
//        unlink_on_stop = true;
//        dest_sz_on_stop = 0;
//        preallocate_delta = src_stat_buffer.st_size;
//    }
//    
//opendest: // open file descriptor for destination
//    oldumask = umask(0);
//    if(m_Options.copy_unix_flags) // we want to copy src permissions
//        destinationfd = io.open(_dest, dstopenflags, src_stat_buffer.st_mode);
//    else // open file with default permissions
//        destinationfd = io.open(_dest, dstopenflags, S_IRUSR | S_IWUSR | S_IRGRP);
//    umask(oldumask);
//    
//    if(destinationfd == -1)
//    {   // failed to open destination file
//        if(m_SkipAll) goto cleanup;
//        int result = [[m_Operation OnCopyCantOpenDestFile:ErrnoToNSError() ForFile:_dest] WaitForResult];
//        if(result == OperationDialogResult::Retry) goto opendest;
//        if(result == OperationDialogResult::Skip) goto cleanup;
//        if(result == OperationDialogResult::SkipAll) {m_SkipAll = true; goto cleanup;}
//        if(result == OperationDialogResult::Stop) { RequestStop(); goto cleanup; }
//    }
//    
//    fcntl(destinationfd, F_NOCACHE, 1); // caching is meaningless here?
//    
//    if( FileCopyOperationJob::ShouldPreallocateSpace(preallocate_delta, destinationfd) ) {
//        // tell systme to preallocate space for data since we dont want to trash our disk
//        FileCopyOperationJob::PreallocateSpace(preallocate_delta, destinationfd);
//        
//        // truncate is needed for actual preallocation
//        need_dst_truncate = true;
//    }
//    
//    if( need_dst_truncate ) {
//    dotruncate:
//        // set right size for destination file for preallocating itself
//        if( ftruncate(destinationfd, totaldestsize) == -1 ) {
//            // failed to set dest file size
//            if(m_SkipAll) goto cleanup;
//            int result = [[m_Operation OnCopyWriteError:ErrnoToNSError() ForFile:_dest] WaitForResult];
//            if(result == OperationDialogResult::Retry) goto dotruncate;
//            if(result == OperationDialogResult::Skip) goto cleanup;
//            if(result == OperationDialogResult::SkipAll) {m_SkipAll = true; goto cleanup;}
//            if(result == OperationDialogResult::Stop) { RequestStop(); goto cleanup; }
//        }
//    }
//    
//    
//dolseek: // find right position in destination file
//    if(startwriteoff > 0 && lseek(destinationfd, startwriteoff, SEEK_SET) == -1)
//    {   // failed seek in a file. lolwhat?
//        if(m_SkipAll) goto cleanup;
//        int result = [[m_Operation OnCopyWriteError:ErrnoToNSError() ForFile:_dest] WaitForResult];
//        if(result == OperationDialogResult::Retry) goto dolseek;
//        if(result == OperationDialogResult::Skip) goto cleanup;
//        if(result == OperationDialogResult::SkipAll) {m_SkipAll = true; goto cleanup;}
//        if(result == OperationDialogResult::Stop) { RequestStop(); goto cleanup; }
//    }
//    
//    while(true)
//    {
//        if(CheckPauseOrStop()) goto cleanup;
//        
//        ssize_t io_nread = 0;
//        m_IOGroup.Run([&]{
//        doread:
//            if(io_totalread < src_stat_buffer.st_size)
//            {
//                io_nread = read(sourcefd, readbuf, m_BufferSize);
//                if(io_nread == -1)
//                {
//                    if(m_SkipAll) {io_docancel = true; return;}
//                    int result = [[m_Operation OnCopyReadError:ErrnoToNSError() ForFile:_dest] WaitForResult];
//                    if(result == OperationDialogResult::Retry) goto doread;
//                    if(result == OperationDialogResult::Skip) {io_docancel = true; return;}
//                    if(result == OperationDialogResult::SkipAll) {io_docancel = true; m_SkipAll = true; return;}
//                    if(result == OperationDialogResult::Stop) { io_docancel = true; RequestStop(); return;}
//                }
//                io_totalread += io_nread;
//            }
//        });
//        
//        m_IOGroup.Run([&]{
//            unsigned long alreadywrote = 0;
//            while(io_leftwrite > 0)
//            {
//            dowrite:
//                ssize_t nwrite = write(destinationfd, writebuf + alreadywrote, io_leftwrite);
//                if(nwrite == -1)
//                {
//                    if(m_SkipAll) {io_docancel = true; return;}
//                    int result = [[m_Operation OnCopyWriteError:ErrnoToNSError() ForFile:_dest] WaitForResult];
//                    if(result == OperationDialogResult::Retry) goto dowrite;
//                    if(result == OperationDialogResult::Skip) {io_docancel = true; return;}
//                    if(result == OperationDialogResult::SkipAll) {io_docancel = true; m_SkipAll = true; return;}
//                    if(result == OperationDialogResult::Stop) { io_docancel = true; RequestStop(); return;}
//                }
//                alreadywrote += nwrite;
//                io_leftwrite -= nwrite;
//            }
//            io_totalwrote += alreadywrote;
//            m_TotalCopied += alreadywrote;
//        });
//        
//        m_IOGroup.Wait();
//        if(io_docancel) goto cleanup;
//        if(io_totalwrote == src_stat_buffer.st_size) break;
//        
//        io_leftwrite = io_nread;
//        swap(readbuf, writebuf); // swap our work buffers - read buffer become write buffer and vice versa
//        
//        // update statistics
//        m_Stats.SetValue(m_TotalCopied);
//    }
//    
//    // TODO: do we need to determine if various attributes setting was successful?
//    
//    // erase destination's xattrs
//    if(m_Options.copy_xattrs && erase_xattrs)
//        EraseXattrs(destinationfd);
//    
//    // copy xattrs from src to dest
//    if(m_Options.copy_xattrs && copy_xattrs)
//        CopyXattrs(sourcefd, destinationfd);
//    
//    // change ownage
//    // TODO: we can't chown without superuser rights.
//    // need to optimize this (sometimes) meaningless call
//    if(m_Options.copy_unix_owners) {
//        if(io.isrouted()) // long path
//            io.chown(_dest, src_stat_buffer.st_uid, src_stat_buffer.st_gid);
//        else // short path
//            fchown(destinationfd, src_stat_buffer.st_uid, src_stat_buffer.st_gid);
//    }
//    
//    // change flags
//    if(m_Options.copy_unix_flags) {
//        if(io.isrouted()) // long path
//            io.chflags(_dest, src_stat_buffer.st_flags);
//        else
//            fchflags(destinationfd, src_stat_buffer.st_flags);
//    }
//    
//    // adjust destination time as source
//    if(m_Options.copy_file_times && adjust_dst_time)
//        AdjustFileTimes(destinationfd, &src_stat_buffer);
//    
//    was_successful = true;
//    
//cleanup:
//    if(sourcefd != -1) close(sourcefd);
//    if(!was_successful && destinationfd != -1)
//    {
//        // we need to revert what we've done
//        ftruncate(destinationfd, dest_sz_on_stop);
//        close(destinationfd);
//        destinationfd = -1;
//        if(unlink_on_stop)
//            io.unlink(_dest);
//    }
//    if(destinationfd != -1) close(destinationfd);
//    return was_successful;
//
    
    return StepResult::Ok;
}

//
//  FileCopyOperationNew.cpp
//  Files
//
//  Created by Michael G. Kazakov on 25/09/15.
//  Copyright © 2015 Michael G. Kazakov. All rights reserved.
//

#include <Habanero/algo.h>
//#include <sys/sendfile.h>
//
//#include <copyfile.h>

#include "Common.h"

#include "VFS.h"
#include "RoutedIO.h"
#include "FileCopyOperationJobNew.h"
#include "DialogResults.h"

static bool ShouldPreallocateSpace(int64_t _bytes_to_write, const NativeFileSystemInfo &_fs_info)
{
    const auto min_prealloc_size = 4096;
    if( _bytes_to_write <= min_prealloc_size )
        return false;

    // need to check destination fs and permit preallocation only on certain filesystems
    return _fs_info.fs_type_name == "hfs"; // Apple's copyfile() also uses preallocation on Xsan volumes
}

// PreallocateSpace assumes following ftruncate, meaningless otherwise
static void PreallocateSpace(int64_t _preallocate_delta, int _file_des)
{
    fstore_t preallocstore = {F_ALLOCATECONTIG, F_PEOFPOSMODE, 0, _preallocate_delta};
    if( fcntl(_file_des, F_PREALLOCATE, &preallocstore) == -1 ) {
        preallocstore.fst_flags = F_ALLOCATEALL;
        fcntl(_file_des, F_PREALLOCATE, &preallocstore);
        
    }
    
    
//    typedef struct fstore {
//        unsigned int fst_flags;	/* IN: flags word */
//        int 	fst_posmode;	/* IN: indicates use of offset field */
//        off_t	fst_offset;	/* IN: start of the region */
//        off_t	fst_length;	/* IN: size of the region */
//        off_t   fst_bytesalloc;	/* OUT: number of bytes allocated */
//    } fstore_t;
//    
    
    
//    /* If supported, do preallocation for Xsan / HFS volumes */
//#ifdef F_PREALLOCATE
//    {
//        fstore_t fst;
//        
//        fst.fst_flags = 0;
//        fst.fst_posmode = F_PEOFPOSMODE;
//        fst.fst_offset = 0;
//        fst.fst_length = s->sb.st_size;
//        /* Ignore errors; this is merely advisory. */
//        (void)fcntl(s->dst_fd, F_PREALLOCATE, &fst);
//    }
//#endif
}

void FileCopyOperationJobNew::Do()
{
}

void FileCopyOperationJobNew::test(string _from, string _to)
{
    auto &nfsm = NativeFSManager::Instance();
    CopyNativeFileToNativeFile(_from,
                               *nfsm.VolumeFromPath(path(_from).parent_path().native()),
                               _to,
                               *nfsm.VolumeFromPath(path(_to).parent_path().native()));
}

static auto run_test = []{
    
//    for( int i = 0; i < 2; ++i ) {
        FileCopyOperationJobNew job;
        MachTimeBenchmark mtb;
        job.test("/users/migun/1/bigfile.avi", "/users/migun/2/newbigfile.avi");
        mtb.ResetMilli();
//        remove("/users/migun/2/newbigfile.avi");
//    }
    
    int a = 10;
    return 0;
}();


FileCopyOperationJobNew::StepResult FileCopyOperationJobNew::CopyNativeFileToNativeFile(const string& _src_path,
                                                                                        const NativeFileSystemInfo &_src_dir_fs_info,
                                                                                        const string& _dst_path,
                                                                                        const NativeFileSystemInfo &_dst_dir_fs_info) const
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
    
    // we need to check if our source file is a symlink, so we can't rely on _src_dir_fs_info as it can point to another filesystem
    struct stat src_lstat_buf;
    while( io.lstat(_src_path.c_str(), &src_lstat_buf) == -1 ) {
        // failed to lstat source file
        if( m_SkipAll ) return StepResult::Skipped;
        switch( m_OnCantAccessSourceItem( VFSError::FromErrno(), _src_path ) ) {
            case OperationDialogResult::Skip:       return StepResult::Skipped;
            case OperationDialogResult::SkipAll:    return StepResult::SkipAll;
            case OperationDialogResult::Stop:       return StepResult::Stop;
        }
    }
    
//    int src_open_flags = O_RDONLY|O_NONBLOCK;
//    if( _src_dir_fs_info.interfaces.file_lock )
//        src_open_flags |= O_SHLOCK;
    
    // we initially open source file in non-blocking mode, so we can fail early and not to cause a hang. (hi, apple!)
    int source_fd = -1;
    while( (source_fd = io.open(_src_path.c_str(), O_RDONLY|O_NONBLOCK|O_SHLOCK)) == -1 &&
           (source_fd = io.open(_src_path.c_str(), O_RDONLY|O_NONBLOCK)) == -1 ) {
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
    if( !S_ISLNK(src_lstat_buf.st_mode) )
        src_stat_buffer = src_lstat_buf;
    else while( fstat(source_fd, &src_stat_buffer) == -1 ) {
        // failed to stat source
        if( m_SkipAll ) return StepResult::Skipped;
        switch( m_OnCantAccessSourceItem( VFSError::FromErrno(), _src_path ) ) {
            case OperationDialogResult::Skip:       return StepResult::Skipped;
            case OperationDialogResult::SkipAll:    return StepResult::SkipAll;
            case OperationDialogResult::Stop:       return StepResult::Stop;
        }
    }
  
    // find fs info for source file. if it is a symlink actually - we need to search for it exclusively with fcntl(..., F_GETPATH, ...) by VolumeFromFD
    shared_ptr<const NativeFileSystemInfo> src_fs_info_holder_for_symlinks;
    if( S_ISLNK(src_lstat_buf.st_mode) )
        src_fs_info_holder_for_symlinks = NativeFSManager::Instance().VolumeFromFD(source_fd);
    const NativeFileSystemInfo &src_fs_into = src_fs_info_holder_for_symlinks ? *src_fs_info_holder_for_symlinks : _src_dir_fs_info;
    
    // setting up copying scenario
    int     dst_open_flags          = 0;
    bool    do_erase_xattrs         = false,
            do_unlink_on_stop       = false,
            need_dst_truncate       = false,
            dst_existed_before      = false,
            dst_is_a_symlink        = false;
    int64_t dst_size_on_stop        = 0,
            total_dst_size          = src_stat_buffer.st_size,
            preallocate_delta       = 0,
            initial_writing_offset  = 0;
    
    // stat destination
    struct stat dst_stat_buffer;
    if( io.stat(_dst_path.c_str(), &dst_stat_buffer) != -1 ) {
        // file already exist. what should we do now?
        dst_existed_before = true;
        
        if( m_SkipAll )
            return StepResult::Skipped;
        
        auto setup_overwrite = [&]{
            dst_open_flags = O_WRONLY;
            do_unlink_on_stop = true;
            dst_size_on_stop = 0;
            do_erase_xattrs = true;
            preallocate_delta = src_stat_buffer.st_size - dst_stat_buffer.st_size; // negative value is ok here
            need_dst_truncate = src_stat_buffer.st_size < dst_stat_buffer.st_size;
        };
        auto setup_append = [&]{
            dst_open_flags = O_WRONLY;
            do_unlink_on_stop = false;
            dst_size_on_stop = dst_stat_buffer.st_size;
            total_dst_size += dst_stat_buffer.st_size;
            initial_writing_offset = dst_stat_buffer.st_size;
            preallocate_delta = src_stat_buffer.st_size;
            
            // TODO:
            //        adjust_dst_time = false;
            //        copy_xattrs = false;

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
        
        // we need to check if existining destination is actually a symlink
        struct stat dst_lstat_buffer;
        if( io.lstat(_dst_path.c_str(), &dst_lstat_buffer) == 0 && S_ISLNK(dst_lstat_buffer.st_mode) )
            dst_is_a_symlink = true;
    }
    else {
        // no dest file - just create it
        dst_open_flags = O_WRONLY|O_CREAT;
        do_unlink_on_stop = true;
        dst_size_on_stop = 0;
        preallocate_delta = src_stat_buffer.st_size;
    }
    
    // open file descriptor for destination
    int destination_fd = -1;
    
    while( true ) {
        // we want to copy src permissions if options say so or just put default ones
        mode_t open_mode = m_Options.copy_unix_flags ? src_stat_buffer.st_mode : S_IRUSR | S_IWUSR | S_IRGRP;
        mode_t old_umask = umask( 0 );
        destination_fd = io.open( _dst_path.c_str(), dst_open_flags, open_mode );
        umask(old_umask);

        if( destination_fd != -1 )
            break; // we're good to go
        
        // failed to open destination file
        if( m_SkipAll )
            return StepResult::Skipped;
        
        switch( m_OnCantOpenDestinationFile(VFSError::FromErrno(), _dst_path) ) {
            case OperationDialogResult::Retry:      continue;
            case OperationDialogResult::Skip:       return StepResult::Skipped;
            case OperationDialogResult::SkipAll:    return StepResult::SkipAll;
            default:                                return StepResult::Stop;
        }
    }
    
    // don't forget ot close destination file descriptor anyway
    auto close_destination = at_scope_end([&]{
        if(destination_fd != -1) {
            close(destination_fd);
            destination_fd = -1;
        }
    });
    
    // for some circumstances we have to clean up remains if anything goes wrong
    // and do it BEFORE close_destination fires
    auto clean_destination = at_scope_end([&]{
        if( destination_fd != -1 ) {
            // we need to revert what we've done
            ftruncate(destination_fd, dst_size_on_stop);
            close(destination_fd);
            destination_fd = -1;
            if( do_unlink_on_stop )
                io.unlink( _dst_path.c_str() );
        }
    });
    
    // caching is meaningless here
    fcntl( destination_fd, F_NOCACHE, 1 );
    
    // find fs info for destination file. if it is a symlink actually - we need to search for it exclusively with fcntl(..., F_GETPATH, ...) by VolumeFromFD
    shared_ptr<const NativeFileSystemInfo> dst_fs_info_holder_for_symlinks;
    if( dst_existed_before && dst_is_a_symlink )
        dst_fs_info_holder_for_symlinks = NativeFSManager::Instance().VolumeFromFD(destination_fd);
    const NativeFileSystemInfo &dst_fs_info = dst_fs_info_holder_for_symlinks ? *dst_fs_info_holder_for_symlinks : _dst_dir_fs_info;
    
    if( ShouldPreallocateSpace(preallocate_delta, dst_fs_info) ) {
        // tell systme to preallocate space for data since we dont want to trash our disk
        PreallocateSpace(preallocate_delta, destination_fd);
        
        // truncate is needed for actual preallocation
        need_dst_truncate = true;
    }
    
    // set right size for destination file for preallocating itself and for reducing file size if necessary
    if( need_dst_truncate )
        while( ftruncate(destination_fd, total_dst_size) == -1 ) {
            // failed to set dest file size
            if(m_SkipAll)
                return StepResult::Skipped;
            
            switch( m_OnDestinationFileWriteError(VFSError::FromErrno(), _dst_path) ) {
                case OperationDialogResult::Retry:      continue;
                case OperationDialogResult::Skip:       return StepResult::Skipped;
                case OperationDialogResult::SkipAll:    return StepResult::SkipAll;
                default:                                return StepResult::Stop;
            }
        }
    
    // find the right position in destination file
    if( initial_writing_offset > 0 ) {
        while( lseek(destination_fd, initial_writing_offset, SEEK_SET) == -1  ) {
            // failed seek in a file. lolwut?
            if(m_SkipAll)
                return StepResult::Skipped;
            
            switch( m_OnDestinationFileWriteError(VFSError::FromErrno(), _dst_path) ) {
                case OperationDialogResult::Retry:      continue;
                case OperationDialogResult::Skip:       return StepResult::Skipped;
                case OperationDialogResult::SkipAll:    return StepResult::SkipAll;
                default:                                return StepResult::Stop;
            }
        }
    }
    
    
    
    auto read_buffer = m_Buffers[0].get(), write_buffer = m_Buffers[1].get();
    const uint32_t src_preffered_io_size = src_fs_into.basic.io_size < m_BufferSize ? src_fs_into.basic.io_size : m_BufferSize;
    const uint32_t dst_preffered_io_size = dst_fs_info.basic.io_size < m_BufferSize ? dst_fs_info.basic.io_size : m_BufferSize;
    constexpr int max_io_loops = 5; // looked in Apple's copyfile() - treat 5 zero-resulting reads/writes as an error
    uint32_t bytes_to_write = 0;
    uint64_t source_bytes_read = 0;
    uint64_t destination_bytes_written = 0;
    
    // read from source within current thread and write to destination within secondary queue
    while( src_stat_buffer.st_size != destination_bytes_written ) {
        
        // check user decided to pause operation or discard it
        if( CheckPauseOrStop() )
            return StepResult::Stop;
        
        optional<StepResult> write_return; // optional storage for error returning
        m_IOGroup.Run([this, bytes_to_write, destination_fd, write_buffer, dst_preffered_io_size, &destination_bytes_written, &write_return, &_dst_path]{
            uint32_t left_to_write = bytes_to_write;
            uint32_t has_written = 0; // amount of bytes written into destination this time
            int write_loops = 0;
            while( left_to_write > 0 ) {
                int64_t n_written = write(destination_fd, write_buffer + has_written, min(left_to_write, dst_preffered_io_size) );
                if( n_written > 0 ) {
                    has_written += n_written;
                    left_to_write -= n_written;
                    destination_bytes_written += n_written;
                }
                else if( n_written < 0 || (++write_loops > max_io_loops) ) {
                    if(m_SkipAll) {
                        write_return = StepResult::Skipped;
                        return;
                    }
                    switch( m_OnDestinationFileWriteError(VFSError::FromErrno(), _dst_path) ) {
                        case OperationDialogResult::Retry:      continue;
                        case OperationDialogResult::Skip:       write_return = StepResult::Skipped; return;
                        case OperationDialogResult::SkipAll:    write_return = StepResult::SkipAll; return;
                        default:                                write_return = StepResult::Stop; return;
                    }
                }
            }
        });
        
        // here we handle the case in which source io size is much smaller than dest's io size
        uint32_t to_read = max( src_preffered_io_size, dst_preffered_io_size );
        if( src_stat_buffer.st_size - source_bytes_read < to_read )
            to_read = uint32_t(src_stat_buffer.st_size - source_bytes_read);
            
        uint32_t has_read = 0; // amount of bytes read into buffer this time
        int read_loops = 0; // amount of zero-resulting reads
        optional<StepResult> read_return; // optional storage for error returning
        while( to_read != 0 ) {
            int64_t read_result = read(source_fd, read_buffer + has_read, src_preffered_io_size);
            if( read_result > 0 ) {
                source_bytes_read += read_result;
                has_read += read_result;
                to_read -= read_result;
            }
            else if( (read_result < 0) || (++read_loops > max_io_loops) ) {
                if(m_SkipAll) {
                    read_return = StepResult::Skipped;
                    break;
                }
                switch( m_OnDestinationFileWriteError(VFSError::FromErrno(), _src_path) ) {
                    case OperationDialogResult::Retry:      continue;
                    case OperationDialogResult::Skip:       read_return = StepResult::Skipped; break;
                    case OperationDialogResult::SkipAll:    read_return = StepResult::SkipAll; break;
                    default:                                read_return = StepResult::Stop; break;
                }
                break;
            }
        }
        
        m_IOGroup.Wait();
        
        if( write_return )
            return *write_return;
        if( read_return )
            return *read_return;
        
        bytes_to_write = has_read;
        swap( read_buffer, write_buffer );
    }
    

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
  
    // we're ok, turn off destination cleaning
    clean_destination.disengage();
    
    return StepResult::Ok;
}

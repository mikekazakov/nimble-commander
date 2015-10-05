//
//  FileCopyOperationNew.cpp
//  Files
//
//  Created by Michael G. Kazakov on 25/09/15.
//  Copyright © 2015 Michael G. Kazakov. All rights reserved.
//

#include <sys/xattr.h>
#include <Habanero/algo.h>

//#include <sys/sendfile.h>
//
//#include <copyfile.h>

#include "Common.h"

#include "VFS.h"
#include "RoutedIO.h"
#include "FileCopyOperationJobNew.h"
#include "DialogResults.h"

static string EnsureTrailingSlash(string _s)
{
    if( _s.empty() || _s.back() != '/' )
        _s.push_back('/');
    return _s;
}

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
}

static void AdjustFileTimesForNativeFD(int _target_fd, struct stat &_with_times)
{
    struct attrlist attrs;
    memset(&attrs, 0, sizeof(attrs));
    attrs.bitmapcount = ATTR_BIT_MAP_COUNT;
    
    attrs.commonattr = ATTR_CMN_MODTIME;
    fsetattrlist(_target_fd, &attrs, &_with_times.st_mtimespec, sizeof(struct timespec), 0);
    
    attrs.commonattr = ATTR_CMN_CRTIME;
    fsetattrlist(_target_fd, &attrs, &_with_times.st_birthtimespec, sizeof(struct timespec), 0);

//  do we really need atime to be changed?
//    attrs.commonattr = ATTR_CMN_ACCTIME;
//    fsetattrlist(_target_fd, &attrs, &_with_times.st_atimespec, sizeof(struct timespec), 0);
    
    attrs.commonattr = ATTR_CMN_CHGTIME;
    fsetattrlist(_target_fd, &attrs, &_with_times.st_ctimespec, sizeof(struct timespec), 0);
}

void FileCopyOperationJobNew::Init(vector<VFSFlexibleListingItem> _source_items,
                                   const string &_dest_path,
                                   const VFSHostPtr &_dest_host,
                                   FileCopyOperationOptions _opts)
{
    m_VFSListingItems = move(_source_items);
    m_InitialDestinationPath = _dest_path;
    m_DestinationHost = _dest_host;
    m_Options = _opts;
}

void FileCopyOperationJobNew::Do()
{
    m_IsSingleItemProcessing = m_VFSListingItems.size() == 1;
    bool need_to_build = false;
    auto comp_type = AnalyzeInitialDestination(m_DestinationPath, need_to_build);
    if( need_to_build )
        BuildDestinationDirectory();
    m_PathCompositionType = comp_type;
    
    auto scan_result = ScanSourceItems();
    if( get<0>(scan_result) != StepResult::Ok ) {
        SetStopped();
        return;
    }
    m_SourceItems = move( get<1>(scan_result) );
    
    m_VFSListingItems.clear(); // don't need them anymore
    
    ProcessItems();
    
    SetCompleted();
}

void FileCopyOperationJobNew::ProcessItems()
{
    const bool dest_host_is_native = m_DestinationHost->IsNativeFS();
    for( int i = 0, e = m_SourceItems.ItemsAmount(); i != e; ++i ) {
        auto mode = m_SourceItems.ItemMode(i);
        auto&host = m_SourceItems.ItemHost(i);
        auto destination_path = ComposeDestinationNameForItem(i);
        auto source_path = m_SourceItems.ComposeFullPath(i);
        
        if( S_ISREG(mode) ) {
            if( host.IsNativeFS() && dest_host_is_native ) {
                if( m_Options.docopy ) {
                    auto step_result = CopyNativeFileToNativeFile(source_path, destination_path, nullptr);
                }
                else
                    assert(0);
            
            }
            else
                assert(0);
            
        }
        else if( S_ISDIR(mode) ) {
            if( host.IsNativeFS() && dest_host_is_native ) {
                if( m_Options.docopy ) {
                    auto step_result = CopyNativeDirectoryToNativeDirectory(source_path, destination_path);
                    
                }
                else
                    assert(0);
                
            }
            else
                assert(0);
            
            
        }
    }
}

string FileCopyOperationJobNew::ComposeDestinationNameForItem( int _src_item_index ) const
{
// !!! need "m_IsSingleEntryCopy" flag !!!
    
    
//    PathPreffix, // path = dest_path + source_rel_path
//    FixedPath    // path = dest_path
    if( m_PathCompositionType == PathCompositionType::PathPreffix ) {
        auto path = m_SourceItems.ComposeRelativePath(_src_item_index);
        path.insert(0, m_DestinationPath);
        return path;
    }
    else {
        assert(0); // later
    }
}

void FileCopyOperationJobNew::test(string _from, string _to)
{
    CopyNativeFileToNativeFile(_from, _to, nullptr);
}

void FileCopyOperationJobNew::test2(string _dest, VFSHostPtr _host)
{
    m_InitialDestinationPath = _dest;
    m_DestinationHost = _host;
    bool need_to_build = false;
    auto comp_type = AnalyzeInitialDestination(m_DestinationPath, need_to_build);
    if( need_to_build )
        BuildDestinationDirectory();
    
    
    
    int a = 10;
}

void FileCopyOperationJobNew::Do_Hack()
{
    Do();
}

void FileCopyOperationJobNew::test3(string _dir, string _filename, VFSHostPtr _host)
{
    vector<VFSFlexibleListingItem> items;
    int ret = _host->FetchFlexibleListingItems(_dir, {_filename}, 0, items, nullptr);
    m_VFSListingItems = items;
    
    auto result = ScanSourceItems();

    
    int a = 10;
}

//static auto run_test = []{
    
//    for( int i = 0; i < 2; ++i ) {
//        FileCopyOperationJobNew job;
//        MachTimeBenchmark mtb;
//        job.test("/users/migun/1/bigfile.avi", "/users/migun/2/newbigfile.avi");
//        mtb.ResetMilli();
//        remove("/users/migun/2/newbigfile.avi");
//    }
    
    FileCopyOperationJobNew job;
//    job.test2("/users/migun/ABRA/", VFSNativeHost::SharedHost());
    
//    job.test3("/Users/migun/", /*"Applications"*/ "!!", VFSNativeHost::SharedHost());
//    
//    auto host = VFSNativeHost::SharedHost();
//    vector<VFSFlexibleListingItem> items;
////    int ret = host->FetchFlexibleListingItems("/Users/migun/Downloads", {"gimp-2.8.14.dmg", "PopcornTime-latest.dmg", "TorBrowser-5.0.1-osx64_en-US.dmg"}, 0, items, nullptr);
////    int ret = host->FetchFlexibleListingItems("/Users/migun", {"Source"}, 0, items, nullptr);
//    int ret = host->FetchFlexibleListingItems("/Users/migun/Documents/Files/source/Files/3rd_party/built/include", {"boost"}, 0, items, nullptr);
//    
//
//    job.Init(move(items), "/Users/migun/!TEST", host, {});
//    job.Do_Hack();
//    
//    
//    
//    int a = 10;
//    return 0;
//}();

FileCopyOperationJobNew::PathCompositionType FileCopyOperationJobNew::AnalyzeInitialDestination(string &_result_destination, bool &_need_to_build) const
{
    if( m_InitialDestinationPath.empty() || m_InitialDestinationPath.front() != '/' )
        throw invalid_argument("FileCopyOperationJobNew::AnalizeDestination: m_InitialDestinationPath should be an absolute path");
  
    VFSStat st;
    if( m_DestinationHost->Stat(m_InitialDestinationPath.c_str(), st, 0, nullptr ) == 0) {
        // destination entry already exist
        if( S_ISDIR(st.mode) ) {
            _result_destination = EnsureTrailingSlash( m_InitialDestinationPath );
            return PathCompositionType::PathPreffix;
        }
        else {
            _result_destination = m_InitialDestinationPath;
            return PathCompositionType::FixedPath; // if we have more than one item - it will cause "item already exist" on a second one
        }
    }
    else {
        // destination entry is non-existent
        _need_to_build = true;
        if( m_InitialDestinationPath.back() == '/' || m_VFSListingItems.size() > 1 ) {
            // user want to copy/rename/move file(s) to some directory, like "/bin/Abra/Carabra/"
            // OR user want to copy/rename/move file(s) to some directory, like "/bin/Abra/Carabra" and have MANY item to copy/rename/move
            _result_destination = EnsureTrailingSlash( m_InitialDestinationPath );
            return PathCompositionType::PathPreffix;
        }
        else {
            // user want to copy/rename/move file/dir to some filename, like "/bin/abra"
            _result_destination = m_InitialDestinationPath;
            return PathCompositionType::FixedPath;
        }
    }
}


template <class T>
static void ReverseForEachDirectoryInString(const string& _path, T _t)
{
    size_t range_end = _path.npos;
    size_t last_slash;
    while( ( last_slash = _path.find_last_of('/', range_end) ) != _path.npos ) {
        if( !_t(_path.substr(0, last_slash+1)) )
            break;
        if( last_slash == 0)
            break;
        range_end = last_slash - 1;
    }
}

// build directories for every entrance of '/' in m_DestinationPath
// for /bin/abra/cadabra/ will check and build: /bin, /bin/abra, /bin/abra/cadabra
// for /bin/abra/cadabra  will check and build: /bin, /bin/abra
FileCopyOperationJobNew::StepResult FileCopyOperationJobNew::BuildDestinationDirectory() const
{
    // find directories to build
    vector<string> paths_to_build;
    ReverseForEachDirectoryInString( m_DestinationPath, [&](string _path) {
        if( !m_DestinationHost->Exists(_path.c_str()) ) {
            paths_to_build.emplace_back(move(_path));
            return true;
        }
        else
            return false;
    });
    
    // found directories are in a reverse order, so reverse this list
    reverse(begin(paths_to_build), end(paths_to_build));

    // build absent directories. no skipping here - all or nothing.
    constexpr mode_t new_dir_mode = S_IXUSR|S_IXGRP|S_IXOTH|S_IRUSR|S_IRGRP|S_IROTH|S_IWUSR;
    for( auto &path: paths_to_build ) {
        int ret = 0;
        while( (ret = m_DestinationHost->CreateDirectory(path.c_str(), new_dir_mode, nullptr)) < 0 ) {
            switch( m_OnCantCreateDestinationRootDir( ret, path ) ) {
                case OperationDialogResult::Stop:   return StepResult::Stop;
                default:                            continue;
            }
        }
    }
    
    return StepResult::Ok;
}

static bool IsAnExternalExtenedAttributesStorage( VFSHost &_host, const string &_path, const string& _item_name, const VFSStat &_st )
{
    // currently we think that ExtEAs can be only on native VFS
    if( !_host.IsNativeFS() )
        return false;
    
    // any ExtEA should have ._Filename format
    auto cstring = _item_name.c_str();
    if( cstring[0] != '.' || cstring[1] != '_' || cstring[2] == 0 )
        return false;
    
    // check if current filesystem uses external eas
    auto fs_info = NativeFSManager::Instance().VolumeFromDevID( _st.dev );
    if( !fs_info || fs_info->interfaces.extended_attr == true )
        return false;
    
    // check if a 'main' file exists
    char path[MAXPATHLEN];
    strcpy(path, _path.c_str());
    
    // some magick to produce /path/subpath/filename from a /path/subpath/._filename
    char *last_dst = strrchr(path, '/');
    if( !last_dst )
        return false;
    strcpy( last_dst + 1, cstring + 2 );
    
    return _host.Exists( path );
}

tuple<FileCopyOperationJobNew::StepResult, FileCopyOperationJobNew::SourceItems> FileCopyOperationJobNew::ScanSourceItems() const
{
    
    SourceItems db;
    auto stat_flags = m_Options.preserve_symlinks ? VFSFlags::F_NoFollow : 0;

    for( auto&i: m_VFSListingItems ) {
        if( CheckPauseOrStop() )
            return StepResult::Stop;
        
        auto host_indx = db.InsertOrFindHost(i.Host());
        auto &host = db.Host(host_indx);
        auto base_dir_indx = db.InsertOrFindBaseDir(i.Directory());
        function<StepResult(int _parent_ind, const string &_full_relative_path, const string &_item_name)> // need function holder for recursion to work
        scan_item = [this, &db, stat_flags, host_indx, &host, base_dir_indx, &scan_item] (int _parent_ind,
                                                                                          const string &_full_relative_path,
                                                                                          const string &_item_name
                                                                                          ) -> StepResult {
//            cout << _full_relative_path << " | " << _item_name << endl;
            
            // compose a full path for current entry
            string path = db.BaseDir(base_dir_indx) + _full_relative_path;
            
            // gather stat() information regarding current entry
            int ret;
            VFSStat st;
            while( (ret = host.Stat(path.c_str(), st, stat_flags, nullptr)) < 0 ) {
                if( m_SkipAll ) return StepResult::Skipped;
                switch( m_OnCantAccessSourceItem(ret, path) ) {
                    case OperationDialogResult::Skip:       return StepResult::Skipped;
                    case OperationDialogResult::SkipAll:    return StepResult::SkipAll;
                    case OperationDialogResult::Stop:       return StepResult::Stop;
                }
            }
            
            if( S_ISREG(st.mode) ) {
                // check if file is an external EA
                if( IsAnExternalExtenedAttributesStorage(host, path, _item_name, st) )
                    return StepResult::Ok; // we're skipping "._xxx" files as they are processed by OS itself when we copy xattrs
                
                db.InsertItem(host_indx, base_dir_indx, _parent_ind, _item_name, st);
            }
            else if( S_ISLNK(st.mode) ) {
                db.InsertItem(host_indx, base_dir_indx, _parent_ind, _item_name, st);
            }
            else if( S_ISDIR(st.mode) ) {
                int my_indx = db.InsertItem(host_indx, base_dir_indx, _parent_ind, _item_name, st);
                
                vector<string> dir_ents;
                while( (ret = host.IterateDirectoryListing(path.c_str(), [&](auto &_) { return dir_ents.emplace_back(_.name), true; })) < 0 ) {
                        if( m_SkipAll ) return StepResult::Skipped;
                        switch( m_OnCantAccessSourceItem(ret, path) ) {
                            case OperationDialogResult::Skip:       return StepResult::Skipped;
                            case OperationDialogResult::SkipAll:    return StepResult::SkipAll;
                            case OperationDialogResult::Stop:       return StepResult::Stop;
                        }
                        dir_ents.clear();
                }
                
                for( auto &entry: dir_ents ) {
                    if( CheckPauseOrStop() )
                        return StepResult::Stop;
                    
                    // go into recursion
                    scan_item(my_indx,
                              _full_relative_path + '/' + entry,
                              entry);
                }
            }
            
            return StepResult::Ok;
        };
        
        auto result = scan_item(-1,
                                i.Filename(),
                                i.Filename()
                                );
        if( result != StepResult::Ok )
            return result;
    }
    
    return {StepResult::Ok, move(db)};
}

FileCopyOperationJobNew::StepResult FileCopyOperationJobNew::CopyNativeFileToNativeFile(const string& _src_path,
                                                                                        const string& _dst_path,
                                                                                        function<void(const void *_data, unsigned _sz)> _source_data_feedback) const
{
    auto &io = RoutedIO::Default;
    
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
    while( fstat(source_fd, &src_stat_buffer) == -1 ) {
        // failed to stat source
        if( m_SkipAll ) return StepResult::Skipped;
        switch( m_OnCantAccessSourceItem( VFSError::FromErrno(), _src_path ) ) {
            case OperationDialogResult::Skip:       return StepResult::Skipped;
            case OperationDialogResult::SkipAll:    return StepResult::SkipAll;
            case OperationDialogResult::Stop:       return StepResult::Stop;
        }
    }
  
    // find fs info for source file.
    auto src_fs_info_holder = NativeFSManager::Instance().VolumeFromDevID( src_stat_buffer.st_dev );
    if( !src_fs_info_holder )
        return StepResult::Stop; // something VERY BAD has happened, can't go on
    auto &src_fs_info = *src_fs_info_holder;
    
    // setting up copying scenario
    int     dst_open_flags          = 0;
    bool    do_erase_xattrs         = false,
            do_copy_xattrs          = true,
            do_unlink_on_stop       = false,
            do_set_times            = true,
            do_set_unix_flags       = true,
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
            do_copy_xattrs = false;
            do_set_times = false;
            do_set_unix_flags = false;
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
    
    // find fs info for destination file.
    auto dst_fs_info_holder = NativeFSManager::Instance().VolumeFromFD( destination_fd );
    if( !dst_fs_info_holder )
        return StepResult::Stop; // something VERY BAD has happened, can't go on
    auto &dst_fs_info = *dst_fs_info_holder;
    
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
    const uint32_t src_preffered_io_size = src_fs_info.basic.io_size < m_BufferSize ? src_fs_info.basic.io_size : m_BufferSize;
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
        
        // <<<--- writing in secondary thread --->>>
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
        
        // <<<--- reading in current thread --->>>
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
                if(_source_data_feedback)
                    _source_data_feedback(read_buffer + has_read, (unsigned)read_result);
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
        
        // if something bad happened in reading or writing - return from this routine
        if( write_return )
            return *write_return;
        if( read_return )
            return *read_return;
        
        // swap buffers ang go again
        bytes_to_write = has_read;
        swap( read_buffer, write_buffer );
    }
    
    // we're ok, turn off destination cleaning
    clean_destination.disengage();
    
    // do xattr things
    // crazy OSX stuff: setting some xattrs like FinderInfo may actually change file's BSD flags
    if( m_Options.copy_xattrs  ) {
        if(do_erase_xattrs) // erase destination's xattrs
            EraseXattrsFromNativeFD(destination_fd);

        if(do_copy_xattrs) // copy xattrs from src to dest
            CopyXattrsFromNativeFDToNativeFD(source_fd, destination_fd);
    }

    // do flags things
    if( m_Options.copy_unix_flags && do_set_unix_flags ) {
        if(io.isrouted()) // long path
            io.chflags(_dst_path.c_str(), src_stat_buffer.st_flags);
        else
            fchflags(destination_fd, src_stat_buffer.st_flags);
    }

    // do times things
    if( m_Options.copy_file_times && do_set_times )
        AdjustFileTimesForNativeFD(destination_fd, src_stat_buffer);
    
    // do ownage things
    // TODO: we actually can't chown without superuser rights.
    // need to optimize this (sometimes) meaningless call
    if( m_Options.copy_unix_owners ) {
        if( io.isrouted() ) // long path
            io.chown(_dst_path.c_str(), src_stat_buffer.st_uid, src_stat_buffer.st_gid);
        else // short path
            fchown(destination_fd, src_stat_buffer.st_uid, src_stat_buffer.st_gid);
    }
    
    return StepResult::Ok;
}

// uses m_Buffer[0] to reduce mallocs
// currently there's no error handling or reporting here. may need this in the future. maybe.
void FileCopyOperationJobNew::EraseXattrsFromNativeFD(int _fd_in) const
{
    auto xnames = (char*)m_Buffers[0].get();
    auto xnamesizes = flistxattr(_fd_in, xnames, m_BufferSize, 0);
    for( auto s = xnames, e = xnames + xnamesizes; s < e; s += strlen(s) + 1 ) // iterate thru xattr names..
        fremovexattr(_fd_in, s, 0); // ..and remove everyone
}

// uses m_Buffer[0] and m_Buffer[1] to reduce mallocs
// currently there's no error handling or reporting here. may need this in the future. maybe.
void FileCopyOperationJobNew::CopyXattrsFromNativeFDToNativeFD(int _fd_from, int _fd_to) const
{
    auto xnames = (char*)m_Buffers[0].get();
    auto xdata = m_Buffers[1].get();
    auto xnamesizes = flistxattr(_fd_from, xnames, m_BufferSize, 0);
    for( auto s = xnames, e = xnames + xnamesizes; s < e; s += strlen(s) + 1 ) { // iterate thru xattr names..
        auto xattrsize = fgetxattr(_fd_from, s, xdata, m_BufferSize, 0, 0); // and read all these xattrs
        if( xattrsize >= 0 ) // xattr can be zero-length, just a tag itself
            fsetxattr(_fd_to, s, xdata, xattrsize, 0, 0); // write them into _fd_to
    }
}

FileCopyOperationJobNew::StepResult FileCopyOperationJobNew::CopyNativeDirectoryToNativeDirectory(const string& _src_path,
                                                                                                  const string& _dst_path)
{
    auto &io = RoutedIO::Default;
    
    struct stat src_stat_buf;
    if( io.stat(_dst_path.c_str(), &src_stat_buf) != -1 ) {
        // target already exists
        
        if( !S_ISDIR(src_stat_buf.st_mode) ) {
            // ouch - existing entry is not a directory
            // TODO: ask user about this and remove this entry if he agrees
            return StepResult::Ok;
        }
    }
    else {
        // create target directory
        constexpr mode_t new_dir_mode = S_IXUSR|S_IXGRP|S_IXOTH|S_IRUSR|S_IRGRP|S_IROTH|S_IWUSR;
        while( io.mkdir(_dst_path.c_str(), new_dir_mode) == -1  ) {
            // failed to create a directory
            if(m_SkipAll)
                return StepResult::Skipped;
            switch( m_OnCantCreateDestinationDir(VFSError::FromErrno(), _dst_path) ) {
                case OperationDialogResult::Retry:      continue;
                case OperationDialogResult::Skip:       return StepResult::Skipped;
                case OperationDialogResult::SkipAll:    return StepResult::SkipAll;
                default:                                return StepResult::Stop;
            }
        }
        
        
//
    }
    
    // TODO: do attributes stuff
    
    
    
    return StepResult::Ok;
    
//    auto &io = RoutedIO::Default;
//    
//    // TODO: need to handle errors on attributes somehow. but I don't know how.
//    struct stat src_stat, dst_stat;
//    bool opres = false;
//    int src_fd = -1, dst_fd = -1;
//    
//    // check if target already exist
//    if( io.lstat(_dest, &dst_stat) != -1 )
//    {
//        // target exists; check that it's a directory
//        
//        if( (dst_stat.st_mode & S_IFMT) != S_IFDIR )
//        {
//            // TODO: ask user what to do
//            goto end;
//        }
//    }
//    else
//    {
//    domkdir:
//        if(io.mkdir(_dest, 0777))
//        {
//            if(m_SkipAll) goto end;
//            int result = [[m_Operation OnCantCreateDir:ErrnoToNSError() ForDir:_dest] WaitForResult];
//            if(result == OperationDialogResult::Retry) goto domkdir;
//            if(result == OperationDialogResult::Skip) goto end;
//            if(result == OperationDialogResult::SkipAll) {m_SkipAll = true; goto end;}
//            if(result == OperationDialogResult::Stop)  { RequestStop(); goto end; }
//        }
//    }
//    
//    // do attributes stuff
//    if((src_fd = io.open(_src, O_RDONLY)) == -1) goto end;
//    if((dst_fd = io.open(_dest, O_RDONLY)) == -1) goto end;
//    if(fstat(src_fd, &src_stat) != 0) goto end;
//    
//    
//    if(m_Options.copy_unix_flags)
//    {
//        // change unix mode
//        fchmod(dst_fd, src_stat.st_mode);
//        
//        // change flags
//        fchflags(dst_fd, src_stat.st_flags);
//    }
//    
//    if(m_Options.copy_unix_owners) // change ownage
//        io.chown(_dest, src_stat.st_uid, src_stat.st_gid);
//    
//    if(m_Options.copy_xattrs) // copy xattrs
//        CopyXattrs(src_fd, dst_fd);
//    
//    if(m_Options.copy_file_times) // adjust destination times
//        AdjustFileTimes(dst_fd, &src_stat);
//    
//    opres = true;
//end:
//    if(src_fd != -1) io.close(src_fd);
//    if(dst_fd != -1) io.close(dst_fd);
//    return opres;
    
}

////////////////////////////////////////////////////////////////////////////
//  FileCopyOperationJobNew::SourceItems
////////////////////////////////////////////////////////////////////////////


int FileCopyOperationJobNew::SourceItems::InsertItem( uint16_t _host_index, unsigned _base_dir_index, int _parent_index, string _item_name, const VFSStat &_stat )
{
    if( _host_index >= m_SourceItemsHosts.size() ||
        _base_dir_index >= m_SourceItemsBaseDirectories.size() ||
        (_parent_index >= 0 && _parent_index >= m_Items.size() ) )
        throw invalid_argument("FileCopyOperationJobNew::SourceItems::InsertItem: invalid index");

// TODO: stats
    
    SourceItem it;
    it.item_name = S_ISDIR(_stat.mode) ? EnsureTrailingSlash( move(_item_name) ) : move( _item_name );
    it.parent_index = _parent_index;
    it.base_dir_index = _base_dir_index;
    it.host_index = _host_index;
    it.mode = _stat.mode;
    it.dev_num = _stat.dev;
    
    m_Items.emplace_back( move(it) );

//    cout << ComposeFullPath(m_Items.size() - 1) << endl << endl;
    
    return int(m_Items.size() - 1);
}

string FileCopyOperationJobNew::SourceItems::ComposeFullPath( int _item_no ) const
{
    auto rel_path = ComposeRelativePath( _item_no );
    rel_path.insert(0, m_SourceItemsBaseDirectories[ m_Items[_item_no].base_dir_index] );
    return rel_path;
}

string FileCopyOperationJobNew::SourceItems::ComposeRelativePath( int _item_no ) const
{
    auto &meta = m_Items.at(_item_no);
    array<int, 128> parents;
    int parents_num = 0;

    int parent = meta.parent_index;
    while( parent >= 0 ) {
        parents[parents_num++] = parent;
        parent = m_Items[parent].parent_index;
    }
    
    string path;
    for( int i = parents_num - 1; i >= 0; i-- )
        path += m_Items[ parents[i] ].item_name;
        
    path += meta.item_name;
    return path;
}

int FileCopyOperationJobNew::SourceItems::ItemsAmount() const noexcept
{
    return (int)m_Items.size();
}

mode_t FileCopyOperationJobNew::SourceItems::ItemMode( int _item_no ) const
{
    return m_Items.at(_item_no).mode;
}

VFSHost &FileCopyOperationJobNew::SourceItems::ItemHost( int _item_no ) const
{
    return *m_SourceItemsHosts[ m_Items.at(_item_no).host_index ];
}

uint16_t FileCopyOperationJobNew::SourceItems::InsertOrFindHost( const VFSHostPtr &_host )
{
    return (uint16_t)linear_find_or_insert(m_SourceItemsHosts, _host);
}

unsigned FileCopyOperationJobNew::SourceItems::InsertOrFindBaseDir( const string &_dir )
{
    return (unsigned)linear_find_or_insert(m_SourceItemsBaseDirectories, _dir);
}

const string &FileCopyOperationJobNew::SourceItems::BaseDir( unsigned _ind ) const
{
    return m_SourceItemsBaseDirectories.at(_ind);
}

VFSHost &FileCopyOperationJobNew::SourceItems::Host( uint16_t _ind ) const
{
    return *m_SourceItemsHosts.at(_ind);
}

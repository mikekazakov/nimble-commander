#include <sys/xattr.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/param.h>
#include <sys/mount.h>
#include <Habanero/algo.h>
#include <Habanero/Hash.h>
#include <Utility/PathManip.h>
#include <RoutedIO/RoutedIO.h>
#include "CopyingJob.h"
#include "DialogResults.h"
#include "../Statistics.h"
#include "NativeFSHelpers.h"
#include <VFS/Native.h>

using namespace nc::ops::copying;

namespace nc::ops {

CopyingJob::CopyingJob(vector<VFSListingItem> _source_items,
                       const string &_dest_path,
                       const VFSHostPtr &_dest_host,
                       CopyingOptions _opts)
{
    m_VFSListingItems = move(_source_items);
    m_InitialDestinationPath = _dest_path;
    if( m_InitialDestinationPath.empty() || m_InitialDestinationPath.front() != '/' )
        throw invalid_argument("CopyingJobNew::Init: m_InitialDestinationPath should be an absolute path");
    m_DestinationHost = _dest_host;
    m_Options = _opts;
    m_IsSingleInitialItemProcessing = m_VFSListingItems.size() == 1;
        
    if( m_VFSListingItems.empty() )
        cerr << "CopyingJob(..) was called with an empty entries list!" << endl;
    
    Statistics().SetPreferredSource(Statistics::SourceType::Bytes);
}

CopyingJob::~CopyingJob()
{
}

bool CopyingJob::IsSingleInitialItemProcessing() const noexcept
{
    return m_IsSingleInitialItemProcessing;
}

bool CopyingJob::IsSingleScannedItemProcessing() const noexcept
{
    return m_IsSingleScannedItemProcessing;
}

CopyingJob::JobStage CopyingJob::Stage() const noexcept
{
    return m_Stage;
}

void CopyingJob::Perform()
{
    SetState(JobStage::Preparing);

    bool need_to_build = false;
    auto comp_type = AnalyzeInitialDestination(m_DestinationPath, need_to_build);
    if( need_to_build ) {
        if( BuildDestinationDirectory() != StepResult::Ok ) {
            Stop();
            return;
        }
    }
    m_PathCompositionType = comp_type;
 
    if( m_DestinationHost->IsNativeFS() )
        if( !(m_DestinationNativeFSInfo = NativeFSManager::Instance().VolumeFromPath(m_DestinationPath)) ) {
            m_DestinationNativeFSInfo = NativeFSManager::Instance().VolumeFromPathFast(m_DestinationPath); // this may be wrong in case of symlinks
            if( !m_DestinationNativeFSInfo ) {
                Stop(); // we're totally fucked. can't go on
                return;
            }
        }
    
    auto scan_result = ScanSourceItems();
    if( get<0>(scan_result) != StepResult::Ok ) {
        Stop();
        return;
    }
    m_SourceItems = move( get<1>(scan_result) );
    
    m_IsSingleScannedItemProcessing = m_SourceItems.ItemsAmount() == 1;
    
    m_VFSListingItems.clear(); // don't need them anymore
    
    ProcessItems();
    
    if( BlockIfPaused(); IsStopped() )
        return;
}

void CopyingJob::ProcessItems()
{
    SetState(JobStage::Process);

    Statistics().CommitEstimated(Statistics::SourceType::Bytes, m_SourceItems.TotalRegBytes());
    
    const bool dest_host_is_native = m_DestinationHost->IsNativeFS();
    auto is_same_native_volume = [this]( int _index ) {
        return NativeFSManager::Instance().VolumeFromDevID( m_SourceItems.ItemDev(_index) ) == m_DestinationNativeFSInfo;
    };
    
    for( int index = 0, index_end = m_SourceItems.ItemsAmount(); index != index_end; ++index ) {
        m_CurrentlyProcessingSourceItemIndex = index;
        auto source_mode = m_SourceItems.ItemMode(index);
        auto&source_host = m_SourceItems.ItemHost(index);
        auto source_size = m_SourceItems.ItemSize(index);
        auto destination_path = ComposeDestinationNameForItem(index);
        auto source_path = m_SourceItems.ComposeFullPath(index);
        
        StepResult step_result = StepResult::Stop;
        
        if( S_ISREG(source_mode) ) {
            /////////////////////////////////////////////////////////////////////////////////////////////////
            // Regular files
            /////////////////////////////////////////////////////////////////////////////////////////////////
            optional<Hash> hash; // this optional will be filled with the first call of hash_feedback
            auto hash_feedback = [&](const void *_data, unsigned _sz) {
                if( !hash )
                    hash.emplace(Hash::MD5);
                hash->Feed( _data, _sz );
            };

            function<void(const void *_data, unsigned _sz)> data_feedback = nullptr;
            if( m_Options.verification == ChecksumVerification::Always )
                data_feedback = hash_feedback;
            else if( !m_Options.docopy && m_Options.verification >= ChecksumVerification::WhenMoves )
                data_feedback = hash_feedback;
            
            if( source_host.IsNativeFS() && dest_host_is_native ) { // native -> native ///////////////////////
                // native fs processing
                if( m_Options.docopy ) { // copy
                    step_result = CopyNativeFileToNativeFile(source_path, destination_path, data_feedback);
                }
                else {
                    if( is_same_native_volume(index) ) { // rename
                        step_result = RenameNativeFile(source_path, destination_path);
                        if( step_result == StepResult::Ok )
                            Statistics().CommitProcessed(Statistics::SourceType::Bytes, source_size);
                    }
                    else { // move
                        step_result = CopyNativeFileToNativeFile(source_path, destination_path, data_feedback);
                        if( step_result == StepResult::Ok )
                            m_SourceItemsToDelete.emplace_back(index); // mark source file for deletion
                    }
                }
            }
            else if( dest_host_is_native  ) { // vfs -> native ///////////////////////////////////////////////
                if( m_Options.docopy ) { // copy
                    step_result = CopyVFSFileToNativeFile(source_host, source_path, destination_path, data_feedback);
                }
                else { // move
                    step_result = CopyVFSFileToNativeFile(source_host, source_path, destination_path, data_feedback);
                    if( step_result == StepResult::Ok )
                        m_SourceItemsToDelete.emplace_back(index); // mark source file for deletion
                }
            }
            else { // vfs -> vfs /////////////////////////////////////////////////////////////////////////////
                if( m_Options.docopy ) { // copy
                    step_result = CopyVFSFileToVFSFile(source_host, source_path, destination_path, data_feedback);
                }
                else { // move
                    if( &source_host == m_DestinationHost.get() ) { // rename
                        // moving on the same host - lets do rename
                        step_result = RenameVFSFile(source_host, source_path, destination_path);
                        if( step_result == StepResult::Ok )
                            Statistics().CommitProcessed(Statistics::SourceType::Bytes, source_size);
                    }
                    else { // move
                        step_result = CopyVFSFileToVFSFile(source_host, source_path, destination_path, data_feedback);
                        if( step_result == StepResult::Ok )
                            m_SourceItemsToDelete.emplace_back(index); // mark source file for deletion
                    }
                }
            }
            
            // check step result?
            if( hash )
                m_Checksums.emplace_back( index, destination_path, hash->Final() );
        }
        else if( S_ISDIR(source_mode) ) {
            /////////////////////////////////////////////////////////////////////////////////////////////////
            // Directories
            /////////////////////////////////////////////////////////////////////////////////////////////////
            if( source_host.IsNativeFS() && dest_host_is_native ) { // native -> native
                if( m_Options.docopy ) { // copy
                    step_result = CopyNativeDirectoryToNativeDirectory(source_path, destination_path);
                }
                else { // move
                    if( is_same_native_volume(index) ) { // rename
                        step_result = RenameNativeFile(source_path, destination_path);
                    }
                    else { // move
                        step_result = CopyNativeDirectoryToNativeDirectory(source_path, destination_path);
                        if( step_result == StepResult::Ok )
                            m_SourceItemsToDelete.emplace_back(index); // mark source file for deletion
                    }
                }
            }
            else if( dest_host_is_native  ) { // vfs -> native
                step_result = CopyVFSDirectoryToNativeDirectory(source_host, source_path, destination_path);
                if( !m_Options.docopy && step_result == StepResult::Ok )
                    m_SourceItemsToDelete.emplace_back(index); // mark source file for deletion
            }
            else {
                if( m_Options.docopy ) { // copy
                    step_result = CopyVFSDirectoryToVFSDirectory(source_host, source_path, destination_path);
                }
                else { // move
                    if( &source_host == m_DestinationHost.get() ) { // moving on the same host - lets do rename
                        step_result = RenameVFSFile(source_host, source_path, destination_path);
                    }
                    else {
                        step_result = CopyVFSDirectoryToVFSDirectory(source_host, source_path, destination_path);
                        if( !m_Options.docopy && step_result == StepResult::Ok )
                            m_SourceItemsToDelete.emplace_back(index); // mark source file for deletion
                    }
                }
                
            }
        }
        else if( S_ISLNK(source_mode) ) {
            step_result = ProcessSymlinkItem(source_host, source_path, destination_path);
        }

        // check current item result
        if( step_result == StepResult::Stop) {
            Stop();
            return;
        }
        if( BlockIfPaused(); IsStopped() )
            return;
    }
    
    bool all_matched = true;
    if( !m_Checksums.empty() ) {
        SetState(JobStage::Verify);
        for( auto &item: m_Checksums ) {
            bool matched = false;
            auto step_result = VerifyCopiedFile(item, matched);            
            if( step_result != StepResult::Ok || matched != true ) {
                m_OnFileVerificationFailed( item.destination_path, *m_DestinationHost );
                all_matched = false;
            }
        }
    }
    
    if( BlockIfPaused(); IsStopped() )
        return;

    // be sure to all it only if ALL previous steps wre OK.
    if( all_matched ) {
        SetState(JobStage::Cleaning);
        CleanSourceItems();
    }
}
    
CopyingJob::StepResult CopyingJob::ProcessSymlinkItem(VFSHost& _source_host,
                                                      const string &_source_path,
                                                      const string &_destination_path)
{
    const auto dest_host_is_native = m_DestinationHost->IsNativeFS();
    if( _source_host.IsNativeFS() && dest_host_is_native ) { // native -> native
        if( m_Options.docopy ) {
            return CopyNativeSymlinkToNative(_source_path, _destination_path);
        }
        else {
            const auto item_dev = m_SourceItems.ItemDev(m_CurrentlyProcessingSourceItemIndex);
            const auto item_fs_info = NativeFSManager::Instance().VolumeFromDevID( item_dev );
            const auto is_same_native_volume = item_fs_info == m_DestinationNativeFSInfo;
            if( is_same_native_volume ) {
                return RenameNativeFile(_source_path, _destination_path);
            }
            else {
                const auto result = CopyNativeSymlinkToNative(_source_path, _destination_path);
                if( result == StepResult::Ok ) // mark source file for deletion
                    m_SourceItemsToDelete.emplace_back(m_CurrentlyProcessingSourceItemIndex);
                return result;
            }
        }
    }
    else if( dest_host_is_native  ) { // vfs -> native
        const auto result = CopyVFSSymlinkToNative(_source_host, _source_path, _destination_path);
        if( m_Options.docopy == false && result == StepResult::Ok)
            m_SourceItemsToDelete.emplace_back(m_CurrentlyProcessingSourceItemIndex);
        return result;
    }
    else { // vfs -> vfs
        const auto result = CopyVFSSymlinkToVFS(_source_host, _source_path, _destination_path);
        if( m_Options.docopy == false && result == StepResult::Ok)
            m_SourceItemsToDelete.emplace_back(m_CurrentlyProcessingSourceItemIndex);
        return result;
    }
    return StepResult::Stop;
}

string CopyingJob::ComposeDestinationNameForItem( int _src_item_index ) const
{
//    PathPreffix, // path = dest_path + source_rel_path
//    FixedPath    // path = dest_path + [source_rel_path without heading]
    if( m_PathCompositionType == PathCompositionType::PathPreffix ) {
        auto path = m_SourceItems.ComposeRelativePath(_src_item_index);
        path.insert(0, m_DestinationPath);
        return path;
    }
    else {
        auto result = m_DestinationPath;
        auto src = m_SourceItems.ComposeRelativePath(_src_item_index);
        if( m_IsSingleInitialItemProcessing ) {
            // for top level we need to just leave path without changes - skip top level's entry name.
            // for nested entries we need to cut first part of a path.
            //            if(strchr(_path, '/') != 0)
            //                strcat(destinationpath, strchr(_path, '/'));
            //        }
            auto sl = src.find('/');
            if( sl != src.npos )
                result += src.c_str() + sl;
        }
        return result;
    }
}

// side-effects: none.
static bool IsSingleDirectoryCaseRenaming( const CopyingOptions &_options, const vector<VFSListingItem> &_items, const VFSHostPtr& _dest_host, const VFSStat &_dest_stat )
{
    if( !S_ISDIR(_dest_stat.mode) )
        return false;

    if( _options.docopy )
        return false;

    if( _items.size() != 1 )
        return false;
    
    if( !_items.front().Host()->IsNativeFS()  )
        return false;
    
    if( _items.front().Host() != _dest_host )
        return false;
    
    if( !_items.front().IsDir() )
        return false;
    
    if( _items.front().Inode() != _dest_stat.inode )
        return false;
    
    return true;
}

CopyingJob::PathCompositionType CopyingJob::AnalyzeInitialDestination(string &_result_destination, bool &_need_to_build) const
{
    VFSStat st;
    if( m_DestinationHost->Stat(m_InitialDestinationPath.c_str(), st, 0, nullptr ) == 0) {
        // destination entry already exist
        if( S_ISDIR(st.mode) &&
            !IsSingleDirectoryCaseRenaming(m_Options, m_VFSListingItems, m_DestinationHost, st) // special exception for renaming a single directory on native case-insensitive fs
           ) {
            _result_destination = EnsureTrailingSlash( m_InitialDestinationPath );
            return PathCompositionType::PathPreffix;
        }
        else {
            _result_destination = m_InitialDestinationPath;
            return PathCompositionType::FixedPath; // if we have more than one item - it will cause "item already exist" on a second one
        }
    }
    else {
        // TODO: check single-item mode here?
        // destination entry is non-existent
        _need_to_build = true;
        if( m_InitialDestinationPath.back() == '/' || m_VFSListingItems.size() > 1 ) {
            // user want to copy/rename/move file(s) to some directory, like "/bin/Abra/Carabra/"
            // OR user want to copy/rename/move file(s) to some directory, like "/bin/Abra/Carabra" and have MANY items to copy/rename/move
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
CopyingJob::StepResult CopyingJob::BuildDestinationDirectory() const
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
        while( true ) {
            const auto rc = m_DestinationHost->CreateDirectory(path.c_str(), new_dir_mode);
            if( rc == VFSError::Ok )
                break;
            switch( m_OnCantCreateDestinationRootDir(rc, path, *m_DestinationHost) ) {
                    case CantCreateDestinationRootDirResolution::Stop: return StepResult::Stop;
                    case CantCreateDestinationRootDirResolution::Retry: continue;
            };
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

tuple<CopyingJob::StepResult, SourceItems> CopyingJob::ScanSourceItems()
{
    
    SourceItems db;
    auto stat_flags = m_Options.preserve_symlinks ? VFSFlags::F_NoFollow : 0;

    for( auto&i: m_VFSListingItems ) {
        if( BlockIfPaused(); IsStopped() )
            return {StepResult::Stop};
        
        auto host_indx = db.InsertOrFindHost(i.Host());
        auto &host = db.Host(host_indx);
        auto base_dir_indx = db.InsertOrFindBaseDir(i.Directory());
        function<StepResult(int _parent_ind, const string &_full_relative_path, const string &_item_name)> // need function holder for recursion to work
        scan_item = [this, &db, stat_flags, host_indx, &host, base_dir_indx, &scan_item] (int _parent_ind,
                                                                                          const string &_full_relative_path,
                                                                                          const string &_item_name
                                                                                          ) -> StepResult {
            // compose a full path for current entry
            string path = db.BaseDir(base_dir_indx) + _full_relative_path;
            
            // gather stat() information regarding current entry
            VFSStat st;
            while( true ) {
                const auto rc = host.Stat(path.c_str(), st, stat_flags, nullptr);
                if( rc == VFSError::Ok )
                    break;
                switch( m_OnCantAccessSourceItem(rc, path, host) ) {
                    case CantAccessSourceItemResolution::Skip: return StepResult::Skipped;
                    case CantAccessSourceItemResolution::Stop: return StepResult::Stop;
                    case CantAccessSourceItemResolution::Retry: continue;
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
                
                bool should_go_inside =
                    m_Options.docopy ||
                    &host != &*m_DestinationHost || // comparing hosts by their addresses. which is NOT GREAT at all
                    (m_DestinationHost->IsNativeFS() && m_DestinationNativeFSInfo != NativeFSManager::Instance().VolumeFromDevID(st.dev) );
                if( should_go_inside ) {
                    vector<string> dir_ents;
                    while( true ) {
                        const auto callback = [&](auto &_) {
                            dir_ents.emplace_back(_.name);
                            return true;
                        };
                        const auto rc = host.IterateDirectoryListing(path.c_str(), callback);
                        if( rc == VFSError::Ok )
                            break;
                        switch( m_OnCantAccessSourceItem(rc, path, host) ) {
                            case CantAccessSourceItemResolution::Skip:  return StepResult::Skipped;
                            case CantAccessSourceItemResolution::Stop:  return StepResult::Stop;
                            case CantAccessSourceItemResolution::Retry: continue;
                        }
                    }
                    
                    for( auto &entry: dir_ents ) {
                        if( BlockIfPaused(); IsStopped() )
                            return StepResult::Stop;
                        
                        // go into recursion
                        scan_item(my_indx,
                                  _full_relative_path + '/' + entry,
                                  entry);
                    }
                }
            }
            
            return StepResult::Ok;
        };
        
        auto result = scan_item(-1,
                                i.Filename(),
                                i.Filename()
                                );
        if( result != StepResult::Ok )
            return {result};
    }
    
    return {StepResult::Ok, move(db)};
}


//////////////////////////////////////////////////////////////////////////////////////////////////////////
// native file -> native file copying routine
//////////////////////////////////////////////////////////////////////////////////////////////////////////

static void TurnIntoBlockingOrThrow( const int _fd )
{
    // get current file descriptor's open flags
    const auto flags = fcntl(_fd, F_GETFL);
    if( flags < 0 )
        throw runtime_error("fcntl(source_fd, F_GETFL) returned a negative value"); // <- if this happens then we're deeply in asshole

    // exclude non-blocking flag for current descriptor, so we will go straight blocking sync next
    const auto rc = fcntl(_fd, F_SETFL, flags & ~O_NONBLOCK);
    if( rc < 0 )
        throw runtime_error("fcntl(source_fd, F_SETFL, fcntl_ret & ~O_NONBLOCK) returned a negative value"); // <- -""-
}

CopyingJob::StepResult CopyingJob::CopyNativeFileToNativeFile(const string& _src_path,
                                                              const string& _dst_path,
                                                              function<void(const void *_data, unsigned _sz)> _source_data_feedback)
{
    auto &io = RoutedIO::Default;
    auto &host = *VFSNativeHost::SharedHost();
    
    // we initially try to open a source file in non-blocking mode, so we can fail early.
    int source_fd = -1;
    while( true ) {
        source_fd = io.open(_src_path.c_str(), O_RDONLY|O_NONBLOCK|O_SHLOCK);
        if( source_fd == -1 )
            source_fd = io.open(_src_path.c_str(), O_RDONLY|O_NONBLOCK);
        if( source_fd >= 0 )
            break;
        switch( m_OnCantAccessSourceItem( VFSError::FromErrno(), _src_path,  host) ) {
            case CantAccessSourceItemResolution::Skip:  return StepResult::Skipped;
            case CantAccessSourceItemResolution::Stop:  return StepResult::Stop;
            case CantAccessSourceItemResolution::Retry: continue;
        }
    }
    
    // be sure to close source file descriptor
    const auto close_source_fd = at_scope_end([&]{
        if( source_fd >= 0 )
            close( source_fd );
    });

    // do not waste OS file cache with one-way data
    fcntl(source_fd, F_NOCACHE, 1);

    TurnIntoBlockingOrThrow(source_fd);
    
    // get information about source file
    struct stat src_stat_buffer;
    while( true ) {
        const auto rc = fstat(source_fd, &src_stat_buffer);
        if( rc == 0 )
            break;
        switch( m_OnCantAccessSourceItem( VFSError::FromErrno(), _src_path, host ) ) {
            case CantAccessSourceItemResolution::Skip:  return StepResult::Skipped;
            case CantAccessSourceItemResolution::Stop:  return StepResult::Stop;
            case CantAccessSourceItemResolution::Retry: continue;
        }
    }
  
    // find fs info for source file.
    auto src_fs_info_holder = NativeFSManager::Instance().VolumeFromDevID( src_stat_buffer.st_dev );
    if( !src_fs_info_holder ) {
        cerr << "Failed to find fs_info for dev_id: " << src_stat_buffer.st_dev << endl;
        return StepResult::Stop; // something VERY BAD has happened, can't go on
    }
    auto &src_fs_info = *src_fs_info_holder;
    
    // setting up copying scenario
    int     dst_open_flags          = 0;
    bool    do_erase_xattrs         = false,
            do_copy_xattrs          = true,
            do_unlink_on_stop       = false,
            do_set_times            = true,
            do_set_unix_flags       = true,
            need_dst_truncate       = false;
    int64_t dst_size_on_stop        = 0,
            total_dst_size          = src_stat_buffer.st_size,
            preallocate_delta       = 0,
            initial_writing_offset  = 0;
    
    // stat destination
    struct stat dst_stat_buffer;
    if( io.stat(_dst_path.c_str(), &dst_stat_buffer) != -1 ) {
        // file already exist. what should we do now?
        const auto setup_overwrite = [&]{
            dst_open_flags = O_WRONLY;
            do_unlink_on_stop = true;
            dst_size_on_stop = 0;
            do_erase_xattrs = true;
            preallocate_delta = src_stat_buffer.st_size - dst_stat_buffer.st_size; // negative value is ok here
            need_dst_truncate = src_stat_buffer.st_size < dst_stat_buffer.st_size;
        };
        const auto setup_append = [&]{
            dst_open_flags = O_WRONLY;
            do_unlink_on_stop = false;
            do_copy_xattrs = false;
            do_set_times = false;
            do_set_unix_flags = false;
            dst_size_on_stop = dst_stat_buffer.st_size;
            total_dst_size += dst_stat_buffer.st_size;
            initial_writing_offset = dst_stat_buffer.st_size;
            preallocate_delta = src_stat_buffer.st_size;
        };
        
        const auto res = m_OnCopyDestinationAlreadyExists(src_stat_buffer, dst_stat_buffer, _dst_path);
        switch( res ) {
            case CopyDestExistsResolution::Skip:
                return StepResult::Skipped;
            case CopyDestExistsResolution::OverwriteOld:
                if( src_stat_buffer.st_mtime <= dst_stat_buffer.st_mtime )
                    return StepResult::Skipped;
            case CopyDestExistsResolution::Overwrite:
                setup_overwrite();
                break;
            case CopyDestExistsResolution::Append:
                setup_append();
                break;
            default:
                return StepResult::Stop;
        }
    }
    else {
        // no dest file - just create it
        dst_open_flags = O_WRONLY|O_CREAT;
        do_unlink_on_stop = true;
        dst_size_on_stop = 0;
        preallocate_delta = src_stat_buffer.st_size;
    }
    
    // open a file descriptor for the destination
    // we want to copy src permissions if options say so or just to put default ones
    int destination_fd = -1;
    while( true ) {
        const mode_t open_mode = m_Options.copy_unix_flags ?
                                    src_stat_buffer.st_mode :
                                    S_IRUSR | S_IWUSR | S_IRGRP;
        const mode_t old_umask = umask( 0 );
        destination_fd = io.open( _dst_path.c_str(), dst_open_flags, open_mode );
        umask(old_umask);
        
        if( destination_fd >= 0 )
            break;
        
        switch( m_OnCantOpenDestinationFile(VFSError::FromErrno(), _dst_path, host) ) {
            case CantOpenDestinationFileResolution::Skip:   return StepResult::Skipped;
            case CantOpenDestinationFileResolution::Stop:   return StepResult::Stop;
            case CantOpenDestinationFileResolution::Retry:  continue;
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
    if( need_dst_truncate ) {
        while( true ) {
            const auto rc = ftruncate(destination_fd, total_dst_size);
            if( rc == 0 )
                break;
            switch( m_OnDestinationFileWriteError(VFSError::FromErrno(), _dst_path, host) ) {
                case DestinationFileWriteErrorResolution::Skip: return StepResult::Skipped;
                case DestinationFileWriteErrorResolution::Stop: return StepResult::Stop;
                case DestinationFileWriteErrorResolution::Retry: continue;
            }
        }
    }
    
    // find the right position in destination file
    if( initial_writing_offset > 0 ) {
        while( true ) {
            const auto rc = lseek(destination_fd, initial_writing_offset, SEEK_SET);
            if( rc >= 0 )
                break;
            switch( m_OnDestinationFileWriteError(VFSError::FromErrno(), _dst_path, host) ) {
                case DestinationFileWriteErrorResolution::Skip: return StepResult::Skipped;
                case DestinationFileWriteErrorResolution::Stop: return StepResult::Stop;
                case DestinationFileWriteErrorResolution::Retry: continue;
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
        if( BlockIfPaused(); IsStopped() )
            return StepResult::Stop;
        
        // <<<--- writing in secondary thread --->>>
        optional<StepResult> write_return; // optional storage for error returning
        m_IOGroup.Run([this, bytes_to_write, destination_fd, write_buffer, dst_preffered_io_size,
            &destination_bytes_written, &write_return, &_dst_path, &host]{
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
                    switch( m_OnDestinationFileWriteError(VFSError::FromErrno(), _dst_path, host) ) {
                        case DestinationFileWriteErrorResolution::Skip: write_return = StepResult::Skipped; return;
                        case DestinationFileWriteErrorResolution::Stop: write_return = StepResult::Stop; return;
                        case DestinationFileWriteErrorResolution::Retry: continue;
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
                if(_source_data_feedback)
                    _source_data_feedback(read_buffer + has_read, (unsigned)read_result);
                source_bytes_read += read_result;
                has_read += read_result;
                to_read -= read_result;
            }
            else if( (read_result < 0) || (++read_loops > max_io_loops) ) {
                switch( m_OnSourceFileReadError(VFSError::FromErrno(), _src_path, host) ) {
                    case SourceFileReadErrorResolution::Skip: read_return = StepResult::Skipped; break;
                    case SourceFileReadErrorResolution::Stop: read_return = StepResult::Stop; break;
                    case SourceFileReadErrorResolution::Retry: continue;
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

        Statistics().CommitProcessed(Statistics::SourceType::Bytes, bytes_to_write);
        
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

//////////////////////////////////////////////////////////////////////////////////////////////////////////
// vfs file -> native file copying routine
//////////////////////////////////////////////////////////////////////////////////////////////////////////
CopyingJob::StepResult CopyingJob::CopyVFSFileToNativeFile(VFSHost &_src_vfs,
                                                           const string& _src_path,
                                                           const string& _dst_path,
                                                           function<void(const void *_data, unsigned _sz)> _source_data_feedback // will be used for checksum calculation for copying verifiyng
    )
{
    auto &io = RoutedIO::Default;
    auto &dst_host = *VFSNativeHost::SharedHost();
    
    // get information about the source file
    VFSStat src_stat_buffer;
    while( true ) {
        const auto rc = _src_vfs.Stat(_src_path.c_str(), src_stat_buffer, 0);
        if( rc == VFSError::Ok )
            break;
        switch( m_OnCantAccessSourceItem( rc, _src_path, _src_vfs ) ) {
            case CantAccessSourceItemResolution::Skip:  return StepResult::Skipped;
            case CantAccessSourceItemResolution::Stop:  return StepResult::Stop;
            case CantAccessSourceItemResolution::Retry: continue;
        }
    }
    
    // create the source file object
    VFSFilePtr src_file;
    while( true ) {
        const auto rc = _src_vfs.CreateFile(_src_path.c_str(), src_file);
        if( rc == VFSError::Ok )
            break;
        switch( m_OnCantAccessSourceItem( rc, _src_path, _src_vfs ) ) {
            case CantAccessSourceItemResolution::Skip:  return StepResult::Skipped;
            case CantAccessSourceItemResolution::Stop:  return StepResult::Stop;
            case CantAccessSourceItemResolution::Retry: continue;
        }
    }
    
    // open the source file
    while( true ) {
        const auto flags = VFSFlags::OF_Read | VFSFlags::OF_ShLock | VFSFlags::OF_NoCache;
        const auto rc = src_file->Open( flags );
        if( rc == VFSError::Ok )
            break;
        switch( m_OnCantAccessSourceItem( rc, _src_path, _src_vfs ) ) {
            case CantAccessSourceItemResolution::Skip:  return StepResult::Skipped;
            case CantAccessSourceItemResolution::Stop:  return StepResult::Stop;
            case CantAccessSourceItemResolution::Retry: continue;
        }
    }
    
    // setting up the copying scenario
    int     dst_open_flags          = 0;
    bool    do_erase_xattrs         = false,
            do_copy_xattrs          = true,
            do_unlink_on_stop       = false,
            do_set_times            = true,
            do_set_unix_flags       = true,
            need_dst_truncate       = false;
    int64_t dst_size_on_stop        = 0,
            total_dst_size          = src_stat_buffer.size,
            preallocate_delta       = 0,
            initial_writing_offset  = 0;
    
    // stat destination
    struct stat dst_stat_buffer;
    if( io.stat(_dst_path.c_str(), &dst_stat_buffer) != -1 ) {
        // file already exist. what should we do now?
        const auto setup_overwrite = [&]{
            dst_open_flags = O_WRONLY;
            do_unlink_on_stop = true;
            dst_size_on_stop = 0;
            do_erase_xattrs = true;
            preallocate_delta = src_stat_buffer.size - dst_stat_buffer.st_size; // negative value is ok here
            need_dst_truncate = src_stat_buffer.size < dst_stat_buffer.st_size;
        };
        const auto setup_append = [&]{
            dst_open_flags = O_WRONLY;
            do_unlink_on_stop = false;
            do_copy_xattrs = false;
            do_set_times = false;
            do_set_unix_flags = false;
            dst_size_on_stop = dst_stat_buffer.st_size;
            total_dst_size += dst_stat_buffer.st_size;
            initial_writing_offset = dst_stat_buffer.st_size;
            preallocate_delta = src_stat_buffer.size;
        };
        
        const auto res = m_OnCopyDestinationAlreadyExists(src_stat_buffer.SysStat(), dst_stat_buffer, _dst_path);
        switch( res ) {
            case CopyDestExistsResolution::Skip:
                return StepResult::Skipped;
            case CopyDestExistsResolution::OverwriteOld:
                if( src_stat_buffer.mtime.tv_sec <= dst_stat_buffer.st_mtime )
                    return StepResult::Skipped;
            case CopyDestExistsResolution::Overwrite:
                setup_overwrite();
                break;
            case CopyDestExistsResolution::Append:
                setup_append();
                break;
            default:
                return StepResult::Stop;
        }
    }
    else {
        // no dest file - just create it
        dst_open_flags = O_WRONLY|O_CREAT;
        do_unlink_on_stop = true;
        dst_size_on_stop = 0;
        preallocate_delta = src_stat_buffer.size;
    }
    
    // open file descriptor for destination
    int destination_fd = -1;
    while( true) {
        // we want to copy src permissions if options say so or just to put default ones
        const mode_t open_mode = m_Options.copy_unix_flags ?
                                    src_stat_buffer.mode :
                                    S_IRUSR | S_IWUSR | S_IRGRP;
        const mode_t old_umask = umask( 0 );
        destination_fd = io.open( _dst_path.c_str(), dst_open_flags, open_mode );
        umask(old_umask);
        
        if( destination_fd >= 0 )
            break;
        
        switch( m_OnCantOpenDestinationFile(VFSError::FromErrno(), _dst_path, dst_host) ) {
            case CantOpenDestinationFileResolution::Skip:   return StepResult::Skipped;
            case CantOpenDestinationFileResolution::Stop:   return StepResult::Stop;
            case CantOpenDestinationFileResolution::Retry:  continue;
        }
    }
    
    // don't forget ot close destination file descriptor anyway
    const auto close_destination = at_scope_end([&]{
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
    if( need_dst_truncate ) {
        while( true  ) {
            const auto rc = ftruncate(destination_fd, total_dst_size);
            if( rc == 0 )
                break;
            switch( m_OnDestinationFileWriteError(VFSError::FromErrno(), _dst_path, dst_host) ) {
                case DestinationFileWriteErrorResolution::Skip: return StepResult::Skipped;
                case DestinationFileWriteErrorResolution::Stop: return StepResult::Stop;
                case DestinationFileWriteErrorResolution::Retry: continue;
            }
        }
    }
    
    // find the right position in destination file
    if( initial_writing_offset > 0 ) {
        while( true ) {
            const auto rc = lseek(destination_fd, initial_writing_offset, SEEK_SET);
            if( rc >= 0 )
                break;
            switch( m_OnDestinationFileWriteError(VFSError::FromErrno(), _dst_path, dst_host) ) {
                case DestinationFileWriteErrorResolution::Skip: return StepResult::Skipped;
                case DestinationFileWriteErrorResolution::Stop: return StepResult::Stop;
                case DestinationFileWriteErrorResolution::Retry: continue;
            }
        }
    }
    
    auto read_buffer = m_Buffers[0].get(), write_buffer = m_Buffers[1].get();
    const uint32_t dst_preffered_io_size = dst_fs_info.basic.io_size < m_BufferSize ? dst_fs_info.basic.io_size : m_BufferSize;
    const uint32_t src_preffered_io_size = src_file->PreferredIOSize() > 0 ?
        src_file->PreferredIOSize() : // use custom IO size for this vfs
        dst_preffered_io_size; // not sure if this is a good idea, but seems to be ok
    constexpr int max_io_loops = 5; // looked in Apple's copyfile() - treat 5 zero-resulting reads/writes as an error
    uint32_t bytes_to_write = 0;
    uint64_t source_bytes_read = 0;
    uint64_t destination_bytes_written = 0;
    
    // read from source within current thread and write to destination within secondary queue
    while( src_stat_buffer.size != destination_bytes_written ) {
        
        // check user decided to pause operation or discard it
        if( BlockIfPaused(); IsStopped() )
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
                    switch( m_OnDestinationFileWriteError(VFSError::FromErrno(), _dst_path, *VFSNativeHost::SharedHost()) ) {
                        case DestinationFileWriteErrorResolution::Skip: write_return = StepResult::Skipped; return;
                        case DestinationFileWriteErrorResolution::Stop: write_return = StepResult::Stop; return;
                        case DestinationFileWriteErrorResolution::Retry: continue;
                    }
                }
            }
        });
        
        // <<<--- reading in current thread --->>>
        // here we handle the case in which source io size is much smaller than dest's io size
        uint32_t to_read = max( src_preffered_io_size, dst_preffered_io_size );
        if( src_stat_buffer.size - source_bytes_read < to_read )
            to_read = uint32_t(src_stat_buffer.size - source_bytes_read);
        uint32_t has_read = 0; // amount of bytes read into buffer this time
        int read_loops = 0; // amount of zero-resulting reads
        optional<StepResult> read_return; // optional storage for error returning
        while( to_read != 0 ) {
            int64_t read_result = src_file->Read(read_buffer + has_read, min(to_read, src_preffered_io_size));
            if( read_result > 0 ) {
                if(_source_data_feedback)
                    _source_data_feedback(read_buffer + has_read, (unsigned)read_result);
                source_bytes_read += read_result;
                has_read += read_result;
                assert( to_read >= read_result ); // regression assert
                to_read -= read_result;
            }
            else if( (read_result < 0) || (++read_loops > max_io_loops) ) {
                switch( m_OnSourceFileReadError((int)read_result, _src_path, _src_vfs) ) {
                    case SourceFileReadErrorResolution::Skip: read_return = StepResult::Skipped; break;
                    case SourceFileReadErrorResolution::Stop: read_return = StepResult::Stop; break;
                    case SourceFileReadErrorResolution::Retry: continue;
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
        
        Statistics().CommitProcessed(Statistics::SourceType::Bytes, bytes_to_write);
        
        // swap buffers ang go again
        bytes_to_write = has_read;
        swap( read_buffer, write_buffer );
    }
    
    // we're ok, turn off destination cleaning
    clean_destination.disengage();
    
    // erase destination's xattrs
    if(m_Options.copy_xattrs && do_erase_xattrs)
        EraseXattrsFromNativeFD(destination_fd);
    
    // copy xattrs from src to dst
    if( m_Options.copy_xattrs && src_file->XAttrCount() > 0 )
        CopyXattrsFromVFSFileToNativeFD(*src_file, destination_fd);
    
    // adjust destination time as source
    if(m_Options.copy_file_times && do_set_times)
        AdjustFileTimesForNativeFD(destination_fd, src_stat_buffer);
    
    // change flags
    if( m_Options.copy_unix_flags && src_stat_buffer.meaning.flags ) {
        if(io.isrouted()) // long path
            io.chflags(_dst_path.c_str(), src_stat_buffer.flags);
        else
            fchflags(destination_fd, src_stat_buffer.flags);
    }
    
    // change ownage
    if(m_Options.copy_unix_owners) {
        if(io.isrouted()) // long path
            io.chown(_dst_path.c_str(), src_stat_buffer.uid, src_stat_buffer.gid);
        else
            fchown(destination_fd, src_stat_buffer.uid, src_stat_buffer.gid);
    }
    
    return StepResult::Ok;
}


CopyingJob::StepResult CopyingJob::CopyVFSFileToVFSFile(VFSHost &_src_vfs,
                                                        const string& _src_path,
                                                        const string& _dst_path,
                                                        function<void(const void *_data, unsigned _sz)> _source_data_feedback // will be used for checksum calculation for copying verifiyng
    )
{
    // get information about the source file
    VFSStat src_stat_buffer;
    while( true ) {
        const auto rc = _src_vfs.Stat(_src_path.c_str(), src_stat_buffer, 0);
        if( rc == VFSError::Ok )
            break;
        switch( m_OnCantAccessSourceItem( rc, _src_path, _src_vfs ) ) {
            case CantAccessSourceItemResolution::Skip:  return StepResult::Skipped;
            case CantAccessSourceItemResolution::Stop:  return StepResult::Stop;
            case CantAccessSourceItemResolution::Retry: continue;
        }
    }
    
    // create the source file object
    VFSFilePtr src_file;
    while( true ) {
        const auto rc = _src_vfs.CreateFile(_src_path.c_str(), src_file);
        if( rc == VFSError::Ok )
            break;
        switch( m_OnCantAccessSourceItem( rc, _src_path, _src_vfs ) ) {
            case CantAccessSourceItemResolution::Skip:  return StepResult::Skipped;
            case CantAccessSourceItemResolution::Stop:  return StepResult::Stop;
            case CantAccessSourceItemResolution::Retry: continue;
        }
    }

    // open source file
    while( true ) {
        const auto flags = VFSFlags::OF_Read | VFSFlags::OF_ShLock | VFSFlags::OF_NoCache;
        const auto rc = src_file->Open(flags);
        if( rc == VFSError::Ok )
            break;
        switch( m_OnCantAccessSourceItem( rc, _src_path, _src_vfs ) ) {
            case CantAccessSourceItemResolution::Skip:  return StepResult::Skipped;
            case CantAccessSourceItemResolution::Stop:  return StepResult::Stop;
            case CantAccessSourceItemResolution::Retry: continue;
        }
    }
    
    // setting up copying scenario
    int     dst_open_flags          = 0;
    bool    do_erase_xattrs         = false,
            do_copy_xattrs          = true,
            do_unlink_on_stop       = false,
            do_set_times            = true,
            do_set_unix_flags       = true,
            need_dst_truncate       = false;
            int64_t dst_size_on_stop= 0,
            total_dst_size          = src_stat_buffer.size,
            initial_writing_offset  = 0;
    
    // stat destination
    VFSStat dst_stat_buffer;
    if( m_DestinationHost->Stat(_dst_path.c_str(), dst_stat_buffer, 0, 0) == 0) {
        // file already exist. what should we do now?
        const auto setup_overwrite = [&]{
            dst_open_flags = VFSFlags::OF_Write | VFSFlags::OF_Truncate | VFSFlags::OF_NoCache;
            do_unlink_on_stop = true;
            dst_size_on_stop = 0;
            do_erase_xattrs = true;
            need_dst_truncate = src_stat_buffer.size < dst_stat_buffer.size;
        };
        const auto setup_append = [&]{
            dst_open_flags = VFSFlags::OF_Write | VFSFlags::OF_Append | VFSFlags::OF_NoCache;
            do_unlink_on_stop = false;
            do_copy_xattrs = false;
            do_set_times = false;
            do_set_unix_flags = false;
            dst_size_on_stop = dst_stat_buffer.size;
            total_dst_size += dst_stat_buffer.size;
            initial_writing_offset = dst_stat_buffer.size;
        };
        
        const auto res = m_OnCopyDestinationAlreadyExists(src_stat_buffer.SysStat(), dst_stat_buffer.SysStat(), _dst_path);
        switch( res ) {
            case CopyDestExistsResolution::Skip:
                return StepResult::Skipped;
            case CopyDestExistsResolution::OverwriteOld:
                if( src_stat_buffer.mtime.tv_sec <= dst_stat_buffer.mtime.tv_sec )
                    return StepResult::Skipped;
            case CopyDestExistsResolution::Overwrite:
                setup_overwrite();
                break;
            case CopyDestExistsResolution::Append:
                setup_append();
                break;
            default:
                return StepResult::Stop;
        }
    }
    else {
        // no dest file - just create it
        dst_open_flags = VFSFlags::OF_Write | VFSFlags::OF_Create | VFSFlags::OF_NoCache;
        do_unlink_on_stop = true;
        dst_size_on_stop = 0;
    }
    
    // open file object for destination
    VFSFilePtr dst_file;
    while( true ) {
        const auto rc = m_DestinationHost->CreateFile(_dst_path.c_str(), dst_file);
        if( rc == VFSError::Ok )
            break;
        switch( m_OnCantOpenDestinationFile(rc, _dst_path, *m_DestinationHost) ) {
            case CantOpenDestinationFileResolution::Skip:   return StepResult::Skipped;
            case CantOpenDestinationFileResolution::Stop:   return StepResult::Stop;
            case CantOpenDestinationFileResolution::Retry:  continue;
        }
    }
    
    // open file itself
    dst_open_flags |= m_Options.copy_unix_flags ?
                      (src_stat_buffer.mode & (S_IRWXU | S_IRWXG | S_IRWXO)) :
                      (S_IRUSR | S_IWUSR | S_IRGRP);
    while( true ) {
        const auto rc = dst_file->Open(dst_open_flags);
        if( rc == VFSError::Ok )
            break;
        switch( m_OnCantOpenDestinationFile(rc, _dst_path, *m_DestinationHost) ) {
            case CantOpenDestinationFileResolution::Skip:   return StepResult::Skipped;
            case CantOpenDestinationFileResolution::Stop:   return StepResult::Stop;
            case CantOpenDestinationFileResolution::Retry:  continue;
        }
    }
    
    // for some circumstances we have to clean up remains if anything goes wrong
    // and do it BEFORE close_destination fires
    auto clean_destination = at_scope_end([&]{
        if( dst_file && dst_file->IsOpened() ) {
            // we need to revert what we've done
            dst_file->Close();
            dst_file.reset();
            if( do_unlink_on_stop == true )
                m_DestinationHost->Unlink(_dst_path.c_str(), 0);
        }
    });

    // tell upload-only vfs'es how much we're going to write
    dst_file->SetUploadSize( src_stat_buffer.size );
    
    // find the right position in destination file
    if( dst_file->Pos() != initial_writing_offset ) {
        while( true ) {
            const auto rc = dst_file->Seek(initial_writing_offset, VFSFile::Seek_Set);
            if( rc >= 0 )
                break;
            switch( m_OnDestinationFileWriteError((int)rc, _dst_path, *m_DestinationHost) ) {
                case DestinationFileWriteErrorResolution::Skip: return StepResult::Skipped;
                case DestinationFileWriteErrorResolution::Stop: return StepResult::Stop;
                case DestinationFileWriteErrorResolution::Retry: continue;
            }
        }
    }
    
    auto read_buffer = m_Buffers[0].get(), write_buffer = m_Buffers[1].get();
    const uint32_t dst_preffered_io_size = m_BufferSize;
    const uint32_t src_preffered_io_size = m_BufferSize;
    constexpr int max_io_loops = 5; // looked in Apple's copyfile() - treat 5 zero-resulting reads/writes as an error
    uint32_t bytes_to_write = 0;
    uint64_t source_bytes_read = 0;
    uint64_t destination_bytes_written = 0;
    
    // read from source within current thread and write to destination within secondary queue
    while( src_stat_buffer.size != destination_bytes_written ) {
        
        // check user decided to pause operation or discard it
        if( BlockIfPaused(); IsStopped() )
            return StepResult::Stop;

        
        // <<<--- writing in secondary thread --->>>
        optional<StepResult> write_return; // optional storage for error returning
        m_IOGroup.Run([this, bytes_to_write, &dst_file, write_buffer, dst_preffered_io_size, &destination_bytes_written, &write_return, &_dst_path]{
            uint32_t left_to_write = bytes_to_write;
            uint32_t has_written = 0; // amount of bytes written into destination this time
            int write_loops = 0;
            while( left_to_write > 0 ) {
//                int64_t n_written = write(destination_fd, write_buffer + has_written, min(left_to_write, dst_preffered_io_size) );
                int64_t n_written = dst_file->Write( write_buffer + has_written, min(left_to_write, dst_preffered_io_size) );
                if( n_written > 0 ) {
                    has_written += n_written;
                    left_to_write -= n_written;
                    destination_bytes_written += n_written;
                }
                else if( n_written < 0 || (++write_loops > max_io_loops) ) {
                    switch( m_OnDestinationFileWriteError((int)n_written, _dst_path, *m_DestinationHost) ) {
                        case DestinationFileWriteErrorResolution::Skip: write_return = StepResult::Skipped; return;
                        case DestinationFileWriteErrorResolution::Stop: write_return = StepResult::Stop; return;
                        case DestinationFileWriteErrorResolution::Retry: continue;
                    }
                }
            }
        });
        
        // <<<--- reading in current thread --->>>
        // here we handle the case in which source io size is much smaller than dest's io size
        uint32_t to_read = max( src_preffered_io_size, dst_preffered_io_size );
        if( src_stat_buffer.size - source_bytes_read < to_read )
            to_read = uint32_t(src_stat_buffer.size - source_bytes_read);
        uint32_t has_read = 0; // amount of bytes read into buffer this time
        int read_loops = 0; // amount of zero-resulting reads
        optional<StepResult> read_return; // optional storage for error returning
        while( to_read != 0 ) {
            int64_t read_result =  src_file->Read(read_buffer + has_read, min(to_read, src_preffered_io_size));
            if( read_result > 0 ) {
                if(_source_data_feedback)
                    _source_data_feedback(read_buffer + has_read, (unsigned)read_result);
                source_bytes_read += read_result;
                has_read += read_result;
                to_read -= read_result;
            }
            else if( (read_result < 0) || (++read_loops > max_io_loops) ) {
                switch( m_OnSourceFileReadError((int)read_result, _src_path, _src_vfs) ) {
                    case SourceFileReadErrorResolution::Skip: read_return = StepResult::Skipped; break;
                    case SourceFileReadErrorResolution::Stop: read_return = StepResult::Stop; break;
                    case SourceFileReadErrorResolution::Retry: continue;
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
        
        Statistics().CommitProcessed(Statistics::SourceType::Bytes, bytes_to_write);
        
        // swap buffers ang go again
        bytes_to_write = has_read;
        swap( read_buffer, write_buffer );
    }
    
    // we're ok, turn off destination cleaning
    clean_destination.disengage();
    
    
    // TODO:
    // xattrs
    // owners
    // flags
    // file times
    
    return StepResult::Ok;
}

// uses m_Buffer[0] to reduce mallocs
// currently there's no error handling or reporting here. may need this in the future. maybe.
void CopyingJob::EraseXattrsFromNativeFD(int _fd_in) const
{
    auto xnames = (char*)m_Buffers[0].get();
    auto xnamesizes = flistxattr(_fd_in, xnames, m_BufferSize, 0);
    for( auto s = xnames, e = xnames + xnamesizes; s < e; s += strlen(s) + 1 ) // iterate thru xattr names..
        fremovexattr(_fd_in, s, 0); // ..and remove everyone
}

// uses m_Buffer[0] and m_Buffer[1] to reduce mallocs
// currently there's no error handling or reporting here. may need this in the future. maybe.
void CopyingJob::CopyXattrsFromNativeFDToNativeFD(int _fd_from, int _fd_to) const
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

void CopyingJob::CopyXattrsFromVFSFileToNativeFD(VFSFile& _source, int _fd_to) const
{
    auto buf = m_Buffers[0].get();
    size_t buf_sz = m_BufferSize;
    _source.XAttrIterateNames([&](const char *name){
        ssize_t res = _source.XAttrGet(name, buf, buf_sz);
        if(res >= 0)
            fsetxattr(_fd_to, name, buf, res, 0, 0);
        return true;
    });
}

void CopyingJob::CopyXattrsFromVFSFileToPath(VFSFile& _file, const char *_fn_to) const
{
    auto buf = m_Buffers[0].get();
    size_t buf_sz = m_BufferSize;
    
    _file.XAttrIterateNames(^bool(const char *name){
        ssize_t res = _file.XAttrGet(name, buf, buf_sz);
        if(res >= 0)
            setxattr(_fn_to, name, buf, res, 0, 0);
        return true;
    });
}

CopyingJob::StepResult CopyingJob::CopyNativeDirectoryToNativeDirectory(const string& _src_path,
                                                                        const string& _dst_path) const
{
    auto &io = RoutedIO::Default;
    auto &host = *VFSNativeHost::SharedHost();
    
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
        // create the target directory
        const auto new_dir_mode = S_IXUSR|S_IXGRP|S_IXOTH|S_IRUSR|S_IRGRP|S_IROTH|S_IWUSR;
        while( true ) {
            const auto rc = io.mkdir(_dst_path.c_str(), new_dir_mode);
            if( rc == 0 )
                break;
            switch( m_OnCantCreateDestinationDir(VFSError::FromErrno(), _dst_path, host) ) {
                case CantCreateDestinationDirResolution::Skip: return StepResult::Skipped;
                case CantCreateDestinationDirResolution::Stop: return StepResult::Stop;
                case CantCreateDestinationDirResolution::Retry: continue;
            }
        }
    }
    
    // do attributes stuff
    // we currently ignore possible errors on attributes copying, which is not great at all
    int src_fd = io.open(_src_path.c_str(), O_RDONLY);
    if( src_fd == -1 )
        return StepResult::Ok;
    auto clean_src_fd = at_scope_end([&]{ close(src_fd); });

    int dst_fd = io.open(_dst_path.c_str(), O_RDONLY); // strangely this works
    if( dst_fd == -1 )
        return StepResult::Ok;
    auto clean_dst_fd = at_scope_end([&]{ close(dst_fd); });
    
    struct stat src_stat;
    if( fstat(src_fd, &src_stat) != 0 )
        return StepResult::Ok;
    
    if(m_Options.copy_unix_flags) {
        // change unix mode
        fchmod(dst_fd, src_stat.st_mode);
        
        // change flags
        fchflags(dst_fd, src_stat.st_flags);
    }
    
    if(m_Options.copy_unix_owners) // change ownage
        io.chown(_dst_path.c_str(), src_stat.st_uid, src_stat.st_gid);
    
    if(m_Options.copy_xattrs) // copy xattrs
        CopyXattrsFromNativeFDToNativeFD(src_fd, dst_fd);
    
    if(m_Options.copy_file_times) // adjust destination times
        AdjustFileTimesForNativeFD(dst_fd, src_stat);
    
    return StepResult::Ok;
}

CopyingJob::StepResult CopyingJob::CopyVFSDirectoryToNativeDirectory(VFSHost &_src_vfs,
                                                                     const string& _src_path,
                                                                     const string& _dst_path) const
{
    auto &io = RoutedIO::Default;
    auto &dst_host = *VFSNativeHost::SharedHost();
    
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
        const auto new_dir_mode = S_IXUSR|S_IXGRP|S_IXOTH|S_IRUSR|S_IRGRP|S_IROTH|S_IWUSR;
        while( true ) {
            const auto rc = io.mkdir(_dst_path.c_str(), new_dir_mode);
            if( rc == 0 )
                break;
            switch( m_OnCantCreateDestinationDir(VFSError::FromErrno(), _dst_path, dst_host) ) {
                case CantCreateDestinationDirResolution::Skip: return StepResult::Skipped;
                case CantCreateDestinationDirResolution::Stop: return StepResult::Stop;
                case CantCreateDestinationDirResolution::Retry: continue;
            }
        }
    }
    
    
    // do attributes stuff
    // we currently ignore possible errors on attributes copying, which is not great at all
    
    VFSStat src_stat_buffer;
    if( _src_vfs.Stat(_src_path.c_str(), src_stat_buffer, 0, 0) < 0 )
        return StepResult::Ok;
    
    if( m_Options.copy_file_times )
        AdjustFileTimesForNativePath( _dst_path.c_str(), src_stat_buffer );
    
    if(m_Options.copy_unix_flags) {
        // change unix mode
        mode_t mode = src_stat_buffer.mode;
        if( (mode & (S_IRWXU | S_IRWXG | S_IRWXO)) == 0)
            mode |= S_IRWXU | S_IRGRP | S_IXGRP; // guard against malformed(?) archives
        io.chmod(_dst_path.c_str(), mode);
        
        // change flags
        if( src_stat_buffer.meaning.flags )
            io.chflags(_dst_path.c_str(), src_stat_buffer.flags);
    }
    
    // xattr processing
    if( m_Options.copy_xattrs ) {
        shared_ptr<VFSFile> src_file;
        if(_src_vfs.CreateFile(_src_path.c_str(), src_file, 0) >= 0)
            if( src_file->Open(VFSFlags::OF_Read | VFSFlags::OF_Directory | VFSFlags::OF_ShLock) >= 0 )
                if( src_file->XAttrCount() > 0 )
                    CopyXattrsFromVFSFileToPath(*src_file, _dst_path.c_str() );
    }
    
    return StepResult::Ok;
}

CopyingJob::StepResult CopyingJob::CopyVFSDirectoryToVFSDirectory(VFSHost &_src_vfs,
                                                                  const string& _src_path,
                                                                  const string& _dst_path) const
{
    VFSStat src_st;
    while( true ) {
        const auto rc = _src_vfs.Stat(_src_path.c_str(), src_st, 0);
        if( rc == VFSError::Ok )
            break;
        switch( m_OnCantAccessSourceItem(rc, _dst_path, _src_vfs) ) {
            case CantAccessSourceItemResolution::Skip: return StepResult::Skipped;
            case CantAccessSourceItemResolution::Stop: return StepResult::Stop;
            case CantAccessSourceItemResolution::Retry:continue;
        }
    }

   VFSStat dest_st;
    if( m_DestinationHost->Stat( _dst_path.c_str(), dest_st, VFSFlags::F_NoFollow, 0) == 0) {
        // this directory already exist. currently do nothing, later - update it's attrs.
    }
    else {
        while( true ) {
            const auto rc = m_DestinationHost->CreateDirectory(_dst_path.c_str(), src_st.mode);
            if( rc == VFSError::Ok )
                break;
            switch( m_OnCantCreateDestinationDir(rc, _dst_path, *m_DestinationHost) ) {
                case CantCreateDestinationDirResolution::Skip: return StepResult::Skipped;
                case CantCreateDestinationDirResolution::Stop: return StepResult::Stop;
                case CantCreateDestinationDirResolution::Retry: continue;
            }
        }
    }
    
    // no attrs currently
    
    return StepResult::Ok;
}

CopyingJob::StepResult CopyingJob::RenameNativeFile(const string& _src_path,
                                                    const string& _dst_path) const
{
    auto &io = RoutedIO::Default;
    auto &host = *VFSNativeHost::SharedHost();
    
    // check if destination file already exist
    struct stat dst_stat_buffer;
    if( io.lstat(_dst_path.c_str(), &dst_stat_buffer) != -1 ) {
        // Destination file already exists.
        // Check if destination and source paths reference the same file. In this case,
        // silently rename the file.
        
        struct stat src_stat_buffer;
        while( true ) {
            const auto rc = io.lstat(_src_path.c_str(), &src_stat_buffer);
            if( rc == 0 )
                break;
            switch( m_OnCantAccessSourceItem( VFSError::FromErrno(), _src_path, host) ) {
                case CantAccessSourceItemResolution::Skip:  return StepResult::Skipped;
                case CantAccessSourceItemResolution::Stop:  return StepResult::Stop;
                case CantAccessSourceItemResolution::Retry: continue;
            }
        }
        
        if( src_stat_buffer.st_dev != dst_stat_buffer.st_dev ||
            src_stat_buffer.st_ino != dst_stat_buffer.st_ino ) {
            // files are different, so renaming into _dst_path will erase it.
            // need to ask user what to do
            const auto res = m_OnRenameDestinationAlreadyExists(src_stat_buffer,
                                                                dst_stat_buffer,
                                                                _dst_path);
            switch( res ) {
                case RenameDestExistsResolution::Skip:
                    return StepResult::Skipped;
                case RenameDestExistsResolution::OverwriteOld:
                    if( src_stat_buffer.st_mtime <= dst_stat_buffer.st_mtime )
                        return StepResult::Skipped;
                case RenameDestExistsResolution::Overwrite:
                    break;
                default:
                    return StepResult::Stop;
            }
        }
    }
    
    // do the rename itself
    while( true ) {
        const auto rc = io.rename(_src_path.c_str(), _dst_path.c_str());
        if( rc == 0 )
            break;
        switch( m_OnDestinationFileWriteError(VFSError::FromErrno(), _dst_path, host) ) {
            case DestinationFileWriteErrorResolution::Skip: return StepResult::Skipped;
            case DestinationFileWriteErrorResolution::Stop: return StepResult::Stop;
            case DestinationFileWriteErrorResolution::Retry: continue;
        }
    }
    
    return StepResult::Ok;
}

CopyingJob::StepResult CopyingJob::RenameVFSFile(VFSHost &_common_host,
                                                 const string& _src_path,
                                                 const string& _dst_path) const
{
    // check if destination file already exist
    VFSStat dst_stat_buffer;
    if( _common_host.Stat(_dst_path.c_str(), dst_stat_buffer, VFSFlags::F_NoFollow) == 0 ) {
        // Destination file already exists.
        
        VFSStat src_stat_buffer;
        while( true ) {
            const auto rc = _common_host.Stat(_src_path.c_str(), src_stat_buffer, VFSFlags::F_NoFollow);
            if( rc == VFSError::Ok )
                break;
            switch( m_OnCantAccessSourceItem( rc, _src_path, _common_host ) ) {
                case CantAccessSourceItemResolution::Skip:  return StepResult::Skipped;
                case CantAccessSourceItemResolution::Stop:  return StepResult::Stop;
                case CantAccessSourceItemResolution::Retry: continue;
            }
        }
        
        // renaming into _dst_path will erase it. need to ask user what to do
        const auto res = m_OnRenameDestinationAlreadyExists(src_stat_buffer.SysStat(),
                                                            dst_stat_buffer.SysStat(),
                                                            _dst_path);
        switch( res ) {
            case RenameDestExistsResolution::Skip:
                return StepResult::Skipped;
            case RenameDestExistsResolution::OverwriteOld:
                if( src_stat_buffer.mtime.tv_nsec <= dst_stat_buffer.mtime.tv_nsec )
                    return StepResult::Skipped;
            case RenameDestExistsResolution::Overwrite:
                break;
            default:
                return StepResult::Stop;
        }
    }

    // do rename itself
    while( true ) {
        const auto rc = _common_host.Rename(_src_path.c_str(), _dst_path.c_str());
        if( rc == VFSError::Ok )
            break;
        switch( m_OnDestinationFileWriteError(rc, _dst_path, _common_host) ) {
            case DestinationFileWriteErrorResolution::Skip: return StepResult::Skipped;
            case DestinationFileWriteErrorResolution::Stop: return StepResult::Stop;
            case DestinationFileWriteErrorResolution::Retry: continue;
        }
    }
    
    return StepResult::Ok;
}

void CopyingJob::CleanSourceItems() const
{
    for( auto i = rbegin(m_SourceItemsToDelete), e = rend(m_SourceItemsToDelete); i != e; ++i ) {
        auto index = *i;
        auto mode = m_SourceItems.ItemMode(index);
        auto&host = m_SourceItems.ItemHost(index);
        auto source_path = m_SourceItems.ComposeFullPath(index);
        
        // maybe any error handling here?
        if( S_ISDIR(mode) )
            host.RemoveDirectory( source_path.c_str() );
        else
            host.Unlink( source_path.c_str() );
    }
}

CopyingJob::StepResult CopyingJob::VerifyCopiedFile(const ChecksumExpectation& _exp, bool &_matched)
{
    _matched = false;
    VFSFilePtr file;
    int rc;
    if( (rc = m_DestinationHost->CreateFile( _exp.destination_path.c_str(), file, nullptr )) != 0)
        switch( m_OnDestinationFileReadError( rc, _exp.destination_path, *m_DestinationHost ) ) {
            case DestinationFileReadErrorResolution::Skip:     return StepResult::Skipped;
            case DestinationFileReadErrorResolution::Stop:     return StepResult::Stop;
        }

    if( (rc = file->Open( VFSFlags::OF_Read | VFSFlags::OF_ShLock | VFSFlags::OF_NoCache )) != 0)
        switch( m_OnDestinationFileReadError( rc, _exp.destination_path, *m_DestinationHost ) ) {
            case DestinationFileReadErrorResolution::Skip:     return StepResult::Skipped;
            case DestinationFileReadErrorResolution::Stop:     return StepResult::Stop;
        }
    
    Hash hash(Hash::MD5);
    
    uint64_t sz = file->Size();
    uint64_t szleft = sz;
    void *buf = m_Buffers[0].get();
    uint64_t buf_sz = m_BufferSize;

    while( szleft > 0 ) {
        if( BlockIfPaused(); IsStopped() )
            return StepResult::Stop;

        ssize_t r = file->Read(buf, min(szleft, buf_sz));
        if(r < 0) {
            switch( m_OnDestinationFileReadError( (int)r, _exp.destination_path, *m_DestinationHost ) ) {
                case DestinationFileReadErrorResolution::Skip:     return StepResult::Skipped;
                case DestinationFileReadErrorResolution::Stop:     return StepResult::Stop;
            }
        }
        else {
            szleft -= r;
            hash.Feed(buf, r);
        }
    }
    file->Close();

    _matched = _exp == hash.Final();
    return StepResult::Ok;
}

CopyingJob::StepResult CopyingJob::CopyNativeSymlinkToNative(const string& _src_path,
                                                             const string& _dst_path) const
{
    auto &io = RoutedIO::Default;
    auto &host = *VFSNativeHost::SharedHost();
    
    char linkpath[MAXPATHLEN];
    while( true ) {
        const auto sz = io.readlink(_src_path.c_str(), linkpath, MAXPATHLEN);
        if( sz >= 0 ) {
            linkpath[sz] = 0;
            break;
        }
        switch( m_OnCantAccessSourceItem( VFSError::FromErrno(), _src_path,  host) ) {
            case CantAccessSourceItemResolution::Skip:  return StepResult::Skipped;
            case CantAccessSourceItemResolution::Stop:  return StepResult::Stop;
            case CantAccessSourceItemResolution::Retry: continue;
        }
    }
    
    struct stat dst_stat_buffer;
    if( io.lstat(_dst_path.c_str(), &dst_stat_buffer) == 0 ) {
        struct stat src_stat_buffer;
        while( true ) {
            const auto rc = io.lstat(_src_path.c_str(), &src_stat_buffer);
            if( rc == 0 )
                break;
            switch( m_OnCantAccessSourceItem( VFSError::FromErrno(), _src_path, host) ) {
                case CantAccessSourceItemResolution::Skip:  return StepResult::Skipped;
                case CantAccessSourceItemResolution::Stop:  return StepResult::Stop;
                case CantAccessSourceItemResolution::Retry: continue;
            }
        }
        
        if( src_stat_buffer.st_dev == dst_stat_buffer.st_dev &&
            src_stat_buffer.st_ino == dst_stat_buffer.st_ino ) {
            // symlinks have the same inode - it's the same object => we're done.
            return StepResult::Ok;
        }
        
        // different objects, need to erase destination before calling symlink()
        // need to ask user what to do
        const auto res = m_OnRenameDestinationAlreadyExists(src_stat_buffer,
                                                            dst_stat_buffer,
                                                            _dst_path);
        switch( res ) {
            case RenameDestExistsResolution::Skip:
                return StepResult::Skipped;
            case RenameDestExistsResolution::OverwriteOld:
                if( src_stat_buffer.st_mtime <= dst_stat_buffer.st_mtime )
                    return StepResult::Skipped;
            case RenameDestExistsResolution::Overwrite:
                break;
            default:
                return StepResult::Stop;
        }
        
        // NEED something like io.trash()!
        if( host.Trash(_dst_path.c_str(), nullptr) != VFSError::Ok ) {
            while( true ) {
                const auto rc = S_ISDIR(dst_stat_buffer.st_mode) ?
                    io.rmdir(_dst_path.c_str()) :
                    io.unlink(_dst_path.c_str());
                if( rc == 0 )
                    break;
                switch( m_OnCantDeleteDestinationFile(VFSError::FromErrno(), _dst_path, host) ) {
                    case CantDeleteDestinationFileResolution::Skip: return StepResult::Skipped;
                    case CantDeleteDestinationFileResolution::Stop: return StepResult::Stop;
                    case CantDeleteDestinationFileResolution::Retry:continue;
                }
            }
        }
    }
    
    while( true ) {
        const auto rc = io.symlink(linkpath, _dst_path.c_str());
        if( rc == 0 )
            break;
        switch( m_OnDestinationFileWriteError(VFSError::FromErrno(), _dst_path, host) ) {
            case DestinationFileWriteErrorResolution::Skip: return StepResult::Skipped;
            case DestinationFileWriteErrorResolution::Stop: return StepResult::Stop;
            case DestinationFileWriteErrorResolution::Retry: continue;
        }
    }
    
    return StepResult::Ok;
}

CopyingJob::StepResult CopyingJob::CopyVFSSymlinkToNative(VFSHost &_src_vfs,
                                                          const string& _src_path,
                                                          const string& _dst_path) const
{
    auto &io = RoutedIO::Default;
    auto &dst_host = *VFSNativeHost::SharedHost();
    
    char linkpath[MAXPATHLEN];
    while( true ) {
        const auto rc = _src_vfs.ReadSymlink(_src_path.c_str(), linkpath, MAXPATHLEN);
        if( rc == VFSError::Ok )
            break;
        switch( m_OnCantAccessSourceItem( rc, _src_path, _src_vfs ) ) {
            case CantAccessSourceItemResolution::Skip:  return StepResult::Skipped;
            case CantAccessSourceItemResolution::Stop:  return StepResult::Stop;
            case CantAccessSourceItemResolution::Retry: continue;
        }
    }
    
    struct stat dst_stat_buffer;
    if( io.lstat(_dst_path.c_str(), &dst_stat_buffer) == 0 ) {
        VFSStat src_stat_buffer;
        while( true ) {
            const auto rc = _src_vfs.Stat(_src_path.c_str(), src_stat_buffer, VFSFlags::F_NoFollow);
            if( rc == VFSError::Ok )
                break;
            switch( m_OnCantAccessSourceItem( rc, _src_path, _src_vfs) ) {
                case CantAccessSourceItemResolution::Skip:  return StepResult::Skipped;
                case CantAccessSourceItemResolution::Stop:  return StepResult::Stop;
                case CantAccessSourceItemResolution::Retry: continue;
            }
        }
        
        // different objects, need to erase destination before calling symlink()
        // need to ask user what to do
        struct stat posix_src_stat_buffer;
        VFSStat::ToSysStat(src_stat_buffer, posix_src_stat_buffer);
        const auto res = m_OnRenameDestinationAlreadyExists(posix_src_stat_buffer,
                                                            dst_stat_buffer,
                                                            _dst_path);
        switch( res ) {
            case RenameDestExistsResolution::Skip:
                return StepResult::Skipped;
            case RenameDestExistsResolution::OverwriteOld:
                if( posix_src_stat_buffer.st_mtime <= dst_stat_buffer.st_mtime )
                    return StepResult::Skipped;
            case RenameDestExistsResolution::Overwrite:
                break;
            default:
                return StepResult::Stop;
        }
        
        // NEED something like io.trash()!
        if( dst_host.Trash(_dst_path.c_str(), nullptr) != VFSError::Ok ) {
            while( true ) {
                const auto rc = S_ISDIR(dst_stat_buffer.st_mode) ?
                io.rmdir(_dst_path.c_str()) :
                io.unlink(_dst_path.c_str());
                if( rc == 0 )
                    break;
                switch( m_OnCantDeleteDestinationFile(VFSError::FromErrno(), _dst_path, dst_host) ) {
                    case CantDeleteDestinationFileResolution::Skip: return StepResult::Skipped;
                    case CantDeleteDestinationFileResolution::Stop: return StepResult::Stop;
                    case CantDeleteDestinationFileResolution::Retry:continue;
                }
            }
        }
    }
    
    while( true ) {
        const auto rc = io.symlink(linkpath, _dst_path.c_str());
        if( rc == 0 )
            break;
        switch( m_OnDestinationFileWriteError(VFSError::FromErrno(), _dst_path, dst_host) ) {
            case DestinationFileWriteErrorResolution::Skip: return StepResult::Skipped;
            case DestinationFileWriteErrorResolution::Stop: return StepResult::Stop;
            case DestinationFileWriteErrorResolution::Retry: continue;
        }
    }
    
    return StepResult::Ok;
}

CopyingJob::StepResult CopyingJob::CopyVFSSymlinkToVFS(VFSHost &_src_vfs,
                                                       const string& _src_path,
                                                       const string& _dst_path) const
{
    auto &dst_host = *m_DestinationHost;
    
    char linkpath[MAXPATHLEN];
    while( true ) {
        const auto rc = _src_vfs.ReadSymlink(_src_path.c_str(), linkpath, MAXPATHLEN);
        if( rc == VFSError::Ok )
            break;
        switch( m_OnCantAccessSourceItem( rc, _src_path, _src_vfs ) ) {
            case CantAccessSourceItemResolution::Skip:  return StepResult::Skipped;
            case CantAccessSourceItemResolution::Stop:  return StepResult::Stop;
            case CantAccessSourceItemResolution::Retry: continue;
        }
    }
    
    VFSStat dst_stat_buffer;
    if( dst_host.Stat(_dst_path.c_str(), dst_stat_buffer, VFSFlags::F_NoFollow) == VFSError::Ok ) {
        VFSStat src_stat_buffer;
        while( true ) {
            const auto rc = _src_vfs.Stat(_src_path.c_str(), src_stat_buffer, VFSFlags::F_NoFollow);
            if( rc == VFSError::Ok )
                break;
            switch( m_OnCantAccessSourceItem( rc, _src_path, _src_vfs) ) {
                case CantAccessSourceItemResolution::Skip:  return StepResult::Skipped;
                case CantAccessSourceItemResolution::Stop:  return StepResult::Stop;
                case CantAccessSourceItemResolution::Retry: continue;
            }
        }
        
        // different objects, need to erase destination before calling symlink()
        // need to ask user what to do
        struct stat posix_src_stat_buffer, posix_dst_stat_buffer;
        VFSStat::ToSysStat(src_stat_buffer, posix_src_stat_buffer);
        VFSStat::ToSysStat(dst_stat_buffer, posix_dst_stat_buffer);
        const auto res = m_OnRenameDestinationAlreadyExists(posix_src_stat_buffer,
                                                            posix_dst_stat_buffer,
                                                            _dst_path);
        switch( res ) {
            case RenameDestExistsResolution::Skip:
                return StepResult::Skipped;
            case RenameDestExistsResolution::OverwriteOld:
                if( posix_src_stat_buffer.st_mtime <= posix_dst_stat_buffer.st_mtime )
                    return StepResult::Skipped;
            case RenameDestExistsResolution::Overwrite:
                break;
            default:
                return StepResult::Stop;
        }
        
        if( dst_host.Trash(_dst_path.c_str(), nullptr) != VFSError::Ok ) {
            while( true ) {
                const auto rc = dst_stat_buffer.mode_bits.dir ?
                    dst_host.RemoveDirectory(_dst_path.c_str()) :
                    dst_host.Unlink(_dst_path.c_str());
                if( rc == VFSError::Ok )
                    break;
                switch( m_OnCantDeleteDestinationFile(rc, _dst_path, dst_host) ) {
                    case CantDeleteDestinationFileResolution::Skip: return StepResult::Skipped;
                    case CantDeleteDestinationFileResolution::Stop: return StepResult::Stop;
                    case CantDeleteDestinationFileResolution::Retry:continue;
                }
            }
        }
    }
    
    while( true ) {
        const auto rc = dst_host.CreateSymlink(_dst_path.c_str(), linkpath);
        if( rc == VFSError::Ok )
            break;
        switch( m_OnDestinationFileWriteError(rc, _dst_path, dst_host) ) {
            case DestinationFileWriteErrorResolution::Skip: return StepResult::Skipped;
            case DestinationFileWriteErrorResolution::Stop: return StepResult::Stop;
            case DestinationFileWriteErrorResolution::Retry: continue;
        }
    }
    
    return StepResult::Ok;
}

void CopyingJob::SetState(CopyingJob::JobStage _state)
{
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//    NotifyWillChange(Notify::Stage);
    m_Stage = _state;
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//    NotifyDidChange(Notify::Stage);
}

}

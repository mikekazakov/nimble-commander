//
//  VFSNativeHost.cpp
//  Files
//
//  Created by Michael G. Kazakov on 26.08.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include <sys/attr.h>
#include <sys/errno.h>
#include <sys/vnode.h>
#include <Habanero/algo.h>
#include <Utility/PathManip.h>
#include <Utility/FSEventsDirUpdate.h>
#include <Utility/NativeFSManager.h>
#include <RoutedIO/RoutedIO.h>
#include "DisplayNamesCache.h"
#include "VFSNativeHost.h"
#include "VFSNativeFile.h"
#include <VFS/VFSError.h>
#include "../VFSListingInput.h"

// TODO:
// do some research about this new function:
// int getattrlistbulk(int, void *, void *, size_t, uint64_t) __OSX_AVAILABLE_STARTING(__MAC_10_10, __IPHONE_8_0);

// hack to access function from libc implementation directly.
// this func does readdir but without mutex locking
struct dirent	*_readdir_unlocked(DIR *, int) __DARWIN_INODE64(_readdir_unlocked);

const char *VFSNativeHost::Tag = "native";

class VFSNativeHostConfiguration
{
public:
    const char *Tag() const
    {
        return VFSNativeHost::Tag;
    }
    
    const char *Junction() const
    {
        return "";
    }
    
    bool operator==(const VFSNativeHostConfiguration&) const
    {
        return true;
    }
};

VFSMeta VFSNativeHost::Meta()
{
    VFSMeta m;
    m.Tag = Tag;
    m.SpawnWithConfig = [](const VFSHostPtr &_parent, const VFSConfiguration& _config, VFSCancelChecker _cancel_checker) {
        return SharedHost();
    };
    return m;
}

VFSNativeHost::VFSNativeHost():
    VFSHost("", 0, Tag)
{
}


//attrList.bitmapcount = ATTR_BIT_MAP_COUNT;
//attrList.commonattr  = ATTR_CMN_RETURNED_ATTRS |
//ATTR_CMN_NAME |
//ATTR_CMN_ERROR |
//ATTR_CMN_OBJTYPE |
//ATTR_CMN_CRTIME |
//ATTR_CMN_MODTIME |
//ATTR_CMN_CHGTIME |
//ATTR_CMN_ACCTIME |
//ATTR_CMN_ADDEDTIME |
//ATTR_CMN_OWNERID |
//ATTR_CMN_GRPID |
//ATTR_CMN_ACCESSMASK	|
//ATTR_CMN_FLAGS

struct EntryAttributesCallbackParams
{
    const char*         filename;
    time_t              crt_time;
    time_t              mod_time;
    time_t              chg_time;
    time_t              acc_time;
    time_t              add_time; // may be -1 if absent
    uid_t               uid;
    gid_t               gid;
    mode_t              mode;
    dev_t               dev;
    uint32_t            inode;
    uint32_t            flags;
    int64_t             size; // will be 0 if absent
};

static mode_t VNodeToUnixMode( const fsobj_type_t _type )
{
    switch( _type ) {
        case VREG:  return S_IFREG;
        case VDIR:  return S_IFDIR;
        case VBLK:  return S_IFBLK;
        case VCHR:  return S_IFCHR;
        case VLNK:  return S_IFLNK;
        case VSOCK: return S_IFSOCK;
        case VFIFO: return S_IFIFO;
        default:    return 0;
    };
}

static int CountDirEntries( const int _dir_fd )
{
    struct Count {
        u_int32_t length;
        u_int32_t count;
    } __attribute__((aligned(4), packed)) count;

    struct attrlist attr_list;
    memset(&attr_list, 0, sizeof(attr_list));
    attr_list.bitmapcount = ATTR_BIT_MAP_COUNT;
    attr_list.dirattr = ATTR_DIR_ENTRYCOUNT;
    if( fgetattrlist( _dir_fd, &attr_list, &count, sizeof(count), 0 ) == 0 )
        return count.count;
    return VFSError::FromErrno();
}

// will not set .filename field
static int ReadSingleEntryAttributesByPath(PosixIOInterface &_io,
                                           const char *_path,
                                           const function<void(const EntryAttributesCallbackParams &_params)> &_cb_param)
{
    struct Attrs {
        uint32_t          length;
        attribute_set_t   returned;
        dev_t             dev;
        fsobj_type_t      obj_type;
        fsobj_id_t        obj_id;
        struct timespec   crt_time;
        struct timespec   mod_time;
        struct timespec   chg_time;
        struct timespec   acc_time;
        uid_t             uid;
        gid_t             gid;
        u_int32_t         access;
        u_int32_t         flags;
        struct timespec   add_time;
        off_t             file_size;
    } __attribute__((aligned(4), packed)) attrs; // for convenience, not very used
    
    attrlist attr_list;
    memset(&attr_list, 0, sizeof(attr_list));
    attr_list.bitmapcount = ATTR_BIT_MAP_COUNT;
    attr_list.commonattr  = ATTR_CMN_RETURNED_ATTRS |
                            ATTR_CMN_DEVID          |
                            ATTR_CMN_OBJTYPE        |
                            ATTR_CMN_OBJPERMANENTID |
                            ATTR_CMN_CRTIME         |
                            ATTR_CMN_MODTIME        |
                            ATTR_CMN_CHGTIME        |
                            ATTR_CMN_ACCTIME        |
                            ATTR_CMN_ADDEDTIME      |
                            ATTR_CMN_OWNERID        |
                            ATTR_CMN_GRPID          |
                            ATTR_CMN_ACCESSMASK	    |
                            ATTR_CMN_FLAGS;
    attr_list.fileattr    = ATTR_FILE_DATALENGTH;
    

    const int fd = _io.open(_path, O_RDONLY | O_NONBLOCK | O_CLOEXEC);
    if( fd < 0 )
        return errno;
    auto close_fd = at_scope_end([fd]{
        close(fd);
    });

    if( fgetattrlist( fd, &attr_list, &attrs, sizeof(attrs), 0) != 0 )
        return errno;
    
    EntryAttributesCallbackParams params;
    params.filename = "";
    
    if( attrs.returned.commonattr & ATTR_CMN_DEVID )
        params.dev = attrs.dev;
    
    params.mode = 0;
    if( attrs.returned.commonattr & ATTR_CMN_OBJTYPE )
        params.mode = VNodeToUnixMode( attrs.obj_type );
    
    if( attrs.returned.commonattr & ATTR_CMN_OBJPERMANENTID )
        params.inode = attrs.obj_id.fid_objno;
    
    if( attrs.returned.commonattr & ATTR_CMN_CRTIME )
        params.crt_time = attrs.crt_time.tv_sec;
    
    if( attrs.returned.commonattr & ATTR_CMN_MODTIME )
        params.mod_time = attrs.mod_time.tv_sec;
    
    if( attrs.returned.commonattr & ATTR_CMN_CHGTIME )
        params.chg_time = attrs.chg_time.tv_sec;
    
    if( attrs.returned.commonattr & ATTR_CMN_ACCTIME )
        params.acc_time = attrs.acc_time.tv_sec;
    
    if( attrs.returned.commonattr & ATTR_CMN_OWNERID )
        params.uid = attrs.uid;
    
    if( attrs.returned.commonattr & ATTR_CMN_GRPID )
        params.gid = attrs.gid;
    
    if( attrs.returned.commonattr & ATTR_CMN_ACCESSMASK )
        params.mode |= attrs.access;
    
    if( attrs.returned.commonattr & ATTR_CMN_FLAGS )
        params.flags = attrs.flags;
    
    if( attrs.returned.commonattr & ATTR_CMN_ADDEDTIME )
        params.add_time = attrs.add_time.tv_sec;
    else
        params.add_time = -1;
    
    if( attrs.returned.fileattr & ATTR_FILE_DATALENGTH )
        params.size = attrs.file_size;
    else
        params.size = -1;
    
    _cb_param( params );
    
    return 0;
}

// assuming this will be called when Admin Mode is on
static int ReadDirAttributesStat(
    const int _dir_fd,
    const char *_dir_path,
    const function<void(int _fetched_now)> &_cb_fetch,
    const function<void(const EntryAttributesCallbackParams &_params)> &_cb_param)
{
    // initial directory lookup
    vector< tuple<string, uint64_t, uint8_t > > dirents; // name, inode, entry_type
    if( auto dirp = fdopendir( dup(_dir_fd) ) ) {
        auto close_dir = at_scope_end([=]{ closedir(dirp); });
        static const auto dirents_reserve_amount = 64;
        dirents.reserve( dirents_reserve_amount );
        while( auto entp = ::_readdir_unlocked(dirp, 1) ) {
            if(entp->d_ino == 0 ||          // apple's documentation suggest to skip such files
               strisdot(entp->d_name) ||    // do not process self entry
               strisdotdot(entp->d_name) )  // do not process parent entry
                continue;
            
            dirents.emplace_back(string(entp->d_name, entp->d_namlen), entp->d_ino, entp->d_type);
        }
    }
    else
        return errno;

    // call stat() for every directory entry
    auto &io = RoutedIO::Default;
    for( auto &e: dirents ) {
        // need absolute paths
        const string entry_path = _dir_path + get<0>(e);
        
        // stat the file
        struct stat stat_buffer;
        if( io.lstat(entry_path.c_str(), &stat_buffer) == 0 ) {
            EntryAttributesCallbackParams params;
            params.filename = get<0>(e).c_str();
            params.crt_time = stat_buffer.st_birthtimespec.tv_sec;
            params.mod_time = stat_buffer.st_mtimespec.tv_sec;
            params.chg_time = stat_buffer.st_mtimespec.tv_sec;
            params.acc_time = stat_buffer.st_ctimespec.tv_sec;
            params.add_time = -1;
            params.uid      = stat_buffer.st_uid;
            params.gid      = stat_buffer.st_gid;
            params.mode     = stat_buffer.st_mode;
            params.dev      = stat_buffer.st_dev;
            params.inode    = stat_buffer.st_ino;
            params.flags    = stat_buffer.st_flags;
            params.size     = stat_buffer.st_size;
            
            _cb_fetch(1);
            _cb_param(params);
        }
    }
    
    return 0;
}

static int ReadDirAttributesBulk(
    const int _dir_fd,
    const function<void(int _fetched_now)> &_cb_fetch,
    const function<void(const EntryAttributesCallbackParams &_params)> &_cb_param)
{
    struct Attrs {
        uint32_t          length;
        attribute_set_t   returned;
        uint32_t          error;
        attrreference_t   name_info;
        char              *name;
        dev_t             dev;
        fsobj_type_t      obj_type;
        fsobj_id_t        obj_id;
        struct timespec   crt_time;
        struct timespec   mod_time;
        struct timespec   chg_time;
        struct timespec   acc_time;
        uid_t             uid;
        gid_t             gid;
        u_int32_t         access;
        u_int32_t         flags;
        struct timespec   add_time;
        off_t             file_size;
    } __attribute__((aligned(4), packed)); // for convenience, not very used

    attrlist attr_list;
    memset(&attr_list, 0, sizeof(attr_list));
    attr_list.bitmapcount = ATTR_BIT_MAP_COUNT;
    attr_list.commonattr  = ATTR_CMN_RETURNED_ATTRS |
                            ATTR_CMN_NAME           |
                            ATTR_CMN_ERROR          |
                            ATTR_CMN_DEVID          |    
                            ATTR_CMN_OBJTYPE        |
                            ATTR_CMN_OBJPERMANENTID |
                            ATTR_CMN_CRTIME         |
                            ATTR_CMN_MODTIME        |
                            ATTR_CMN_CHGTIME        |
                            ATTR_CMN_ACCTIME        |
                            ATTR_CMN_ADDEDTIME      |
                            ATTR_CMN_OWNERID        |
                            ATTR_CMN_GRPID          |
                            ATTR_CMN_ACCESSMASK	    |
                            ATTR_CMN_FLAGS;
    attr_list.fileattr    = ATTR_FILE_DATALENGTH;
    

    char attr_buf[65536];
    EntryAttributesCallbackParams params;
    while( true ) {
        const int retcount = getattrlistbulk(_dir_fd,
                                             &attr_list,
                                             &attr_buf[0],
                                             sizeof(attr_buf),
                                             0);
        if( retcount < 0 )
            return errno;
        else if (retcount == 0)
            return 0;
        else {
            _cb_fetch(retcount);
            
            char *entry_start = &attr_buf[0];
            for( int index = 0; index < retcount; index++ ) {
                Attrs attrs = {0};
                
                char *field = entry_start;
                attrs.length = *(uint32_t *)field;
                field += sizeof(uint32_t);
                
                entry_start += attrs.length;
                
                attrs.returned = *(attribute_set_t *)field;
                field += sizeof(attribute_set_t);
                
                if( attrs.returned.commonattr & ATTR_CMN_ERROR ) {
                    attrs.error = *(uint32_t *)field;
                    field += sizeof(uint32_t);
                }
                
                if( attrs.error != 0 )
                    continue;
                
                if ( attrs.returned.commonattr & ATTR_CMN_NAME ) {
                    params.filename = field + ((attrreference_t *)field)->attr_dataoffset;
                    field += sizeof(attrreference_t);
                }
                else
                    continue; // can't work without filename
                
                if( attrs.returned.commonattr & ATTR_CMN_DEVID ) {
                    params.dev = *(dev_t*)field;
                    field += sizeof(dev_t);
                }
                
                params.mode = 0;
                if( attrs.returned.commonattr & ATTR_CMN_OBJTYPE ) {
                    params.mode = VNodeToUnixMode(*(fsobj_type_t *)field);
                    field += sizeof(fsobj_type_t);
                }
                
                if( attrs.returned.commonattr & ATTR_CMN_OBJPERMANENTID ) {
                    params.inode = ((fsobj_id_t*)field)->fid_objno;
                    field += sizeof(fsobj_id_t);
                }

                if( attrs.returned.commonattr & ATTR_CMN_CRTIME ) {
                    params.crt_time = ((timespec*)field)->tv_sec;
                    field += sizeof(timespec);
                }
                
                if( attrs.returned.commonattr & ATTR_CMN_MODTIME ) {
                    params.mod_time = ((timespec*)field)->tv_sec;
                    field += sizeof(timespec);
                }

                if( attrs.returned.commonattr & ATTR_CMN_CHGTIME ) {
                    params.chg_time = ((timespec*)field)->tv_sec;
                    field += sizeof(timespec);
                }

                if( attrs.returned.commonattr & ATTR_CMN_ACCTIME ) {
                    params.acc_time = ((timespec*)field)->tv_sec;
                    field += sizeof(timespec);
                }
                
                if( attrs.returned.commonattr & ATTR_CMN_OWNERID ) {
                    params.uid = *(uid_t*)field;
                    field += sizeof(uid_t);
                }

                if( attrs.returned.commonattr & ATTR_CMN_GRPID ) {
                    params.gid = *(gid_t*)field;
                    field += sizeof(gid_t);
                }

                if( attrs.returned.commonattr & ATTR_CMN_ACCESSMASK ) {
                    params.mode |= ((*(u_int32_t*)field) & (~S_IFMT));
                    field += sizeof(u_int32_t);
                }
                
                if( attrs.returned.commonattr & ATTR_CMN_FLAGS ) {
                    params.flags = *(uint32_t*)field;
                    field += sizeof(u_int32_t);
                }
                
                if( attrs.returned.commonattr & ATTR_CMN_ADDEDTIME ) {
                    params.add_time = ((timespec*)field)->tv_sec;
                    field += sizeof(timespec);
                }
                else
                    params.add_time = -1;
                
                if( attrs.returned.fileattr & ATTR_FILE_DATALENGTH ) {
                    params.size = *(off_t*)field;
                    field += sizeof(off_t);
                }
                else
                    params.size = -1;
                    
                _cb_param( params );
            }
        }
    }
}

int VFSNativeHost::FetchFlexibleListingBulk(const char *_path,
                                    shared_ptr<VFSListing> &_target,
                                    int _flags,
                                    VFSCancelChecker _cancel_checker)
{
//    MachTimeBenchmark mtb;
    
    const auto need_to_add_dot_dot = !(_flags & VFSFlags::F_NoDotDot) &&
                                     strcmp(_path, "/") != 0;
    auto &io = RoutedIO::InterfaceForAccess(_path, R_OK); // don't need it
    const bool is_native_io = !io.isrouted();
    const int fd = io.open(_path, O_RDONLY | O_NONBLOCK | O_DIRECTORY | O_CLOEXEC);
    if( fd < 0 )
        return VFSError::FromErrno();
    auto close_fd = at_scope_end([fd]{
        close(fd);
    });
    
    const int approx_entries_count = [&]{
        auto count = CountDirEntries(fd);
        if( count < 0 ) // negative means error
            count = 64;
         return count + (need_to_add_dot_dot ? 1 : 0);
    }();
    
    VFSListingInput listing_source;
    listing_source.hosts[0] = shared_from_this();
    listing_source.directories[0] = EnsureTrailingSlash(_path);
    listing_source.inodes.reset( variable_container<>::type::dense );
    listing_source.atimes.reset( variable_container<>::type::dense );
    listing_source.mtimes.reset( variable_container<>::type::dense );
    listing_source.ctimes.reset( variable_container<>::type::dense );
    listing_source.btimes.reset( variable_container<>::type::dense );
    listing_source.add_times.reset( variable_container<>::type::sparse );
    listing_source.unix_flags.reset( variable_container<>::type::dense );
    listing_source.uids.reset( variable_container<>::type::dense );
    listing_source.gids.reset( variable_container<>::type::dense );
    listing_source.sizes.reset( variable_container<>::type::dense );
    listing_source.symlinks.reset( variable_container<>::type::sparse );
    listing_source.display_filenames.reset( variable_container<>::type::sparse );
    
    auto resize_dense = [&](int _sz) {
        listing_source.filenames.resize( _sz );
        listing_source.inodes.resize( _sz );
        listing_source.unix_types.resize( _sz );
        listing_source.atimes.resize( _sz );
        listing_source.mtimes.resize( _sz );
        listing_source.ctimes.resize( _sz);
        listing_source.btimes.resize( _sz );
        listing_source.unix_modes.resize( _sz );
        listing_source.unix_flags.resize( _sz );
        listing_source.uids.resize( _sz );
        listing_source.gids.resize( _sz );
        listing_source.sizes.resize( _sz );
    };
    
    auto fill = [&]( int _n, const EntryAttributesCallbackParams &_params ) {
        listing_source.filenames[_n]     = _params.filename;
        listing_source.inodes[_n]        = _params.inode;
        listing_source.unix_types[_n]    = IFTODT(_params.mode);
        listing_source.atimes[_n]        = _params.acc_time;
        listing_source.mtimes[_n]        = _params.mod_time;
        listing_source.ctimes[_n]        = _params.chg_time;
        listing_source.btimes[_n]        = _params.crt_time;
        listing_source.unix_modes[_n]    = _params.mode;
        listing_source.unix_flags[_n]    = _params.flags;
        listing_source.uids[_n]          = _params.uid;
        listing_source.gids[_n]          = _params.gid;
        listing_source.sizes[_n]         = _params.size;
        if( _params.add_time >= 0 )
            listing_source.add_times.insert(_n, _params.add_time );
        
        if( _flags & VFSFlags::F_LoadDisplayNames )
            if( S_ISDIR(listing_source.unix_modes[_n]) &&
               !listing_source.filenames[_n].empty() &&
               !strisdotdot(listing_source.filenames[_n]) ) {
                static auto &dnc = DisplayNamesCache::Instance();
                if( auto display_name = dnc.DisplayName( _params.inode, _params.dev, listing_source.directories[0] + listing_source.filenames[_n]) )
                    listing_source.display_filenames.insert(_n, display_name);
            }
    };
    
    resize_dense( approx_entries_count );
    
    int next_entry_index = 0;
    auto cb_param = [&](const EntryAttributesCallbackParams &_params){
        fill(next_entry_index++, _params);
    };
    
    if( need_to_add_dot_dot ) {
        ReadSingleEntryAttributesByPath( io, _path, cb_param );
        listing_source.filenames[0] = "..";
    }
    
    auto cb_fetch = [&](int _fetched_now){
        // check if final entries count is more than previous approximate
        if( next_entry_index + _fetched_now > approx_entries_count )
            resize_dense( next_entry_index + _fetched_now );
    };

    // when Admin Mode is on - we use different fetch route
    const int ret = is_native_io ?
        ReadDirAttributesBulk( fd, cb_fetch, cb_param ) :
        ReadDirAttributesStat( fd, listing_source.directories[0].c_str(), cb_fetch, cb_param);
    if( ret != 0 )
        return VFSError::FromErrno(ret);
    
    if( _cancel_checker && _cancel_checker() ) VFSError::Cancelled;
    
    // check if final entries count is less than approximate
    if( next_entry_index < approx_entries_count )
        resize_dense( next_entry_index );
    
    // a little more work with symlinks, if there are any
    for( int n = 0; n < next_entry_index; ++n )
        if( listing_source.unix_types[n] == DT_LNK ) {
            // read an actual link path
            char linkpath[MAXPATHLEN];
            const ssize_t sz = is_native_io ?
                readlinkat(fd,
                           listing_source.filenames[n].c_str(),
                           linkpath,
                           MAXPATHLEN) :
                io.readlink((listing_source.directories[0] + listing_source.filenames[n]).c_str(),
                            linkpath,
                            MAXPATHLEN);
            if( sz != -1 ) {
                linkpath[sz] = 0;
                listing_source.symlinks.insert(n, linkpath);
            }
            
            // stat the target file
            struct stat stat_buffer;
            const auto stat_ret = is_native_io ?
                fstatat(fd,
                        listing_source.filenames[n].c_str(),
                        &stat_buffer,
                        0) :
                io.stat((listing_source.directories[0] + listing_source.filenames[n]).c_str(),
                        &stat_buffer);
            if( stat_ret == 0 ) {
                listing_source.unix_modes[n]    = stat_buffer.st_mode;
                listing_source.unix_flags[n]    = stat_buffer.st_flags;
                listing_source.uids[n]          = stat_buffer.st_uid;
                listing_source.gids[n]          = stat_buffer.st_gid;
                listing_source.sizes[n]         = stat_buffer.st_size;
            }
        }

    _target = VFSListing::Build(move(listing_source));
    
//    mtb.ResetMicro();
    
    return 0;
}

int VFSNativeHost::FetchFlexibleListing(const char *_path,
                                        shared_ptr<VFSListing> &_target,
                                        int _flags,
                                        VFSCancelChecker _cancel_checker)
{
  
    return FetchFlexibleListingBulk(_path, _target, _flags, _cancel_checker);
    
    MachTimeBenchmark mtb;
    
    static const auto dirents_reserve_amount = 64;
    auto &io = RoutedIO::InterfaceForAccess(_path, R_OK); // don't need it
    const bool is_native_io = !io.isrouted();
    
    const int fd = io.open(_path, O_RDONLY | O_NONBLOCK | O_DIRECTORY | O_CLOEXEC);
    if( fd < 0 )
        return VFSError::FromErrno();
    auto close_fd = at_scope_end([fd]{
        close(fd);
    });
    
    
    
//    cout << "[[[[[[[[[" << endl;
//    ReadDirAttributesBulk( fd, [](const ReadDirAttributesBulkCallbackParams &_params){
//        cout << _params.filename << "  " << _params.inode << endl;
//    });
//    cout << "]]]]]]]]]" << endl;
    
    
    
    
    
    
    
    
    
    
    bool need_to_add_dot_dot = true; // in some fancy situations there's no ".." entry in directory - we should insert it by hand
    if(_flags & VFSFlags::F_NoDotDot)
        need_to_add_dot_dot = false;
    
    vector< tuple<string, uint64_t, uint8_t > > dirents; // name, inode, entry_type
    dirents.reserve( dirents_reserve_amount );
    
    // initial directory lookup
    if( auto dirp = fdopendir(dup(fd)) ) {
        auto close_dir = at_scope_end([=]{ closedir(dirp); });
    
        if(_cancel_checker && _cancel_checker())
            return VFSError::Cancelled;
    
        while( auto entp = ::_readdir_unlocked(dirp, 1) ) {
            if(_cancel_checker && _cancel_checker())
                return VFSError::Cancelled;
            
            if( entp->d_ino == 0 ||      // apple's documentation suggest to skip such files
                strisdot(entp->d_name) ) // do not process self entry
                continue;
               
            if( strisdotdot( entp->d_name) ) { // special case for dot-dot directory
                if( !need_to_add_dot_dot )
                    continue;
                
                // TODO: handle situation when ".." is not the #0 entry
                need_to_add_dot_dot = false;
                
                if(strcmp(_path, "/") == 0)
                    continue; // skip .. for root directory
                
                // it's very nice that sometimes OSX can not set a valid flags on ".." file in a mount point
                // so for now - just fix it by hand
                if(entp->d_type == 0)
                    entp->d_type = DT_DIR; // a very-very strange bugfix
            }
            
            dirents.emplace_back(string(entp->d_name, entp->d_namlen), entp->d_ino, entp->d_type);
        }
    }
    else
        return VFSError::FromErrno();
    
    if(need_to_add_dot_dot)
        dirents.insert(begin(dirents), make_tuple("..", 0, DT_DIR)); // add ".." entry by hand
    
    // set up or listing structure
    VFSListingInput listing_source;
    listing_source.hosts[0] = shared_from_this();
    listing_source.directories[0] = EnsureTrailingSlash(_path);
    listing_source.inodes.reset( variable_container<>::type::dense );
    listing_source.atimes.reset( variable_container<>::type::dense );
    listing_source.mtimes.reset( variable_container<>::type::dense );
    listing_source.ctimes.reset( variable_container<>::type::dense );
    listing_source.btimes.reset( variable_container<>::type::dense );
    listing_source.add_times.reset( variable_container<>::type::sparse );
    listing_source.unix_flags.reset( variable_container<>::type::dense );
    listing_source.uids.reset( variable_container<>::type::dense );
    listing_source.gids.reset( variable_container<>::type::dense );
    listing_source.sizes.reset( variable_container<>::type::dense );
    listing_source.symlinks.reset( variable_container<>::type::sparse );
    listing_source.display_filenames.reset( variable_container<>::type::sparse );
    spinlock symlinks_guard, display_names_guard, add_times_guard;
    
    const unsigned amount = (unsigned)dirents.size();
    listing_source.filenames.resize(amount);
    listing_source.inodes.resize(amount);
    listing_source.unix_types.resize(amount);
    listing_source.atimes.resize(amount);
    listing_source.mtimes.resize(amount);
    listing_source.ctimes.resize(amount);
    listing_source.btimes.resize(amount);
    listing_source.unix_modes.resize(amount);
    listing_source.unix_flags.resize(amount);
    listing_source.uids.resize(amount);
    listing_source.gids.resize(amount);
    listing_source.sizes.resize(amount);
    
    for(unsigned n = 0; n != amount ; ++n ) {
        auto &i = dirents[n];
        listing_source.filenames[n] = move(get<0>(i));
        listing_source.inodes[n] = get<1>(i);
        listing_source.unix_types[n] = get<2>(i);
    }
    
    // stat files, read info about symlinks ands possible display names
    dispatch_apply(amount, dispatch_get_global_queue(0, 0), [&](size_t n) {
        if(_cancel_checker && _cancel_checker()) return;
        auto filename = listing_source.filenames[n].c_str();
        
        // stat the file
        struct stat stat_buffer;
        if( (is_native_io && fstatat(fd, filename, &stat_buffer, 0) == 0) ||
           (!is_native_io && io.stat((listing_source.directories[0] + filename).c_str(), &stat_buffer) == 0 ) ) {
            listing_source.atimes[n]        = stat_buffer.st_atimespec.tv_sec;
            listing_source.mtimes[n]        = stat_buffer.st_mtimespec.tv_sec;
            listing_source.ctimes[n]        = stat_buffer.st_ctimespec.tv_sec;
            listing_source.btimes[n]        = stat_buffer.st_birthtimespec.tv_sec;
            listing_source.unix_modes[n]    = stat_buffer.st_mode;
            listing_source.unix_flags[n]    = stat_buffer.st_flags;
            listing_source.uids[n]          = stat_buffer.st_uid;
            listing_source.gids[n]          = stat_buffer.st_gid;
            listing_source.sizes[n]         = stat_buffer.st_size;
            // add other stat info here. there's a lot more
        }
        
        struct AttrListTime {
            u_int32_t       length = 0;
            struct timespec time;
        } __attribute__((aligned(4), packed)) added_time_buffer;
        
        struct attrlist attr_list;
        memset(&attr_list, 0, sizeof(attr_list));
        attr_list.bitmapcount = ATTR_BIT_MAP_COUNT;
        attr_list.commonattr = ATTR_CMN_ADDEDTIME;
        if( getattrlistat(fd, filename, &attr_list, &added_time_buffer, sizeof(added_time_buffer), 0) == 0) {
            lock_guard<spinlock> guard(add_times_guard);
            listing_source.add_times.insert(n, added_time_buffer.time.tv_sec );
        }

        // if we're dealing with a symlink - read it's content to know the real file path
        if( listing_source.unix_types[n] == DT_LNK ) {
            char linkpath[MAXPATHLEN];
            ssize_t sz = is_native_io ?
                readlinkat(fd, filename, linkpath, MAXPATHLEN) :
                io.readlink((listing_source.directories[0] + filename).c_str(), linkpath, MAXPATHLEN);
            if(sz != -1) {
                linkpath[sz] = 0;
                lock_guard<spinlock> guard(symlinks_guard);
                listing_source.symlinks.insert(n, linkpath);
            }
            
            // stat the original file so we can extract some interesting info from it
            struct stat link_stat_buffer;
            if( (is_native_io && fstatat(fd, filename, &link_stat_buffer, AT_SYMLINK_NOFOLLOW) == 0) ||
               (!is_native_io && io.lstat((listing_source.directories[0] + filename).c_str(), &link_stat_buffer) == 0 ) )
               if(link_stat_buffer.st_flags & UF_HIDDEN)
                listing_source.unix_flags[n] |= UF_HIDDEN; // currently using only UF_HIDDEN flag
        }
        
        if( _flags & VFSFlags::F_LoadDisplayNames )
            if( S_ISDIR(listing_source.unix_modes[n]) &&
               !strisdotdot(listing_source.filenames[n]) ) {
                static auto &dnc = DisplayNamesCache::Instance();
                if( auto display_name = dnc.DisplayName(stat_buffer, listing_source.directories[0] + filename) ) {
                    lock_guard<spinlock> guard(display_names_guard);
                    listing_source.display_filenames.insert(n, display_name);
                }
            }
    });
    
    _target = VFSListing::Build(move(listing_source));
    
    mtb.ResetMicro();
    
    return 0;
}

int VFSNativeHost::CreateFile(const char* _path,
                       shared_ptr<VFSFile> &_target,
                       VFSCancelChecker _cancel_checker)
{
    auto file = make_shared<VFSNativeFile>(_path, SharedPtr());
    if(_cancel_checker && _cancel_checker())
        return VFSError::Cancelled;
    _target = file;
    return VFSError::Ok;
}

const shared_ptr<VFSNativeHost> &VFSNativeHost::SharedHost()
{
    static auto host = make_shared<VFSNativeHost>();
    return host;
}

// return false on error or cancellation
static int CalculateDirectoriesSizesHelper(char *_path,
                                      size_t _path_len,
                                      bool &_iscancelling,
                                      VFSCancelChecker _checker,
                                      dispatch_queue &_stat_queue,
                                      int64_t &_size_stock)
{
    if(_checker && _checker())
    {
        _iscancelling = true;
        return VFSError::Cancelled;
    }
    
    auto &io = RoutedIO::InterfaceForAccess(_path, R_OK);
    
    DIR *dirp = io.opendir(_path);
    if( dirp == 0 )
        return VFSError::FromErrno();
    
    dirent *entp;
    
    _path[_path_len] = '/';
    _path[_path_len+1] = 0;
    char *var = _path + _path_len + 1;
    
    while((entp = io.readdir(dirp)) != NULL)
    {
        if(_checker && _checker())
        {
            _iscancelling = true;
            goto cleanup;
        }
        
        if(entp->d_ino == 0) continue; // apple's documentation suggest to skip such files
        if(entp->d_namlen == 1 && entp->d_name[0] == '.') continue; // do not process self entry
        if(entp->d_namlen == 2 && entp->d_name[0] == '.' && entp->d_name[1] == '.') continue; // do not process parent entry
        
        memcpy(var, entp->d_name, entp->d_namlen+1);
        if(entp->d_type == DT_DIR)
        {
            CalculateDirectoriesSizesHelper(_path,
                                      _path_len + entp->d_namlen + 1,
                                      _iscancelling,
                                      _checker,
                                      _stat_queue,
                                      _size_stock);
            if(_iscancelling)
                goto cleanup;
        }
        else if(entp->d_type == DT_REG || entp->d_type == DT_LNK)
        {
            char *full_path = (char*) malloc(_path_len + entp->d_namlen + 2);
            memcpy(full_path, _path, _path_len + entp->d_namlen + 2);
            
            _stat_queue.async([&,full_path]{
                if(_iscancelling) return;
                
                struct stat st;
                
                if(io.lstat(full_path, &st) == 0)
                    _size_stock += st.st_size;
                
                free(full_path);
            });
        }
    }
    
cleanup:
    io.closedir(dirp);
    _path[_path_len] = 0;
    return VFSError::Ok;
}


ssize_t VFSNativeHost::CalculateDirectorySize(const char *_path,
                                              VFSCancelChecker _cancel_checker)
{
    if(_cancel_checker && _cancel_checker())
        return VFSError::Cancelled;
    
    if(_path == 0 ||
       _path[0] != '/')
        return VFSError::InvalidCall;
    
    bool iscancelling = false;
    char path[MAXPATHLEN];
    strcpy(path, _path);
    
    dispatch_queue stat_queue("VFSNativeHost.CalculateDirectoriesSizes");
    
    int64_t size = 0;
    int result = CalculateDirectoriesSizesHelper(path, strlen(path), iscancelling, _cancel_checker, stat_queue, size);
    stat_queue.sync([]{});
    if(result >= 0)
        return size;
    else
        return result;
}

bool VFSNativeHost::IsDirChangeObservingAvailable(const char *_path)
{
    if(!_path)
        return false;
    return access(_path, R_OK) == 0; // should use _not_ routed I/O here!
}

VFSHostDirObservationTicket VFSNativeHost::DirChangeObserve(const char *_path, function<void()> _handler)
{
    uint64_t t = FSEventsDirUpdate::Instance().AddWatchPath(_path, _handler);
    return t ? VFSHostDirObservationTicket(t, shared_from_this()) : VFSHostDirObservationTicket();
}

void VFSNativeHost::StopDirChangeObserving(unsigned long _ticket)
{
    FSEventsDirUpdate::Instance().RemoveWatchPathWithTicket(_ticket);
}

int VFSNativeHost::Stat(const char *_path, VFSStat &_st, int _flags, VFSCancelChecker _cancel_checker)
{
    auto &io = RoutedIO::InterfaceForAccess(_path, R_OK);
    memset(&_st, 0, sizeof(_st));
    
    struct stat st;
    
    int ret = (_flags & VFSFlags::F_NoFollow) ? io.lstat(_path, &st) : io.stat(_path, &st);
    
    if(ret == 0) {
        VFSStat::FromSysStat(st, _st);
        return VFSError::Ok;
    }
    
    return VFSError::FromErrno();
}

int VFSNativeHost::IterateDirectoryListing(const char *_path, function<bool(const VFSDirEnt &_dirent)> _handler)
{
    auto &io = RoutedIO::InterfaceForAccess(_path, R_OK);
    
    DIR *dirp = io.opendir(_path);
    if(dirp == 0)
        return VFSError::FromErrno();
        
    dirent *entp;
    VFSDirEnt vfs_dirent;
    while((entp = io.readdir(dirp)) != NULL)
    {
        if((entp->d_namlen == 1 && entp->d_name[0] == '.') ||
           (entp->d_namlen == 2 && entp->d_name[0] == '.' && entp->d_name[1] == '.'))
            continue;

        vfs_dirent.type = entp->d_type;
        vfs_dirent.name_len = entp->d_namlen;
        memcpy(vfs_dirent.name, entp->d_name, entp->d_namlen+1);
            
        if(!_handler(vfs_dirent))
            break;
    }
    
    io.closedir(dirp);
    
    return VFSError::Ok;
}

int VFSNativeHost::StatFS(const char *_path, VFSStatFS &_stat, VFSCancelChecker _cancel_checker)
{
    struct statfs info;
    if(statfs(_path, &info) < 0)
        return VFSError::FromErrno();

    auto volume = NativeFSManager::Instance().VolumeFromMountPoint(info.f_mntonname);
    if(!volume)
        return VFSError::GenericError;
    
    NativeFSManager::Instance().UpdateSpaceInformation(volume);
    
    _stat.volume_name   = volume->verbose.name.UTF8String;
    _stat.total_bytes   = volume->basic.total_bytes;
    _stat.free_bytes    = volume->basic.free_bytes;
    _stat.avail_bytes   = volume->basic.available_bytes;
    
    return 0;
}

int VFSNativeHost::Unlink(const char *_path, VFSCancelChecker _cancel_checker)
{
    auto &io = RoutedIO::Default;
    int ret = io.unlink(_path);
    if(ret == 0)
        return 0;
    return VFSError::FromErrno();
}

bool VFSNativeHost::IsWriteable() const
{
    return true; // dummy now
}

bool VFSNativeHost::IsWriteableAtPath(const char *_dir) const
{
    return true; // dummy now
}

int VFSNativeHost::CreateDirectory(const char* _path, int _mode, VFSCancelChecker _cancel_checker)
{
    auto &io = RoutedIO::Default;
    int ret = io.mkdir(_path, _mode);
    if(ret == 0)
        return 0;
    return VFSError::FromErrno();
}

int VFSNativeHost::RemoveDirectory(const char *_path, VFSCancelChecker _cancel_checker)
{
    auto &io = RoutedIO::Default;
    int ret = io.rmdir(_path);
    if(ret == 0)
        return 0;
    return VFSError::FromErrno();
}

int VFSNativeHost::ReadSymlink(const char *_path, char *_buffer, size_t _buffer_size, VFSCancelChecker _cancel_checker)
{
    auto &io = RoutedIO::Default;
    ssize_t sz = io.readlink(_path, _buffer, _buffer_size);
    if(sz < 0)
        return VFSError::FromErrno();
    
    if(sz >= _buffer_size)
        return VFSError::SmallBuffer;
    
    _buffer[sz] = 0;
    return 0;
}

int VFSNativeHost::CreateSymlink(const char *_symlink_path,
                                 const char *_symlink_value,
                                 VFSCancelChecker _cancel_checker)
{
    auto &io = RoutedIO::Default;
    int result = io.symlink(_symlink_value, _symlink_path);
    if(result < 0)
        return VFSError::FromErrno();
    
    return 0;
}

int VFSNativeHost::SetTimes(const char *_path,
                            int _flags,
                            struct timespec *_birth_time,
                            struct timespec *_mod_time,
                            struct timespec *_chg_time,
                            struct timespec *_acc_time,
                            VFSCancelChecker _cancel_checker
                            )
{
    if(_path == nullptr)
        return VFSError::InvalidCall;
    
    if(_birth_time == nullptr &&
       _mod_time == nullptr &&
       _chg_time == nullptr &&
       _acc_time == nullptr)
        return 0;
    
    // TODO: optimize this with first opening a file descriptor and then using fsetattrlist.
    // (that should be faster).
    
    int result = 0;
    int flags = (_flags & VFSFlags::F_NoFollow) ? FSOPT_NOFOLLOW : 0;
    struct attrlist attrs;
    memset(&attrs, 0, sizeof(attrs));
    attrs.bitmapcount = ATTR_BIT_MAP_COUNT;
    
    if(_birth_time != nullptr) {
        attrs.commonattr = ATTR_CMN_CRTIME;
        if(setattrlist(_path, &attrs, _birth_time, sizeof(struct timespec), flags) < 0)
            result = VFSError::FromErrno();
    }
    
    if(_chg_time != nullptr) {
        attrs.commonattr = ATTR_CMN_CHGTIME;
        if(setattrlist(_path, &attrs, _chg_time, sizeof(struct timespec), flags) < 0)
            result = VFSError::FromErrno();
    }
    
    if(_mod_time != nullptr) {
        attrs.commonattr = ATTR_CMN_MODTIME;
        if(setattrlist(_path, &attrs, _mod_time, sizeof(struct timespec), flags) < 0)
            result = VFSError::FromErrno();
    }
        
    if(_acc_time != nullptr) {
        attrs.commonattr = ATTR_CMN_ACCTIME;
        if(setattrlist(_path, &attrs, _acc_time, sizeof(struct timespec), flags) < 0)
            result = VFSError::FromErrno();
    }
    
    return result;
}

int VFSNativeHost::Rename(const char *_old_path, const char *_new_path, VFSCancelChecker _cancel_checker)
{
    auto &io = RoutedIO::Default;
    int ret = io.rename(_old_path, _new_path);
    if(ret == 0)
        return 0;
    return VFSError::FromErrno();
}

bool VFSNativeHost::IsNativeFS() const noexcept
{
    return true;
}

VFSConfiguration VFSNativeHost::Configuration() const
{
    static const auto aa = VFSNativeHostConfiguration();
    return aa;
}

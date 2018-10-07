// Copyright (C) 2014-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "NativeFSManager.h"
#include <AppKit/AppKit.h>
#include <DiskArbitration/DiskArbitration.h>
#include <sys/param.h>
#include <sys/ucred.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <Utility/SystemInformation.h>
#include <Utility/FSEventsDirUpdate.h>
#include <Utility/StringExtras.h>
#include <Habanero/dispatch_cpp.h>
#include <Habanero/algo.h>
#include <iostream>
#include "DiskUtility.h"

using namespace std;

namespace nc::utility {

static NativeFSManager *g_SharedFSManager;

static void GetAllInfos(NativeFileSystemInfo &_volume);
static bool GetBasicInfo(NativeFileSystemInfo &_volume);
static bool GetFormatInfo(NativeFileSystemInfo &_volume);
static bool GetInterfacesInfo(NativeFileSystemInfo &_volume);
static bool GetVerboseInfo(NativeFileSystemInfo &_volume);
static bool UpdateSpaceInfo(const NativeFileSystemInfo &_volume);
static bool VolumeHasTrash(const std::string &_volume_path);
static std::optional<std::string> GetBSDName(const NativeFileSystemInfo &_volume);
static vector<string> GetFullFSList();
static DASessionRef DASessionForMainThread();

struct NativeFSManagerProxy2 // this proxy is needed only for private methods access
{
    static void OnDidMount(const string &_on_path) {
        g_SharedFSManager->OnDidMount(_on_path);
    }
    static void OnWillUnmount(const string &_on_path) {
        g_SharedFSManager->OnWillUnmount(_on_path);
    }
    static void OnDidUnmount(const string &_on_path) {
        g_SharedFSManager->OnDidUnmount(_on_path);
    }
    static void OnDidRename(const string &_old_path, const string &_new_path) {
        g_SharedFSManager->OnDidRename(_old_path, _new_path);
    }
};
    
}

@interface NativeFSManagerProxy : NSObject
@end
@implementation NativeFSManagerProxy
+ (void) volumeDidMount:(NSNotification *)aNotification
{
    if( NSString *path = aNotification.userInfo[@"NSDevicePath"] )
        nc::utility::NativeFSManagerProxy2::OnDidMount(path.fileSystemRepresentationSafe);
}

+ (void) volumeDidRename:(NSNotification *)aNotification
{
    if( NSURL *new_path = aNotification.userInfo[NSWorkspaceVolumeURLKey] )
        if( NSURL *old_path = aNotification.userInfo[NSWorkspaceVolumeOldURLKey] )
            nc::utility::NativeFSManagerProxy2::OnDidRename(old_path.path.fileSystemRepresentationSafe,
                                               new_path.path.fileSystemRepresentationSafe);
}

+ (void) volumeWillUnmount:(NSNotification *)aNotification
{
    if( NSString *path = aNotification.userInfo[@"NSDevicePath"] )
        nc::utility::NativeFSManagerProxy2::OnWillUnmount(path.fileSystemRepresentationSafe);
}

+ (void) volumeDidUnmount:(NSNotification *)aNotification
{
    if( NSString *path = aNotification.userInfo[@"NSDevicePath"] )
        nc::utility::NativeFSManagerProxy2::OnDidUnmount(path.fileSystemRepresentationSafe);
}
@end

namespace nc::utility {

NativeFSManager::NativeFSManager()
{
    for( const auto &mount_path: GetFullFSList() ) {
        m_Volumes.emplace_back(make_shared<NativeFileSystemInfo>());
        
        auto volume = m_Volumes.back();
        volume->mounted_at_path = mount_path;
        
        GetAllInfos(*volume.get());
    }
    
	const auto center = NSWorkspace.sharedWorkspace.notificationCenter;
    const auto observer = NativeFSManagerProxy.class;
	[center addObserver:observer selector:@selector(volumeDidMount:)
                   name:NSWorkspaceDidMountNotification object:nil];
	[center addObserver:observer selector:@selector(volumeDidRename:)
                   name:NSWorkspaceDidRenameVolumeNotification object:nil];
	[center addObserver:observer selector:@selector(volumeDidUnmount:)
                   name:NSWorkspaceDidUnmountNotification object:nil];
	[center addObserver:observer selector:@selector(volumeWillUnmount:)
                   name:NSWorkspaceWillUnmountNotification object:nil];
}

NativeFSManager &NativeFSManager::Instance()
{
    static once_flag once;
    call_once(once, []{
        g_SharedFSManager = new NativeFSManager();
    });
    return *g_SharedFSManager;
}

static void GetAllInfos(NativeFileSystemInfo &_volume)
{
    if( !GetBasicInfo(_volume) )
        cerr << "failed to GetBasicInfo() on the volume: " << _volume.mounted_at_path << endl;
    if( !GetFormatInfo(_volume) )
        cerr << "failed to GetFormatInfo() on the volume: " << _volume.mounted_at_path << endl;
    if( !GetInterfacesInfo(_volume) )
        cerr << "failed to GetInterfacesInfo() on the volume: " << _volume.mounted_at_path << endl;
    if( !GetVerboseInfo(_volume) )
        cerr << "failed to GetVerboseInfo() on the volume: " << _volume.mounted_at_path << endl;
    if( !UpdateSpaceInfo(_volume) )
        cerr << "failed to UpdateSpaceInfo() on the volume: " << _volume.mounted_at_path << endl;
}

static bool GetBasicInfo(NativeFileSystemInfo &_volume)
{
    struct statfs stat;
    
    if(statfs(_volume.mounted_at_path.c_str(), &stat) != 0)
        return false;
    
    _volume.fs_type_name = stat.f_fstypename;
    _volume.mounted_from_name = stat.f_mntfromname;
    _volume.basic.fs_id = stat.f_fsid;
    _volume.basic.owner = stat.f_owner;
    _volume.basic.block_size = stat.f_bsize;
    _volume.basic.io_size = stat.f_iosize;
    _volume.basic.total_blocks = stat.f_blocks;
    _volume.basic.free_blocks = stat.f_bfree;
    _volume.basic.available_blocks = stat.f_bavail;
    _volume.basic.total_nodes = stat.f_files;
    _volume.basic.free_nodes = stat.f_ffree;
    _volume.basic.mount_flags = stat.f_flags;

    _volume.mount_flags.read_only           = stat.f_flags & MNT_RDONLY;
    _volume.mount_flags.synchronous         = stat.f_flags & MNT_SYNCHRONOUS;
    _volume.mount_flags.no_exec             = stat.f_flags & MNT_NOEXEC;
    _volume.mount_flags.no_suid             = stat.f_flags & MNT_NOSUID;
    _volume.mount_flags.no_dev              = stat.f_flags & MNT_NODEV;
    _volume.mount_flags.f_union             = stat.f_flags & MNT_UNION;
    _volume.mount_flags.asynchronous        = stat.f_flags & MNT_ASYNC;
    _volume.mount_flags.exported            = stat.f_flags & MNT_EXPORTED;
    _volume.mount_flags.local               = stat.f_flags & MNT_LOCAL;
    _volume.mount_flags.quota               = stat.f_flags & MNT_QUOTA;
    _volume.mount_flags.root                = stat.f_flags & MNT_ROOTFS;
    _volume.mount_flags.vol_fs              = stat.f_flags & MNT_DOVOLFS;
    _volume.mount_flags.dont_browse         = stat.f_flags & MNT_DONTBROWSE;
    _volume.mount_flags.unknown_permissions = stat.f_flags & MNT_UNKNOWNPERMISSIONS;
    _volume.mount_flags.auto_mounted        = stat.f_flags & MNT_AUTOMOUNTED;
    _volume.mount_flags.journaled           = stat.f_flags & MNT_JOURNALED;
    _volume.mount_flags.defer_writes        = stat.f_flags & MNT_DEFWRITE;
    _volume.mount_flags.multi_label         = stat.f_flags & MNT_MULTILABEL;
    _volume.mount_flags.cprotect            = stat.f_flags & MNT_CPROTECT;
    
    
    struct stat entry_stat;
    if( ::stat(_volume.mounted_at_path.c_str(), &entry_stat) != 0 ) {
        cerr << "failed to stat() a volume: " << _volume.mounted_at_path << endl;
        return false;
    }

    _volume.basic.dev_id = entry_stat.st_dev;
    
    return true;
}

static bool GetFormatInfo(NativeFileSystemInfo &_v)
{
    struct
    {
        u_int32_t                   attr_length;
        vol_capabilities_attr_t     c;
    } __attribute__((aligned(4), packed)) i;
    
    struct attrlist attrs;
    memset(&attrs, 0, sizeof(attrs));
    attrs.bitmapcount = ATTR_BIT_MAP_COUNT;
    attrs.volattr = ATTR_VOL_INFO | ATTR_VOL_CAPABILITIES;
    
    if(getattrlist(_v.mounted_at_path.c_str(), &attrs, &i, sizeof(i), 0) != 0)
        return false;
    
    const auto volume_format = i.c.capabilities[VOL_CAPABILITIES_FORMAT];
    _v.format.persistent_objects_ids = volume_format & VOL_CAP_FMT_PERSISTENTOBJECTIDS;
    _v.format.symbolic_links         = volume_format & VOL_CAP_FMT_SYMBOLICLINKS;
    _v.format.hard_links             = volume_format & VOL_CAP_FMT_HARDLINKS;
    _v.format.journal                = volume_format & VOL_CAP_FMT_JOURNAL;
    _v.format.journal_active         = volume_format & VOL_CAP_FMT_JOURNAL_ACTIVE;
    _v.format.no_root_times          = volume_format & VOL_CAP_FMT_NO_ROOT_TIMES;
    _v.format.sparse_files           = volume_format & VOL_CAP_FMT_SPARSE_FILES;
    _v.format.zero_runs              = volume_format & VOL_CAP_FMT_ZERO_RUNS;
    _v.format.case_sensitive         = volume_format & VOL_CAP_FMT_CASE_SENSITIVE;
    _v.format.case_preserving        = volume_format & VOL_CAP_FMT_CASE_PRESERVING;
    _v.format.fast_statfs            = volume_format & VOL_CAP_FMT_FAST_STATFS;
    _v.format.filesize_2tb           = volume_format & VOL_CAP_FMT_2TB_FILESIZE;
    _v.format.open_deny_modes        = volume_format & VOL_CAP_FMT_OPENDENYMODES;
    _v.format.hidden_files           = volume_format & VOL_CAP_FMT_HIDDEN_FILES;
    _v.format.path_from_id           = volume_format & VOL_CAP_FMT_PATH_FROM_ID;
    _v.format.no_volume_sizes        = volume_format & VOL_CAP_FMT_NO_VOLUME_SIZES;
    _v.format.object_ids_64bit       = volume_format & VOL_CAP_FMT_64BIT_OBJECT_IDS;
    _v.format.decmpfs_compression    = volume_format & VOL_CAP_FMT_DECMPFS_COMPRESSION;
    _v.format.dir_hardlinks          = volume_format & VOL_CAP_FMT_DIR_HARDLINKS;
    _v.format.document_id            = volume_format & VOL_CAP_FMT_DOCUMENT_ID;
    _v.format.write_generation_count = volume_format & VOL_CAP_FMT_WRITE_GENERATION_COUNT;
    _v.format.no_immutable_files     = volume_format & VOL_CAP_FMT_NO_IMMUTABLE_FILES;
    _v.format.no_permissions         = volume_format & VOL_CAP_FMT_NO_PERMISSIONS;
    return true;
}

static bool GetInterfacesInfo(NativeFileSystemInfo &_v)
{
    struct
    {
        u_int32_t                   attr_length;
        vol_capabilities_attr_t     c;
    } __attribute__((aligned(4), packed)) i;
    
    struct attrlist attrs;
    memset(&attrs, 0, sizeof(attrs));
    attrs.bitmapcount = ATTR_BIT_MAP_COUNT;
    attrs.volattr = ATTR_VOL_INFO | ATTR_VOL_CAPABILITIES;
    
    if(getattrlist(_v.mounted_at_path.c_str(), &attrs, &i, sizeof(i), 0) != 0)
        return false;
    const auto volume_interfaces = i.c.capabilities[VOL_CAPABILITIES_INTERFACES];
    _v.interfaces.search_fs         = volume_interfaces & VOL_CAP_INT_SEARCHFS;
    _v.interfaces.attr_list         = volume_interfaces & VOL_CAP_INT_ATTRLIST;
    _v.interfaces.nfs_export        = volume_interfaces & VOL_CAP_INT_NFSEXPORT;
    _v.interfaces.read_dir_attr     = volume_interfaces & VOL_CAP_INT_READDIRATTR;
    _v.interfaces.exchange_data     = volume_interfaces & VOL_CAP_INT_EXCHANGEDATA;
    _v.interfaces.copy_file         = volume_interfaces & VOL_CAP_INT_COPYFILE;
    _v.interfaces.allocate          = volume_interfaces & VOL_CAP_INT_ALLOCATE;
    _v.interfaces.vol_rename        = volume_interfaces & VOL_CAP_INT_VOL_RENAME;
    _v.interfaces.adv_lock          = volume_interfaces & VOL_CAP_INT_ADVLOCK;
    _v.interfaces.file_lock         = volume_interfaces & VOL_CAP_INT_FLOCK;
    _v.interfaces.extended_security = volume_interfaces & VOL_CAP_INT_EXTENDED_SECURITY;
    _v.interfaces.user_access       = volume_interfaces & VOL_CAP_INT_USERACCESS;
    _v.interfaces.mandatory_lock    = volume_interfaces & VOL_CAP_INT_MANLOCK;
    _v.interfaces.extended_attr     = volume_interfaces & VOL_CAP_INT_EXTENDED_ATTR;
    _v.interfaces.named_streams     = volume_interfaces & VOL_CAP_INT_NAMEDSTREAMS;
    _v.interfaces.clone             = volume_interfaces & VOL_CAP_INT_CLONE;
    _v.interfaces.snapshot          = volume_interfaces & VOL_CAP_INT_SNAPSHOT;
    _v.interfaces.rename_swap       = volume_interfaces & VOL_CAP_INT_RENAME_SWAP;
    _v.interfaces.rename_excl       = volume_interfaces & VOL_CAP_INT_RENAME_EXCL;
    _v.interfaces.has_trash         = VolumeHasTrash(_v.mounted_at_path);
    return true;
}

static bool GetVerboseInfo(NativeFileSystemInfo &_volume)
{
    NSString *path_str = [NSString stringWithUTF8String:_volume.mounted_at_path.c_str()];
    if(path_str == nil)
        return false;

    _volume.verbose.mounted_at_path = path_str;
    
    NSURL *url = [NSURL fileURLWithPath:path_str isDirectory:true];
    if(url == nil)
        return false;
    
    _volume.verbose.url = url;
    
    NSString *string;
    NSImage *img;
    NSNumber *number;
    NSError *error;
    
    if([url getResourceValue:&string forKey:NSURLVolumeNameKey error:&error])
        _volume.verbose.name = string;
    if(!_volume.verbose.name)
        _volume.verbose.name = @"";
    
    if([url getResourceValue:&string forKey:NSURLVolumeLocalizedNameKey error:&error])
        _volume.verbose.localized_name = string;
    if(!_volume.verbose.localized_name)
        _volume.verbose.localized_name = @"";
    
    if([url getResourceValue:&img forKey:NSURLEffectiveIconKey error:&error])
        _volume.verbose.icon = img;
    else
        _volume.verbose.icon = nil;
    
    if([url getResourceValue:&number forKey:NSURLVolumeIsEjectableKey error:&error])
        _volume.mount_flags.ejectable = number.boolValue;
    else
        _volume.mount_flags.ejectable = false;
    
    if([url getResourceValue:&number forKey:NSURLVolumeIsRemovableKey error:&error])
        _volume.mount_flags.removable = number.boolValue;
    else
        _volume.mount_flags.removable = false;
    
    if([url getResourceValue:&number forKey:NSURLVolumeIsInternalKey error:&error])
        _volume.mount_flags.internal = number.boolValue;
    else
        _volume.mount_flags.internal = false;
    
    return true;
}

void NativeFSManager::OnDidMount(const string &_on_path)
{
    // presumably called from main thread, so go async to keep UI smooth
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), [=]{
        auto volume = make_shared<NativeFileSystemInfo>();
        volume->mounted_at_path = _on_path;
        GetAllInfos(*volume.get());
        
        lock_guard<mutex> lock(m_Lock);
        InsertNewVolume_Unlocked(volume);
    });
}

void NativeFSManager::InsertNewVolume_Unlocked( const shared_ptr<NativeFileSystemInfo> &_volume )
{
    const auto it = find_if(begin(m_Volumes),
                            end(m_Volumes),
                            [=] (shared_ptr<NativeFileSystemInfo>& _v) {
                                return _v->mounted_at_path == _volume->mounted_at_path;
                            });
    if( it != end(m_Volumes) )
        *it = _volume;
    else
        m_Volumes.emplace_back(_volume);
}

void NativeFSManager::OnWillUnmount(const string &_on_path)
{
}

void NativeFSManager::OnDidUnmount(const string &_on_path)
{
    m_Lock.lock();
    
    auto it = find_if(begin(m_Volumes),
                      end(m_Volumes),
                      [&] (shared_ptr<NativeFileSystemInfo>& _v) {
                          return _v->mounted_at_path == _on_path;
                        }
                      );
    if(it != end(m_Volumes))
        m_Volumes.erase(it);
    
    m_Lock.unlock();
    
    FSEventsDirUpdate::Instance().OnVolumeDidUnmount(_on_path);
}

void NativeFSManager::OnDidRename(const string &_old_path, const string &_new_path)
{
    m_Lock.lock();
    
    auto it = find_if(begin(m_Volumes),
                      end(m_Volumes),
                      [&] (shared_ptr<NativeFileSystemInfo>& _v) {
                          return _v->mounted_at_path == _old_path;
                        }
                      );
    if(it != end(m_Volumes))
    {
        auto volume = *it;
        volume->mounted_at_path = _new_path;
        GetVerboseInfo(*volume.get());
    }
    else
    {
        OnDidMount(_new_path);
    }

    m_Lock.unlock();

    FSEventsDirUpdate::Instance().OnVolumeDidUnmount(_old_path);
}

vector<NativeFSManager::Info> NativeFSManager::Volumes() const
{
    lock_guard<mutex> lock(m_Lock);
    vector<NativeFSManager::Info> volumes( begin(m_Volumes), end(m_Volumes) );
    return volumes;
}

static bool UpdateSpaceInfo(const NativeFileSystemInfo &_volume)
{
    struct statfs stat;
    
    if( statfs(_volume.mounted_at_path.c_str(), &stat) != 0 )
        return false;
    
    _volume.basic.total_blocks      = stat.f_blocks;
    _volume.basic.free_blocks       = stat.f_bfree;
    _volume.basic.available_blocks  = stat.f_bavail;

    _volume.basic.total_bytes       = _volume.basic.block_size * _volume.basic.total_blocks;
    _volume.basic.free_bytes        = _volume.basic.block_size * _volume.basic.free_blocks;
    _volume.basic.available_bytes   = _volume.basic.block_size * _volume.basic.available_blocks;

    return true;
}

void NativeFSManager::UpdateSpaceInformation(const Info &_volume)
{
    if( !_volume )
        return;
    
    UpdateSpaceInfo( *_volume.get() );
}

NativeFSManager::Info NativeFSManager::VolumeFromFD(int _fd) const
{
    struct stat st;
    if( fstat(_fd, &st) < 0 )
        return nullptr;
    return VolumeFromDevID( st.st_dev );
}

NativeFSManager::Info NativeFSManager::VolumeFromPathFast(const string &_path) const
{
    lock_guard<mutex> lock(m_Lock);
    return VolumeFromPathFast_Unlocked(_path);
}

NativeFSManager::Info NativeFSManager::VolumeFromPathFast_Unlocked(const string &_path) const
{
    if( _path.empty() )
        return {};

    shared_ptr<NativeFileSystemInfo> result;
    size_t best_fit_sz = 0;
    for(auto &vol: m_Volumes)
        if( _path.compare(0, vol->mounted_at_path.size(), vol->mounted_at_path) == 0 &&
            vol->mounted_at_path.size() > best_fit_sz ) {
            best_fit_sz = vol->mounted_at_path.size();
            result = vol;
        }
    
    return result;
}

NativeFSManager::Info NativeFSManager::VolumeFromMountPoint(const string &_mount_point) const
{
    return VolumeFromMountPoint( _mount_point.c_str() );
}

NativeFSManager::Info NativeFSManager::VolumeFromMountPoint(const char *_mount_point) const
{
    lock_guard<mutex> lock(m_Lock);
    return VolumeFromMountPoint_Unlocked(_mount_point);
}

NativeFSManager::Info NativeFSManager::VolumeFromMountPoint_Unlocked(const char *_mount_point) const
{
    if( !_mount_point )
        return nullptr;
    const auto it = find_if(begin(m_Volumes),
                            end(m_Volumes),
                            [=](auto&_){ return _->mounted_at_path == _mount_point; } );
    if( it != end(m_Volumes) )
        return *it;
    return nullptr;
}

NativeFSManager::Info NativeFSManager::VolumeFromDevID(dev_t _dev_id) const
{
    lock_guard<mutex> lock(m_Lock);
    return VolumeFromDevID_Unlocked(_dev_id);
}

NativeFSManager::Info NativeFSManager::VolumeFromDevID_Unlocked(dev_t _dev_id) const
{
    const auto it = find_if(begin(m_Volumes),
                            end(m_Volumes),
                            [=](auto&_){ return _->basic.dev_id == _dev_id; } );
    if( it != end(m_Volumes) )
        return *it;
    return nullptr;
}

NativeFSManager::Info NativeFSManager::VolumeFromPath(const string &_path) const
{
    return VolumeFromPath( _path.c_str() );
}

NativeFSManager::Info NativeFSManager::VolumeFromPath(const char* _path) const
{
    // TODO: compare performance with stat() and searching for fs with dev_id    
    struct statfs info;
    if(_path == nullptr ||
       statfs(_path, &info) < 0)
        return nullptr;
    
    return VolumeFromMountPoint((const char*)info.f_mntonname);
}

bool NativeFSManager::IsVolumeContainingPathEjectable(const string &_path)
{
    auto volume = VolumeFromPath(_path);
    
    if(!volume)
        return false;
    
    using namespace std::string_literals;
    static const auto excl_list = {"/net"sv, "/dev"sv, "/home"sv};

    if( std::find(excl_list.begin(), excl_list.end(), volume->mounted_at_path) != excl_list.end() )
        return false;
        
    return  volume->mount_flags.ejectable   == true  ||
            volume->mount_flags.removable   == true  ||
            volume->mount_flags.internal    == false ||
            volume->mount_flags.local       == false ;
}

void NativeFSManager::EjectVolumeContainingPath(const string &_path)
{
    dispatch_to_main_queue([=]{
        if( const auto volume = VolumeFromPath(_path) )
            PerformUnmounting(volume);
    });
}

void NativeFSManager::PerformUnmounting(const Info &_volume)
{
    dispatch_assert_main_queue();
    
    if( _volume->fs_type_name == "apfs" ) {
        PerformAPFSUnmounting(_volume);
    }
    else {
        PerformGenericUnmounting(_volume);
    }    
}

static void GenericDiskUnmountCallback( DADiskRef _disk, DADissenterRef _dissenter, void *_context )
{
    if( _dissenter != nullptr )
        return;
        
    const auto whole_disk = DADiskCopyWholeDisk(_disk);
    if( whole_disk == nullptr )
        return;
    auto release_disk = at_scope_end([=]{ CFRelease(whole_disk); });    
    
    DADiskEject(whole_disk, kDADiskEjectOptionDefault, nullptr, nullptr);
}

void NativeFSManager::PerformGenericUnmounting(const Info &_volume)
{
    const auto session = DASessionForMainThread();
    
    const auto url = (__bridge CFURLRef)_volume->verbose.url;
    const auto disk = DADiskCreateFromVolumePath(kCFAllocatorDefault, session, url);
    if( disk == nullptr )
        return;
    auto release_disk = at_scope_end([=]{ CFRelease(disk); });
        
    if( _volume->mount_flags.ejectable ) {
        DADiskUnmount(disk, kDADiskUnmountOptionForce, GenericDiskUnmountCallback, nullptr);
    }
    else {
        DADiskUnmount(disk, kDADiskUnmountOptionForce, nullptr, nullptr);            
    }
}

struct APFSUnmountingContext
{
    APFSUnmountingContext(nc::utility::APFSTree _tree,
                          const NativeFSManager::Info &_unmounted_volume ):
        apfs_tree(std::move(_tree)),
        unmounted_volume(_unmounted_volume)
    {
    }
    
    nc::utility::APFSTree apfs_tree;
    NativeFSManager::Info unmounted_volume;
};

static void APFSUnmountCallback( DADiskRef _disk, DADissenterRef _dissenter, void *_context )
{
    const auto context = std::unique_ptr<APFSUnmountingContext>{(APFSUnmountingContext*)_context};
    
    if( _dissenter != nullptr )
        return;
    
    const auto volume_bsd_name = GetBSDName(*context->unmounted_volume);
    if( volume_bsd_name == std::nullopt )
        return;
    
    const auto apfs_container = context->apfs_tree.FindContainerOfVolume(*volume_bsd_name);
    if( apfs_container == std::nullopt )
        return;
    
    // TODO:
    // do we need to check whether other volumes in this container are not mounted at the moment?
    // is it guaranteed that the disk will not be ejected while there is still some mounted volume?
    
    const auto stores = context->apfs_tree.FindPhysicalStoresOfContainer(*apfs_container);
    if( stores == std::nullopt )
        return;
    
    for( const auto &store: *stores ) {
        const auto store_partition = DADiskCreateFromBSDName(kCFAllocatorDefault,
                                                             DASessionForMainThread(),
                                                             store.c_str());
        if( store_partition == nullptr )
            continue;
        auto release_disk = at_scope_end([=]{ CFRelease(store_partition); });        
        
        const auto whole_disk = DADiskCopyWholeDisk(store_partition);
        if( whole_disk == nullptr )
            continue;
        auto release_whole_disk = at_scope_end([=]{ CFRelease(whole_disk); });        
           
        DADiskEject(whole_disk, kDADiskEjectOptionDefault, nullptr, nullptr);
    }    
}

void NativeFSManager::PerformAPFSUnmounting(const Info &_volume)
{    
    const auto url = (__bridge CFURLRef)_volume->verbose.url;
    const auto disk = DADiskCreateFromVolumePath(kCFAllocatorDefault, DASessionForMainThread(),url);
    if( disk == nullptr )
        return;
    auto release_disk = at_scope_end([=]{ CFRelease(disk); }); 
    
    if( _volume->mount_flags.ejectable ) {
        const auto apfs_plist = nc::utility::DiskUtility{}.ListAPFSObjects();
        if( apfs_plist == nil )
            return;
        
        auto context = std::make_unique<APFSUnmountingContext>(nc::utility::APFSTree{apfs_plist},
                                                               _volume);
        
        DADiskUnmount(disk, kDADiskUnmountOptionForce, APFSUnmountCallback, context.release());
    }
    else {
        DADiskUnmount(disk, kDADiskUnmountOptionForce, nullptr, nullptr);            
    }    
}

static bool VolumeHasTrash(const string &_volume_path)
{
    const auto url = CFURLCreateFromFileSystemRepresentation(0,
                                                             (const UInt8*)_volume_path.c_str(),
                                                             _volume_path.length(),
                                                             true);
    if( !url )
        return false;
    const auto trash = [[NSFileManager defaultManager] URLForDirectory:NSTrashDirectory
                                                              inDomain:NSUserDomainMask
                                                     appropriateForURL:(__bridge NSURL*)url
                                                                create:true
                                                                 error:nil];
    CFRelease(url);
    return trash != nil;
}

static vector<string> GetFullFSList()
{
    struct statfs* mounts;
    struct stat st;
    int num_mounts = getmntinfo(&mounts, MNT_WAIT);
    
    vector<string> result;
    for (int i = 0; i < num_mounts; i++)
        if(lstat(mounts[i].f_mntonname, &st) == 0)
            result.emplace_back(mounts[i].f_mntonname);
            
            return result;
}

static DASessionRef DASessionForMainThread()
{
    dispatch_assert_main_queue();
    static const auto session = []{
        const auto s = DASessionCreate(kCFAllocatorDefault);
        DASessionScheduleWithRunLoop(s, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);        
        return s;
    }();
    return session;
}

static std::optional<std::string> GetBSDName(const NativeFileSystemInfo &_volume)
{
    const auto &source = _volume.mounted_from_name;
    const auto prefix = std::string_view{"/dev/"};
    if( source.length() <= prefix.length() || source.compare(0, prefix.length(), prefix) != 0 )
        return {};
    
    return source.substr( prefix.length() );
}

}

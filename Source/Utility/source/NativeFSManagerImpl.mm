// Copyright (C) 2014-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "NativeFSManagerImpl.h"
#include <AppKit/AppKit.h>
#include <Base/CFPtr.h>
#include <Base/StackAllocator.h>
#include <Base/algo.h>
#include <Base/dispatch_cpp.h>
#include <DiskArbitration/DiskArbitration.h>
#include <Utility/FSEventsDirUpdate.h>
#include <Utility/Log.h>
#include <Utility/PathManip.h>
#include <Utility/StringExtras.h>
#include <Utility/SystemInformation.h>
#include <algorithm>
#include <fstream>
#include <future>
#include <iostream>
#include <string_view>
#include <sys/mount.h>
#include <sys/param.h>
#include <sys/stat.h>
#include <sys/ucred.h>

@interface NCUtilityNativeFSManagerNotificationsReceiver : NSObject
@property(readwrite, nonatomic) std::function<void(NSNotification *)> onVolumeDidMount;
@property(readwrite, nonatomic) std::function<void(NSNotification *)> onVolumeDidRename;
@property(readwrite, nonatomic) std::function<void(NSNotification *)> onVolumeWillUnmount;
@property(readwrite, nonatomic) std::function<void(NSNotification *)> onVolumeDidUnmount;
- (void)volumeDidMount:(NSNotification *)_notification;
- (void)volumeDidRename:(NSNotification *)_notification;
- (void)volumeWillUnmount:(NSNotification *)_notification;
- (void)volumeDidUnmount:(NSNotification *)_notification;
@end

namespace nc::utility {

static const auto g_FirmlinksMappingPath = "/usr/share/firmlinks";

static void GetAllInfos(NativeFileSystemInfo &_volume);
static bool GetBasicInfo(NativeFileSystemInfo &_volume);
static bool GetFormatInfo(NativeFileSystemInfo &_volume);
static bool GetInterfacesInfo(NativeFileSystemInfo &_volume);
static bool GetVerboseInfo(NativeFileSystemInfo &_volume);
static bool UpdateSpaceInfo(NativeFileSystemInfo &_volume);
static bool VolumeHasTrash(const std::string &_volume_path);
static std::optional<std::string> GetBSDName(const NativeFileSystemInfo &_volume);
static std::vector<std::string> GetFullFSList();
static DASessionRef DASessionForMainThread();
static std::optional<APFSTree> FetchAPFSTree() noexcept;
static std::vector<FirmlinksMappingParser::Firmlink> FetchFirmlinks() noexcept;

NativeFSManagerImpl::NativeFSManagerImpl()
{
    Log::Debug("Started initializing NativeFSManagerImpl {}", static_cast<void *>(this));
    // it takes ~150ms, so this delay can be shaved off by running it async
    auto apfstree_promise = std::async(std::launch::async, [] { return FetchAPFSTree(); });

    Log::Trace("Gathering info about all native filesystems {}", static_cast<void *>(this));
    for( const auto &mount_path : GetFullFSList() ) {
        const auto volume = std::make_shared<NativeFileSystemInfo>();
        volume->mounted_at_path = mount_path;
        m_Volumes.emplace_back(volume);
        GetAllInfos(*volume);

        m_VolumeLookup.Insert(volume, EnsureTrailingSlash(mount_path));
    }

    Log::Trace("Getting APFSTree {}", static_cast<void *>(this));
    m_StartupAPFSTree = apfstree_promise.get();

    Log::Trace("Getting firmlinks {}", static_cast<void *>(this));
    m_RootFirmlinks = FetchFirmlinks();

    if( m_StartupAPFSTree )
        InjectRootFirmlinks(*m_StartupAPFSTree);
    m_NotificationsReceiver = [[NCUtilityNativeFSManagerNotificationsReceiver alloc] init];

    SubscribeToWorkspaceNotifications();

    Log::Debug("Finished initializing NativeFSManagerImpl {}", static_cast<void *>(this));
}

NativeFSManagerImpl::~NativeFSManagerImpl()
{
    UnsubscribeFromWorkspaceNotifications();
}

void NativeFSManagerImpl::SubscribeToWorkspaceNotifications()
{
    const auto receiver = m_NotificationsReceiver;
    assert(receiver);

    receiver.onVolumeDidMount = [this](NSNotification *_notification) {
        if( NSString *const path = _notification.userInfo[@"NSDevicePath"] )
            OnDidMount(path.fileSystemRepresentationSafe);
    };
    receiver.onVolumeDidRename = [this](NSNotification *_notification) {
        NSURL *const new_path = _notification.userInfo[NSWorkspaceVolumeURLKey];
        NSURL *const old_path = _notification.userInfo[NSWorkspaceVolumeOldURLKey];
        if( new_path && old_path )
            OnDidRename(old_path.path.fileSystemRepresentationSafe, new_path.path.fileSystemRepresentationSafe);
    };
    receiver.onVolumeWillUnmount = [this](NSNotification *_notification) {
        if( NSString *const path = _notification.userInfo[@"NSDevicePath"] )
            OnWillUnmount(path.fileSystemRepresentationSafe);
    };
    receiver.onVolumeDidUnmount = [this](NSNotification *_notification) {
        if( NSString *const path = _notification.userInfo[@"NSDevicePath"] )
            OnDidUnmount(path.fileSystemRepresentationSafe);
    };

    const auto center = NSWorkspace.sharedWorkspace.notificationCenter;
    [center addObserver:receiver selector:@selector(volumeDidMount:) name:NSWorkspaceDidMountNotification object:nil];
    [center addObserver:receiver
               selector:@selector(volumeDidRename:)
                   name:NSWorkspaceDidRenameVolumeNotification
                 object:nil];
    [center addObserver:receiver
               selector:@selector(volumeWillUnmount:)
                   name:NSWorkspaceWillUnmountNotification
                 object:nil];
    [center addObserver:receiver
               selector:@selector(volumeDidUnmount:)
                   name:NSWorkspaceDidUnmountNotification
                 object:nil];
}

void NativeFSManagerImpl::UnsubscribeFromWorkspaceNotifications()
{
    const auto receiver = m_NotificationsReceiver;
    assert(receiver);

    const auto center = NSWorkspace.sharedWorkspace.notificationCenter;
    [center removeObserver:receiver name:NSWorkspaceDidMountNotification object:nil];
    [center removeObserver:receiver name:NSWorkspaceDidRenameVolumeNotification object:nil];
    [center removeObserver:receiver name:NSWorkspaceWillUnmountNotification object:nil];
    [center removeObserver:receiver name:NSWorkspaceDidUnmountNotification object:nil];
}

static void GetAllInfos(NativeFileSystemInfo &_volume)
{
    Log::Info("Gatherning info about {}", _volume.mounted_at_path);

    if( !GetBasicInfo(_volume) )
        Log::Error("failed to GetBasicInfo() on the volume {}", _volume.mounted_at_path);

    if( !GetFormatInfo(_volume) )
        Log::Error("failed to GetFormatInfo() on the volume {}", _volume.mounted_at_path);

    if( !GetInterfacesInfo(_volume) )
        Log::Error("failed to GetInterfacesInfo() on the volume {}", _volume.mounted_at_path);

    if( !GetVerboseInfo(_volume) )
        Log::Error("failed to GetVerboseInfo() on the volume {}", _volume.mounted_at_path);

    if( !UpdateSpaceInfo(_volume) )
        Log::Error("failed to UpdateSpaceInfo() on the volume {}", _volume.mounted_at_path);
}

static bool GetBasicInfo(NativeFileSystemInfo &_volume)
{
    Log::Trace("Getting basic info about {}", _volume.mounted_at_path);

    struct statfs stat;

    if( statfs(_volume.mounted_at_path.c_str(), &stat) != 0 )
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

    _volume.mount_flags.read_only = stat.f_flags & MNT_RDONLY;
    _volume.mount_flags.synchronous = stat.f_flags & MNT_SYNCHRONOUS;
    _volume.mount_flags.no_exec = stat.f_flags & MNT_NOEXEC;
    _volume.mount_flags.no_suid = stat.f_flags & MNT_NOSUID;
    _volume.mount_flags.no_dev = stat.f_flags & MNT_NODEV;
    _volume.mount_flags.f_union = stat.f_flags & MNT_UNION;
    _volume.mount_flags.asynchronous = stat.f_flags & MNT_ASYNC;
    _volume.mount_flags.exported = stat.f_flags & MNT_EXPORTED;
    _volume.mount_flags.local = stat.f_flags & MNT_LOCAL;
    _volume.mount_flags.quota = stat.f_flags & MNT_QUOTA;
    _volume.mount_flags.root = stat.f_flags & MNT_ROOTFS;
    _volume.mount_flags.vol_fs = stat.f_flags & MNT_DOVOLFS;
    _volume.mount_flags.dont_browse = stat.f_flags & MNT_DONTBROWSE;
    _volume.mount_flags.unknown_permissions = stat.f_flags & MNT_UNKNOWNPERMISSIONS;
    _volume.mount_flags.auto_mounted = stat.f_flags & MNT_AUTOMOUNTED;
    _volume.mount_flags.journaled = stat.f_flags & MNT_JOURNALED;
    _volume.mount_flags.defer_writes = stat.f_flags & MNT_DEFWRITE;
    _volume.mount_flags.multi_label = stat.f_flags & MNT_MULTILABEL;
    _volume.mount_flags.cprotect = stat.f_flags & MNT_CPROTECT;

    struct stat entry_stat;
    if( ::stat(_volume.mounted_at_path.c_str(), &entry_stat) != 0 ) {
        std::cerr << "failed to stat() a volume: " << _volume.mounted_at_path << '\n';
        return false;
    }

    _volume.basic.dev_id = entry_stat.st_dev;

    return true;
}

static bool GetFormatInfo(NativeFileSystemInfo &_v)
{
    Log::Trace("Getting format info about {}", _v.mounted_at_path);

    struct {
        u_int32_t attr_length;
        vol_capabilities_attr_t c;
    } __attribute__((aligned(4), packed)) i;

    struct attrlist attrs;
    memset(&attrs, 0, sizeof(attrs));
    attrs.bitmapcount = ATTR_BIT_MAP_COUNT;
    attrs.volattr = ATTR_VOL_INFO | ATTR_VOL_CAPABILITIES;

    if( getattrlist(_v.mounted_at_path.c_str(), &attrs, &i, sizeof(i), 0) != 0 )
        return false;

    const auto volume_format = i.c.capabilities[VOL_CAPABILITIES_FORMAT];
    _v.format.persistent_objects_ids = volume_format & VOL_CAP_FMT_PERSISTENTOBJECTIDS;
    _v.format.symbolic_links = volume_format & VOL_CAP_FMT_SYMBOLICLINKS;
    _v.format.hard_links = volume_format & VOL_CAP_FMT_HARDLINKS;
    _v.format.journal = volume_format & VOL_CAP_FMT_JOURNAL;
    _v.format.journal_active = volume_format & VOL_CAP_FMT_JOURNAL_ACTIVE;
    _v.format.no_root_times = volume_format & VOL_CAP_FMT_NO_ROOT_TIMES;
    _v.format.sparse_files = volume_format & VOL_CAP_FMT_SPARSE_FILES;
    _v.format.zero_runs = volume_format & VOL_CAP_FMT_ZERO_RUNS;
    _v.format.case_sensitive = volume_format & VOL_CAP_FMT_CASE_SENSITIVE;
    _v.format.case_preserving = volume_format & VOL_CAP_FMT_CASE_PRESERVING;
    _v.format.fast_statfs = volume_format & VOL_CAP_FMT_FAST_STATFS;
    _v.format.filesize_2tb = volume_format & VOL_CAP_FMT_2TB_FILESIZE;
    _v.format.open_deny_modes = volume_format & VOL_CAP_FMT_OPENDENYMODES;
    _v.format.hidden_files = volume_format & VOL_CAP_FMT_HIDDEN_FILES;
    _v.format.path_from_id = volume_format & VOL_CAP_FMT_PATH_FROM_ID;
    _v.format.no_volume_sizes = volume_format & VOL_CAP_FMT_NO_VOLUME_SIZES;
    _v.format.object_ids_64bit = volume_format & VOL_CAP_FMT_64BIT_OBJECT_IDS;
    _v.format.decmpfs_compression = volume_format & VOL_CAP_FMT_DECMPFS_COMPRESSION;
    _v.format.dir_hardlinks = volume_format & VOL_CAP_FMT_DIR_HARDLINKS;
    _v.format.document_id = volume_format & VOL_CAP_FMT_DOCUMENT_ID;
    _v.format.write_generation_count = volume_format & VOL_CAP_FMT_WRITE_GENERATION_COUNT;
    _v.format.no_immutable_files = volume_format & VOL_CAP_FMT_NO_IMMUTABLE_FILES;
    _v.format.no_permissions = volume_format & VOL_CAP_FMT_NO_PERMISSIONS;
    _v.format.shared_space = volume_format & VOL_CAP_FMT_SHARED_SPACE;
    _v.format.volume_groups = volume_format & VOL_CAP_FMT_VOL_GROUPS;
    _v.format.sealed = volume_format & VOL_CAP_FMT_SEALED;
    return true;
}

static bool GetInterfacesInfo(NativeFileSystemInfo &_v)
{
    Log::Trace("Getting interface info about {}", _v.mounted_at_path);
    struct {
        u_int32_t attr_length;
        vol_capabilities_attr_t c;
    } __attribute__((aligned(4), packed)) i;

    struct attrlist attrs;
    memset(&attrs, 0, sizeof(attrs));
    attrs.bitmapcount = ATTR_BIT_MAP_COUNT;
    attrs.volattr = ATTR_VOL_INFO | ATTR_VOL_CAPABILITIES;

    if( getattrlist(_v.mounted_at_path.c_str(), &attrs, &i, sizeof(i), 0) != 0 )
        return false;
    const auto volume_interfaces = i.c.capabilities[VOL_CAPABILITIES_INTERFACES];
    _v.interfaces.search_fs = volume_interfaces & VOL_CAP_INT_SEARCHFS;
    _v.interfaces.attr_list = volume_interfaces & VOL_CAP_INT_ATTRLIST;
    _v.interfaces.nfs_export = volume_interfaces & VOL_CAP_INT_NFSEXPORT;
    _v.interfaces.read_dir_attr = volume_interfaces & VOL_CAP_INT_READDIRATTR;
    _v.interfaces.exchange_data = volume_interfaces & VOL_CAP_INT_EXCHANGEDATA;
    _v.interfaces.copy_file = volume_interfaces & VOL_CAP_INT_COPYFILE;
    _v.interfaces.allocate = volume_interfaces & VOL_CAP_INT_ALLOCATE;
    _v.interfaces.vol_rename = volume_interfaces & VOL_CAP_INT_VOL_RENAME;
    _v.interfaces.adv_lock = volume_interfaces & VOL_CAP_INT_ADVLOCK;
    _v.interfaces.file_lock = volume_interfaces & VOL_CAP_INT_FLOCK;
    _v.interfaces.extended_security = volume_interfaces & VOL_CAP_INT_EXTENDED_SECURITY;
    _v.interfaces.user_access = volume_interfaces & VOL_CAP_INT_USERACCESS;
    _v.interfaces.mandatory_lock = volume_interfaces & VOL_CAP_INT_MANLOCK;
    _v.interfaces.extended_attr = volume_interfaces & VOL_CAP_INT_EXTENDED_ATTR;
    _v.interfaces.named_streams = volume_interfaces & VOL_CAP_INT_NAMEDSTREAMS;
    _v.interfaces.clone = volume_interfaces & VOL_CAP_INT_CLONE;
    _v.interfaces.snapshot = volume_interfaces & VOL_CAP_INT_SNAPSHOT;
    _v.interfaces.rename_swap = volume_interfaces & VOL_CAP_INT_RENAME_SWAP;
    _v.interfaces.rename_excl = volume_interfaces & VOL_CAP_INT_RENAME_EXCL;
    _v.interfaces.has_trash = VolumeHasTrash(_v.mounted_at_path);
    return true;
}

static bool GetVerboseInfo(NativeFileSystemInfo &_volume)
{
    Log::Trace("Getting verbose info about {}", _volume.mounted_at_path);

    NSString *const path_str = [NSString stringWithUTF8String:_volume.mounted_at_path.c_str()];
    if( path_str == nil )
        return false;

    _volume.verbose.mounted_at_path = path_str;

    NSURL *const url = [NSURL fileURLWithPath:path_str isDirectory:true];
    if( url == nil )
        return false;

    _volume.verbose.url = url;

    NSString *string;
    NSImage *img;
    NSNumber *number;
    NSError *error;

    if( [url getResourceValue:&string forKey:NSURLVolumeNameKey error:&error] )
        _volume.verbose.name = string;
    if( !_volume.verbose.name )
        _volume.verbose.name = @"";

    if( [url getResourceValue:&string forKey:NSURLVolumeLocalizedNameKey error:&error] )
        _volume.verbose.localized_name = string;
    if( !_volume.verbose.localized_name )
        _volume.verbose.localized_name = @"";

    if( [url getResourceValue:&img forKey:NSURLEffectiveIconKey error:&error] )
        _volume.verbose.icon = img;
    else
        _volume.verbose.icon = nil;

    if( [url getResourceValue:&number forKey:NSURLVolumeIsEjectableKey error:&error] )
        _volume.mount_flags.ejectable = number.boolValue;
    else
        _volume.mount_flags.ejectable = false;

    if( [url getResourceValue:&number forKey:NSURLVolumeIsRemovableKey error:&error] )
        _volume.mount_flags.removable = number.boolValue;
    else
        _volume.mount_flags.removable = false;

    if( [url getResourceValue:&number forKey:NSURLVolumeIsInternalKey error:&error] )
        _volume.mount_flags.internal = number.boolValue;
    else
        _volume.mount_flags.internal = false;

    return true;
}

void NativeFSManagerImpl::OnDidMount(const std::string &_on_path)
{
    // presumably called from main thread, so go async to keep UI smooth
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), [=, this] {
        auto volume = std::make_shared<NativeFileSystemInfo>();
        volume->mounted_at_path = _on_path;
        GetAllInfos(*volume);

        const std::lock_guard<std::mutex> lock(m_Lock);
        InsertNewVolume_Unlocked(volume);
    });
}

void NativeFSManagerImpl::InsertNewVolume_Unlocked(const std::shared_ptr<NativeFileSystemInfo> &_volume)
{
    const auto pred = [=](const std::shared_ptr<NativeFileSystemInfo> &_v) {
        return _v->mounted_at_path == _volume->mounted_at_path;
    };
    const auto it = std::ranges::find_if(m_Volumes, pred);
    if( it != std::end(m_Volumes) )
        *it = _volume;
    else
        m_Volumes.emplace_back(_volume);

    m_VolumeLookup.Insert(_volume, EnsureTrailingSlash(_volume->mounted_at_path));
}

void NativeFSManagerImpl::OnWillUnmount([[maybe_unused]] const std::string &_on_path)
{
}

void NativeFSManagerImpl::OnDidUnmount(const std::string &_on_path)
{
    {
        const std::lock_guard lock{m_Lock};
        const auto pred = [=](std::shared_ptr<NativeFileSystemInfo> &_v) { return _v->mounted_at_path == _on_path; };
        const auto it = std::ranges::find_if(m_Volumes, pred);
        if( it != std::end(m_Volumes) )
            m_Volumes.erase(it);

        m_VolumeLookup.Remove(EnsureTrailingSlash(_on_path));
    }

    FSEventsDirUpdate::Instance().OnVolumeDidUnmount(_on_path);
}

void NativeFSManagerImpl::OnDidRename(const std::string &_old_path, const std::string &_new_path)
{
    {
        const std::lock_guard lock{m_Lock};

        const auto pred = [=](std::shared_ptr<NativeFileSystemInfo> &_v) { return _v->mounted_at_path == _old_path; };
        auto it = std::ranges::find_if(m_Volumes, pred);
        if( it != std::end(m_Volumes) ) {
            const auto &volume = *it;
            volume->mounted_at_path = _new_path;
            GetVerboseInfo(*volume);
            m_VolumeLookup.Remove(EnsureTrailingSlash(_old_path));
            m_VolumeLookup.Insert(volume, EnsureTrailingSlash(_new_path));
        }
        else {
            OnDidMount(_new_path);
        }
    }

    FSEventsDirUpdate::Instance().OnVolumeDidUnmount(_old_path);
}

std::vector<NativeFSManager::Info> NativeFSManagerImpl::Volumes() const
{
    const std::lock_guard<std::mutex> lock(m_Lock);
    std::vector<NativeFSManager::Info> volumes(std::begin(m_Volumes), std::end(m_Volumes));
    return volumes;
}

static bool UpdateSpaceInfo(NativeFileSystemInfo &_volume)
{
    struct statfs stat;

    if( statfs(_volume.mounted_at_path.c_str(), &stat) != 0 )
        return false;

    _volume.basic.total_blocks = stat.f_blocks;
    _volume.basic.free_blocks = stat.f_bfree;
    _volume.basic.available_blocks = stat.f_bavail;

    _volume.basic.total_bytes = _volume.basic.block_size * _volume.basic.total_blocks;
    _volume.basic.free_bytes = _volume.basic.block_size * _volume.basic.free_blocks;
    _volume.basic.available_bytes = _volume.basic.block_size * _volume.basic.available_blocks;

    return true;
}

void NativeFSManagerImpl::UpdateSpaceInformation(const Info &_volume)
{
    if( !_volume )
        return;

    UpdateSpaceInfo(const_cast<NativeFileSystemInfo &>(*_volume.get()));
}

NativeFSManager::Info NativeFSManagerImpl::VolumeFromFD(int _fd) const noexcept
{
    struct statfs info;
    if( fstatfs(_fd, &info) < 0 )
        return nullptr;

    return VolumeFromMountPoint(info.f_mntonname);
}

NativeFSManager::Info NativeFSManagerImpl::VolumeFromPathFast(std::string_view _path) const noexcept
{
    const std::lock_guard<std::mutex> lock(m_Lock);
    return m_VolumeLookup.FindVolumeForLocation(_path);
}

NativeFSManager::Info NativeFSManagerImpl::VolumeFromMountPoint(std::string_view _mount_point) const noexcept
{
    if( _mount_point.empty() )
        return nullptr;

    const std::lock_guard<std::mutex> lock(m_Lock);
    return VolumeFromMountPoint_Unlocked(_mount_point);
}

NativeFSManagerImpl::Info
NativeFSManagerImpl::VolumeFromMountPoint_Unlocked(std::string_view _mount_point) const noexcept
{
    if( _mount_point.empty() )
        return nullptr;
    const auto it = std::ranges::find_if(m_Volumes, [=](auto &_) { return _->mounted_at_path == _mount_point; });
    if( it != std::end(m_Volumes) )
        return *it;
    return nullptr;
}

NativeFSManagerImpl::Info NativeFSManagerImpl::VolumeFromBSDName_Unlocked(std::string_view _bsd_name) const noexcept
{
    // not sure how legit this is...
    const auto device = "/dev/" + std::string(_bsd_name);
    const auto it = std::ranges::find_if(m_Volumes, [&](auto &_) { return _->mounted_from_name == device; });
    if( it != std::end(m_Volumes) )
        return *it;
    return nullptr;
}

NativeFSManager::Info NativeFSManagerImpl::VolumeFromPath(std::string_view _path) const noexcept
{
    if( _path.empty() )
        return nullptr;

    nc::StackAllocator alloc;
    const std::pmr::string path(_path, &alloc);
    struct statfs info;
    if( statfs(path.c_str(), &info) < 0 )
        return nullptr;

    return VolumeFromMountPoint(info.f_mntonname);
}

bool NativeFSManagerImpl::IsVolumeContainingPathEjectable(const std::string &_path)
{
    auto volume = VolumeFromPath(_path);

    if( !volume )
        return false;

    using namespace std::string_view_literals;
    static const auto excl_list = std::initializer_list<std::string_view>{"/net"sv, "/dev"sv, "/home"sv};

    if( std::ranges::find(excl_list, volume->mounted_at_path) != excl_list.end() )
        return false;

    return volume->mount_flags.ejectable || volume->mount_flags.removable || !volume->mount_flags.internal ||
           !volume->mount_flags.local;
}

void NativeFSManagerImpl::EjectVolumeContainingPath(const std::string &_path)
{
    dispatch_to_main_queue([=, this] {
        if( const auto volume = VolumeFromPath(_path) )
            PerformUnmounting(volume);
    });
}

void NativeFSManagerImpl::PerformUnmounting(const Info &_volume)
{
    dispatch_assert_main_queue();

    if( _volume->fs_type_name == "apfs" ) {
        PerformAPFSUnmounting(_volume);
    }
    else {
        PerformGenericUnmounting(_volume);
    }
}

void NativeFSManagerImpl::InjectRootFirmlinks(const APFSTree &_tree)
{
    // get volume info for the root mount point
    const auto root = VolumeFromMountPoint_Unlocked("/");
    if( root == nullptr )
        return;

    // get BSD name of that volume
    auto root_bsd_name = GetBSDName(*root);
    if( root_bsd_name == std::nullopt )
        return;

    // remove snapshot information - BigSur (+?)
    const auto root_snapshot_pattern = std::string_view("diskXsYsZ");
    if( root_bsd_name->length() == root_snapshot_pattern.length() ) {
        // e.g. disk3s1s1 -> disk3s1
        auto pattern = *root_bsd_name;
        pattern[4] = root_snapshot_pattern[4];
        pattern[6] = root_snapshot_pattern[6];
        pattern[8] = root_snapshot_pattern[8];
        if( pattern == root_snapshot_pattern ) {
            root_bsd_name->resize(root_snapshot_pattern.length() - 2);
        }
    }

    // pick the APFS container of the root volume
    const auto container = _tree.FindContainerOfVolume(*root_bsd_name);
    if( container == std::nullopt )
        return;

    // ensure that "/" has the "System" APFS role, otherwise bail out
    const auto system_volumes = _tree.FindVolumesInContainerWithRole(*container, APFSTree::Role::System);
    if( system_volumes == std::nullopt ||
        std::find(system_volumes->begin(), system_volumes->end(), *root_bsd_name) == system_volumes->end() )
        return;

    // being extra-cautios here and proceed only if there's exactly one Data volume in the
    // container. otherwise there's an ambiguity
    const auto data_volumes = _tree.FindVolumesInContainerWithRole(*container, APFSTree::Role::Data);
    if( data_volumes == std::nullopt || data_volumes->size() != 1 )
        return;

    // find the volume with the Data role
    const std::string &data_volume_bsd_id = data_volumes->front();
    const auto data_volume_ptr = VolumeFromBSDName_Unlocked(data_volume_bsd_id);
    if( data_volume_ptr == nullptr )
        return;

    // ... and finaly inject the firmlinks into the lookup table
    for( const auto &firmlink : m_RootFirmlinks )
        m_VolumeLookup.Insert(data_volume_ptr, EnsureTrailingSlash(firmlink.target));
}

static void GenericDiskUnmountCallback(DADiskRef _disk, DADissenterRef _dissenter, [[maybe_unused]] void *_context)
{
    if( _dissenter != nullptr )
        return;

    const auto whole_disk = DADiskCopyWholeDisk(_disk);
    if( whole_disk == nullptr )
        return;
    auto release_disk = at_scope_end([=] { CFRelease(whole_disk); });

    DADiskEject(whole_disk, kDADiskEjectOptionDefault, nullptr, nullptr);
}

void NativeFSManagerImpl::PerformGenericUnmounting(const Info &_volume)
{
    const auto session = DASessionForMainThread();

    const auto url = (__bridge CFURLRef)_volume->verbose.url;
    const auto disk = DADiskCreateFromVolumePath(kCFAllocatorDefault, session, url);
    if( disk == nullptr )
        return;
    auto release_disk = at_scope_end([=] { CFRelease(disk); });

    if( _volume->mount_flags.ejectable ) {
        DADiskUnmount(disk, kDADiskUnmountOptionForce, GenericDiskUnmountCallback, nullptr);
    }
    else {
        DADiskUnmount(disk, kDADiskUnmountOptionForce, nullptr, nullptr);
    }
}

struct APFSUnmountingContext {
    APFSUnmountingContext(nc::utility::APFSTree _tree, const NativeFSManager::Info &_unmounted_volume)
        : apfs_tree(std::move(_tree)), unmounted_volume(_unmounted_volume)
    {
    }

    nc::utility::APFSTree apfs_tree;
    NativeFSManager::Info unmounted_volume;
};

static void APFSUnmountCallback([[maybe_unused]] DADiskRef _disk, DADissenterRef _dissenter, void *_context)
{
    const auto context = std::unique_ptr<APFSUnmountingContext>{static_cast<APFSUnmountingContext *>(_context)};

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

    for( const auto &store : *stores ) {
        const auto store_partition =
            DADiskCreateFromBSDName(kCFAllocatorDefault, DASessionForMainThread(), store.c_str());
        if( store_partition == nullptr )
            continue;
        auto release_disk = at_scope_end([=] { CFRelease(store_partition); });

        const auto whole_disk = DADiskCopyWholeDisk(store_partition);
        if( whole_disk == nullptr )
            continue;
        auto release_whole_disk = at_scope_end([=] { CFRelease(whole_disk); });

        DADiskEject(whole_disk, kDADiskEjectOptionDefault, nullptr, nullptr);
    }
}

void NativeFSManagerImpl::PerformAPFSUnmounting(const Info &_volume)
{
    const auto url = (__bridge CFURLRef)_volume->verbose.url;
    const auto disk = DADiskCreateFromVolumePath(kCFAllocatorDefault, DASessionForMainThread(), url);
    if( disk == nullptr )
        return;
    auto release_disk = at_scope_end([=] { CFRelease(disk); });

    if( _volume->mount_flags.ejectable ) {
        const auto apfs_plist = nc::utility::DiskUtility::ListAPFSObjects();
        if( apfs_plist == nil )
            return;

        auto context = std::make_unique<APFSUnmountingContext>(nc::utility::APFSTree{apfs_plist}, _volume);

        DADiskUnmount(disk, kDADiskUnmountOptionForce, APFSUnmountCallback, context.release());
    }
    else {
        DADiskUnmount(disk, kDADiskUnmountOptionForce, nullptr, nullptr);
    }
}

static bool VolumeHasTrash(const std::string &_volume_path)
{
    const auto url = base::CFPtr<CFURLRef>::adopt(CFURLCreateFromFileSystemRepresentation(
        kCFAllocatorDefault, reinterpret_cast<const UInt8 *>(_volume_path.c_str()), _volume_path.length(), true));
    if( !url )
        return false;

    const auto file_manager = NSFileManager.defaultManager;
    const auto trash = [file_manager URLForDirectory:NSTrashDirectory
                                            inDomain:NSUserDomainMask
                                   appropriateForURL:(__bridge NSURL *)url.get()
                                              create:false
                                               error:nil];
    return trash != nil;
}

static std::vector<std::string> GetFullFSList()
{
    struct statfs *mounts_ptr = nullptr;
    const int num_mounts = getmntinfo_r_np(&mounts_ptr, MNT_NOWAIT);
    const std::unique_ptr<struct statfs[], decltype(&std::free)> mounts(mounts_ptr, &std::free);

    std::vector<std::string> result;
    for( int i = 0; i < num_mounts; i++ ) {
        struct stat st;
        if( lstat(mounts[i].f_mntonname, &st) == 0 )
            result.emplace_back(mounts[i].f_mntonname);
    }

    return result;
}

static DASessionRef DASessionForMainThread()
{
    dispatch_assert_main_queue();
    static const auto session = [] {
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
    if( source.length() <= prefix.length() || !source.starts_with(prefix) )
        return {};

    return source.substr(prefix.length());
}

static std::optional<APFSTree> FetchAPFSTree() noexcept
{
    try {
        auto dictionary = nc::utility::DiskUtility::ListAPFSObjects();
        if( dictionary == nil )
            return std::nullopt;
        return APFSTree{dictionary};
    } catch( ... ) {
        return std::nullopt;
    }
}

static std::vector<FirmlinksMappingParser::Firmlink> FetchFirmlinks() noexcept
{
    try {
        std::ifstream in(g_FirmlinksMappingPath, std::ios::in | std::ios::binary);
        if( !in )
            return {};
        std::string mapping;
        in.seekg(0, std::ios::end);
        mapping.resize(in.tellg());
        in.seekg(0, std::ios::beg);
        in.read(mapping.data(), mapping.size());
        in.close();

        return nc::utility::FirmlinksMappingParser::Parse(mapping);
    } catch( ... ) {
        return {};
    }
}

} // namespace nc::utility

@implementation NCUtilityNativeFSManagerNotificationsReceiver

@synthesize onVolumeDidMount;
@synthesize onVolumeDidRename;
@synthesize onVolumeWillUnmount;
@synthesize onVolumeDidUnmount;

- (void)volumeDidMount:(NSNotification *)_notification
{
    if( self.onVolumeDidMount )
        self.onVolumeDidMount(_notification);
}

- (void)volumeDidRename:(NSNotification *)_notification
{
    if( self.onVolumeDidRename )
        self.onVolumeDidRename(_notification);
}

- (void)volumeWillUnmount:(NSNotification *)_notification
{
    if( self.onVolumeWillUnmount )
        self.onVolumeWillUnmount(_notification);
}

- (void)volumeDidUnmount:(NSNotification *)_notification
{
    if( self.onVolumeDidUnmount )
        self.onVolumeDidUnmount(_notification);
}

@end

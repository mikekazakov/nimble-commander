//
//  NativeFSManager.cpp
//  Files
//
//  Created by Michael G. Kazakov on 22.01.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#include <sys/param.h>
#include <sys/ucred.h>
#include <sys/mount.h>
#include <algorithm>
#include "NativeFSManager.h"
#include "FSEventsDirUpdate.h"

static NativeFSManager *g_SharedFSManager;

static vector<string> GetFullFSList()
{
    struct statfs* mounts;
    int num_mounts = getmntinfo(&mounts, MNT_WAIT);
    
    vector<string> result;
    for (int i = 0; i < num_mounts; i++)
        result.emplace_back(mounts[i].f_mntonname);
    
    return result;
}

struct NativeFSManagerProxy2
{
    static void OnDidMount(string _on_path)     { g_SharedFSManager->OnDidMount(_on_path);      }
    static void OnWillUnmount(string _on_path)  { g_SharedFSManager->OnWillUnmount(_on_path);   }
    static void OnDidUnmount(string _on_path)   { g_SharedFSManager->OnDidUnmount(_on_path);    }
};

@interface NativeFSManagerProxy : NSObject
@end

@implementation NativeFSManagerProxy
+ (void) volumeDidMount:(NSNotification *)aNotification
{    
    NSString *path = aNotification.userInfo[@"NSDevicePath"];
    NativeFSManagerProxy2::OnDidMount([path fileSystemRepresentation]);
}

+ (void) volumeWillUnmount:(NSNotification *)aNotification
{
    NSString *path = aNotification.userInfo[@"NSDevicePath"];
    NativeFSManagerProxy2::OnWillUnmount([path fileSystemRepresentation]);
}

+ (void) volumeDidUnmount:(NSNotification *)aNotification
{
    NSString *path = aNotification.userInfo[@"NSDevicePath"];
    NativeFSManagerProxy2::OnDidUnmount([path fileSystemRepresentation]);
}
@end

NativeFSManager::NativeFSManager()
{
    auto list = GetFullFSList();

    for(auto &i: list)
    {
        m_Volumes.emplace_back(make_shared<NativeFileSystemInfo>());
        
        auto volume = m_Volumes.back();
        volume->mounted_at_path = i;
        
        GetAllInfos(*volume.get());
    }
    
    NSWorkspace *workspace = NSWorkspace.sharedWorkspace;
	NSNotificationCenter *center = workspace.notificationCenter;
    
    //TODO: NSWorkspaceDidRenameVolumeNotification
	[center addObserver:[NativeFSManagerProxy class] selector:@selector(volumeDidMount:) name:NSWorkspaceDidMountNotification object:nil];
	[center addObserver:[NativeFSManagerProxy class] selector:@selector(volumeDidUnmount:) name:NSWorkspaceDidUnmountNotification object:nil];
	[center addObserver:[NativeFSManagerProxy class] selector:@selector(volumeWillUnmount:) name:NSWorkspaceWillUnmountNotification object:nil];
}

NativeFSManager &NativeFSManager::Instance()
{
    static dispatch_once_t once;
    
    dispatch_once(&once, ^{
        g_SharedFSManager = new NativeFSManager();
        assert(g_SharedFSManager != nullptr);
    });
    
    return *g_SharedFSManager;
}

void NativeFSManager::GetAllInfos(NativeFileSystemInfo &_volume)
{
    GetBasicInfo(_volume);
    GetFormatInfo(_volume);
    GetInterfacesInfo(_volume);
    GetVerboseInfo(_volume);
}

bool NativeFSManager::GetBasicInfo(NativeFileSystemInfo &_volume)
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
    return true;
}

bool NativeFSManager::GetFormatInfo(NativeFileSystemInfo &_v)
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
    
    _v.format.persistent_objects_ids = i.c.capabilities[VOL_CAPABILITIES_FORMAT] & VOL_CAP_FMT_PERSISTENTOBJECTIDS;
    _v.format.symbolic_links         = i.c.capabilities[VOL_CAPABILITIES_FORMAT] & VOL_CAP_FMT_SYMBOLICLINKS;
    _v.format.hard_links             = i.c.capabilities[VOL_CAPABILITIES_FORMAT] & VOL_CAP_FMT_HARDLINKS;
    _v.format.journal                = i.c.capabilities[VOL_CAPABILITIES_FORMAT] & VOL_CAP_FMT_JOURNAL;
    _v.format.journal_active         = i.c.capabilities[VOL_CAPABILITIES_FORMAT] & VOL_CAP_FMT_JOURNAL_ACTIVE;
    _v.format.no_root_times          = i.c.capabilities[VOL_CAPABILITIES_FORMAT] & VOL_CAP_FMT_NO_ROOT_TIMES;
    _v.format.sparse_files           = i.c.capabilities[VOL_CAPABILITIES_FORMAT] & VOL_CAP_FMT_SPARSE_FILES;
    _v.format.zero_runs              = i.c.capabilities[VOL_CAPABILITIES_FORMAT] & VOL_CAP_FMT_ZERO_RUNS;
    _v.format.case_sensitive         = i.c.capabilities[VOL_CAPABILITIES_FORMAT] & VOL_CAP_FMT_CASE_SENSITIVE;
    _v.format.case_preserving        = i.c.capabilities[VOL_CAPABILITIES_FORMAT] & VOL_CAP_FMT_CASE_PRESERVING;
    _v.format.fast_statfs            = i.c.capabilities[VOL_CAPABILITIES_FORMAT] & VOL_CAP_FMT_FAST_STATFS;
    _v.format.filesize_2tb           = i.c.capabilities[VOL_CAPABILITIES_FORMAT] & VOL_CAP_FMT_2TB_FILESIZE;
    _v.format.open_deny_modes        = i.c.capabilities[VOL_CAPABILITIES_FORMAT] & VOL_CAP_FMT_OPENDENYMODES;
    _v.format.hidden_files           = i.c.capabilities[VOL_CAPABILITIES_FORMAT] & VOL_CAP_FMT_HIDDEN_FILES;
    _v.format.path_from_id           = i.c.capabilities[VOL_CAPABILITIES_FORMAT] & VOL_CAP_FMT_PATH_FROM_ID;
    _v.format.no_volume_sizes        = i.c.capabilities[VOL_CAPABILITIES_FORMAT] & VOL_CAP_FMT_NO_VOLUME_SIZES;
    _v.format.object_ids_64bit       = i.c.capabilities[VOL_CAPABILITIES_FORMAT] & VOL_CAP_FMT_64BIT_OBJECT_IDS;
    _v.format.decmpfs_compression    = i.c.capabilities[VOL_CAPABILITIES_FORMAT] & VOL_CAP_FMT_DECMPFS_COMPRESSION;
    
    return true;
}

bool NativeFSManager::GetInterfacesInfo(NativeFileSystemInfo &_v)
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
    
    _v.interfaces.search_fs         = i.c.capabilities[VOL_CAPABILITIES_INTERFACES] & VOL_CAP_INT_SEARCHFS;
    _v.interfaces.attr_list         = i.c.capabilities[VOL_CAPABILITIES_INTERFACES] & VOL_CAP_INT_ATTRLIST;
    _v.interfaces.nfs_export        = i.c.capabilities[VOL_CAPABILITIES_INTERFACES] & VOL_CAP_INT_NFSEXPORT;
    _v.interfaces.read_dir_attr     = i.c.capabilities[VOL_CAPABILITIES_INTERFACES] & VOL_CAP_INT_READDIRATTR;
    _v.interfaces.exchange_data     = i.c.capabilities[VOL_CAPABILITIES_INTERFACES] & VOL_CAP_INT_EXCHANGEDATA;
    _v.interfaces.copy_file         = i.c.capabilities[VOL_CAPABILITIES_INTERFACES] & VOL_CAP_INT_COPYFILE;
    _v.interfaces.allocate          = i.c.capabilities[VOL_CAPABILITIES_INTERFACES] & VOL_CAP_INT_ALLOCATE;
    _v.interfaces.vol_rename        = i.c.capabilities[VOL_CAPABILITIES_INTERFACES] & VOL_CAP_INT_VOL_RENAME;
    _v.interfaces.adv_lock          = i.c.capabilities[VOL_CAPABILITIES_INTERFACES] & VOL_CAP_INT_ADVLOCK;
    _v.interfaces.file_lock         = i.c.capabilities[VOL_CAPABILITIES_INTERFACES] & VOL_CAP_INT_FLOCK;
    _v.interfaces.extended_security = i.c.capabilities[VOL_CAPABILITIES_INTERFACES] & VOL_CAP_INT_EXTENDED_SECURITY;
    _v.interfaces.user_access       = i.c.capabilities[VOL_CAPABILITIES_INTERFACES] & VOL_CAP_INT_USERACCESS;
    _v.interfaces.mandatory_lock    = i.c.capabilities[VOL_CAPABILITIES_INTERFACES] & VOL_CAP_INT_MANLOCK;
    _v.interfaces.extended_attr     = i.c.capabilities[VOL_CAPABILITIES_INTERFACES] & VOL_CAP_INT_EXTENDED_ATTR;
    _v.interfaces.named_strems      = i.c.capabilities[VOL_CAPABILITIES_INTERFACES] & VOL_CAP_INT_NAMEDSTREAMS;
    
    return true;
}

bool NativeFSManager::GetVerboseInfo(NativeFileSystemInfo &_volume)
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
    NSError *error;
    
    if([url getResourceValue:&string forKey:NSURLVolumeNameKey error:&error])
        _volume.verbose.name = string;
    
    if([url getResourceValue:&string forKey:NSURLVolumeLocalizedNameKey error:&error])
        _volume.verbose.localized_name = string;
    
    if([url getResourceValue:&img forKey:NSURLEffectiveIconKey error:&error])
        _volume.verbose.icon = img;
    
    return true;
}

void NativeFSManager::OnDidMount(string _on_path)
{
    // presumably called from main thread, so go async to keep UI smooth
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        auto volume = make_shared<NativeFileSystemInfo>();
        volume->mounted_at_path = _on_path;
        GetAllInfos(*volume.get());
        
        m_Lock.lock();
        auto it = find_if(begin(m_Volumes),
                          end(m_Volumes),
                          [=] (shared_ptr<NativeFileSystemInfo>& _v) {
                              return _v->mounted_at_path == _on_path;
                            }
                          );
        if(it != end(m_Volumes))
            m_Volumes.erase(it);
        
        m_Volumes.emplace_back(volume);
        
        m_Lock.unlock();
    });
}

void NativeFSManager::OnWillUnmount(string _on_path)
{
}

void NativeFSManager::OnDidUnmount(string _on_path)
{
    m_Lock.lock();
    
    auto it = find_if(begin(m_Volumes),
                      end(m_Volumes),
                      [=] (shared_ptr<NativeFileSystemInfo>& _v) {
                          return _v->mounted_at_path == _on_path;
                        }
                      );
    if(it != end(m_Volumes))
        m_Volumes.erase(it);
    
    m_Lock.unlock();
    
    FSEventsDirUpdate::OnVolumeDidUnmount(_on_path);
}

vector<shared_ptr<NativeFileSystemInfo>> NativeFSManager::Volumes()
{
    m_Lock.lock();
    auto copy = m_Volumes;
    m_Lock.unlock();
    
    return copy;
}

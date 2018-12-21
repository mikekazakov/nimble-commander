// Copyright (C) 2013-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <sys/param.h>
#include <sys/mount.h>
#include <unistd.h>

// see getattrlist function documentation to get info about values
struct VolumeCapabilitiesInformation
{
    enum {attr_valid = 0, attr_native = 1};
    struct
    {
        bool persistent_objects_ids;
        bool symbolic_links;
        bool hard_links;
        bool journal;
        bool journal_active;
        bool no_root_times;
        bool sparse_files;
        bool zero_runs;
        bool case_sensitive;
        bool case_preserving;
        bool fast_statfs;
        bool filesize_2tb;
        bool open_deny_modes;
        bool hidden_files;
        bool path_from_id;
        bool no_volume_sizes;
        bool object_ids_64bit;
        bool decmpfs_compression;
    } fmt;
    struct
    {
        bool search_fs;
        bool attr_list;
        bool nfs_export;
        bool read_dir_attr;
        bool exchange_data;
        bool copy_file;
        bool allocate;
        bool vol_rename;
        bool adv_lock;
        bool file_lock;
        bool extended_security;
        bool user_access;
        bool mandatory_lock;
        bool extended_attr;
        bool named_strems;
    } intr;
    struct
    {
        struct
        {
            bool name[2];
            bool dev_id[2];
            bool fs_id[2];
            bool obj_type[2];
            bool obj_tag[2];
            bool obj_id[2];
            bool obj_permanent_id[2];
            bool par_obj_id[2];
            bool script[2];
            bool cr_time[2];
            bool mod_time[2];
            bool chg_time[2];
            bool acc_time[2];
            bool bkup_time[2];
            bool fndr_info[2];
            bool owner_id[2];
            bool grp_id[2];
            bool access_mask[2];
            bool named_attr_count[2];
            bool named_attr_list[2];
            bool flags[2];
            bool user_access[2];
            bool extended_security[2];
            bool uuid[2];
            bool grp_uuid[2];
            bool file_id[2];
            bool parent_id[2];
            bool full_path[2];
            bool added_time[2];
        } cmn;
        struct
        {
            bool fs_type[2];
            bool signature[2];
            bool size[2];
            bool space_free[2];
            bool space_avail[2];
            bool min_allocation[2];
            bool allocation_clump[2];
            bool io_block_size[2];
            bool obj_count[2];
            bool file_count[2];
            bool dir_count[2];
            bool max_obj_count[2];
            bool mount_point[2];
            bool name[2];
            bool mount_flags[2];
            bool mounted_device[2];
            bool encoding_used[2];
            bool uuid[2];
        } vol;
        struct
        {
            bool link_count[2];
            bool entry_count[2];
            bool mount_status[2];
        } dir;
        struct
        {
            bool link_count[2];
            bool total_size[2];
            bool alloc_size[2];
            bool io_block_size[2];
            bool clump_size[2];
            bool dev_type[2];
            bool file_type[2];
            bool fork_count[2];
            bool fork_list[2];
            bool data_length[2];
            bool data_alloc_size[2];
            bool data_extents[2];
            bool rsrc_length[2];
            bool rsrc_alloc_size[2];
            bool rsrc_extents[2];
        } file;
    } attr;
};

struct VolumeAttributesInformation
{
    u_int32_t fs_type;
    u_int32_t signature;
    off_t     size;
    off_t     space_free;
    off_t     space_avail;
    off_t     min_allocation;
    off_t     allocation_clump;
    u_int32_t io_block_size;
    u_int32_t obj_count;
    u_int32_t file_count;
    u_int32_t dir_count;
    u_int32_t max_obj_count;
    char      mount_point[MAXPATHLEN];
    char      name[NAME_MAX + 1];
    u_int32_t mount_flags;
    char      mounted_device[MAXPATHLEN];
    unsigned long long encoding_used;
    uuid_t    uuid;
    char      fs_type_name[MFSNAMELEN]; // this field is retrieved from statfs, not from getattrlist
    uid_t     fs_owner;                 // this field is retrieved from statfs, not from getattrlist
    char      fs_type_verb[256];        // from CFURL framework
    bool      is_sw_ejectable;
    bool      is_sw_removable;
    bool      is_local;
    bool      is_internal;
};

// all functions below return 0 on successful completion or errno on error
int FetchVolumeCapabilitiesInformation(const char *_path,
                                       VolumeCapabilitiesInformation *_c);

int FetchVolumeAttributesInformation(const char *_path,
                                     const VolumeCapabilitiesInformation *_c,
                                     VolumeAttributesInformation *_a);
// fetches only information available for current volume, choosing it whith _c
// it fetches available info even it's not native for file system - when drivers layer emulates it

//
//  filesysinfo.cpp
//  Directories
//
//  Created by Michael G. Kazakov on 21.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include <sys/attr.h>
#include <sys/vnode.h>
#include <sys/param.h>
#include <sys/mount.h>
#include <unistd.h>
#include "filesysinfo.h"

int FetchVolumeCapabilitiesInformation(const char *_path, VolumeCapabilitiesInformation *_c)
{
    struct
    {
        u_int32_t                   attr_length;
        vol_capabilities_attr_t     c;
        vol_attributes_attr_t       a;
    } info;

    int             err;
    struct attrlist attrs;
    memset(&attrs, 0, sizeof(attrs));
    attrs.bitmapcount = ATTR_BIT_MAP_COUNT;    
    attrs.volattr = ATTR_VOL_INFO | ATTR_VOL_CAPABILITIES | ATTR_VOL_ATTRIBUTES;
    
    err = getattrlist(_path, &attrs, &info, sizeof(info), 0);
    if(err == 0)
    {
#define CAPAB(_a, _b) (info.c.capabilities[(_a)] & info.c.valid[(_a)] & (_b))
        _c->fmt.persistent_objects_ids =    CAPAB(VOL_CAPABILITIES_FORMAT, VOL_CAP_FMT_PERSISTENTOBJECTIDS);
        _c->fmt.symbolic_links =            CAPAB(VOL_CAPABILITIES_FORMAT, VOL_CAP_FMT_SYMBOLICLINKS);
        _c->fmt.hard_links =                CAPAB(VOL_CAPABILITIES_FORMAT, VOL_CAP_FMT_HARDLINKS);
        _c->fmt.journal =                   CAPAB(VOL_CAPABILITIES_FORMAT, VOL_CAP_FMT_JOURNAL);
        _c->fmt.journal_active =            CAPAB(VOL_CAPABILITIES_FORMAT, VOL_CAP_FMT_JOURNAL_ACTIVE);
        _c->fmt.no_root_times =             CAPAB(VOL_CAPABILITIES_FORMAT, VOL_CAP_FMT_NO_ROOT_TIMES);
        _c->fmt.sparse_files =              CAPAB(VOL_CAPABILITIES_FORMAT, VOL_CAP_FMT_SPARSE_FILES);
        _c->fmt.zero_runs =                 CAPAB(VOL_CAPABILITIES_FORMAT, VOL_CAP_FMT_ZERO_RUNS);
        _c->fmt.case_sensitive =            CAPAB(VOL_CAPABILITIES_FORMAT, VOL_CAP_FMT_CASE_SENSITIVE);
        _c->fmt.case_preserving =           CAPAB(VOL_CAPABILITIES_FORMAT, VOL_CAP_FMT_CASE_PRESERVING);
        _c->fmt.fast_statfs =               CAPAB(VOL_CAPABILITIES_FORMAT, VOL_CAP_FMT_FAST_STATFS);
        _c->fmt.filesize_2tb =              CAPAB(VOL_CAPABILITIES_FORMAT, VOL_CAP_FMT_2TB_FILESIZE);
        _c->fmt.open_deny_modes =           CAPAB(VOL_CAPABILITIES_FORMAT, VOL_CAP_FMT_OPENDENYMODES);
        _c->fmt.hidden_files =              CAPAB(VOL_CAPABILITIES_FORMAT, VOL_CAP_FMT_HIDDEN_FILES);
        _c->fmt.path_from_id =              CAPAB(VOL_CAPABILITIES_FORMAT, VOL_CAP_FMT_PATH_FROM_ID);
        _c->fmt.no_volume_sizes =           CAPAB(VOL_CAPABILITIES_FORMAT, VOL_CAP_FMT_NO_VOLUME_SIZES);
        _c->fmt.object_ids_64bit =          CAPAB(VOL_CAPABILITIES_FORMAT, VOL_CAP_FMT_64BIT_OBJECT_IDS);
        _c->intr.search_fs =                CAPAB(VOL_CAPABILITIES_INTERFACES, VOL_CAP_INT_SEARCHFS);
        _c->intr.attr_list =                CAPAB(VOL_CAPABILITIES_INTERFACES, VOL_CAP_INT_ATTRLIST);
        _c->intr.nfs_export =               CAPAB(VOL_CAPABILITIES_INTERFACES, VOL_CAP_INT_NFSEXPORT);
        _c->intr.read_dir_attr =            CAPAB(VOL_CAPABILITIES_INTERFACES, VOL_CAP_INT_READDIRATTR);
        _c->intr.exchange_data =            CAPAB(VOL_CAPABILITIES_INTERFACES, VOL_CAP_INT_EXCHANGEDATA);
        _c->intr.copy_file =                CAPAB(VOL_CAPABILITIES_INTERFACES, VOL_CAP_INT_COPYFILE);
        _c->intr.allocate =                 CAPAB(VOL_CAPABILITIES_INTERFACES, VOL_CAP_INT_ALLOCATE);
        _c->intr.vol_rename =               CAPAB(VOL_CAPABILITIES_INTERFACES, VOL_CAP_INT_VOL_RENAME);
        _c->intr.adv_lock =                 CAPAB(VOL_CAPABILITIES_INTERFACES, VOL_CAP_INT_ADVLOCK);
        _c->intr.file_lock =                CAPAB(VOL_CAPABILITIES_INTERFACES, VOL_CAP_INT_FLOCK);
        _c->intr.extended_security =        CAPAB(VOL_CAPABILITIES_INTERFACES, VOL_CAP_INT_EXTENDED_SECURITY);
        _c->intr.user_access =              CAPAB(VOL_CAPABILITIES_INTERFACES, VOL_CAP_INT_USERACCESS);
        _c->intr.mandatory_lock =           CAPAB(VOL_CAPABILITIES_INTERFACES, VOL_CAP_INT_MANLOCK);
        _c->intr.extended_attr =            CAPAB(VOL_CAPABILITIES_INTERFACES, VOL_CAP_INT_EXTENDED_ATTR);
        _c->intr.named_strems =             CAPAB(VOL_CAPABILITIES_INTERFACES, VOL_CAP_INT_NAMEDSTREAMS);
#undef CAPAB
#define ATTRIB(_a, _b, _d) \
        _c->attr._a[0] = info.a.validattr._b & _d; \
        _c->attr._a[1] = info.a.nativeattr._b & _d;

        ATTRIB(cmn.name,             commonattr, ATTR_CMN_NAME);
        ATTRIB(cmn.dev_id,           commonattr, ATTR_CMN_DEVID);
        ATTRIB(cmn.fs_id,            commonattr, ATTR_CMN_FSID);
        ATTRIB(cmn.obj_type,         commonattr, ATTR_CMN_OBJTYPE);
        ATTRIB(cmn.obj_id,           commonattr, ATTR_CMN_OBJID);
        ATTRIB(cmn.obj_permanent_id, commonattr, ATTR_CMN_OBJPERMANENTID);
        ATTRIB(cmn.par_obj_id,       commonattr, ATTR_CMN_PAROBJID);
        ATTRIB(cmn.script,           commonattr, ATTR_CMN_SCRIPT);
        ATTRIB(cmn.cr_time,          commonattr, ATTR_CMN_CRTIME);
        ATTRIB(cmn.mod_time,         commonattr, ATTR_CMN_MODTIME);
        ATTRIB(cmn.chg_time,         commonattr, ATTR_CMN_CHGTIME);
        ATTRIB(cmn.acc_time,         commonattr, ATTR_CMN_ACCTIME);
        ATTRIB(cmn.bkup_time,        commonattr, ATTR_CMN_BKUPTIME);
        ATTRIB(cmn.fndr_info,        commonattr, ATTR_CMN_FNDRINFO);
        ATTRIB(cmn.owner_id,         commonattr, ATTR_CMN_OWNERID);
        ATTRIB(cmn.grp_id,           commonattr, ATTR_CMN_GRPID);
        ATTRIB(cmn.access_mask,      commonattr, ATTR_CMN_ACCESSMASK);
        ATTRIB(cmn.named_attr_count, commonattr, ATTR_CMN_NAMEDATTRCOUNT);
        ATTRIB(cmn.named_attr_list,  commonattr, ATTR_CMN_NAMEDATTRLIST);
        ATTRIB(cmn.flags,            commonattr, ATTR_CMN_FLAGS);
        ATTRIB(cmn.user_access,      commonattr, ATTR_CMN_USERACCESS);
        ATTRIB(cmn.extended_security,commonattr, ATTR_CMN_EXTENDED_SECURITY);
        ATTRIB(cmn.uuid,             commonattr, ATTR_CMN_UUID);
        ATTRIB(cmn.grp_uuid,         commonattr, ATTR_CMN_GRPUUID);
        ATTRIB(cmn.file_id,          commonattr, ATTR_CMN_FILEID);
        ATTRIB(cmn.parent_id,        commonattr, ATTR_CMN_PARENTID);
        ATTRIB(cmn.full_path,        commonattr, ATTR_CMN_FULLPATH);
        ATTRIB(cmn.added_time,       commonattr, ATTR_CMN_ADDEDTIME);
        ATTRIB(vol.fs_type,          volattr, ATTR_VOL_FSTYPE);
        ATTRIB(vol.signature,        volattr, ATTR_VOL_SIGNATURE);
        ATTRIB(vol.size,             volattr, ATTR_VOL_SIZE);
        ATTRIB(vol.space_free,       volattr, ATTR_VOL_SPACEFREE);
        ATTRIB(vol.space_avail,      volattr, ATTR_VOL_SPACEAVAIL);
        ATTRIB(vol.min_allocation,   volattr, ATTR_VOL_MINALLOCATION);
        ATTRIB(vol.allocation_clump, volattr, ATTR_VOL_ALLOCATIONCLUMP);
        ATTRIB(vol.io_block_size,    volattr, ATTR_VOL_IOBLOCKSIZE);
        ATTRIB(vol.obj_count,        volattr, ATTR_VOL_OBJCOUNT);
        ATTRIB(vol.file_count,       volattr, ATTR_VOL_FILECOUNT);
        ATTRIB(vol.dir_count,        volattr, ATTR_VOL_DIRCOUNT);
        ATTRIB(vol.max_obj_count,    volattr, ATTR_VOL_MAXOBJCOUNT);
        ATTRIB(vol.mount_point,      volattr, ATTR_VOL_MOUNTPOINT);
        ATTRIB(vol.name,             volattr, ATTR_VOL_NAME);
        ATTRIB(vol.mount_flags,      volattr, ATTR_VOL_MOUNTFLAGS);
        ATTRIB(vol.mounted_device,   volattr, ATTR_VOL_MOUNTEDDEVICE);
        ATTRIB(vol.encoding_used,    volattr, ATTR_VOL_ENCODINGSUSED);
        ATTRIB(vol.uuid,             volattr, ATTR_VOL_UUID);
        ATTRIB(dir.link_count,       dirattr, ATTR_DIR_LINKCOUNT);
        ATTRIB(dir.entry_count,      dirattr, ATTR_DIR_ENTRYCOUNT);
        ATTRIB(dir.mount_status,     dirattr, ATTR_DIR_MOUNTSTATUS);
        ATTRIB(file.link_count,      fileattr, ATTR_FILE_LINKCOUNT);
        ATTRIB(file.total_size,      fileattr, ATTR_FILE_TOTALSIZE);
        ATTRIB(file.alloc_size,      fileattr, ATTR_FILE_ALLOCSIZE);
        ATTRIB(file.alloc_size,      fileattr, ATTR_FILE_ALLOCSIZE);
        ATTRIB(file.io_block_size,   fileattr, ATTR_FILE_IOBLOCKSIZE);
        ATTRIB(file.clump_size,      fileattr, ATTR_FILE_CLUMPSIZE);
        ATTRIB(file.dev_type,        fileattr, ATTR_FILE_DEVTYPE);
        ATTRIB(file.file_type,       fileattr, ATTR_FILE_FILETYPE);
        ATTRIB(file.fork_count,      fileattr, ATTR_FILE_FORKCOUNT);
        ATTRIB(file.fork_list,       fileattr, ATTR_FILE_FORKLIST);
        ATTRIB(file.data_length,     fileattr, ATTR_FILE_DATALENGTH);
        ATTRIB(file.data_alloc_size, fileattr, ATTR_FILE_DATAALLOCSIZE);
        ATTRIB(file.data_extents,    fileattr, ATTR_FILE_DATAEXTENTS);
        ATTRIB(file.rsrc_length,     fileattr, ATTR_FILE_RSRCLENGTH);
        ATTRIB(file.rsrc_alloc_size, fileattr, ATTR_FILE_RSRCALLOCSIZE);
        ATTRIB(file.rsrc_extents,    fileattr, ATTR_FILE_RSRCEXTENTS);
#undef ATTRIB
        return 0;
    }
    else
    {
        return errno;
    }
};


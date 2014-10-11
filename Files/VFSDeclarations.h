//
//  VFSDeclarations.h
//  Files
//
//  Created by Michael G. Kazakov on 11/10/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once

struct VFSStatFS
{
    uint64_t total_bytes = 0;
    uint64_t free_bytes  = 0;
    uint64_t avail_bytes = 0; // may be less than actuat free_bytes
    string   volume_name;
    
    bool operator==(const VFSStatFS& _r) const;
    bool operator!=(const VFSStatFS& _r) const;
};

struct VFSDirEnt
{
    enum {
        Unknown     =  0, /* = DT_UNKNOWN */
        FIFO        =  1, /* = DT_FIFO    */
        Char        =  2, /* = DT_CHR     */
        Dir         =  4, /* = DT_DIR     */
        Block       =  6, /* = DT_BLK     */
        Reg         =  8, /* = DT_REG     */
        Link        = 10, /* = DT_LNK     */
        Socket      = 12, /* = DT_SOCK    */
        Whiteout    = 14  /* = DT_WHT     */
    };
    
    uint16_t    type;
    uint16_t    name_len;
    char        name[1024];
};

struct VFSStat
{
    uint64_t    size;   /* File size, in bytes */
    uint64_t    blocks; /* blocks allocated for file */
    uint64_t    inode;  /* File serial number */
    int32_t     dev;    /* ID of device containing file */
    int32_t     rdev;   /* Device ID (if special file) */
    uint32_t    uid;    /* User ID of the file */
    uint32_t    gid;    /* Group ID of the file */
    int32_t     blksize;/* Optimal blocksize for I/O */
    uint32_t	flags;  /* User defined flags for file */
    union {
        uint16_t    mode;   /* Mode of file */
        struct {
            unsigned xoth : 1;
            unsigned woth : 1;
            unsigned roth : 1;
            unsigned xgrp : 1;
            unsigned wgrp : 1;
            unsigned rgrp : 1;
            unsigned xusr : 1;
            unsigned wusr : 1;
            unsigned rusr : 1;
            unsigned vtx  : 1;
            unsigned gid  : 1;
            unsigned uid  : 1;
            unsigned fifo : 1;
            unsigned chr  : 1;
            unsigned dir  : 1;
            unsigned reg  : 1;
        } __attribute__((packed)) mode_bits; /* Mode decomposed as flags*/
    };
    uint16_t    nlink;  /* Number of hard links */
    timespec    atime;  /* Time of last access */
    timespec    mtime;	/* Time of last data modification */
    timespec    ctime;	/* Time of last status change */
    timespec    btime;	/* Time of file creation(birth) */
    struct meaningT {
        unsigned size:   1;
        unsigned blocks: 1;
        unsigned inode:  1;
        unsigned dev:    1;
        unsigned rdev:   1;
        unsigned uid:    1;
        unsigned gid:    1;
        unsigned blksize:1;
        unsigned flags:  1;
        unsigned mode:   1;
        unsigned nlink:  1;
        unsigned atime:  1;
        unsigned mtime:  1;
        unsigned ctime:  1;
        unsigned btime:  1;
    } meaning;
    static void FromSysStat(const struct stat &_from, VFSStat &_to);
    static void ToSysStat(const VFSStat &_from, struct stat &_to);
    inline static meaningT AllMeaning() { const uint64_t t = ~0; return *(meaningT*)&t; }
};

class VFSListing;
class VFSHost;
class VFSHostOptions;
class VFSFile;
class VFSPath;

typedef shared_ptr<VFSHost>         VFSHostPtr;
typedef shared_ptr<VFSHostOptions>  VFSHostOptionsPtr;
typedef shared_ptr<VFSFile>         VFSFilePtr;
typedef function<bool()>            VFSCancelChecker;

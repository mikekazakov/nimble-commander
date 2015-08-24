//
//  VFSNativeListing.h
//  Files
//
//  Created by Michael G. Kazakov on 26.08.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#import <CoreFoundation/CoreFoundation.h>
#import <sys/dirent.h>
#import <sys/types.h>
#import <sys/stat.h>
#import <stdlib.h>
#import <time.h>
#import <Habanero/tiny_string.h>
#import "VFSListing.h"

class VFSNativeHost;

struct VFSNativeListingItem : VFSListingItem
{
    // #0
    string         name;                    // UTF-8 decomposed entry name
    // #24
    uint64_t       inode = 0;               // 64b-long inode number
    // #32
    uint64_t       size = 0;                // file size. initial 0xFFFFFFFFFFFFFFFFu for directories, other value means calculated directory size
    // #40
    time_t         atime = 0;               // time of last access. we're dropping st_atimespec.tv_nsec information
    // #48
    time_t         mtime = 0;               // time of last data modification. we're dropping st_mtimespec.tv_nsec information
    // #56
    time_t         ctime = 0;               // time of last status change (data modification OR access changes, hardlink changes etc). we're dropping st_ctimespec.tv_nsec information
    // #64
    time_t         btime = 0;               // time of file creation(birth). we're dropping st_birthtimespec.tv_nsec information
    // #72
    mode_t         unix_mode = 0;           // file type from stat
    // #76
    uint32_t       unix_flags = 0;          // st_flags field from stat, see chflags(2)
    // #80
    CFStringRef    cf_name = 0;             // it's a string created with CFStringCreateWithBytesNoCopy, pointing at name()
    // #88
    CFStringRef    cf_displayname = 0;      // string got from DispayNamesCache or NULL, thus cf_name should be used
    // #96
    tiny_string    symlink;                 // symlink's value if any
    // #104
    uid_t          unix_uid = 0;            // user ID of the file
    // #108
    gid_t          unix_gid = 0;            // group ID of the file
    // #112
    unsigned short extoffset = 0;           // extension of a file if any. 0 if there's no extension, or position of a first char of an extention
    // #113
    unsigned char  unix_type = 0;           // file type from <sys/dirent.h> (from readdir)
    // #114
    
    virtual ~VFSNativeListingItem() {
        if(cf_name != 0)
            CFRelease(cf_name);
        if(cf_displayname != 0)
            CFRelease(cf_displayname);
    }
    
    virtual const char     *Name()      const override { return name.c_str(); }
    virtual CFStringRef     CFName()    const override { return cf_name; }
    virtual CFStringRef     CFDisplayName() const override { return cf_displayname ? cf_displayname : cf_name; }
    virtual size_t          NameLen()   const override { return name.length(); }
    virtual uint64_t        Size()      const override { return size; }
    virtual uint64_t        Inode()     const override { return inode; }
    virtual time_t          ATime()     const override { return atime; }
    virtual time_t          MTime()     const override { return mtime; }
    virtual time_t          CTime()     const override { return ctime; }
    virtual time_t          BTime()     const override { return btime; }
    virtual mode_t          UnixMode()  const override { return unix_mode; }
    virtual uint32_t        UnixFlags() const override { return unix_flags; }
    virtual uid_t           UnixUID()   const override { return unix_uid; }
    virtual gid_t           UnixGID()   const override { return unix_gid; }
    virtual uint8_t         UnixType()  const override { return unix_type; }
    virtual const char     *Symlink()   const override { return unix_type == DT_LNK ? symlink.c_str() : nullptr; }
    virtual bool            IsDir()     const override { return (unix_mode & S_IFMT) == S_IFDIR; }
    virtual bool            IsReg()     const override { return (unix_mode & S_IFMT) == S_IFREG;  }
    virtual bool            IsSymlink() const override { return unix_type == DT_LNK; }
    virtual bool            IsDotDot()  const override { return (name.length() == 2) && (name[0] == '.') && (name[1] == '.'); } // huh. can we have a regular file named ".."? Hope not.; }
    virtual bool            IsHidden()  const override { return !IsDotDot() && (Name()[0] == '.' || (unix_flags & UF_HIDDEN)); }
    virtual bool            HasExtension()      const override { return extoffset != 0; }
    virtual unsigned short  ExtensionOffset()   const override { return extoffset; }
    virtual const char*     Extension()         const override { return Name() + extoffset; }
    
    
    virtual void            SetSize(uint64_t _size) override { size = _size; };
};

class VFSNativeListing : public VFSListing
{
public:
    VFSNativeListing(const char *_path);
    ~VFSNativeListing();
    
    
    int LoadListingData(int _flags, VFSCancelChecker _cancel_checker);
    
    virtual VFSListingItem& At(size_t _position) override;
    virtual const VFSListingItem& At(size_t _position) const override;
    virtual int Count() const override;

    unsigned                           m_Count = 0;
    unique_ptr<VFSNativeListingItem[]> m_Items;
};

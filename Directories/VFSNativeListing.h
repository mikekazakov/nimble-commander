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
#import <deque>
#import "VFSListing.h"

class VFSNativeHost;

struct VFSNativeListingItem : VFSListingItem
{
    // #0
    char           namebuf[14];             // UTF-8, including null-term. if namelen >13 => (char**)&name[0] is a buffer from malloc for namelen+1 bytes
    // #14
    unsigned short namelen;                 // not-including null-term
    // #16
    uint64_t       inode;                     // 64b-long inode number
    // #24
    uint64_t       size;                    // file size. initial 0xFFFFFFFFFFFFFFFFu for directories, other value means calculated directory size
    // #32
    time_t         atime;                   // time of last access. we're dropping st_atimespec.tv_nsec information
    // #40
    time_t         mtime;                   // time of last data modification. we're dropping st_mtimespec.tv_nsec information
    // #48
    time_t         ctime;                   // time of last status change (data modification OR access changes, hardlink changes etc). we're dropping st_ctimespec.tv_nsec information
    // #56
    time_t         btime;                   // time of file creation(birth). we're dropping st_birthtimespec.tv_nsec information
    // #64
    mode_t         unix_mode;               // file type from stat
    // #66
    CFStringRef    cf_name;                 // it's a string created with CFStringCreateWithBytesNoCopy, pointing at name()
    // #74
    const char     *symlink;                // a pointer to symlink's value or NULL if entry is not a symlink or an error has occured
    // #82
    uint32_t       unix_flags;              // st_flags field from stat, see chflags(2)
    // #86
    uid_t          unix_uid;                // user ID of the file
    // #90
    gid_t          unix_gid;                // group ID of the file
    // #94
    unsigned short extoffset;               // extension of a file if any. 0 if there's no extension, or position of a first char of an extention
    // #96
    unsigned char  unix_type;               // file type from <sys/dirent.h> (from readdir)
    // #97
//    unsigned char  ___padding[15];
    // #112
    
    inline void Destroy()
    {
        if(cf_name != 0)
            CFRelease(cf_name);
        if(symlink != 0)
            free((void*)symlink);
        if(namelen > 13)
            free((void*)*(const unsigned char**)(&namebuf[0]));
    }
    
    virtual const char     *Name()      const override {
        if(namelen < 14) return namebuf;
        return *(const char**)(&namebuf[0]);
    }
    virtual CFStringRef     CFName()    const override { return cf_name; }
    virtual size_t          NameLen()   const override { return namelen; }
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
    virtual const char     *Symlink()   const override { return symlink; }
    virtual bool            IsDir()     const override { return (unix_mode & S_IFMT) == S_IFDIR; }
    virtual bool            IsReg()     const override { return (unix_mode & S_IFMT) == S_IFREG;  }
    virtual bool            IsSymlink() const override { return unix_type == DT_LNK; }
    virtual bool            IsDotDot()  const override { return (namelen == 2) && (namebuf[0] == '.') && (namebuf[1] == '.'); } // huh. can we have a regular file named ".."? Hope not.; }
    virtual bool            IsHidden()  const override { return !IsDotDot() && (Name()[0] == '.' || (unix_flags & UF_HIDDEN)); }
    virtual bool            HasExtension()      const override { return extoffset != 0; }
    virtual unsigned short  ExtensionOffset()   const override { return extoffset; }
    virtual const char*     Extension()         const override { return Name() + extoffset; }
    
    
    virtual void            SetSize(uint64_t _size) override { size = _size; };
};

class VFSNativeListing : public VFSListing
{
public:
    VFSNativeListing(const char *_path, std::shared_ptr<VFSNativeHost> _host);
    ~VFSNativeListing();
    
    
    int LoadListingData(bool (^_cancel_checker)());
    void EraseListing();
    
    virtual VFSListingItem& At(size_t _position) override;
    virtual const VFSListingItem& At(size_t _position) const override;
    virtual int Count() const override;

    
    std::deque<VFSNativeListingItem> m_Items;
    
};

/*
class VFSListing
{
public:
    VFSListing(std::shared_ptr<VFSHost> _host);
    virtual ~VFSListing();
    
    virtual VFSListingItem& At(int _position);
    virtual const VFSListingItem& At(int _position) const;
    virtual int Count() const;
    virtual long Attributes() const; // bitfield with VFSListingAttributes values
    
    std::shared_ptr<VFSHost> Host() const;
private:
    std::shared_ptr<VFSHost> m_Host;
    
    // forbid copying
    VFSListing(const VFSListing&);
    void operator=(const VFSListing&);
};*/
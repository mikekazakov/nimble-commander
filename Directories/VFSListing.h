//
//  VFSListing.h
//  Files
//
//  Created by Michael G. Kazakov on 25.08.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include <string>
#include <memory>

class VFSHost;
class VFSListing;

struct VFSListingAttributes
{
    enum {
        // [REQUIRED]
        Name            = 1 << 1, // should be supported by all virtual file systems
        // [OPTIONAL]
        InodeNumber     = 1 << 2,
        // [OPTIONAL]
        Size            = 1 << 3,
        // [OPTIONAL]
        ATime           = 1 << 4,
        // [OPTIONAL]
        MTime           = 1 << 5,
        // [OPTIONAL]
        CTime           = 1 << 6,
        // [OPTIONAL]
        BTime           = 1 << 7,
        // [REQUIRED]
        CustomFlags     = 1 << 8,
        // [OPTIONAL]
        UnixMode        = 1 << 9,  // file type from stat, mode_t
        // [OPTIONAL]
        UnixFlags       = 1 << 10, // st_flags field from stat, see chflags(2), uint32_t
        // [OPTIONAL]
        UnixUID         = 1 << 11, // user ID of the file
        // [OPTIONAL]
        UnixGID         = 1 << 12, // group ID of the file
        // [OPTIONAL]
        UnixType        = 1 << 13, // file type from <sys/dirent.h> (from readdir)
        // [OPTIONAL]
        Symlink         = 1 << 14, // a pointer to symlink's value or NULL if entry is not a symlink or an error has occured
        // [OPTIONAL]
        Directory       = 1 << 15  // some vfs may not have directories at all
    };
};

class VFSListingItem
{ // this stuff has no virtual destructor and should be freed by derived classes only
public:
    // overridable part
    virtual const char     *Name()      const { return ""; }
    virtual CFStringRef     CFName()    const { return (CFStringRef)@""; }
    virtual uint64_t        Size()      const { return 0; }
    virtual uint64_t        Inode()     const { return 0; }
    virtual time_t          ATime()     const { return 0; }
    virtual time_t          MTime()     const { return 0; }
    virtual time_t          CTime()     const { return 0; }
    virtual time_t          BTime()     const { return 0; }
    virtual mode_t          UnixMode()  const { return 0; }
    virtual uint32_t        UnixFlags() const { return 0; }
    virtual uid_t           UnixUID()   const { return 0; }
    virtual gid_t           UnixGID()   const { return 0; }
    virtual uint8_t         UnixType()  const { return 0; }
    virtual const char     *Symlink()   const { return ""; }
    virtual bool            IsDir()     const { return false; }
    virtual bool            IsReg()     const { return true;  }
    virtual bool            IsSymlink() const { return false; }
    virtual bool            IsDotDot()  const { return false; }
    virtual bool            IsHidden()  const { return false; }
    virtual bool            HasExtension() const { return false; }
    virtual unsigned short  ExtensionOffset() const { return 0; }
    virtual const char*     Extension() const { return false; }
    
    // common part
    inline unsigned int     CFlags()    const { return cflags; }
    inline unsigned short   CIcon()     const { return cicon; }
    inline void             SetCFlag(unsigned int _flag)    { cflags = cflags | _flag; }
    inline void             UnsetCFlag(unsigned int _flag)  { cflags = cflags & ~_flag; }
    inline void             SetCIcon(unsigned short _icon)  { cicon = _icon; }
    
    enum {
    InvalidSize = (0xFFFFFFFFFFFFFFFFu)
    };
private:
    unsigned int   cflags;
    unsigned short cicon;   // custom icon ID. zero means invalid value. volatile - can be changed. saved upon directory reload.
}; // 8 + 4 + 2 bytes = 14 total

// hold an items listing
// perform access operations
// support partial updates by callers code
class VFSListing : public std::enable_shared_from_this<VFSListing>
{
public:
    VFSListing(const char* _relative_path, std::shared_ptr<VFSHost> _host);
    virtual ~VFSListing();
    
    virtual VFSListingItem& At(int _position);
    virtual const VFSListingItem& At(int _position) const;
    virtual int Count() const;
    virtual long Attributes() const; // bitfield with VFSListingAttributes values

    inline std::shared_ptr<VFSListing> SharedPtr() { return shared_from_this(); }
    inline std::shared_ptr<const VFSListing> SharedPtr() const { return shared_from_this(); }
    const char *RelativePath() const;
    std::shared_ptr<VFSHost> Host() const;
private:
    std::string m_RelativePath;
    std::shared_ptr<VFSHost> m_Host;
    
    // forbid copying
    VFSListing(const VFSListing&) = delete;
    void operator=(const VFSListing&) = delete;
};
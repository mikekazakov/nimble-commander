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
    struct Flags {
        enum {
            Selected = 1 << 1
            
            
        };
    };
    
    // overridable part - getters
    virtual const char     *Name()      const { return ""; }
    virtual size_t          NameLen()   const { return 0; }
    virtual CFStringRef     CFName()    const { return CFSTR(""); }
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
    
    // overridable part - setters
    virtual void            SetSize(uint64_t _size) {};

    // common part
    inline unsigned int     CFlags()    const { return cflags; }
    inline unsigned short   CIcon()     const { return cicon; }
    inline void             SetCFlags(unsigned int _flags)  { cflags = _flags; }
    inline void             SetCFlag(unsigned int _flag)    { cflags = cflags | _flag; }
    inline void             UnsetCFlag(unsigned int _flag)  { cflags = cflags & ~_flag; }
    inline void             SetCIcon(unsigned short _icon)  { cicon = _icon; }
    
    inline bool             CFIsSelected() const { return (cflags & Flags::Selected) != 0; }
    
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
    
    // generic virtual access - overloaded by descendants
    virtual VFSListingItem& At(size_t _position);
    virtual const VFSListingItem& At(size_t _position) const;
    virtual int Count() const;
    inline VFSListingItem& operator[](size_t _position) { return At(_position); } // consider something unsafe here
    inline const VFSListingItem& operator[](size_t _position) const { return At(_position); }
    
    // bitfield with VFSListingAttributes values - shows capabilities of current VFS listing
    virtual long Attributes() const;

    
    
    
    // common stuff
    inline std::shared_ptr<VFSListing> SharedPtr() { return shared_from_this(); }
    inline std::shared_ptr<const VFSListing> SharedPtr() const { return shared_from_this(); }
    void ComposeFullPathForEntry(size_t _entry_position, char *_buf) const;
    
    const char *RelativePath() const;
    std::shared_ptr<VFSHost> Host() const;
    
    
    
    
    
    // iteration whitin listing
    struct iterator
    {
        VFSListing *listing;
        unsigned index;
        inline void operator++() { index++; }
        inline bool operator==(const iterator& _right) const {
            return listing == _right.listing && index == _right.index; }
        inline bool operator!=(const iterator& _right) const {
            return listing != _right.listing || index != _right.index; }
        inline VFSListingItem& operator*() { return listing->At(index);}
    };
    struct const_iterator
    {
        const VFSListing *listing;
        unsigned index;
        inline void operator++() { index++; }
        inline bool operator==(const const_iterator& _right) const {
            return listing == _right.listing && index == _right.index;
        }
        inline bool operator!=(const const_iterator& _right) const {
            return listing != _right.listing || index != _right.index;
        }
        inline const VFSListingItem& operator*() const { return listing->At(index); }
    };
    inline const_iterator begin() const { return {this, 0}; }
    inline const_iterator end()   const { return {this, (unsigned)Count()}; }
    inline iterator begin() { return {this, 0}; }
    inline iterator end()   { return {this, (unsigned)Count()}; }
    
    
private:
    std::string m_RelativePath;
    std::shared_ptr<VFSHost> m_Host;
    
    // forbid copying
    VFSListing(const VFSListing&) = delete;
    void operator=(const VFSListing&) = delete;
};
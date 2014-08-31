//
//  VFSListing.h
//  Files
//
//  Created by Michael G. Kazakov on 25.08.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once
#include <dirent.h>

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
    virtual size_t          NameLen()   const { return strlen(Name()); }
    virtual CFStringRef     CFName()    const { return CFSTR(""); }
    virtual CFStringRef     CFDisplayName() const { return CFName(); }
#ifdef __OBJC__
    inline  NSString*       NSName()        const { return (__bridge NSString*)CFName(); }
    inline  NSString*       NSDisplayName() const { return (__bridge NSString*)CFDisplayName(); }
#endif
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
    virtual bool            IsDotDot()  const { return strcmp(Name(), "..") == 0; }
    virtual bool            IsHidden()  const { return Name()[0]=='.' && !IsDotDot(); }
    virtual bool            HasExtension() const { return false; }
    virtual unsigned short  ExtensionOffset() const { return 0; }
    virtual const char*     Extension() const { return 0; }
    
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
    unsigned int   cflags = 0;
    unsigned short cicon = 0;   // custom icon ID. zero means invalid value. volatile - can be changed. saved upon directory reload.
}; // 8 + 4 + 2 bytes = 14 total


/**
 * Wrapper around VFSListingItem interface, holding trivial data and providing it via inherited api.
 * Has no implicit behaviour nor construction or descruction, only trivital zero initialization.
 * It provided not best performance in layout and memory terms, it's more about architectural simplicity.
 */
struct VFSGenericListingItem : public VFSListingItem
{
    virtual ~VFSGenericListingItem();
    virtual const char     *Name()      const override { return m_Name;     }
    virtual size_t          NameLen()   const override { return m_NameLen;  }
    virtual CFStringRef     CFName()    const override { return m_CFName;   }
    virtual uint64_t        Size()      const override { return m_Size;     }
    virtual uint64_t        Inode()     const override { return m_Inode;    }
    virtual time_t          ATime()     const override { return m_ATime;    }
    virtual time_t          MTime()     const override { return m_MTime;    }
    virtual time_t          CTime()     const override { return m_CTime;    }
    virtual time_t          BTime()     const override { return m_BTime;    }
    virtual mode_t          UnixMode()  const override { return m_Mode;     }
    virtual uint32_t        UnixFlags() const override { return m_Flags;    }
    virtual uid_t           UnixUID()   const override { return m_UID;      }
    virtual gid_t           UnixGID()   const override { return m_GID;      }
    virtual uint8_t         UnixType()  const override { return m_Type;     }
    virtual const char     *Symlink()   const override { return (IsSymlink() && m_Symlink == 0) ? "" : m_Symlink;  } // fix for a bad-bad vfs, remove it later!
    virtual bool            IsDir()     const override { return (m_Mode & S_IFMT) == S_IFDIR;   }
    virtual bool            IsReg()     const override { return (m_Mode & S_IFMT) == S_IFREG;   }
    virtual bool            IsSymlink() const override { return m_Type == DT_LNK;               }
    virtual bool            HasExtension()      const override { return m_ExtOff > 0;           }
    virtual unsigned short  ExtensionOffset()   const override { return m_ExtOff;               }
    virtual const char*     Extension()         const override { return m_Name + m_ExtOff;      }
    virtual void            SetSize(uint64_t _size)   override { m_Size = _size;                };
    const char     *m_Name      = 0;
    size_t          m_NameLen   = 0;
    CFStringRef     m_CFName    = 0;
    uint64_t        m_Size      = 0;
    uint64_t        m_Inode     = 0;
    time_t          m_ATime     = 0;
    time_t          m_MTime     = 0;
    time_t          m_CTime     = 0;
    time_t          m_BTime     = 0;
    mode_t          m_Mode      = 0;
    uint32_t        m_Flags     = 0;
    uid_t           m_UID       = 0;
    gid_t           m_GID       = 0;
    uint8_t         m_Type      = 0;
    const char     *m_Symlink   = 0;
    uint16_t        m_ExtOff    = 0;
    bool            m_NeedReleaseName = false;
    bool            m_NeedReleaseCFName = false;
    bool            m_NeedReleaseSymlink = false;

    // helper methods
    void FindExtension()
    {
        m_ExtOff = 0;
        for(int i = (int)m_NameLen - 1; i >= 0; --i)
            if(m_Name[i] == '.')
            {
                if(i == m_NameLen - 1 || i == 0)
                    break; // degenerate case, lets think that there's no extension at all
                m_ExtOff = i+1;
                break;
            }
    }

};

// hold an items listing
// perform access operations
// support partial updates by callers code
class VFSListing : public enable_shared_from_this<VFSListing>
{
public:
    VFSListing(const char* _relative_path, shared_ptr<VFSHost> _host);
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
    inline shared_ptr<VFSListing> SharedPtr() { return shared_from_this(); }
    inline shared_ptr<VFSListing> SharedPtr() const { return ((VFSListing*)this)->shared_from_this(); }
    string ComposeFullPathForEntry(size_t _entry_position) const;
    
    const char *RelativePath() const;
    const shared_ptr<VFSHost>& Host() const;
    
    
    
    
    
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
    string m_RelativePath;
    shared_ptr<VFSHost> m_Host;
    
    // forbid copying
    VFSListing(const VFSListing&) = delete;
    void operator=(const VFSListing&) = delete;
};

/**
 * VFSGenericListing is a dumb class, storing a set of VFSGenericListingItem items.
 * Meant to be filled by some outside code.
 */
class VFSGenericListing : public VFSListing
{
public:
    VFSGenericListing(const char *_path, shared_ptr<VFSHost> _host);
    virtual VFSListingItem& At(size_t _position) override;
    virtual const VFSListingItem& At(size_t _position) const override;
    virtual int Count() const override;
    deque<VFSGenericListingItem> m_Items;
};

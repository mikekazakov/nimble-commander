//
//  VFSArchiveListing.h
//  Files
//
//  Created by Michael G. Kazakov on 03.09.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <vector>
#import <sys/stat.h>
#import "VFSListing.h"


class VFSArchiveHost;
struct VFSArchiveDir;

// sub-optimized version now
struct VFSArchiveListingItem : VFSListingItem
{
    std::string name; // optimize
    struct stat st;
    CFStringRef cf_name;
    unsigned short extoffset;               // extension of a file if any. 0 if there's no extension, or position of a first char of an extention
    
    
    
    
    virtual const char     *Name()      const override { return name.c_str(); }
    virtual CFStringRef     CFName()    const override { return cf_name; }
    virtual size_t          NameLen()   const override { return name.length(); }
    virtual uint64_t        Size()      const override { return st.st_size; }
    virtual time_t          ATime()     const override { return st.st_atime; }
    virtual time_t          MTime()     const override { return st.st_mtime; }
    virtual time_t          CTime()     const override { return st.st_ctime; }
    virtual time_t          BTime()     const override { return st.st_birthtime; }
    virtual mode_t          UnixMode()  const override { return st.st_mode; }
    virtual uint32_t        UnixFlags() const override { return st.st_flags; }
    virtual uid_t           UnixUID()   const override { return st.st_uid; }
    virtual gid_t           UnixGID()   const override { return st.st_gid; }
//    virtual uint8_t         UnixType()  const override { return unix_type; }
    virtual const char     *Symlink()   const override { return 0; }
    virtual bool            IsDir()     const override { return (st.st_mode & S_IFMT) == S_IFDIR; }
    virtual bool            IsReg()     const override { return (st.st_mode & S_IFMT) == S_IFREG;  }
    virtual bool            IsSymlink() const override { return false; }
    virtual bool            IsDotDot()  const override { return (name.length() == 2) && (name[0] == '.') && (name[1] == '.'); }
    virtual bool            IsHidden()  const override { return !IsDotDot() && (Name()[0] == '.'); }
    virtual bool            HasExtension()      const override { return extoffset != 0; }
    virtual unsigned short  ExtensionOffset()   const override { return extoffset; }
    virtual const char*     Extension()         const override { return Name() + extoffset; }
        
    virtual void            SetSize(uint64_t _size) override { st.st_size = _size; };

    void destroy()
    {
        if(cf_name != 0)
            CFRelease(cf_name);
    }
};


class VFSArchiveListing : public VFSListing
{
public:
    VFSArchiveListing(const VFSArchiveDir *_dir, const char *_path, std::shared_ptr<VFSArchiveHost> _host);
    ~VFSArchiveListing();
    
    virtual VFSListingItem& At(size_t _position) override;
    virtual const VFSListingItem& At(size_t _position) const override;
    virtual int Count() const override;
    
private:
    std::vector<VFSArchiveListingItem> m_Items;
};

//
//  VFSArchiveListing.cpp
//  Files
//
//  Created by Michael G. Kazakov on 03.09.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "VFSArchiveListing.h"
#import "VFSArchiveHost.h"
#import "VFSArchiveInternal.h"
#import "Encodings.h"

VFSArchiveListing::VFSArchiveListing(const VFSArchiveDir *_dir, const char *_path, int _flags, shared_ptr<VFSArchiveHost> _host):
    VFSListing(_path, _host)
{
    size_t shift = (_flags & VFSHost::F_NoDotDot) ? 0 : 1;
    size_t i = 0, e = _dir->entries.size();
    m_Items.resize( _dir->entries.size() + shift);
    for(;i!=e;++i)
    {
        auto &item = m_Items[i+shift];
        item.name = _dir->entries[i].name;
        item.st = _dir->entries[i].st;
        item.cf_name = CFStringCreateWithBytesNoCopy(0,
                                                         (UInt8*)item.name.c_str(),
                                                         item.name.length(),
                                                         kCFStringEncodingUTF8,
                                                         false,
                                                         kCFAllocatorNull);
        if(item.cf_name == 0)
        {
            // fallback case 'coz of invalid encodings(?)
            // use our bulletproof decoder to recover anything from this trash
            unsigned short tmp[65536];
            size_t sz;
            encodings::InterpretAsUnichar(
                                    ENCODING_UTF8,
                                    (const unsigned char*)item.name.c_str(),
                                    item.name.length(),          // in bytes
                                    &tmp[0], // should be at least _input_size unichars long
                                    0, // should be at least _input_size 32b words long, can be NULL
                                    &sz           // size of an _output_buf
                                    );

            item.cf_name = CFStringCreateWithCharacters(0, &tmp[0], sz);
            assert(item.cf_name);
        }

        item.extoffset = 0;
        for(int i = (int)item.name.length() - 1; i >= 0; --i)
            if(item.name.c_str()[i] == '.')
            {
                if(i == item.name.length() - 1 || i == 0)
                    break; // degenerate case, lets think that there's no extension at all
                item.extoffset = i+1;
                break;
            }
        
        if(item.IsDir())
            item.st.st_size = VFSListingItem::InvalidSize;
    }
    
    if(shift)
    { // dot-dot
        auto &item = m_Items[0];
        item.name = "..";
        memset(&item.st, 0, sizeof(item.st));
        item.st.st_mode |= S_IFDIR;
        item.st.st_size = VFSListingItem::InvalidSize;
        item.cf_name = CFStringCreateWithBytesNoCopy(0,
                                                     (UInt8*)item.name.c_str(),
                                                     item.name.length(),
                                                     kCFStringEncodingUTF8,
                                                     false,
                                                     kCFAllocatorNull);
    }
    
/*    if(need_to_add_dot_dot)
    {
        // ?? do we need to handle properly the usual ".." appearance, since we have a fix-up way anyhow?
        // add ".." entry by hand
        VFSNativeListingItem current = {};
        //        memset(&current, 0, sizeof(DirectoryEntryInformation));
        current.unix_type = DT_DIR;
        current.inode  = 0;
        current.namelen = 2;
        memcpy(&current.namebuf[0], "..", current.namelen+1);
        current.size = VFSListingItem::InvalidSize;
        m_Items.insert(m_Items.begin(), current); // this can be looong on biiiiiig directories
    }*/

}

VFSArchiveListing::~VFSArchiveListing()
{
    for(auto &i: m_Items)
        i.destroy();
}


VFSListingItem& VFSArchiveListing::At(size_t _position)
{
    assert(_position < m_Items.size());
    return m_Items[_position];
}

const VFSListingItem& VFSArchiveListing::At(size_t _position) const
{
    assert(_position < m_Items.size());
    return m_Items[_position];
}

int VFSArchiveListing::Count() const
{
    return (int)m_Items.size();
}

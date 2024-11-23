// Copyright (C) 2013-2021 Michael Kazakov. Subject to GNU General Public License version 3.
#include <CoreFoundation/CoreFoundation.h>
#include <cstdlib>
#include <cstring>
#include <libkern/OSByteOrder.h>
#include <sys/types.h>
#include <sys/xattr.h>

#include "../include/VFS/AppleDoubleEA.h"

// this requires a complete rewrite...
#pragma clang diagnostic ignored "-Wold-style-cast"

namespace nc::vfs {

// thanks filecopy.c from Apple:
/*
   Typical "._" AppleDouble Header File layout:
  ------------------------------------------------------------
         MAGIC          0x00051607
         VERSION        0x00020000
         FILLER         0
         COUNT          2
     .-- AD ENTRY[0]    Finder Info Entry (must be first)
  .--+-- AD ENTRY[1]    Resource Fork Entry (must be last)
  |  '-> FINDER INFO
  |      /////////////  Fixed Size Data (32 bytes)
  |      EXT ATTR HDR
  |      /////////////
  |      ATTR ENTRY[0] --.
  |      ATTR ENTRY[1] --+--.
  |      ATTR ENTRY[2] --+--+--.
  |         ...          |  |  |
  |      ATTR ENTRY[N] --+--+--+--.
  |      ATTR DATA 0   <-'  |  |  |
  |      ////////////       |  |  |
  |      ATTR DATA 1   <----'  |  |
  |      /////////////         |  |
  |      ATTR DATA 2   <-------'  |
  |      /////////////            |
  |         ...                   |
  |      ATTR DATA N   <----------'
  |      /////////////
  |                      Attribute Free Space
  |
  '----> RESOURCE FORK
         /////////////   Variable Sized Data
         /////////////
         /////////////
         /////////////
         /////////////
         /////////////
            ...
         /////////////

  ------------------------------------------------------------

   NOTE: The EXT ATTR HDR, ATTR ENTRY's and ATTR DATA's are
   stored as part of the Finder Info.  The length in the Finder
   Info AppleDouble entry includes the length of the extended
   attribute header, attribute entries, and attribute data.
*/

/*
 * On Disk Data Structures
 *
 * Note: Motorola 68K alignment and big-endian.
 *
 * See RFC 1740 for additional information about the AppleDouble file format.
 *
 */

#define ADH_MAGIC 0x00051607
#define ADH_VERSION 0x00020000
#define ADH_MACOSX "Mac OS X        "

/*
 * AppleDouble Entry ID's
 */
#define AD_DATA 1        /* Data fork */
#define AD_RESOURCE 2    /* Resource fork */
#define AD_REALNAME 3    /* File’s name on home file system */
#define AD_COMMENT 4     /* Standard Mac comment */
#define AD_ICONBW 5      /* Mac black & white icon */
#define AD_ICONCOLOR 6   /* Mac color icon */
#define AD_UNUSED 7      /* Not used */
#define AD_FILEDATES 8   /* File dates; create, modify, etc */
#define AD_FINDERINFO 9  /* Mac Finder info & extended info */
#define AD_MACINFO 10    /* Mac file info, attributes, etc */
#define AD_PRODOSINFO 11 /* Pro-DOS file info, attrib., etc */
#define AD_MSDOSINFO 12  /* MS-DOS file info, attributes, etc */
#define AD_AFPNAME 13    /* Short name on AFP server */
#define AD_AFPINFO 14    /* AFP file info, attrib., etc */
#define AD_AFPDIRID 15   /* AFP directory ID */
#define AD_ATTRIBUTES AD_FINDERINFO

#define ATTR_HDR_MAGIC 0x41545452 /* 'ATTR' */

#define FINDERINFOSIZE 32

// #pragma options align=mac68k
#pragma pack(1)

using apple_double_entry_t = struct apple_double_entry {
    u_int32_t type;   /* entry type: see list, 0 invalid */
    u_int32_t offset; /* entry data offset from the beginning of the file. */
    u_int32_t length; /* entry data length in bytes. */
};

/* Entries are aligned on 4 byte boundaries */
using attr_entry_t = struct attr_entry {
    u_int32_t offset; /* file offset to data */
    u_int32_t length; /* size of attribute data */
    u_int16_t flags;
    u_int8_t namelen; /* length of name including NULL termination char */
    u_int8_t name[1]; /* NULL-terminated UTF-8 name (up to 128 bytes max) */
};

using apple_double_header_t = struct apple_double_header {
    u_int32_t magic;   /* == ADH_MAGIC */
    u_int32_t version; /* format version: 2 = 0x00020000 */
    u_int32_t filler[4];
    u_int16_t numEntries;            /* number of entries which follow */
    apple_double_entry_t entries[2]; /* 'finfo' & 'rsrc' always exist */
    u_int8_t finfo[FINDERINFOSIZE];  /* Must start with Finder Info (32 bytes) */
    u_int8_t pad[2];                 /* get better alignment inside attr_header */
};

/* Header + entries must fit into 64K <-- guess not true since 10.7 .MK. */
using attr_header_t = struct attr_header {
    apple_double_header_t appledouble;
    u_int32_t magic;       /* == ATTR_HDR_MAGIC */
    u_int32_t debug_tag;   /* for debugging == file id of owning file */
    u_int32_t total_size;  /* total size of attribute header + entries + data */
    u_int32_t data_start;  /* file offset to attribute data area */
    u_int32_t data_length; /* length of attribute data area */
    u_int32_t reserved[3];
    u_int16_t flags;
    u_int16_t num_attrs;
};

// #pragma options align=reset
#pragma pack()

#define SWAP16(x) OSSwapBigToHostInt16(x)
#define SWAP32(x) OSSwapBigToHostInt32(x)
#define SWAP64(x) OSSwapBigToHostInt64(x)

#define ATTR_ALIGN 3L      /* Use four-byte alignment */
#define ATTR_DATA_ALIGN 1L /* Use two-byte alignment */

#define ATTR_ENTRY_LENGTH(namelen) ((sizeof(attr_entry_t) - 1 + (namelen) + ATTR_ALIGN) & (~ATTR_ALIGN))

#define ATTR_NEXT(ae) (attr_entry_t *)((u_int8_t *)(ae) + ATTR_ENTRY_LENGTH((ae)->namelen))

#define XATTR_SECURITY_NAME "com.apple.acl.text"

static const u_int32_t emptyfinfo[8] = {0};

/*
 * Endian swap Apple Double header
 */
static void swap_adhdr(apple_double_header_t *adh)
{
    int count;
    int i;

    count = (adh->magic == ADH_MAGIC) ? adh->numEntries : SWAP16(adh->numEntries);

    adh->magic = SWAP32(adh->magic);
    adh->version = SWAP32(adh->version);
    adh->numEntries = SWAP16(adh->numEntries);

    for( i = 0; i < count; i++ ) {
        adh->entries[i].type = SWAP32(adh->entries[i].type);
        adh->entries[i].offset = SWAP32(adh->entries[i].offset);
        adh->entries[i].length = SWAP32(adh->entries[i].length);
    }
}

/*
 * Endian swap extended attributes header
 */
static void swap_attrhdr(attr_header_t *ah)
{
    ah->magic = SWAP32(ah->magic);
    ah->debug_tag = SWAP32(ah->debug_tag);
    ah->total_size = SWAP32(ah->total_size);
    ah->data_start = SWAP32(ah->data_start);
    ah->data_length = SWAP32(ah->data_length);
    ah->flags = SWAP16(ah->flags);
    ah->num_attrs = SWAP16(ah->num_attrs);
}

static bool IsAppleDouble(const void *_memory_buf, size_t _memory_size)
{
    const apple_double_header_t *adhdr = static_cast<const apple_double_header_t *>(_memory_buf);
    return _memory_size >= sizeof(apple_double_header_t) - 2 && SWAP32(adhdr->magic) == ADH_MAGIC &&
           SWAP32(adhdr->version) == ADH_VERSION && SWAP16(adhdr->numEntries) == 2 &&
           SWAP32(adhdr->entries[0].type) == AD_FINDERINFO;
}

std::vector<AppleDoubleEA> ExtractEAFromAppleDouble(const void *_memory_buf, size_t _memory_size)
{
    if( !_memory_buf || !_memory_size )
        return {};

    if( !IsAppleDouble(_memory_buf, _memory_size) )
        return {};

    apple_double_header_t adhdr = *static_cast<const apple_double_header_t *>(_memory_buf);
    swap_adhdr(&adhdr);

    const bool has_finfo = memcmp(adhdr.finfo, emptyfinfo, sizeof(emptyfinfo)) != 0;

    std::vector<AppleDoubleEA> eas;
    int eas_last = 0;

    if( adhdr.entries[0].length > FINDERINFOSIZE ) {
        attr_header_t attrhdr = *static_cast<const attr_header_t *>(_memory_buf);
        swap_attrhdr(&attrhdr);

        if( attrhdr.magic == ATTR_HDR_MAGIC ) {
            const int count = attrhdr.num_attrs;
            eas.resize(has_finfo ? count + 1 : count);

            const attr_entry_t *entry =
                reinterpret_cast<const attr_entry_t *>(static_cast<const char *>(_memory_buf) + sizeof(attr_header_t));
            for( int i = 0; i < count; i++ ) {
                if( reinterpret_cast<const char *>(entry) + sizeof(attr_entry_t) >
                    static_cast<const char *>(_memory_buf) + _memory_size )
                    break; // out-of-boundary guard to be safe about memory (not)corrupting

                const u_int32_t offset = SWAP32(entry->offset);
                const u_int32_t length = SWAP32(entry->length);
                u_int32_t namelen = 0;
                const char *name = reinterpret_cast<const char *>(&entry->name[0]);

                // safely calculate a name len
                for( const char *si = name; si < static_cast<const char *>(_memory_buf) + _memory_size && (*si) != 0;
                     ++si, ++namelen )
                    ;

                if( namelen > 0 && name + namelen < static_cast<const char *>(_memory_buf) + _memory_size &&
                    name[namelen] == 0 && offset + length <= _memory_size ) { // seems to be a valid EA
                    eas[eas_last].data = static_cast<const char *>(_memory_buf) + offset;
                    eas[eas_last].data_sz = length;
                    eas[eas_last].name = name;
                    eas[eas_last].name_len = namelen;
                    ++eas_last;
                }
                entry = ATTR_NEXT(entry);
            }
        }
    }

    if( has_finfo ) {
        if( eas.empty() ) // no extended attributes except FinderInfo was found
            eas.resize(1);
        eas[eas_last].data = &((const apple_double_header_t *)_memory_buf)->finfo[0];
        eas[eas_last].data_sz = 32;
        eas[eas_last].name = XATTR_FINDERINFO_NAME; // "com.apple.FinderInfo"
        eas[eas_last].name_len = 20;
        ++eas_last;
    }

    return eas;
}

std::vector<std::byte> BuildAppleDoubleFromEA(VFSFile &_file)
{
    const unsigned ret_xattr_count = _file.XAttrCount();
    if( ret_xattr_count == 0 )
        return {};

    struct EA {
        std::string name;
        std::unique_ptr<char[]> data;
        unsigned data_sz = 0;
        bool isfinfo = false;
        unsigned attr_hdr_offset = 0;
        unsigned attr_data_offset = 0;
    };
    std::vector<EA> file_eas;

    _file.XAttrIterateNames([&](const char *_name) {
        file_eas.emplace_back();
        EA &ea = file_eas.back();
        ea.name = _name;
        ea.isfinfo = ea.name == XATTR_FINDERINFO_NAME;
        return true;
    });

    for( EA &ea : file_eas ) {
        const ssize_t sz = _file.XAttrGet(ea.name.c_str(), nullptr, 0);
        if( sz > 0 ) {
            ea.data = std::make_unique<char[]>(sz);
            ea.data_sz = (unsigned)sz;
            _file.XAttrGet(ea.name.c_str(), ea.data.get(), ea.data_sz);
        }
    }

    unsigned attrs_hdrs_size = 0;
    uint16_t attrs_hdrs_count = 0;
    for( EA &ea : file_eas )
        if( !ea.isfinfo ) {
            ea.attr_hdr_offset = sizeof(attr_header) + attrs_hdrs_size;
            attrs_hdrs_size += ATTR_ENTRY_LENGTH(ea.name.length() + 1); // namelen with zero-terminator
            ++attrs_hdrs_count;
        }

    unsigned attrs_data_size = 0;
    for( EA &ea : file_eas )
        if( !ea.isfinfo ) {
            ea.attr_data_offset = sizeof(attr_header) + attrs_hdrs_size + attrs_data_size;
            attrs_data_size += (ea.data_sz + ATTR_ALIGN) & (~ATTR_ALIGN);
        }

    const unsigned full_ad_size = sizeof(attr_header) + attrs_hdrs_size + attrs_data_size;
    std::vector<std::byte> apple_double(full_ad_size, std::byte{});

    attr_header *attr_header_p = reinterpret_cast<attr_header *>(apple_double.data());
    attr_header_p->appledouble.magic = SWAP32(ADH_MAGIC);
    attr_header_p->appledouble.version = SWAP32(ADH_VERSION);
    memcpy(attr_header_p->appledouble.filler, ADH_MACOSX, sizeof(attr_header_p->appledouble.filler));
    attr_header_p->appledouble.numEntries = SWAP16(2);
    attr_header_p->appledouble.entries[0].type = SWAP32(AD_FINDERINFO);
    attr_header_p->appledouble.entries[0].offset = SWAP32(offsetof(apple_double_header, finfo));
    attr_header_p->appledouble.entries[0].length = SWAP32(full_ad_size - offsetof(apple_double_header, finfo));
    attr_header_p->appledouble.entries[1].type = SWAP32(AD_RESOURCE);
    attr_header_p->appledouble.entries[1].offset = SWAP32(full_ad_size);
    /*attr_header_p->appledouble.entries[1].length    = SWAP32(0);*/
    attr_header_p->magic = SWAP32(ATTR_HDR_MAGIC);
    /*attr_header_p->debug_tag                        = SWAP32(0);*/
    attr_header_p->total_size = SWAP32(full_ad_size);
    attr_header_p->data_start = SWAP32(sizeof(attr_header) + attrs_hdrs_size);
    attr_header_p->data_length = SWAP32(full_ad_size - (sizeof(attr_header) + attrs_hdrs_size));
    /*attr_header_p->flags                            = SWAP32(0);*/
    attr_header_p->num_attrs = SWAP16(attrs_hdrs_count);

    for( const EA &ea : file_eas ) {
        if( ea.isfinfo ) {
            memcpy(&attr_header_p->appledouble.finfo[0], ea.data.get(), std::min(32u, ea.data_sz));
        }
        else {
            attr_entry_t *entry = reinterpret_cast<attr_entry_t *>(apple_double.data() + ea.attr_hdr_offset);
            entry->offset = SWAP32(ea.attr_data_offset);
            entry->length = SWAP32(ea.data_sz);
            entry->namelen = uint8_t(ea.name.length() + 1);
            strcpy((char *)&entry->name[0], ea.name.c_str());
            memcpy(apple_double.data() + ea.attr_data_offset, ea.data.get(), ea.data_sz);
        }
    }

    return apple_double;
}

} // namespace nc::vfs

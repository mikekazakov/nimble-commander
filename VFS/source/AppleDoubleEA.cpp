// Copyright (C) 2013-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include <string.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/xattr.h>
#include <libkern/OSByteOrder.h>
#include <CoreFoundation/CoreFoundation.h>

#include "../include/VFS/AppleDoubleEA.h"

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

#define ADH_MAGIC     0x00051607
#define ADH_VERSION   0x00020000
#define ADH_MACOSX    "Mac OS X        "

/*
 * AppleDouble Entry ID's
 */
#define AD_DATA          1   /* Data fork */
#define AD_RESOURCE      2   /* Resource fork */
#define AD_REALNAME      3   /* File’s name on home file system */
#define AD_COMMENT       4   /* Standard Mac comment */
#define AD_ICONBW        5   /* Mac black & white icon */
#define AD_ICONCOLOR     6   /* Mac color icon */
#define AD_UNUSED        7   /* Not used */
#define AD_FILEDATES     8   /* File dates; create, modify, etc */
#define AD_FINDERINFO    9   /* Mac Finder info & extended info */
#define AD_MACINFO      10   /* Mac file info, attributes, etc */
#define AD_PRODOSINFO   11   /* Pro-DOS file info, attrib., etc */
#define AD_MSDOSINFO    12   /* MS-DOS file info, attributes, etc */
#define AD_AFPNAME      13   /* Short name on AFP server */
#define AD_AFPINFO      14   /* AFP file info, attrib., etc */
#define AD_AFPDIRID     15   /* AFP directory ID */
#define AD_ATTRIBUTES   AD_FINDERINFO

#define ATTR_HDR_MAGIC     0x41545452   /* 'ATTR' */

#define FINDERINFOSIZE	32

//#pragma options align=mac68k
#pragma pack(1)

typedef struct apple_double_entry
{
	u_int32_t   type;     /* entry type: see list, 0 invalid */
	u_int32_t   offset;   /* entry data offset from the beginning of the file. */
	u_int32_t   length;   /* entry data length in bytes. */
} apple_double_entry_t;

/* Entries are aligned on 4 byte boundaries */
typedef struct attr_entry
{
	u_int32_t   offset;    /* file offset to data */
	u_int32_t   length;    /* size of attribute data */
	u_int16_t   flags;
	u_int8_t    namelen;   /* length of name including NULL termination char */
	u_int8_t    name[1];   /* NULL-terminated UTF-8 name (up to 128 bytes max) */
} attr_entry_t;

typedef struct apple_double_header
{
	u_int32_t   magic;         /* == ADH_MAGIC */
	u_int32_t   version;       /* format version: 2 = 0x00020000 */
	u_int32_t   filler[4];
	u_int16_t   numEntries;	   /* number of entries which follow */
	apple_double_entry_t   entries[2];  /* 'finfo' & 'rsrc' always exist */
	u_int8_t    finfo[FINDERINFOSIZE];  /* Must start with Finder Info (32 bytes) */
	u_int8_t    pad[2];        /* get better alignment inside attr_header */
} apple_double_header_t;

/* Header + entries must fit into 64K <-- guess not true since 10.7 .MK. */
typedef struct attr_header
{
	apple_double_header_t  appledouble;
	u_int32_t   magic;        /* == ATTR_HDR_MAGIC */
	u_int32_t   debug_tag;    /* for debugging == file id of owning file */
	u_int32_t   total_size;   /* total size of attribute header + entries + data */
	u_int32_t   data_start;   /* file offset to attribute data area */
	u_int32_t   data_length;  /* length of attribute data area */
	u_int32_t   reserved[3];
	u_int16_t   flags;
	u_int16_t   num_attrs;
} attr_header_t;

//#pragma options align=reset
#pragma pack()

#define SWAP16(x)	OSSwapBigToHostInt16(x)
#define SWAP32(x)	OSSwapBigToHostInt32(x)
#define SWAP64(x)	OSSwapBigToHostInt64(x)

#define ATTR_ALIGN 3L  /* Use four-byte alignment */
#define ATTR_DATA_ALIGN 1L  /* Use two-byte alignment */

#define ATTR_ENTRY_LENGTH(namelen)  \
        ((sizeof(attr_entry_t) - 1 + (namelen) + ATTR_ALIGN) & (~ATTR_ALIGN))

#define ATTR_NEXT(ae)  \
	 (attr_entry_t *)((u_int8_t *)(ae) + ATTR_ENTRY_LENGTH((ae)->namelen))

#define	XATTR_SECURITY_NAME	  "com.apple.acl.text"

static const u_int32_t emptyfinfo[8] = {0};

/*
 * Endian swap Apple Double header
 */
static void
swap_adhdr(apple_double_header_t *adh)
{
	int count;
	int i;
    
	count = (adh->magic == ADH_MAGIC) ? adh->numEntries : SWAP16(adh->numEntries);
    
	adh->magic      = SWAP32 (adh->magic);
	adh->version    = SWAP32 (adh->version);
	adh->numEntries = SWAP16 (adh->numEntries);
    
	for (i = 0; i < count; i++)
	{
		adh->entries[i].type   = SWAP32 (adh->entries[i].type);
		adh->entries[i].offset = SWAP32 (adh->entries[i].offset);
		adh->entries[i].length = SWAP32 (adh->entries[i].length);
	}
}

/*
 * Endian swap extended attributes header
 */
static void
swap_attrhdr(attr_header_t *ah)
{
	ah->magic       = SWAP32 (ah->magic);
	ah->debug_tag   = SWAP32 (ah->debug_tag);
	ah->total_size  = SWAP32 (ah->total_size);
	ah->data_start  = SWAP32 (ah->data_start);
	ah->data_length = SWAP32 (ah->data_length);
	ah->flags       = SWAP16 (ah->flags);
	ah->num_attrs   = SWAP16 (ah->num_attrs);
}

static bool IsAppleDouble(const void *_memory_buf, size_t _memory_size)
{
    const apple_double_header_t *adhdr = (const apple_double_header_t *)_memory_buf;
    if(_memory_size < sizeof(apple_double_header_t) - 2 ||
       SWAP32(adhdr->magic) != ADH_MAGIC ||
       SWAP32(adhdr->version) != ADH_VERSION ||
       SWAP16(adhdr->numEntries) != 2 ||
       SWAP32(adhdr->entries[0].type) != AD_FINDERINFO
       )
        return false;

    return true;
}

vector<AppleDoubleEA> ExtractEAFromAppleDouble(const void *_memory_buf, size_t _memory_size)
{
    if(!_memory_buf || !_memory_size)
        return vector<AppleDoubleEA>();

    if(!IsAppleDouble(_memory_buf, _memory_size))
        return vector<AppleDoubleEA>();
    
    apple_double_header_t adhdr = *(const apple_double_header_t *) _memory_buf;
    swap_adhdr(&adhdr);
  
    bool has_finfo = memcmp(adhdr.finfo, emptyfinfo, sizeof(emptyfinfo)) != 0;
    
    vector<AppleDoubleEA> eas;
    int eas_last = 0;
    
    if(adhdr.entries[0].length > FINDERINFOSIZE)
    {
        attr_header_t attrhdr = *(const attr_header_t *)_memory_buf;
        swap_attrhdr(&attrhdr);
        
        if (attrhdr.magic == ATTR_HDR_MAGIC)
        {
            int count = attrhdr.num_attrs;
            eas.resize( has_finfo ? count + 1 : count );
            
            const attr_entry_t *entry = (const attr_entry_t *)((char*)_memory_buf + sizeof(attr_header_t));
            for (int i = 0; i < count; i++)
            {
                if((char*)entry + sizeof(attr_entry_t) > (char*)_memory_buf + _memory_size)
                    break; // out-of-boundary guard to be safe about memory (not)corrupting
                
                u_int32_t offset = SWAP32(entry->offset);
                u_int32_t length = SWAP32(entry->length);
                u_int32_t namelen = 0;
                const char *name = (const char*)&entry->name[0];
                
                // safely calculate a name len
                for(const char *si = name; si < (char*)_memory_buf + _memory_size && (*si) != 0; ++si, ++namelen)
                    ;
              

                if(namelen > 0 &&
                   name + namelen < (char*)_memory_buf + _memory_size &&
                   name[namelen] == 0 &&
                   offset + length <= _memory_size)
                { // seems to be a valid EA
                    eas[eas_last].data = (char*)_memory_buf + offset;
                    eas[eas_last].data_sz = length;
                    eas[eas_last].name = name;
                    eas[eas_last].name_len = namelen;
                    ++eas_last;
                }
                entry = ATTR_NEXT(entry);
            }
        }
    }
    
    if(has_finfo)
    {
        if(eas.empty()) // no extended attributes except FinderInfo was found
            eas.resize(1);
        eas[eas_last].data = &((const apple_double_header_t *)_memory_buf)->finfo[0];
        eas[eas_last].data_sz = 32;
        eas[eas_last].name = XATTR_FINDERINFO_NAME; // "com.apple.FinderInfo"
        eas[eas_last].name_len = 20;
        ++eas_last;
    }
    
    return eas;
}

void *BuildAppleDoubleFromEA(VFSFile &_file,
                             size_t *_buf_sz)
{
    unsigned ret_xattr_count = _file.XAttrCount();
    if(ret_xattr_count == 0)
        return 0;
    
    static const int max_eas = 64;
    struct {
        char name[256];
        int name_len;
        unique_ptr<char[]> data;
        unsigned data_sz;
        bool isfinfo;
        unsigned attr_hdr_offset;
        unsigned attr_data_offset;
    } file_eas_s[max_eas];
    auto *file_eas = &file_eas_s[0]; // to bypass block prohibition of arrays modification
    memset(file_eas, 0, sizeof(file_eas_s));
    
    assert(ret_xattr_count < max_eas); // anti-crash protection;
    
    int eas_count = 0;
    
    bool has_finfo = false;
    
    _file.XAttrIterateNames([&](auto _name){
            assert(eas_count < max_eas);
            file_eas[eas_count].name_len = (int)strlen(_name);
            assert(file_eas[eas_count].name_len < 256);
            strcpy(file_eas[eas_count].name, _name);
            if(strcmp(_name, XATTR_FINDERINFO_NAME) == 0) {
                has_finfo = true;
                file_eas[eas_count].isfinfo = true;
            }
            eas_count++;
            return true;
        });
    
    for(int i = 0; i < eas_count; ++i) {
        ssize_t sz = _file.XAttrGet(file_eas[i].name, 0, 0);
        if(sz > 0) {
            file_eas[i].data = make_unique<char[]>(sz);
            assert(file_eas[i].data);
            file_eas[i].data_sz = (unsigned)sz;
            _file.XAttrGet(file_eas[i].name, file_eas[i].data.get(), file_eas[i].data_sz);
        }
    }

    unsigned attrs_hdrs_size = 0;
    uint16_t attrs_hdrs_count = 0;
    for(int i = 0; i < eas_count; ++i)
        if(!file_eas[i].isfinfo) {
            file_eas[i].attr_hdr_offset = sizeof(attr_header) + attrs_hdrs_size;
            attrs_hdrs_size += ATTR_ENTRY_LENGTH(file_eas[i].name_len+1); // namelen with zero-terminator
            ++attrs_hdrs_count;
        }
    
    unsigned attrs_data_size = 0;
    for(int i = 0; i < eas_count; ++i)
        if(!file_eas[i].isfinfo) {
            file_eas[i].attr_data_offset = sizeof(attr_header) + attrs_hdrs_size + attrs_data_size;
            attrs_data_size += (file_eas[i].data_sz + ATTR_ALIGN) & (~ATTR_ALIGN);
        }
    
    unsigned full_ad_size = sizeof(attr_header) + attrs_hdrs_size + attrs_data_size;
    void *apple_double = malloc(full_ad_size);
    memset(apple_double, 0, full_ad_size);
    
    attr_header *attr_header_p = (attr_header *) apple_double;
    attr_header_p->appledouble.magic                = SWAP32(ADH_MAGIC);
    attr_header_p->appledouble.version              = SWAP32(ADH_VERSION);
    memcpy(attr_header_p->appledouble.filler, ADH_MACOSX, sizeof(attr_header_p->appledouble.filler));
    attr_header_p->appledouble.numEntries           = SWAP16(2);
    attr_header_p->appledouble.entries[0].type      = SWAP32(AD_FINDERINFO);
    attr_header_p->appledouble.entries[0].offset    = SWAP32(offsetof(apple_double_header, finfo));
    attr_header_p->appledouble.entries[0].length    = SWAP32(full_ad_size - offsetof(apple_double_header, finfo));
    attr_header_p->appledouble.entries[1].type      = SWAP32(AD_RESOURCE);
    attr_header_p->appledouble.entries[1].offset    = SWAP32(full_ad_size);
  /*attr_header_p->appledouble.entries[1].length    = SWAP32(0);*/
    attr_header_p->magic                            = SWAP32(ATTR_HDR_MAGIC);
  /*attr_header_p->debug_tag                        = SWAP32(0);*/
    attr_header_p->total_size                       = SWAP32(full_ad_size);
    attr_header_p->data_start                       = SWAP32(sizeof(attr_header) + attrs_hdrs_size);
    attr_header_p->data_length                      = SWAP32( full_ad_size - (sizeof(attr_header) + attrs_hdrs_size) );
  /*attr_header_p->flags                            = SWAP32(0);*/
    attr_header_p->num_attrs                        = SWAP16(attrs_hdrs_count);
    
    for(int i = 0; i < eas_count; ++i) {
        const auto &ea = file_eas[i];
        if( !ea.isfinfo ) {
            attr_entry_t *entry = (attr_entry_t *)((char *)apple_double + ea.attr_hdr_offset);
            entry->offset   = SWAP32(ea.attr_data_offset);
            entry->length   = SWAP32(ea.data_sz);
            entry->namelen  = uint8_t(ea.name_len + 1);
            strcpy((char*)&entry->name[0], ea.name);
            memcpy((char *)apple_double + ea.attr_data_offset, ea.data.get(), ea.data_sz);
        }
        else {
            memcpy(&attr_header_p->appledouble.finfo[0],
                   ea.data.get(),
                   min(32u, ea.data_sz)
                   );
        }
    }

    *_buf_sz = full_ad_size;
    return apple_double;
}

}

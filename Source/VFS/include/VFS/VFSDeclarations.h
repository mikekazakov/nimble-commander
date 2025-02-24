// Copyright (C) 2014-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <string>
#include <functional>
#include <compare>
#include <Base/intrusive_ptr.h>
#include <Base/Error.h>

struct stat;

namespace nc::vfs {

struct DirEnt {
    enum {
        Unknown = 0,  /* = DT_UNKNOWN */
        FIFO = 1,     /* = DT_FIFO    */
        Char = 2,     /* = DT_CHR     */
        Dir = 4,      /* = DT_DIR     */
        Block = 6,    /* = DT_BLK     */
        Reg = 8,      /* = DT_REG     */
        Link = 10,    /* = DT_LNK     */
        Socket = 12,  /* = DT_SOCK    */
        Whiteout = 14 /* = DT_WHT     */
    };

    uint16_t type;
    uint16_t name_len;
    char name[1024];
};

struct StatFS {
    uint64_t total_bytes = 0;
    uint64_t free_bytes = 0;
    uint64_t avail_bytes = 0; // may be less than actual free_bytes
    std::string volume_name;

    constexpr bool operator==(const StatFS &_rhs) const noexcept = default;
};

struct Stat {
    uint64_t size = 0;       /* File size, in bytes */
    uint64_t blocks = 0;     /* blocks allocated for file */
    uint64_t inode = 0;      /* File serial number */
    int32_t dev = 0;         /* ID of device containing file */
    int32_t rdev = 0;        /* Device ID (if special file) */
    uint32_t uid = 0;        /* User ID of the file */
    uint32_t gid = 0;        /* Group ID of the file */
    int32_t blksize = 0;     /* Optimal blocksize for I/O */
    uint32_t flags = 0;      /* User defined flags for file */
    timespec atime = {0, 0}; /* Time of last access */
    timespec mtime = {0, 0}; /* Time of last data modification */
    timespec ctime = {0, 0}; /* Time of last status change */
    timespec btime = {0, 0}; /* Time of file creation(birth) */
    union {
        uint16_t mode = 0; /* Mode of file */
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
            unsigned vtx : 1;
            unsigned gid : 1;
            unsigned uid : 1;
            unsigned fifo : 1;
            unsigned chr : 1;
            unsigned dir : 1;
            unsigned reg : 1;
        } __attribute__((packed)) mode_bits; /* Mode decomposed as flags*/
    };
    uint16_t nlink = 0; /* Number of hard links */
    struct __attribute__((packed)) meaningT {
        unsigned size : 1 = 0;
        unsigned blocks : 1 = 0;
        unsigned inode : 1 = 0;
        unsigned dev : 1 = 0;
        unsigned rdev : 1 = 0;
        unsigned uid : 1 = 0;
        unsigned gid : 1 = 0;
        unsigned blksize : 1 = 0;
        unsigned flags : 1 = 0;
        unsigned mode : 1 = 0;
        unsigned nlink : 1 = 0;
        unsigned atime : 1 = 0;
        unsigned mtime : 1 = 0;
        unsigned ctime : 1 = 0;
        unsigned btime : 1 = 0;
        unsigned __unused_padding_dont_touch_me__ : 1 = 0;
    } meaning;

    // TODO: return the value instead of using the out parameter
    static void FromSysStat(const struct ::stat &_from, Stat &_to);

    // TODO: return the value instead of using the out parameter
    static void ToSysStat(const Stat &_from, struct ::stat &_to);

    struct ::stat SysStat() const noexcept;

    inline static meaningT AllMeaning()
    {
        const uint64_t t = ~0ull;
        return *reinterpret_cast<const meaningT *>(&t);
    }
    inline static meaningT NoMeaning()
    {
        const uint64_t t = 0ull;
        return *reinterpret_cast<const meaningT *>(&t);
    }
};

struct User {
    uint32_t uid;
    std::string name;
    std::string gecos;
    friend bool operator==(const User &, const User &) noexcept = default;
};

struct Group {
    uint32_t gid;
    std::string name;
    std::string gecos;
    friend bool operator==(const Group &, const Group &) noexcept = default;
};

struct Flags {
    static constexpr uint64_t None = 0x00000000;

    //  VFSFile opening-time flags
    static constexpr uint64_t OF_IXOth = 0x00000001; // = S_IXOTH
    static constexpr uint64_t OF_IWOth = 0x00000002; // = S_IWOTH
    static constexpr uint64_t OF_IROth = 0x00000004; // = S_IROTH
    static constexpr uint64_t OF_IXGrp = 0x00000008; // = S_IXGRP
    static constexpr uint64_t OF_IWGrp = 0x00000010; // = S_IWGRP
    static constexpr uint64_t OF_IRGrp = 0x00000020; // = S_IRGRP
    static constexpr uint64_t OF_IXUsr = 0x00000040; // = S_IXUSR
    static constexpr uint64_t OF_IWUsr = 0x00000080; // = S_IWUSR
    static constexpr uint64_t OF_IRUsr = 0x00000100; // = S_IRUSR
    static constexpr uint64_t OF_Read = 0x00010000;
    static constexpr uint64_t OF_Write = 0x00020000;
    static constexpr uint64_t OF_Create = 0x00040000;
    static constexpr uint64_t OF_NoExist = 0x00080000;   // POSIX O_EXCL actcually, for clarity
    static constexpr uint64_t OF_ShLock = 0x00100000;    // not yet implemented
    static constexpr uint64_t OF_ExLock = 0x00200000;    // not yet implemented
    static constexpr uint64_t OF_NoCache = 0x00400000;   // turns off caching if supported
    static constexpr uint64_t OF_Append = 0x00800000;    // appends file on writing
    static constexpr uint64_t OF_Truncate = 0x01000000;  // truncates files upon opening
    static constexpr uint64_t OF_Directory = 0x02000000; // opens directory for xattr reading

    // Flags altering host behaviour
    /** do not follow symlinks when resolving item name */
    static constexpr uint64_t F_NoFollow = 0x010000000ull;

    // Flags altering listing building
    /** for listing. don't fetch dot-dot entry in directory listing */
    static constexpr uint64_t F_NoDotDot = 0x020000000ull;

    /** for listing. ask system to provide localized display names */
    static constexpr uint64_t F_LoadDisplayNames = 0x040000000ull;

    /** discard caches when fetching information. */
    static constexpr uint64_t F_ForceRefresh = 0x080000000ull;

    /** load Finder Tafs. */
    static constexpr uint64_t F_LoadTags = 0x100000000ull;
};

class Listing;
class ListingItem;
class Host;
class VFSPath;

} // namespace nc::vfs

using VFSListing = nc::vfs::Listing;
using VFSListingPtr = nc::base::intrusive_ptr<const nc::vfs::Listing>;
using VFSListingItem = nc::vfs::ListingItem;
using VFSHost = nc::vfs::Host;
using VFSHostPtr = std::shared_ptr<nc::vfs::Host>;
using VFSHostWeakPtr = std::weak_ptr<nc::vfs::Host>;
using VFSFlags = nc::vfs::Flags;
using VFSGroup = nc::vfs::Group;
using VFSUser = nc::vfs::User;
using VFSStat = nc::vfs::Stat;
using VFSStatFS = nc::vfs::StatFS;
using VFSDirEnt = nc::vfs::DirEnt;

class VFSFile;
class VFSConfiguration;

using VFSFilePtr = std::shared_ptr<VFSFile>;
using VFSCancelChecker = std::function<bool()>;

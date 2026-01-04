// Copyright (C) 2015-2026 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Base/variable_container.h>
#include <Base/CFString.h>
#include <Base/intrusive_ptr.h>
#include <VFS/VFSDeclarations.h>
#include <Utility/Tags.h>
#include <chrono>
#include <span>
#include <ankerl/unordered_dense.h>

/**
 * A note about symlinks handling. Listing must be aware, that some items might be symlinks.
 * UnixType() must stay unfollowed, i.e. specifying that an entry is a symlink.
 * The following fields are expected to be resolved, i.e. followed by symlink:
 * UnixMode()
 * UnixFlags
 * UID()
 * GID()
 * Size()
 * Symlink()
 */

namespace nc::vfs {

struct ListingInput;
class ListingItem;

class Listing : public nc::base::intrusive_ref_counter<Listing>
{
public:
    Listing(const Listing &) = delete;
    Listing &operator=(const Listing &) = delete;
    ~Listing();

    static const base::intrusive_ptr<const Listing> &EmptyListing() noexcept;
    static base::intrusive_ptr<const Listing> Build(ListingInput &&_input);

    /**
     * compose many listings into a new ListingInput.
     * it will contain only sparse-based variable containers.
     * will throw on errors
     */
    static ListingInput Compose(const std::vector<base::intrusive_ptr<const Listing>> &_listings);
    static ListingInput Compose(const std::vector<base::intrusive_ptr<const Listing>> &_listings,
                                const std::vector<std::vector<unsigned>> &_items_indeces);

    static base::intrusive_ptr<const Listing> ProduceUpdatedTemporaryPanelListing(const Listing &_original,
                                                                                  VFSCancelChecker _cancel_checker);

    /**
     * Returns items amount in this listing.
     */
    unsigned Count() const noexcept;
    bool Empty() const noexcept;
    bool IsUniform() const noexcept;
    bool HasCommonHost() const noexcept;
    bool HasCommonDirectory() const noexcept;

    /**
     * Returns an optional title for this listing object.
     */
    const std::string &Title() const noexcept;

    // Returns a timestamp time kernel ticks (mach_time) of the time point at which this listing was built.
    std::chrono::nanoseconds BuildTicksTimestamp() const noexcept;

    ListingItem Item(unsigned _ind) const;

    const std::string &Directory() const; // will throw if there's no common directory
    const std::string &Directory(unsigned _ind) const;
    const VFSHostPtr &Host() const; // will throw if there's no common host
    const VFSHostPtr &Host(unsigned _ind) const;

    /**
     * Compose a path to specified listing item. Is case of ".." item will directory path itself.
     */
    std::string Path(unsigned _ind) const;

    const std::string &Filename(unsigned _ind) const;
    CFStringRef FilenameCF(unsigned _ind) const;
#ifdef __OBJC__
    NSString *FilenameNS(unsigned _ind) const;
#endif

    mode_t UnixMode(unsigned _ind) const;
    uint8_t UnixType(unsigned _ind) const;

    // Returns true if the item has a well-specified extension.
    bool HasExtension(unsigned _ind) const;

    // Returns the offset in the filename string where the extension starts.
    // In case the item has no extension, returns 0.
    uint16_t ExtensionOffset(unsigned _ind) const;

    // Returns the C-string pointer to the extension within the filename.
    // In case the item has no extension, returns a pointer to the beginning of the filename.
    const char *Extension(unsigned _ind) const;

    std::string FilenameWithoutExt(unsigned _ind) const;

    bool HasSize(unsigned _ind) const;
    uint64_t Size(unsigned _ind) const;

    bool HasInode(unsigned _ind) const;
    uint64_t Inode(unsigned _ind) const;

    bool HasATime(unsigned _ind) const;
    time_t ATime(unsigned _ind) const;

    bool HasMTime(unsigned _ind) const;
    time_t MTime(unsigned _ind) const;

    bool HasCTime(unsigned _ind) const;
    time_t CTime(unsigned _ind) const;

    bool HasBTime(unsigned _ind) const;
    time_t BTime(unsigned _ind) const;

    bool HasAddTime(unsigned _ind) const;
    time_t AddTime(unsigned _ind) const; // will return BTime if there's no AddTime

    bool HasUID(unsigned _ind) const;
    uid_t UID(unsigned _ind) const;

    bool HasGID(unsigned _ind) const;
    gid_t GID(unsigned _ind) const;

    bool HasUnixFlags(unsigned _ind) const;
    uint32_t UnixFlags(unsigned _ind) const;

    bool HasSymlink(unsigned _ind) const;
    const std::string &Symlink(unsigned _ind) const;

    bool HasTags(unsigned _ind) const;
    std::span<const utility::Tags::Tag> Tags(unsigned _ind) const; // will return {} if there are no tags

    bool HasDisplayFilename(unsigned _ind) const;
    const std::string &DisplayFilename(unsigned _ind) const;
    CFStringRef DisplayFilenameCF(unsigned _ind) const;
#ifdef __OBJC__
    inline NSString *DisplayFilenameNS(unsigned _ind) const;
#endif

    bool IsDotDot(unsigned _ind) const;

    bool IsDir(unsigned _ind) const;

    // Returns true if the item is a regular file, i.e. ((UnixMode & S_IFMT) == S_IFREG).
    // In case of a symlink, the target type is returned.
    bool IsReg(unsigned _ind) const;

    // Return true if the item is a symlink, i.e. (UnixType == DT_LNK).
    // This refers to the item itself, not to its target, i.e. the file type without potentially following a symlink.
    // An item can be both a symlink and a Dir or a Reg.
    bool IsSymlink(unsigned _ind) const;

    // An item is hidden when either its filename starts with the dot character or the item has a `UF_HIDDEN` flag up.
    // ".." entries are never hidden.
    bool IsHidden(unsigned _ind) const;

    class iterator;
    iterator begin() const noexcept;
    iterator end() const noexcept;

private:
    Listing();

    void BuildFilenames();

    unsigned m_ItemsCount;
    time_t m_CreationTime;
    std::chrono::nanoseconds m_CreationTicks; // the kernel ticks stamp at which the Listing was created
    std::string m_Title;
    std::unique_ptr<std::string[]> m_Filenames;
    std::unique_ptr<base::CFString[]> m_FilenamesCF;
    std::unique_ptr<uint16_t[]> m_ExtensionOffsets;
    std::unique_ptr<mode_t[]> m_UnixModes;
    std::unique_ptr<uint8_t[]> m_UnixTypes;
    base::variable_container<VFSHostPtr> m_Hosts;
    base::variable_container<std::string> m_Directories;
    base::variable_container<uint64_t> m_Sizes;
    base::variable_container<uint64_t> m_Inodes;
    base::variable_container<time_t> m_ATimes;
    base::variable_container<time_t> m_MTimes;
    base::variable_container<time_t> m_CTimes;
    base::variable_container<time_t> m_BTimes;
    base::variable_container<time_t> m_AddTimes;
    base::variable_container<uid_t> m_UIDS;
    base::variable_container<gid_t> m_GIDS;
    base::variable_container<uint32_t> m_UnixFlags;
    base::variable_container<std::string> m_Symlinks;
    base::variable_container<std::string> m_DisplayFilenames;
    base::variable_container<base::CFString> m_DisplayFilenamesCF;
    ankerl::unordered_dense::map<size_t, std::vector<utility::Tags::Tag>> m_Tags;

    // this is a copy of POSIX/BSD constants to reduce headers pollution
    constexpr static const mode_t m_S_IFMT = 0170000;
    constexpr static const mode_t m_S_IFIFO = 0010000;
    constexpr static const mode_t m_S_IFCHR = 0020000;
    constexpr static const mode_t m_S_IFDIR = 0040000;
    constexpr static const mode_t m_S_IFBLK = 0060000;
    constexpr static const mode_t m_S_IFREG = 0100000;
    constexpr static const mode_t m_S_IFLNK = 0120000;
    constexpr static const mode_t m_S_IFSOCK = 0140000;
    constexpr static const mode_t m_S_IFWHT = 0160000;
    constexpr static const uint8_t m_DT_UNKNOWN = 0;
    constexpr static const uint8_t m_DT_FIFO = 1;
    constexpr static const uint8_t m_DT_CHR = 2;
    constexpr static const uint8_t m_DT_DIR = 4;
    constexpr static const uint8_t m_DT_BLK = 6;
    constexpr static const uint8_t m_DT_REG = 8;
    constexpr static const uint8_t m_DT_LNK = 10;
    constexpr static const uint8_t m_DT_SOCK = 12;
    constexpr static const uint8_t m_DT_WHT = 14;
    constexpr static const uint32_t m_UF_SETTABLE = 0x0000ffff;
    constexpr static const uint32_t m_UF_NODUMP = 0x00000001;
    constexpr static const uint32_t m_UF_IMMUTABLE = 0x00000002;
    constexpr static const uint32_t m_UF_APPEND = 0x00000004;
    constexpr static const uint32_t m_UF_OPAQUE = 0x00000008;
    constexpr static const uint32_t m_UF_COMPRESSED = 0x00000020;
    constexpr static const uint32_t m_UF_TRACKED = 0x00000040;
    constexpr static const uint32_t m_UF_DATAVAULT = 0x00000080;
    constexpr static const uint32_t m_UF_HIDDEN = 0x00008000;
    constexpr static const uint32_t m_SF_SUPPORTED = 0x001f0000;
    constexpr static const uint32_t m_SF_SETTABLE = 0xffff0000;
    constexpr static const uint32_t m_SF_ARCHIVED = 0x00010000;
    constexpr static const uint32_t m_SF_IMMUTABLE = 0x00020000;
    constexpr static const uint32_t m_SF_APPEND = 0x00040000;
    constexpr static const uint32_t m_SF_RESTRICTED = 0x00080000;
    constexpr static const uint32_t m_SF_NOUNLINK = 0x00100000;
};

// ListingItem class is a simple wrapper around (pointer;index)
// pair for object-oriented access to listing items with value semantics.
class ListingItem
{
public:
    ListingItem() noexcept;
    ListingItem(const base::intrusive_ptr<const Listing> &_listing, unsigned _ind) noexcept;
    operator bool() const noexcept;
    [[nodiscard]] const base::intrusive_ptr<const Listing> &Listing() const noexcept;
    [[nodiscard]] unsigned Index() const noexcept;

    [[nodiscard]] std::string Path() const;
    [[nodiscard]] const VFSHostPtr &Host() const;
    [[nodiscard]] const std::string &Directory() const;

    // currently mimicking old VFSListingItem interface, may change methods names later
    [[nodiscard]] const std::string &Filename() const;
    [[nodiscard]] const char *FilenameC() const;
    [[nodiscard]] size_t FilenameLen() const;
    [[nodiscard]] CFStringRef FilenameCF() const;
#ifdef __OBJC__
    [[nodiscard]] NSString *FilenameNS() const;
#endif

    [[nodiscard]] bool HasDisplayName() const;
    [[nodiscard]] const std::string &DisplayName() const;
    [[nodiscard]] CFStringRef DisplayNameCF() const;
#ifdef __OBJC__
    [[nodiscard]] NSString *DisplayNameNS() const;
#endif

    [[nodiscard]] bool HasExtension() const;
    [[nodiscard]] uint16_t ExtensionOffset() const;
    [[nodiscard]] const char *Extension() const;      // unguarded calls whout HasExtension will
                                                      // yeild a whole filename as a result
    [[nodiscard]] const char *ExtensionIfAny() const; // will return "" if there's no extension
    [[nodiscard]] std::string FilenameWithoutExt() const;

    [[nodiscard]] mode_t UnixMode() const;  // resolved for symlinks
    [[nodiscard]] uint8_t UnixType() const; // type is _original_ directory entry, without symlinks resolving

    [[nodiscard]] bool HasSize() const;
    [[nodiscard]] uint64_t Size() const;

    [[nodiscard]] bool HasInode() const;
    [[nodiscard]] uint64_t Inode() const;

    [[nodiscard]] bool HasATime() const;
    [[nodiscard]] time_t ATime() const;

    [[nodiscard]] bool HasMTime() const;
    [[nodiscard]] time_t MTime() const;

    [[nodiscard]] bool HasCTime() const;
    [[nodiscard]] time_t CTime() const;

    [[nodiscard]] bool HasBTime() const;
    [[nodiscard]] time_t BTime() const;

    [[nodiscard]] bool HasAddTime() const;
    [[nodiscard]] time_t AddTime() const;

    [[nodiscard]] bool HasUnixFlags() const;
    [[nodiscard]] uint32_t UnixFlags() const;

    [[nodiscard]] bool HasUnixUID() const;
    [[nodiscard]] uid_t UnixUID() const;

    [[nodiscard]] bool HasUnixGID() const;
    [[nodiscard]] gid_t UnixGID() const;

    [[nodiscard]] bool HasSymlink() const;
    [[nodiscard]] const std::string &Symlink() const;

    [[nodiscard]] bool HasTags() const;
    [[nodiscard]] std::span<const utility::Tags::Tag> Tags() const;

    [[nodiscard]] bool IsDir() const;
    [[nodiscard]] bool IsReg() const;
    [[nodiscard]] bool IsSymlink() const;
    [[nodiscard]] bool IsDotDot() const;
    [[nodiscard]] bool IsHidden() const;

    bool operator==(const ListingItem &_) const noexcept;
    bool operator!=(const ListingItem &_) const noexcept;

private:
    nc::base::intrusive_ptr<const class Listing> L;
    unsigned I;
    friend Listing::iterator;
};

class Listing::iterator
{
public:
    using difference_type = long;
    using value_type = ListingItem;
    using pointer = void;
    using reference = const ListingItem &;
    using iterator_category = std::random_access_iterator_tag;

    iterator &operator--() noexcept;   // prefix decrement
    iterator &operator++() noexcept;   // prefix increment
    iterator operator--(int) noexcept; // posfix decrement
    iterator operator++(int) noexcept; // posfix increment
    iterator operator+(long _diff) const noexcept;
    iterator operator-(long _diff) const noexcept;
    long operator-(const iterator &_rhs) const noexcept;
    iterator &operator+=(long _diff) noexcept;
    iterator &operator-=(long _diff) noexcept;

    bool operator==(const iterator &_r) const noexcept;
    bool operator!=(const iterator &_r) const noexcept;
    bool operator<(const iterator &_r) const noexcept;
    bool operator<=(const iterator &_r) const noexcept;
    bool operator>(const iterator &_r) const noexcept;
    bool operator>=(const iterator &_r) const noexcept;
    const ListingItem &operator*() const noexcept;

private:
    ListingItem i;
    friend class Listing;
};

}; // namespace nc::vfs

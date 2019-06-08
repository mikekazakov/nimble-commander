// Copyright (C) 2015-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Habanero/variable_container.h>
#include <Habanero/CFString.h>
#include <VFS/VFSDeclarations.h>

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
class WeakListingItem;

class Listing : public std::enable_shared_from_this<Listing>
{
public:
    static const VFSListingPtr &EmptyListing() noexcept;
    static VFSListingPtr    Build(ListingInput &&_input);
    
    /**
     * compose many listings into a new ListingInput.
     * it will contain only sparse-based variable containers.
     * will throw on errors
     */
    static ListingInput Compose(const std::vector<std::shared_ptr<Listing>> &_listings);
    static ListingInput Compose(const std::vector<std::shared_ptr<Listing>> &_listings,
                                const std::vector< std::vector<unsigned> > &_items_indeces);
    
    
    static VFSListingPtr ProduceUpdatedTemporaryPanelListing(const Listing& _original,
                                                             VFSCancelChecker _cancel_checker );
    
    /**
     * Returns items amount in this listing. 
     */
    unsigned            Count               () const noexcept;
    bool                Empty               () const noexcept;
    bool                IsUniform           () const noexcept;
    bool                HasCommonHost       () const noexcept;
    bool                HasCommonDirectory  () const noexcept;

    ListingItem         Item                (unsigned _ind) const;

    const std::string&  Directory           () const; // will throw if there's no common directory
    const std::string&  Directory           (unsigned _ind) const;
    const VFSHostPtr&   Host                () const; // will throw if there's no common host
    const VFSHostPtr&   Host                (unsigned _ind) const;
    
    /**
     * Compose a path to specified listing item. Is case of ".." item will directory path itself.
     */
    std::string         Path                (unsigned _ind) const;
    
    const std::string&  Filename            (unsigned _ind) const;
    CFStringRef         FilenameCF          (unsigned _ind) const;
#ifdef __OBJC__
    NSString*           FilenameNS          (unsigned _ind) const;
#endif

    mode_t              UnixMode            (unsigned _ind) const;
    uint8_t             UnixType            (unsigned _ind) const;
    
    bool                HasExtension        (unsigned _ind) const;
    uint16_t            ExtensionOffset     (unsigned _ind) const;
    const char*         Extension           (unsigned _ind) const;
    
    std::string         FilenameWithoutExt  (unsigned _ind) const;
    
    bool                HasSize             (unsigned _ind) const;
    uint64_t            Size                (unsigned _ind) const;
    
    bool                HasInode            (unsigned _ind) const;
    uint64_t            Inode               (unsigned _ind) const;
    
    bool                HasATime            (unsigned _ind) const;
    time_t              ATime               (unsigned _ind) const;

    bool                HasMTime            (unsigned _ind) const;
    time_t              MTime               (unsigned _ind) const;

    bool                HasCTime            (unsigned _ind) const;
    time_t              CTime               (unsigned _ind) const;

    bool                HasBTime            (unsigned _ind) const;
    time_t              BTime               (unsigned _ind) const;

    bool                HasAddTime          (unsigned _ind) const;
    time_t              AddTime             (unsigned _ind) const; // will return BTime if there's no AddTime
    
    bool                HasUID              (unsigned _ind) const;
    uid_t               UID                 (unsigned _ind) const;

    bool                HasGID              (unsigned _ind) const;
    gid_t               GID                 (unsigned _ind) const;

    bool                HasUnixFlags        (unsigned _ind) const;
    uint32_t            UnixFlags           (unsigned _ind) const;
    
    bool                HasSymlink          (unsigned _ind) const;
    const std::string&  Symlink             (unsigned _ind) const;
    
    bool                HasDisplayFilename  (unsigned _ind) const;
    const std::string&  DisplayFilename     (unsigned _ind) const;
    CFStringRef         DisplayFilenameCF   (unsigned _ind) const;
#ifdef __OBJC__
    inline NSString*    DisplayFilenameNS   (unsigned _ind) const;
#endif
    
    bool                IsDotDot            (unsigned _ind) const;
    bool                IsDir               (unsigned _ind) const;
    bool                IsReg               (unsigned _ind) const;
    bool                IsSymlink           (unsigned _ind) const;
    bool                IsHidden            (unsigned _ind) const;
    
    class iterator;
    iterator            begin               () const noexcept;
    iterator            end                 () const noexcept;
    
private:
    Listing() = default;
    ~Listing() = default;
    static std::shared_ptr<Listing> Alloc(); // fighting against c++...
    void BuildFilenames();    
    
    unsigned                                m_ItemsCount;
    time_t                                  m_CreationTime;
    base::variable_container<VFSHostPtr>    m_Hosts;
    base::variable_container<std::string>   m_Directories;
    std::vector<std::string>                m_Filenames;
    std::vector<CFString>                   m_FilenamesCF;
    std::vector<uint16_t>                   m_ExtensionOffsets;
    std::vector<mode_t>                     m_UnixModes;
    std::vector<uint8_t>                    m_UnixTypes;
    base::variable_container<uint64_t>      m_Sizes;
    base::variable_container<uint64_t>      m_Inodes;
    base::variable_container<time_t>        m_ATimes;
    base::variable_container<time_t>        m_MTimes;
    base::variable_container<time_t>        m_CTimes;
    base::variable_container<time_t>        m_BTimes;
    base::variable_container<time_t>        m_AddTimes;
    base::variable_container<uid_t>         m_UIDS;
    base::variable_container<gid_t>         m_GIDS;
    base::variable_container<uint32_t>      m_UnixFlags;
    base::variable_container<std::string>   m_Symlinks;
    base::variable_container<std::string>   m_DisplayFilenames;
    base::variable_container<CFString>      m_DisplayFilenamesCF;
    
    // this is a copy of POSIX/BSD constants to reduce headers pollution
    inline constexpr static const mode_t   m_S_IFMT        = 0170000;
    inline constexpr static const mode_t   m_S_IFIFO       = 0010000;    
    inline constexpr static const mode_t   m_S_IFCHR       = 0020000;  
    inline constexpr static const mode_t   m_S_IFDIR       = 0040000;
    inline constexpr static const mode_t   m_S_IFBLK       = 0060000;    
    inline constexpr static const mode_t   m_S_IFREG       = 0100000;    
    inline constexpr static const mode_t   m_S_IFLNK       = 0120000;
    inline constexpr static const mode_t   m_S_IFSOCK      = 0140000;    
    inline constexpr static const mode_t   m_S_IFWHT       = 0160000;    
    inline constexpr static const uint8_t  m_DT_UNKNOWN    = 0;
    inline constexpr static const uint8_t  m_DT_FIFO       = 1;    
    inline constexpr static const uint8_t  m_DT_CHR        = 2;    
    inline constexpr static const uint8_t  m_DT_DIR        = 4;    
    inline constexpr static const uint8_t  m_DT_BLK        = 6;    
    inline constexpr static const uint8_t  m_DT_REG        = 8;
    inline constexpr static const uint8_t  m_DT_LNK        = 10;    
    inline constexpr static const uint8_t  m_DT_SOCK       = 12;    
    inline constexpr static const uint8_t  m_DT_WHT        = 14;
    inline constexpr static const uint32_t m_UF_SETTABLE   = 0x0000ffff;    
    inline constexpr static const uint32_t m_UF_NODUMP     = 0x00000001;    
    inline constexpr static const uint32_t m_UF_IMMUTABLE  = 0x00000002;    
    inline constexpr static const uint32_t m_UF_APPEND     = 0x00000004;
    inline constexpr static const uint32_t m_UF_OPAQUE     = 0x00000008;    
    inline constexpr static const uint32_t m_UF_COMPRESSED = 0x00000020;    
    inline constexpr static const uint32_t m_UF_TRACKED    = 0x00000040;    
    inline constexpr static const uint32_t m_UF_DATAVAULT  = 0x00000080;    
    inline constexpr static const uint32_t m_UF_HIDDEN     = 0x00008000;    
    inline constexpr static const uint32_t m_SF_SUPPORTED  = 0x001f0000;    
    inline constexpr static const uint32_t m_SF_SETTABLE   = 0xffff0000;    
    inline constexpr static const uint32_t m_SF_ARCHIVED   = 0x00010000;    
    inline constexpr static const uint32_t m_SF_IMMUTABLE  = 0x00020000;    
    inline constexpr static const uint32_t m_SF_APPEND     = 0x00040000;    
    inline constexpr static const uint32_t m_SF_RESTRICTED = 0x00080000;    
    inline constexpr static const uint32_t m_SF_NOUNLINK   = 0x00100000;    
};

// ListingItem class is a simple wrapper around (pointer;index)
// pair for object-oriented access to listing items with value semantics.
class ListingItem
{
public:
    ListingItem() noexcept;
    ListingItem(const std::shared_ptr<const Listing>& _listing, unsigned _ind) noexcept;
    operator                                bool()              const noexcept;
    const std::shared_ptr<const Listing>&   Listing()           const noexcept;
    unsigned                                Index()             const noexcept;
    
    std::string         Path()          const;
    const VFSHostPtr&   Host()          const;
    const std::string&  Directory()     const;
    
    // currently mimicking old VFSListingItem interface, may change methods names later
    const std::string&  Filename()      const;
    const char     *FilenameC()         const;
    size_t          FilenameLen()       const;
    CFStringRef     FilenameCF()        const;
#ifdef __OBJC__
    NSString*       FilenameNS()        const;
#endif

    bool            HasDisplayName()    const;
    const std::string&  DisplayName()   const;
    CFStringRef     DisplayNameCF()     const;
#ifdef __OBJC__
    NSString*       DisplayNameNS()     const;
#endif

    bool            HasExtension()      const;
    uint16_t        ExtensionOffset()   const;
    const char*     Extension()         const; // unguarded calls whout HasExtension will yeild a whole filename as a result
    const char*     ExtensionIfAny()    const; // will return "" if there's no extension
    std::string     FilenameWithoutExt()const;
    
    mode_t          UnixMode()          const; // resolved for symlinks
    uint8_t         UnixType()          const; // type is _original_ directory entry, without symlinks resolving

    bool            HasSize()           const;
    uint64_t        Size()              const;

    bool            HasInode()          const;
    uint64_t        Inode()             const;

    bool            HasATime()          const;
    time_t          ATime()             const;

    bool            HasMTime()          const;
    time_t          MTime()             const;
    
    bool            HasCTime()          const;
    time_t          CTime()             const;

    bool            HasBTime()          const;
    time_t          BTime()             const;

    bool            HasAddTime()        const;
    time_t          AddTime()           const;
    
    bool            HasUnixFlags()      const;
    uint32_t        UnixFlags()         const;
    
    bool            HasUnixUID()        const;
    uid_t           UnixUID()           const;
    
    bool            HasUnixGID()        const;
    gid_t           UnixGID()           const;
    
    bool            HasSymlink()        const;
    const char     *Symlink()           const;
    
    bool            IsDir()             const;
    bool            IsReg()             const;
    bool            IsSymlink()         const;
    bool            IsDotDot()          const;
    bool            IsHidden()          const;
    
    bool operator ==(const ListingItem&_) const noexcept;
    bool operator !=(const ListingItem&_) const noexcept;
    
private:
    std::shared_ptr<const class Listing> L;
    unsigned                        I;
    friend Listing::iterator;
    friend WeakListingItem;
};

class WeakListingItem
{
public:
    WeakListingItem() noexcept;
    WeakListingItem(const ListingItem &_item) noexcept;
    WeakListingItem(const WeakListingItem &_item) noexcept;
    WeakListingItem(WeakListingItem &&_item) noexcept;
    
    const WeakListingItem& operator=( const ListingItem &_item ) noexcept;
    const WeakListingItem& operator=( const WeakListingItem &_item ) noexcept;
    const WeakListingItem& operator=( WeakListingItem &&_item ) noexcept;
    
    ListingItem Lock() const noexcept;
    
    bool operator ==(const WeakListingItem&) const noexcept;
    bool operator !=(const WeakListingItem&) const noexcept;
    bool operator ==(const ListingItem&) const noexcept;
    bool operator !=(const ListingItem&) const noexcept;
    
private:
    std::weak_ptr<const Listing>  L;
    unsigned                    I;
};

bool operator==(const ListingItem&_l, const WeakListingItem&_r) noexcept;
bool operator!=(const ListingItem&_l, const WeakListingItem&_r) noexcept;

class Listing::iterator
{
public:
    iterator &operator--() noexcept; // prefix decrement
    iterator &operator++() noexcept; // prefix increment
    iterator operator--(int) noexcept; // posfix decrement
    iterator operator++(int) noexcept; // posfix increment
    
    bool operator==(const iterator& _r) const noexcept;
    bool operator!=(const iterator& _r) const noexcept;
    const ListingItem& operator*() const noexcept;

private:
    ListingItem i;
    friend class Listing;
};

#define __CHECK_BOUNDS( a ) \
    if( (a) >= m_ItemsCount ) \
        throw std::out_of_range(std::string(__PRETTY_FUNCTION__) + ": index out of range");

inline bool Listing::HasExtension(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_ExtensionOffsets[_ind] != 0;
}

inline uint16_t Listing::ExtensionOffset(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_ExtensionOffsets[_ind];
}

inline const char *Listing::Extension(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_Filenames[_ind].c_str() + m_ExtensionOffsets[_ind];
}

inline const std::string& Listing::Filename(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_Filenames[_ind];
}

inline CFStringRef Listing::FilenameCF(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return *m_FilenamesCF[_ind];
}

inline std::string Listing::Path(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    if( !IsDotDot(_ind) )
        return m_Directories[_ind] + m_Filenames[_ind];
    else {
        std::string p = m_Directories[_ind];
        if( p.length() > 1 )
            p.pop_back();
        return p;
    }
}

inline std::string Listing::FilenameWithoutExt(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    if( m_ExtensionOffsets[_ind] == 0 )
        return m_Filenames[_ind];
    return m_Filenames[_ind].substr(0, m_ExtensionOffsets[_ind]-1);
}

inline const VFSHostPtr& Listing::Host() const
{
    if( HasCommonHost() )
        return m_Hosts[0];
    throw std::logic_error("Listing::Host() called for listing with no common host");
}

inline const VFSHostPtr& Listing::Host(unsigned _ind) const
{
    if( HasCommonHost() )
        return m_Hosts[0];
    else {
        __CHECK_BOUNDS(_ind);
        return m_Hosts[_ind];
    }
}

inline const std::string& Listing::Directory() const
{
    if( HasCommonDirectory() )
        return m_Directories[0];
    throw std::logic_error("Listing::Directory() called for listing with no common directory");
}

inline const std::string& Listing::Directory(unsigned _ind) const
{
    if( HasCommonDirectory() ) {
        return m_Directories[0];
    }
    else {
        __CHECK_BOUNDS(_ind);
        return m_Directories[_ind];
    }
}

inline unsigned Listing::Count() const noexcept
{
    return m_ItemsCount;
};

inline bool Listing::Empty() const noexcept
{
    return m_ItemsCount == 0;
}

inline bool Listing::IsUniform() const noexcept
{
    return HasCommonHost() && HasCommonDirectory();
}

inline bool Listing::HasCommonHost() const noexcept
{
    return m_Hosts.mode() == base::variable_container<>::type::common;
}

inline bool Listing::HasCommonDirectory() const noexcept
{
    return m_Directories.mode() == base::variable_container<>::type::common;
}

inline bool Listing::HasSize(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_Sizes.has(_ind);
}

inline uint64_t Listing::Size(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_Sizes.has(_ind) ? m_Sizes[_ind] : 0;
}

inline bool Listing::HasInode(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_Inodes.has(_ind);
}

inline uint64_t Listing::Inode(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_Inodes.has(_ind) ? m_Inodes[_ind] : 0;
}

inline bool Listing::HasATime(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_ATimes.has(_ind);
}

inline time_t Listing::ATime(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_ATimes.has(_ind) ? m_ATimes[_ind] : m_CreationTime;
}

inline bool Listing::HasMTime(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_MTimes.has(_ind);
}

inline time_t Listing::MTime(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_MTimes.has(_ind) ? m_MTimes[_ind] : m_CreationTime;
}

inline bool Listing::HasCTime(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_CTimes.has(_ind);
}

inline time_t Listing::CTime(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_CTimes.has(_ind) ? m_CTimes[_ind] : m_CreationTime;
}

inline bool Listing::HasBTime(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_BTimes.has(_ind);
}

inline time_t Listing::BTime(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_BTimes.has(_ind) ? m_BTimes[_ind] : m_CreationTime;
}

inline bool Listing::HasAddTime(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_AddTimes.has(_ind);
}

inline time_t Listing::AddTime(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_AddTimes.has(_ind) ? m_AddTimes[_ind] : BTime(_ind);
}

inline mode_t Listing::UnixMode(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_UnixModes[_ind];
}

inline uint8_t Listing::UnixType(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_UnixTypes[_ind];
}

inline bool Listing::HasUID(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_UIDS.has(_ind);
}

inline uid_t Listing::UID(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_UIDS.has(_ind) ? m_UIDS[_ind] : 0;
}

inline bool Listing::HasGID(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_GIDS.has(_ind);
}

inline gid_t Listing::GID(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_GIDS.has(_ind) ? m_GIDS[_ind] : 0;
}

inline bool Listing::HasUnixFlags(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_UnixFlags.has(_ind);
}

inline uint32_t Listing::UnixFlags(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_UnixFlags.has(_ind) ? m_UnixFlags[_ind] : 0;
}

inline bool Listing::HasSymlink(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_Symlinks.has(_ind);
}

inline const std::string& Listing::Symlink(unsigned _ind) const
{
    static const std::string st = "";
    __CHECK_BOUNDS(_ind);
    return m_Symlinks.has(_ind) ? m_Symlinks[_ind] : st;
}

inline bool Listing::HasDisplayFilename(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_DisplayFilenames.has(_ind);
}

inline const std::string& Listing::DisplayFilename(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_DisplayFilenames.has(_ind) ? m_DisplayFilenames[_ind] : Filename(_ind);
}

inline CFStringRef Listing::DisplayFilenameCF(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_DisplayFilenamesCF.has(_ind) ? *m_DisplayFilenamesCF[_ind] : FilenameCF(_ind);
}

inline bool Listing::IsDotDot(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    auto &s = m_Filenames[_ind];
    return s[0]=='.' && s[1] == '.' && s[2] == 0;
}

inline bool Listing::IsDir(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return (m_UnixModes[_ind] & m_S_IFMT) == m_S_IFDIR;
}

inline bool Listing::IsReg(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return (m_UnixModes[_ind] & m_S_IFMT) == m_S_IFREG;
}

inline bool Listing::IsSymlink(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_UnixTypes[_ind] == m_DT_LNK;
}

inline bool Listing::IsHidden(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return (Filename(_ind)[0] == '.' || (UnixFlags(_ind) & m_UF_HIDDEN)) && !IsDotDot(_ind);
}

inline ListingItem Listing::Item(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return ListingItem(shared_from_this(), _ind);
}

inline Listing::iterator Listing::begin() const noexcept
{
    iterator it;
    it.i = ListingItem(shared_from_this(), 0);
    return it;
}

inline Listing::iterator Listing::end() const noexcept
{
    iterator it;
    it.i = ListingItem(shared_from_this(), m_ItemsCount);
    return it;
}

#undef __CHECK_BOUNDS
    
inline ListingItem::ListingItem() noexcept:
    L( nullptr ),
    I( std::numeric_limits<unsigned>::max() )
{
}

inline ListingItem::ListingItem
    (const std::shared_ptr<const class Listing>& _listing, unsigned _ind) noexcept:
    L(_listing),
    I(_ind)
{
}

inline ListingItem::operator bool() const noexcept
{
    return (bool)L;
}

inline const std::shared_ptr<const Listing>& ListingItem::Listing() const noexcept
{
    return L;
}

inline unsigned ListingItem::Index() const noexcept
{
    return I;
}

inline std::string ListingItem::Path() const
{
    return L->Path(I);
}

inline const VFSHostPtr& ListingItem::Host() const
{
    return L->Host(I);
}

inline const std::string& ListingItem::Directory() const
{
    return L->Directory(I);
}

inline const std::string& ListingItem::Filename() const
{
    return L->Filename(I);
}

inline const char *ListingItem::FilenameC() const
{
    return L->Filename(I).c_str();
}

inline size_t ListingItem::FilenameLen() const
{
    return L->Filename(I).length();
}

inline CFStringRef ListingItem::FilenameCF() const
{
    return L->FilenameCF(I);
}

inline bool ListingItem::HasDisplayName() const
{
    return L->HasDisplayFilename(I);
}

inline const std::string& ListingItem::DisplayName() const
{
    return L->DisplayFilename(I);
}

inline CFStringRef ListingItem::DisplayNameCF() const
{
    return L->DisplayFilenameCF(I);
}

inline bool ListingItem::HasExtension() const
{
    return L->HasExtension(I);
}

inline uint16_t ListingItem::ExtensionOffset() const
{
    return L->ExtensionOffset(I);
}

inline const char* ListingItem::Extension() const
{
    return L->Extension(I);
}

inline const char* ListingItem::ExtensionIfAny() const
{
    return HasExtension() ? Extension() : "";
}

inline std::string ListingItem::FilenameWithoutExt() const
{
    return L->FilenameWithoutExt(I);
}

inline mode_t ListingItem::UnixMode() const
{
    return L->UnixMode(I);
}

inline uint8_t ListingItem::UnixType() const
{
    return L->UnixType(I);
}

inline bool ListingItem::HasSize() const
{
    return L->HasSize(I);
}

inline uint64_t ListingItem::Size() const
{
    return L->Size(I);
}

inline bool ListingItem::HasInode() const
{
    return L->HasInode(I);
}

inline uint64_t ListingItem::Inode() const
{
    return L->Inode(I);
}

inline bool ListingItem::HasATime() const
{
    return L->HasATime(I);
}

inline time_t ListingItem::ATime() const
{
    return L->ATime(I);
}

inline bool ListingItem::HasMTime() const
{
    return L->HasMTime(I);
}

inline time_t ListingItem::MTime() const
{
    return L->MTime(I);
}

inline bool ListingItem::HasCTime() const
{
    return L->HasCTime(I);
}

inline time_t ListingItem::CTime() const
{
    return L->CTime(I);
}

inline bool ListingItem::HasBTime() const
{
    return L->HasBTime(I);
}

inline time_t ListingItem::BTime() const
{
    return L->BTime(I);
}

inline bool ListingItem::HasAddTime() const
{
    return L->HasAddTime(I);
}

inline time_t ListingItem::AddTime() const
{
    return L->AddTime(I);
}

inline bool ListingItem::HasUnixFlags() const
{
    return L->HasUnixFlags(I);
}

inline uint32_t ListingItem::UnixFlags() const
{
    return L->UnixFlags(I);
}

inline bool ListingItem::HasUnixUID() const
{
    return L->HasUID(I);
}

inline uid_t ListingItem::UnixUID() const
{
    return L->UID(I);
}

inline bool ListingItem::HasUnixGID() const
{
    return L->HasGID(I);
}

inline gid_t ListingItem::UnixGID() const
{
    return L->GID(I);
}

inline bool ListingItem::HasSymlink() const
{
    return L->HasSymlink(I);
}

inline const char *ListingItem::Symlink() const
{
    return L->Symlink(I).c_str();
}

inline bool ListingItem::IsDir() const
{
    return L->IsDir(I);
}

inline bool ListingItem::IsReg() const
{
    return L->IsReg(I);
}

inline bool ListingItem::IsSymlink() const
{
    return L->IsSymlink(I);
}

inline bool ListingItem::IsDotDot() const
{
    return L->IsDotDot(I);
}

inline bool ListingItem::IsHidden() const
{
    return L->IsHidden(I);
}

inline bool ListingItem::operator ==(const ListingItem&_) const noexcept
{
    return I == _.I && L == _.L;
}

inline bool ListingItem::operator !=(const ListingItem&_) const noexcept
{
    return I != _.I || L != _.L;
}

inline WeakListingItem::WeakListingItem() noexcept
{
}

inline WeakListingItem::WeakListingItem(const ListingItem &_item) noexcept:
    L(_item.L),
    I(_item.I)
{
}

inline WeakListingItem::WeakListingItem(const WeakListingItem &_item) noexcept:
    L(_item.L),
    I(_item.I)
{
}

inline WeakListingItem::WeakListingItem(WeakListingItem &&_item) noexcept:
    L( move(_item.L) ),
    I( _item.I )
{
}

inline const WeakListingItem& WeakListingItem::operator=( const ListingItem &_item ) noexcept
{
    L = _item.L;
    I = _item.I;
    return *this;
}

inline const WeakListingItem& WeakListingItem::operator=( const WeakListingItem &_item ) noexcept
{
    L = _item.L;
    I = _item.I;
    return *this;
}

inline const WeakListingItem& WeakListingItem::operator=( WeakListingItem &&_item ) noexcept
{
    L = move(_item.L);
    I = _item.I;
    return *this;
}

inline ListingItem WeakListingItem::Lock() const noexcept
{
    return { L.lock(), I };
}

inline bool WeakListingItem::operator ==(const WeakListingItem&_) const noexcept
{
    return I == _.I && !L.owner_before(_.L) && !_.L.owner_before(L);
}

inline bool WeakListingItem::operator !=(const WeakListingItem&_) const noexcept
{
    return !(*this == _);
}

inline bool WeakListingItem::operator ==(const ListingItem&_) const noexcept
{
    return I == _.I && !L.owner_before(_.L) && !_.L.owner_before(L);
}

inline bool WeakListingItem::operator !=(const ListingItem&_) const noexcept
{
    return !(*this == _);
}

inline bool operator==(const ListingItem&_l, const WeakListingItem&_r) noexcept
{
    return _r == _l;
}

inline bool operator!=(const ListingItem&_l, const WeakListingItem&_r) noexcept
{
    return !(_r == _l);
}

inline Listing::iterator &Listing::iterator::operator--() noexcept // prefix decrement
{
    i.I--;
    return *this;
}

inline Listing::iterator &Listing::iterator::operator++() noexcept // prefix increment
{
    i.I++;
    return *this;
}
    
inline Listing::iterator Listing::iterator::operator--(int) noexcept // posfix decrement
{
    auto p = *this;
    i.I--;
    return p;
}

inline Listing::iterator Listing::iterator::operator++(int) noexcept // posfix increment
{
    auto p = *this;
    i.I++;
    return p;
}
    
inline bool Listing::iterator::operator==(const iterator& _r) const noexcept
{
    return i.I == _r.i.I && i.L == _r.i.L;
}

inline bool Listing::iterator::operator!=(const iterator& _r) const noexcept
{
    return !(*this == _r);
}

inline const ListingItem& Listing::iterator::operator*() const noexcept
{
    return i;
}    

};

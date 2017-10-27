// Copyright (C) 2015-2017 Michael Kazakov. Subject to GNU General Public License version 3.
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

class Listing : public enable_shared_from_this<Listing>
{
public:
    static const VFSListingPtr &EmptyListing() noexcept;
    static VFSListingPtr    Build(ListingInput &&_input);
    
    /**
     * compose many listings into a new ListingInput.
     * it will contain only sparse-based variable containers.
     * will throw on errors
     */
    static ListingInput Compose(const vector<shared_ptr<Listing>> &_listings);
    static ListingInput Compose(const vector<shared_ptr<Listing>> &_listings,
                                const vector< vector<unsigned> > &_items_indeces);
    
    
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

    const string&       Directory           () const; // will throw if there's no common directory
    const string&       Directory           (unsigned _ind) const;
    const VFSHostPtr&   Host                () const; // will throw if there's no common host
    const VFSHostPtr&   Host                (unsigned _ind) const;
    
    /**
     * Compose a path to specified listing item. Is case of ".." item will directory path itself.
     */
    string              Path                (unsigned _ind) const;
    
    const string&       Filename            (unsigned _ind) const;
    CFStringRef         FilenameCF          (unsigned _ind) const;
#ifdef __OBJC__
    NSString*           FilenameNS          (unsigned _ind) const;
#endif

    mode_t              UnixMode            (unsigned _ind) const;
    uint8_t             UnixType            (unsigned _ind) const;
    
    bool                HasExtension        (unsigned _ind) const;
    uint16_t            ExtensionOffset     (unsigned _ind) const;
    const char*         Extension           (unsigned _ind) const;
    
    string              FilenameWithoutExt  (unsigned _ind) const;
    
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
    const string&       Symlink             (unsigned _ind) const;
    
    bool                HasDisplayFilename  (unsigned _ind) const;
    const string&       DisplayFilename     (unsigned _ind) const;
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
    Listing();
    ~Listing();
    static shared_ptr<Listing> Alloc(); // fighting against c++...
    void BuildFilenames();    
    
    unsigned                        m_ItemsCount;
    time_t                          m_CreationTime;
    variable_container<VFSHostPtr>  m_Hosts;
    variable_container<string>      m_Directories;
    vector<string>                  m_Filenames;
    vector<CFString>                m_FilenamesCF;
    vector<uint16_t>                m_ExtensionOffsets;
    vector<mode_t>                  m_UnixModes;
    vector<uint8_t>                 m_UnixTypes;
    variable_container<uint64_t>    m_Sizes;
    variable_container<uint64_t>    m_Inodes;
    variable_container<time_t>      m_ATimes;
    variable_container<time_t>      m_MTimes;
    variable_container<time_t>      m_CTimes;
    variable_container<time_t>      m_BTimes;
    variable_container<time_t>      m_AddTimes;
    variable_container<uid_t>       m_UIDS;
    variable_container<gid_t>       m_GIDS;
    variable_container<uint32_t>    m_UnixFlags;
    variable_container<string>      m_Symlinks;
    variable_container<string>      m_DisplayFilenames;
    variable_container<CFString>    m_DisplayFilenamesCF;
};

// ListingItem class is a simple wrapper around (pointer;index) pair for object-oriented access to listing items with value semantics.
class ListingItem
{
public:
    ListingItem() noexcept;
    ListingItem(const shared_ptr<const Listing>& _listing, unsigned _ind) noexcept;
    operator                                bool()              const noexcept;
    const shared_ptr<const Listing>&        Listing()           const noexcept;
    unsigned                                Index()             const noexcept;
    
    string          Path()              const;
    const VFSHostPtr& Host()            const;
    const string&   Directory()         const;
    
    // currently mimicking old VFSListingItem interface, may change methods names later
    const string&   Filename()          const;
    const char     *FilenameC()         const;
    size_t          FilenameLen()       const;
    CFStringRef     FilenameCF()        const;
#ifdef __OBJC__
    NSString*       FilenameNS()        const;
#endif

    bool            HasDisplayName()    const;
    const string&   DisplayName()       const;
    CFStringRef     DisplayNameCF()     const;
#ifdef __OBJC__
    NSString*       DisplayNameNS()     const;
#endif

    bool            HasExtension()      const;
    uint16_t        ExtensionOffset()   const;
    const char*     Extension()         const; // unguarded calls whout HasExtension will yeild a whole filename as a result
    const char*     ExtensionIfAny()    const; // will return "" if there's no extension
    string          FilenameWithoutExt()const;
    
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
    shared_ptr<const class Listing> L;
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
    weak_ptr<const Listing>  L;
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

};

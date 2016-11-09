//
//  VFSListing.h
//  Files
//
//  Created by Michael G. Kazakov on 03/09/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include <Habanero/variable_container.h>
#include <Habanero/CFString.h>
#include "VFSDeclarations.h"

struct VFSListingInput;
class VFSListingItem;
class VFSWeakListingItem;

class VFSListing : public enable_shared_from_this<VFSListing>
{
public:
    static VFSListingPtr    EmptyListing();
    static VFSListingPtr    Build(VFSListingInput &&_input);
    
    /**
     * compose many listings into a new ListingInput.
     * it will contain only sparse-based variable containers.
     * will throw on errors
     */
    static VFSListingInput Compose(const vector<shared_ptr<VFSListing>> &_listings, const vector< vector<unsigned> > &_items_indeces);
    
    
    static VFSListingPtr ProduceUpdatedTemporaryPanelListing( const VFSListing& _original, VFSCancelChecker _cancel_checker );
    
    /**
     * Returns items amount in this listing. 
     */
    unsigned            Count               () const noexcept;
    bool                IsUniform           () const noexcept;
    bool                HasCommonHost       () const noexcept;
    bool                HasCommonDirectory  () const noexcept;

    VFSListingItem     Item                 (unsigned _ind) const;

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
    NSString*           FilenameNS          (unsigned _ind) const { return (__bridge NSString*)FilenameCF(_ind); }
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
    inline NSString*    DisplayFilenameNS   (unsigned _ind) const { return (__bridge NSString*)DisplayFilenameCF(_ind); }
#endif
    
    bool                IsDotDot            (unsigned _ind) const;
    bool                IsDir               (unsigned _ind) const;
    bool                IsReg               (unsigned _ind) const;
    bool                IsSymlink           (unsigned _ind) const;
    bool                IsHidden            (unsigned _ind) const;
    
    struct iterator;
    iterator            begin               () const noexcept;
    iterator            end                 () const noexcept;
    
private:
    VFSListing();
    static shared_ptr<VFSListing> Alloc(); // fighting against c++...
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

// VFSListingItem class is a simple wrapper around (pointer;index) pair for object-oriented access to listing items with value semantics.
class VFSListingItem
{
public:
    VFSListingItem() noexcept;
    VFSListingItem(const shared_ptr<const VFSListing>& _listing, unsigned _ind) noexcept;
    operator                                bool()              const noexcept;
    const shared_ptr<const VFSListing>&     Listing()           const noexcept;
    unsigned                                Index()             const noexcept;
    
    string          Path()              const;
    const VFSHostPtr& Host()            const;
    const string&   Directory()         const;
    
    // currently mimicking old VFSListingItem interface, may change methods names later
    const string&   Filename()          const;
    const char     *Name()              const;
    size_t          NameLen()           const;
    CFStringRef     CFName()            const;
#ifdef __OBJC__
    NSString*       NSName()            const { return L->FilenameNS(I);            }
#endif

    bool            HasDisplayName()    const;
    const string&   DisplayName()       const;
    CFStringRef     CFDisplayName()     const;
#ifdef __OBJC__
    NSString*       NSDisplayName()     const { return L->DisplayFilenameNS(I);     }
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
    
    bool operator ==(const VFSListingItem&_) const noexcept;
    bool operator !=(const VFSListingItem&_) const noexcept;
    
private:
    shared_ptr<const VFSListing>    L;
    unsigned                        I;
    friend VFSListing::iterator;
    friend VFSWeakListingItem;
};

class VFSWeakListingItem
{
public:
    VFSWeakListingItem() noexcept;
    VFSWeakListingItem(const VFSListingItem &_item) noexcept;
    VFSWeakListingItem(const VFSWeakListingItem &_item) noexcept;
    VFSWeakListingItem(VFSWeakListingItem &&_item) noexcept;
    
    const VFSWeakListingItem& operator=( const VFSListingItem &_item ) noexcept;
    const VFSWeakListingItem& operator=( const VFSWeakListingItem &_item ) noexcept;
    const VFSWeakListingItem& operator=( VFSWeakListingItem &&_item ) noexcept;
    
    VFSListingItem Lock() const noexcept;
    
    bool operator ==(const VFSWeakListingItem&) const noexcept;
    bool operator !=(const VFSWeakListingItem&) const noexcept;
    bool operator ==(const VFSListingItem&) const noexcept;
    bool operator !=(const VFSListingItem&) const noexcept;
    
private:
    weak_ptr<const VFSListing>  L;
    unsigned                    I;
};

bool operator==(const VFSListingItem&_l, const VFSWeakListingItem&_r) noexcept;
bool operator!=(const VFSListingItem&_l, const VFSWeakListingItem&_r) noexcept;

struct VFSListing::iterator
{
    iterator &operator--() noexcept; // prefix decrement
    iterator &operator++() noexcept; // prefix increment
    iterator operator--(int) noexcept; // posfix decrement
    iterator operator++(int) noexcept; // posfix increment
    
    bool operator==(const iterator& _r) const noexcept;
    bool operator!=(const iterator& _r) const noexcept;
    const VFSListingItem& operator*() const noexcept;

private:
    VFSListingItem i;
    friend class VFSListing;
};

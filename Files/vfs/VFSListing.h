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
    
    unsigned            Count               () const noexcept { return m_ItemsCount; };
    bool                IsUniform           () const;
    bool                HasCommonHost       () const;
    bool                HasCommonDirectory  () const;

    VFSListingItem     Item                (unsigned _ind) const;

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
    VFSListingItem() noexcept:
        I( numeric_limits<unsigned>::max() ),
        L( nullptr ) {}
    VFSListingItem(const shared_ptr<const VFSListing>& _listing, unsigned _ind) noexcept:
        I(_ind),
        L(_listing) {}
    operator        bool()              const noexcept { return (bool)L;            }
    auto&           Listing()           const noexcept { return L;                  }
    unsigned        Index()             const noexcept { return I;                  }
    
    string          Path()              const { return L->Path(I);                  }
    const VFSHostPtr& Host()            const { return L->Host(I);                  }
    const string&   Directory()         const { return L->Directory(I);             }
    
    // currently mimicking old VFSListingItem interface, may change methods names later
    const string&   Filename()          const { return L->Filename(I);              }
    const char     *Name()              const { return L->Filename(I).c_str();      }
    size_t          NameLen()           const { return L->Filename(I).length();     }
    CFStringRef     CFName()            const { return L->FilenameCF(I);            }
#ifdef __OBJC__
    NSString*       NSName()            const { return L->FilenameNS(I);            }
#endif

    bool            HasDisplayName()    const { return L->HasDisplayFilename(I);    }
    CFStringRef     CFDisplayName()     const { return L->DisplayFilenameCF(I);     }
#ifdef __OBJC__
    NSString*       NSDisplayName()     const { return L->DisplayFilenameNS(I);     }
#endif

    bool            HasExtension()      const { return L->HasExtension(I);          }
    uint16_t        ExtensionOffset()   const { return L->ExtensionOffset(I);       }
    const char*     Extension()         const { return L->Extension(I);             }
    string          FilenameWithoutExt()const { return L->FilenameWithoutExt(I);    }
    
    mode_t          UnixMode()          const { return L->UnixMode(I);              } // resolved for symlinks
    uint8_t         UnixType()          const { return L->UnixType(I);              } // type is _original_ directory entry, without symlinks resolving

    bool            HasSize()           const { return L->HasSize(I);               }
    uint64_t        Size()              const { return L->Size(I);                  }

    bool            HasInode()          const { return L->HasInode(I);              }
    uint64_t        Inode()             const { return L->Inode(I);                 }

    bool            HasATime()          const { return L->HasATime(I);              }
    time_t          ATime()             const { return L->ATime(I);                 }

    bool            HasMTime()          const { return L->HasMTime(I);              }
    time_t          MTime()             const { return L->MTime(I);                 }
    
    bool            HasCTime()          const { return L->HasCTime(I);              }
    time_t          CTime()             const { return L->CTime(I);                 }

    bool            HasBTime()          const { return L->HasBTime(I);              }
    time_t          BTime()             const { return L->BTime(I);                 }
    
    bool            HasUnixFlags()      const { return L->HasUnixFlags(I);          }
    uint32_t        UnixFlags()         const { return L->UnixFlags(I);             }
    
    bool            HasUnixUID()        const { return L->HasUID(I);                }
    uid_t           UnixUID()           const { return L->UID(I);                   }
    
    bool            HasUnixGID()        const { return L->HasGID(I);                }
    gid_t           UnixGID()           const { return L->GID(I);                   }
    
    bool            HasSymlink()        const { return L->HasSymlink(I);            }
    const char     *Symlink()           const { return L->Symlink(I).c_str();       }
    
    bool            IsDir()             const { return L->IsDir(I);                 }
    bool            IsReg()             const { return L->IsReg(I);                 }
    bool            IsSymlink()         const { return L->IsSymlink(I);             }
    bool            IsDotDot()          const { return L->IsDotDot(I);              }
    bool            IsHidden()          const { return L->IsHidden(I);              }
    
    bool operator ==(const VFSListingItem&_) const noexcept { return I == _.I && L == _.L; }
    bool operator !=(const VFSListingItem&_) const noexcept { return I != _.I || L != _.L; }
    
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

inline bool operator==(const VFSListingItem&_l, const VFSWeakListingItem&_r) noexcept { return   _r == _l ; }
inline bool operator!=(const VFSListingItem&_l, const VFSWeakListingItem&_r) noexcept { return !(_r == _l); }

struct VFSListing::iterator
{
    iterator &operator--() noexcept { i.I--; return *this; } // prefix decrement
    iterator &operator++() noexcept { i.I++; return *this; } // prefix increment
    iterator operator--(int) noexcept { auto p = *this; i.I--; return p; } // posfix decrement
    iterator operator++(int) noexcept { auto p = *this; i.I++; return p; } // posfix increment
    
    bool operator==(const iterator& _r) const noexcept { return i.I == _r.i.I && i.L == _r.i.L; }
    bool operator!=(const iterator& _r) const noexcept { return !(*this == _r); }
    const VFSListingItem& operator*() const noexcept { return i; }

private:
    VFSListingItem i;
    friend class VFSListing;
};

//
//  VFSFlexibleListing.h
//  Files
//
//  Created by Michael G. Kazakov on 03/09/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include <Habanero/variable_container.h>
#include <Habanero/CFString.h>
#include "VFSDeclarations.h"

struct VFSFlexibleListingInput
{

    /**
     * host for file.
     * can be common or dense. On sparse will throw an extension (every filename should have it's host).
     * this will extenend host's lifetime till any corresponding listings are alive.
     */
    variable_container<VFSHostPtr>  hosts;
    
    /**
     * directory path for filename. should contain a trailing slash (and thus be non-empty).
     * can be common or dense. On sparse will throw an exception (every filename should have it's directory).
     */
    variable_container<string>      directories;
    
    /**
     * required for every element and is a cornerstone by which decisions are made within Listing itself.
     * filename can't be empty
     */
    vector<string>                  filenames;
    
    /**
     * used for HFS+, can be localized.
     * can be dense or sparse. on common size will throw an exception.
     */
    variable_container<string>      display_filenames{variable_container<>::type::sparse};
    
    /**
     * can be dense or sparse. on common size will throw an exception
     */
    variable_container<uint64_t>    sizes{variable_container<>::type::sparse};
    
    /**
     * can be dense or sparse. on common size will throw an exception
     */
    variable_container<uint64_t>    inodes{variable_container<>::type::sparse};

    /**
     * can be dense, sparse or common.
     * if client ask for an item's time with no such information - listing will return it's creation time.
     */
    variable_container<time_t>      atimes;
    variable_container<time_t>      mtimes;
    variable_container<time_t>      ctimes;
    variable_container<time_t>      btimes;
    
    /**
     * unix modes should be present for every item in listing.
     * for symlinks should contain target's modes (a-la with stat(), not lstat()).
     */
    vector<mode_t>                  unix_modes;
    
    /**
     * type is an original directory entry, without symlinks resolving. Like .d_type in readdir().
     */
    vector<uint8_t>                 unix_types;
    
    /**
     * can be dense, sparse or common.
     */
    variable_container<uid_t>       uids;
    variable_container<gid_t>       gids;
    
    /**
     * st_flags field from stat, see chflags(2).
     * can be dense, sparse or common.
     * if client ask for an item's flags with no such information - listing will return zero.
     */
    variable_container<uint32_t>    unix_flags;
 
    /**
     * symlink values for such directory entries.
     * can be sparse or dense. on common type will throw an exception.
     */
    variable_container<string>      symlinks{variable_container<>::type::sparse};
    
    
};

class VFSFlexibleListing : public enable_shared_from_this<VFSFlexibleListing>
{
public:
    static shared_ptr<VFSFlexibleListing> Build(VFSFlexibleListingInput &&_input);
    
    unsigned            Count               () const;
    bool                HasCommonHost       () const;
    bool                HasCommonDirectory  () const;
    
    
    const string&       Directory           (unsigned _ind) const;
    const VFSHostPtr&   Host                (unsigned _ind) const;
    
    const string&       Filename            (unsigned _ind) const;
    CFStringRef         FilenameCF          (unsigned _ind) const;
#ifdef __OBJC__
    inline NSString*    FilenameNS          (unsigned _ind) const { return (__bridge NSString*)FilenameCF(_ind); }
#endif

    mode_t              UnixMode            (unsigned _ind) const;
    uint8_t             UnixType            (unsigned _ind) const;
    
    bool                HasExtension        (unsigned _ind) const;
    uint16_t            ExtensionOffset     (unsigned _ind) const;
    const char*         Extension           (unsigned _ind) const;
    
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
    
private:
    VFSFlexibleListing();
    static shared_ptr<VFSFlexibleListing> Alloc(); // fighting against c++...
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


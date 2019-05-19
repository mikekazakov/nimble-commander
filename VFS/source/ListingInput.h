// Copyright (C) 2016-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Habanero/variable_container.h>
#include "../include/VFS/VFSDeclarations.h"
#include <sys/types.h>

namespace nc::vfs {

struct ListingInput
{
    
    /**
     * host for file.
     * can be common or dense. On sparse will throw an extension (every filename should have it's host).
     * this will extenend host's lifetime till any corresponding listings are alive.
     */
    base::variable_container<VFSHostPtr>  hosts{base::variable_container<>::type::common};
    
    /**
     * directory path for filename. should contain a trailing slash (and thus be non-empty).
     * can be common or dense. On sparse will throw an exception (every filename should have it's directory).
     */
    base::variable_container<std::string> directories{base::variable_container<>::type::common};
    
    /**
     * required for every element and is a cornerstone by which decisions are made within Listing itself.
     * filename can't be empty
     */
    std::vector<std::string>        filenames;
    
    /**
     * used for HFS+, can be localized.
     * can be dense or sparse. on common size will throw an exception.
     */
    base::variable_container<std::string> display_filenames{base::variable_container<>::type::sparse};
    
    /**
     * can be dense or sparse. on common size will throw an exception.
     * client can treat entries with value of undefined_size as an ebsent ones (useful for dirs).
     */
    base::variable_container<uint64_t>    sizes{base::variable_container<>::type::sparse};
    enum {
        unknown_size = std::numeric_limits<uint64_t>::max()
    };
    
    /**
     * can be dense or sparse. on common size will throw an exception
     */
    base::variable_container<uint64_t>    inodes{base::variable_container<>::type::sparse};
    
    /**
     * can be dense, sparse or common.
     * if client ask for an item's time with no such information - listing will return it's creation time.
     */
    base::variable_container<time_t>      atimes{base::variable_container<>::type::common};
    base::variable_container<time_t>      mtimes{base::variable_container<>::type::common};
    base::variable_container<time_t>      ctimes{base::variable_container<>::type::common};
    base::variable_container<time_t>      btimes{base::variable_container<>::type::common};
    base::variable_container<time_t>      add_times{base::variable_container<>::type::sparse};
    
    /**
     * unix modes should be present for every item in listing.
     * for symlinks should contain target's modes (a-la with stat(), not lstat()).
     */
    std::vector<mode_t>             unix_modes;
    
    /**
     * type is an original directory entry, without symlinks resolving. Like .d_type in readdir().
     */
    std::vector<uint8_t>            unix_types;
    
    /**
     * can be dense, sparse or common.
     */
    base::variable_container<uid_t>       uids{base::variable_container<>::type::sparse};
    base::variable_container<gid_t>       gids{base::variable_container<>::type::sparse};
    
    /**
     * st_flags field from stat, see chflags(2).
     * can be dense, sparse or common.
     * if client ask for an item's flags with no such information - listing will return zero.
     */
    base::variable_container<uint32_t>    unix_flags{base::variable_container<>::type::sparse};
    
    /**
     * symlink values for such directory entries.
     * can be sparse or dense. on common type will throw an exception.
     */
    base::variable_container<std::string> symlinks{base::variable_container<>::type::sparse};
};

}

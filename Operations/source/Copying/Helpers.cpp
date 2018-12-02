// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Helpers.h"

namespace nc::ops::copying {

std::string FindNonExistingItemPath(const std::string &_orig_existing_path,
                                    VFSHost &_host,
                                    const VFSCancelChecker &_cancel_checker)
{    
    const auto [epilog, prologue] = [&]{
        const auto p = boost::filesystem::path{_orig_existing_path}; 
        if( p.has_extension() ) {        
            return std::make_pair((p.parent_path() / p.stem()).native() + " ",
                                  p.extension().native());
        }
        else {
            return std::make_pair(_orig_existing_path + " ", std::string{});
        }
    }();
        
    for( int check_index = 2; /*noop*/; ++check_index) {
        if( _cancel_checker && _cancel_checker() )
            return "";
        auto path = epilog + std::to_string(check_index) + prologue;
        if( _host.Exists(path.c_str(), _cancel_checker) == false ) {
            if( _cancel_checker && _cancel_checker() )
                return "";
            return path;
        }
    }
}

}

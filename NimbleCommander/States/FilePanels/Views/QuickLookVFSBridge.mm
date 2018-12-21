// Copyright (C) 2013-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "QuickLookVFSBridge.h"
#include <NimbleCommander/Core/TemporaryNativeFileStorage.h>
#include <Utility/StringExtras.h>

namespace nc::panel {

static const uint64_t g_MaxSize = 64*1024*1024; // 64mb
    
NSURL *QuickLookVFSBridge::FetchItem( const std::string& _path, VFSHost &_host )
{
    auto &storage = TemporaryNativeFileStorage::Instance();
    const auto is_dir = _host.IsDirectory(_path.c_str(), 0);
    
    if( !is_dir ) {
        VFSStat st;
        if(_host.Stat(_path.c_str(), st, 0, 0) < 0)
            return nil;
        if(st.size > g_MaxSize)
            return nil;
        
        const auto copied_path = storage.CopySingleFile(_path, _host);
        if( !copied_path )
            return nil;
        
        const auto ns_copied_path = [NSString stringWithUTF8StdString:*copied_path];
        if( !ns_copied_path )
            return nil;
        
        return [NSURL fileURLWithPath:ns_copied_path];
    }
    else {
        // basic check that directory looks like a bundle
        if( !boost::filesystem::path(_path).has_extension() ||
            boost::filesystem::path(_path).filename() == boost::filesystem::path(_path).extension() )
            return nil;
        
        std::string copied_path;
        if( !storage.CopyDirectory(_path, _host.shared_from_this(), g_MaxSize, nullptr, copied_path) )
            return nil;
        
        const auto ns_copied_path = [NSString stringWithUTF8StdString:copied_path];
        return [NSURL fileURLWithPath:ns_copied_path];
    }
}

}

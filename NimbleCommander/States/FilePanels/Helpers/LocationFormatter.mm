// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "LocationFormatter.h"
#include "../ListingPromise.h"
#include <compose_visitors.hpp>
#include <VFS/Native.h>
#include <NimbleCommander/Core/NetworkConnectionIconProvider.h>

namespace nc::panel::loc_fmt {

static const auto g_IconSize = NSMakeSize(16, 16);
    
static NSImage *ImageForPromiseAndPath(const VFSInstanceManager::Promise &_promise,
                                       const string& _path );
    
ListingPromiseFormatter::Representation
ListingPromiseFormatter::Render( RenderOptions _options, const ListingPromise &_promise )
{
    Representation rep;
    
    const auto visitor = compose_visitors
    (
     [&](const ListingPromise::UniformListing &l) {
         if( _options & RenderMenuTitle ) {
             const auto title = l.promise.verbose_title() + l.directory;
             rep.menu_title = [NSString stringWithUTF8StdString:title];
         }
         if( _options & RenderMenuIcon )
             rep.menu_icon = ImageForPromiseAndPath(l.promise, l.directory);
     },
     [&](const ListingPromise::NonUniformListing &l)
     {
         if( _options & RenderMenuTitle ) {
             static const auto formatter = []{
                 auto fmt = [[NSNumberFormatter alloc] init];
                 fmt.usesGroupingSeparator = true;
                 fmt.groupingSize = 3;
                 return fmt;
             }();
             
             const auto count = [NSNumber numberWithUnsignedInteger:l.EntriesCount()];
             rep.menu_title = [NSString stringWithFormat:@"Temporary Panel (%@)",
                               [formatter stringFromNumber:count]];
         }
     }
     );
    boost::apply_visitor(visitor, _promise.Description());

    return rep;
}

static NSImage *ImageForPromiseAndPath(const VFSInstanceManager::Promise &_promise,
                                       const string& _path )
{
    if( _promise.tag() == VFSNativeHost::UniqueTag ) {
        static const auto workspace = NSWorkspace.sharedWorkspace;
        if( auto image = [workspace iconForFile:[NSString stringWithUTF8StdString:_path]] ) {
            image.size = g_IconSize;
            return image;
        }
    }
    
    if( auto image = NetworkConnectionIconProvider{}.Icon16px(_promise) )
        return image;
    
    static const auto fallback = []{
        auto image = [NSImage imageNamed:NSImageNameFolder];
        image.size = g_IconSize;
        return image;
    }();
    return fallback;
}
    
}

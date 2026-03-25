// Copyright (C) 2016-2026 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelViewHeaderPathBarBreadcrumbs.h"

#include <Foundation/Foundation.h>

namespace nc::panel {

[[nodiscard]] std::vector<PanelHeaderBreadcrumb>
BuildPanelHeaderBreadcrumbsFromPaths(const std::string &verbose_full,
                                     const std::string &dir_with_trailing_slash,
                                     const std::string &path_without_trailing_slash)
{
    std::vector<PanelHeaderBreadcrumb> out;
    if( verbose_full.empty() )
        return out;

    // Must match VerboseDirectoryFullPath(), which appends '/' when Directory() omits it.
    std::string dir_slash = dir_with_trailing_slash;
    if( dir_slash.empty() )
        return out;
    if( dir_slash.back() != '/' )
        dir_slash += '/';
    if( verbose_full.size() < dir_slash.size() )
        return out;
    if( verbose_full.compare(verbose_full.size() - dir_slash.size(), dir_slash.size(), dir_slash) != 0 )
        return out;

    std::string junction = verbose_full.substr(0, verbose_full.size() - dir_slash.size());
    while( !junction.empty() && junction.back() == '/' )
        junction.pop_back();

    const std::string &path_only = path_without_trailing_slash;

    if( !junction.empty() ) {
        PanelHeaderBreadcrumb j;
        j.label = [NSString stringWithUTF8String:junction.c_str()];
        j.navigate_to_vfs_path = "/";
        out.push_back(std::move(j));
    }

    if( path_only == "/" ) {
        if( junction.empty() ) {
            PanelHeaderBreadcrumb b;
            b.label = @"/";
            out.push_back(std::move(b));
        }
        return out;
    }

    if( path_only.empty() || path_only.front() != '/' )
        return out;

    if( junction.empty() ) {
        PanelHeaderBreadcrumb root;
        root.label = @"/";
        root.navigate_to_vfs_path = "/";
        out.push_back(std::move(root));
    }

    const std::string rest = path_only.substr(1);
    std::vector<std::string> comps;
    size_t start = 0;
    while( start <= rest.size() ) {
        const size_t slash = rest.find('/', start);
        if( slash == std::string::npos ) {
            if( start < rest.size() )
                comps.emplace_back(rest.substr(start));
            break;
        }
        if( slash > start )
            comps.emplace_back(rest.substr(start, slash - start));
        start = slash + 1;
    }

    std::string acc;
    for( size_t i = 0; i < comps.size(); ++i ) {
        acc += "/";
        acc += comps[i];
        PanelHeaderBreadcrumb b;
        b.label = [NSString stringWithUTF8String:comps[i].c_str()];
        if( i + 1 < comps.size() )
            b.navigate_to_vfs_path = acc;
        out.push_back(std::move(b));
    }
    return out;
}

} // namespace nc::panel


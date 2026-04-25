// Copyright (C) 2016-2026 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Panel/PathBar.h>
#include <Foundation/Foundation.h>

namespace nc::panel {

static void MarkCurrentDirectoryBreadcrumb(std::vector<PanelHeaderBreadcrumb> &breadcrumbs)
{
    if( !breadcrumbs.empty() )
        breadcrumbs.back().is_current_directory = true;
}

std::vector<PanelHeaderBreadcrumb> BuildPanelHeaderBreadcrumbs(const PanelPathContext &path_context)
{
    std::vector<PanelHeaderBreadcrumb> out;
    const std::string_view verbose_full = path_context.verbose_full_path;
    if( verbose_full.empty() )
        return out;

    // Must match VerboseDirectoryFullPath(), which appends '/' when Directory() omits it.
    // Normalize dir to always have a trailing slash for suffix matching.
    const std::string_view dir_raw = path_context.directory_path;
    if( dir_raw.empty() )
        return out;
    const bool dir_needs_slash = dir_raw.back() != '/';
    const std::string dir_slash_storage = dir_needs_slash ? std::string(dir_raw) + '/' : std::string{};
    const std::string_view dir_slash = dir_needs_slash ? std::string_view(dir_slash_storage) : dir_raw;

    if( verbose_full.size() < dir_slash.size() )
        return out;
    if( !verbose_full.ends_with(dir_slash) )
        return out;

    std::string_view junction = verbose_full.substr(0, verbose_full.size() - dir_slash.size());
    while( !junction.empty() && junction.back() == '/' )
        junction.remove_suffix(1);

    const std::string_view path_only = path_context.posix_path;

    if( !junction.empty() ) {
        PanelHeaderBreadcrumb j;
        j.label = [NSString stringWithUTF8String:std::string(junction).c_str()];
        j.navigate_to_vfs_path = "/";
        out.push_back(std::move(j));
    }

    if( path_only == "/" ) {
        if( junction.empty() ) {
            PanelHeaderBreadcrumb b;
            b.label = @"/";
            out.push_back(std::move(b));
        }
        MarkCurrentDirectoryBreadcrumb(out);
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

    // Walk path_only component by component using string_view slicing.
    std::string_view rest = path_only.substr(1);
    std::string acc = "/";
    while( !rest.empty() ) {
        const size_t slash = rest.find('/');
        const std::string_view comp = rest.substr(0, slash);
        if( !comp.empty() ) {
            acc += comp;
            PanelHeaderBreadcrumb b;
            b.label = [[NSString alloc] initWithBytes:comp.data()
                                               length:comp.size()
                                             encoding:NSUTF8StringEncoding];
            // Navigate link for all but the last component.
            const bool is_last = (slash == std::string_view::npos);
            if( !is_last )
                b.navigate_to_vfs_path = acc;
            out.push_back(std::move(b));
            acc += '/';
        }
        if( slash == std::string_view::npos )
            break;
        rest.remove_prefix(slash + 1);
    }
    MarkCurrentDirectoryBreadcrumb(out);
    return out;
}

std::string NormalizePanelHeaderPOSIXPathForActions(std::string_view path)
{
    if( path.empty() )
        return "/";
    std::string p;
    p.reserve(path.size() + 1);
    if( path.front() != '/' )
        p += '/';
    p += path;
    while( p.size() > 1 && p.back() == '/' )
        p.pop_back();
    return p;
}

std::optional<std::string> ResolvePanelBreadcrumbSegmentPOSIXForMenu(
    bool is_current_directory,
    const std::optional<std::string> &navigate_to_vfs_path,
    const std::optional<std::string> &fallback_posix_path,
    const std::optional<std::string> &plain_path)
{
    if( is_current_directory ) {
        if( fallback_posix_path.has_value() && !fallback_posix_path->empty() )
            return fallback_posix_path;
        return std::nullopt;
    }
    if( navigate_to_vfs_path.has_value() && !navigate_to_vfs_path->empty() )
        return navigate_to_vfs_path;
    if( fallback_posix_path.has_value() && !fallback_posix_path->empty() )
        return fallback_posix_path;
    return plain_path;
}

} // namespace nc::panel

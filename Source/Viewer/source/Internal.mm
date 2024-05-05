// Copyright (C) 2019-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Internal.h"
#include <Base/CommonPaths.h>
#include <cassert>

namespace nc::viewer {

NSBundle *Bundle() noexcept
{
    static NSBundle *const bundle = [] {
        const char *const rel_path = "Contents/Resources/ViewerResources.bundle";
        const std::string full_path = nc::base::CommonPaths::AppBundle() + rel_path;
        NSString *const ns_path = [NSString stringWithUTF8String:full_path.c_str()];
        return [NSBundle bundleWithPath:ns_path];
    }();
    assert(bundle != nil);
    return bundle;
}

NSString *NSLocalizedString(NSString *_key, [[maybe_unused]] const char *_comment) noexcept
{
    return [Bundle() localizedStringForKey:_key value:@"" table:@"Localizable"];
}

} // namespace nc::viewer

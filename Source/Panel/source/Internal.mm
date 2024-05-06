// Copyright (C) 2022 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Internal.h"
#include <Base/CommonPaths.h>
#include <filesystem>

namespace nc::panel {

NSBundle *Bundle() noexcept
{
    static NSBundle *const bundle = []() -> NSBundle * {
        const std::filesystem::path packaged = "Contents/Resources/PanelResources.bundle";
        const std::filesystem::path non_packaged = "PanelResources.bundle";
        const std::filesystem::path base = nc::base::CommonPaths::AppBundle();

        if( auto path = base / packaged; std::filesystem::is_directory(path) ) {
            // packaged structure
            NSString *const ns_path = [NSString stringWithUTF8String:path.c_str()];
            return [NSBundle bundleWithPath:ns_path];
        }
        if( auto path = base / non_packaged; std::filesystem::is_directory(path) ) {
            // non-packaged structure
            NSString *const ns_path = [NSString stringWithUTF8String:path.c_str()];
            return [NSBundle bundleWithPath:ns_path];
        }
        return nil;
    }();
    assert(bundle != nil);
    return bundle;
}

NSString *NSLocalizedString(NSString *_key, [[maybe_unused]] const char *_comment) noexcept
{
    return [Bundle() localizedStringForKey:_key value:@"" table:@"Localizable"];
}

} // namespace nc::panel

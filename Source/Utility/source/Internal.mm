// Copyright (C) 2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Internal.h"
#include <Base/CommonPaths.h>
#include <filesystem>

namespace nc::utility {

NSBundle *Bundle() noexcept
{
    static NSBundle *const bundle = []() -> NSBundle * {
        const std::filesystem::path packaged = "Contents/Resources/UtilityResources.bundle";
        const std::filesystem::path non_packaged = "UtilityResources.bundle";
        const std::filesystem::path base = nc::base::CommonPaths::AppBundle();

        if( const auto path = base / packaged; std::filesystem::is_directory(path) ) {
            // packaged structure
            NSString *const ns_path = [NSString stringWithUTF8String:path.c_str()];
            return [NSBundle bundleWithPath:ns_path];
        }
        if( const auto path = base / non_packaged; std::filesystem::is_directory(path) ) {
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

} // namespace nc::utility

#include "Internal.h"

// REMOVE THIS WHEN CLANG WILL HAVE IT INSIDE DEFAULT LIB
bad_optional_access::~bad_optional_access() noexcept = default;

namespace nc::ops {

NSBundle *Bundle()
{
    static const auto bundle_id = @"com.magnumbytes.NimbleCommander.Operations";
    static const auto bundle = [NSBundle bundleWithIdentifier:bundle_id];
    return bundle;
}

NSString *NSLocalizedString(NSString *_key, const char *_comment)
{
    return [Bundle() localizedStringForKey:_key value:@"" table:@"Localizable"];
}

}

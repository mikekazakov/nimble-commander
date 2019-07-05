// Copyright (C) 2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Internal.h"

namespace nc::viewer {

NSBundle *Bundle()
{
    static const auto bundle_id = @"com.magnumbytes.NimbleCommander.Viewer";
    static const auto bundle = [NSBundle bundleWithIdentifier:bundle_id];
    return bundle;
}

NSString *NSLocalizedString(NSString *_key, [[maybe_unused]] const char *_comment)
{
    return [Bundle() localizedStringForKey:_key value:@"" table:@"Localizable"];
}

}

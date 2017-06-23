#include "Internal.h"

namespace nc::ops {

NSBundle *Bundle()
{
    static const auto bundle_id = @"com.magnumbytes.NimbleCommander.Operations";
    static const auto bundle = [NSBundle bundleWithIdentifier:bundle_id];
    return bundle;
}

}

// Copyright (C) 2016-2021 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ActivationManagerImpl.h"

namespace nc::bootstrap {

std::string CFBundleGetAppStoreReceiptPath(CFBundleRef _bundle)
{
    if( !_bundle )
        return "";

    CFURLRef url = CFBundleCopyBundleURL(_bundle);
    if( !url )
        return "";

    NSBundle *bundle = [NSBundle bundleWithURL:static_cast<NSURL *>(CFBridgingRelease(url))];
    if( !bundle )
        return "";

    return bundle.appStoreReceiptURL.fileSystemRepresentation;
}

}

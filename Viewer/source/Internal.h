// Copyright (C) 2019 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#ifdef __OBJC__
    #include <Cocoa/Cocoa.h>
#endif

namespace nc::viewer {

#ifdef __OBJC__
NSBundle *Bundle();

#undef NSLocalizedString
NSString *NSLocalizedString(NSString *_key, const char *_comment);

#endif
    
}

#pragma once

#ifdef __OBJC__
    #include <Cocoa/Cocoa.h>
#endif

namespace nc::ops {

#ifdef __OBJC__
NSBundle *Bundle();

#undef NSLocalizedString
NSString *NSLocalizedString(NSString *_key, const char *_comment);

#endif
    
}

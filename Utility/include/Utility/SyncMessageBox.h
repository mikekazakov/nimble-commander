#pragma once

// intended for debug and development purposes only
void SyncMessageBoxUTF8(const char *_utf8_string);

#ifdef __OBJC__

#include <Foundation/Foundation.h>

void SyncMessageBoxNS(NSString *_ns_string);

#endif

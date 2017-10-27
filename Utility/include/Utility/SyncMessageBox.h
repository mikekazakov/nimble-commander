// Copyright (C) 2015-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

// intended for debug and development purposes only
void SyncMessageBoxUTF8(const char *_utf8_string);

#ifdef __OBJC__

#include <Foundation/Foundation.h>

void SyncMessageBoxNS(NSString *_ns_string);

#endif

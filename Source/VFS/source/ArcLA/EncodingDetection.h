// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <CoreFoundation/CoreFoundation.h>

namespace nc::vfs::arc {

CFStringEncoding DetectEncoding( const void* _bytes, size_t _sz );

}

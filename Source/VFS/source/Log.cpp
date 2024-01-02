// Copyright (C) 2021 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Log.h"

namespace nc::vfs {

[[clang::no_destroy]] nc::base::SpdLogger Log::m_Logger("vfs");

} // namespace nc::vfs

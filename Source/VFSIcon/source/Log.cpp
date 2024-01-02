// Copyright (C) 2022 Michael Kazakov. Subject to GNU General Public License version 3.
#include <VFSIcon/Log.h>

namespace nc::vfsicon {

[[clang::no_destroy]] nc::base::SpdLogger Log::m_Logger("vfsicon");

} // namespace nc::vfsicon

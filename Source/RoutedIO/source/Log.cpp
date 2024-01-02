// Copyright (C) 2021 Michael Kazakov. Subject to GNU General Public License version 3.
#include <RoutedIO/Log.h>

namespace nc::routedio {

[[clang::no_destroy]] nc::base::SpdLogger Log::m_Logger("routedio");

} // namespace nc::routedio

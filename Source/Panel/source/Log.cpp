// Copyright (C) 2021 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Log.h"

namespace nc::panel {

[[clang::no_destroy]] nc::base::SpdLogger Log::m_Logger("panel");

} // namespace nc::panel

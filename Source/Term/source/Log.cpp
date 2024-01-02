// Copyright (C) 2020-2021 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Log.h"

namespace nc::term {

[[clang::no_destroy]] nc::base::SpdLogger Log::m_Logger("term");

} // namespace nc::term

// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <time.h>

namespace nc::vfs::webdav {

time_t DateTimeFromRFC1123(const char *_date_time);
time_t DateTimeFromRFC850(const char *_date_time);
time_t DateTimeFromRFC3339(const char *_date_time);
time_t DateTimeFromASCTime(const char *_date_time);

} // namespace nc::vfs::webdav

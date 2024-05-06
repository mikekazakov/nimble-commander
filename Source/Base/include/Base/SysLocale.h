// Copyright (C) 2023 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

namespace nc::base {

// Gets the current MacOSX locale and sets it as a C locale
void SetSystemLocaleAsCLocale() noexcept;

} // namespace nc::base

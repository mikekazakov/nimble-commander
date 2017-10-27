// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

namespace nc::ops {

inline constexpr long NSModalResponseOK                 =       1;
inline constexpr long NSModalResponseCancel             =       0;
inline constexpr long NSModalResponseStop               =  -1'000;
inline constexpr long NSModalResponseAbort              =  -1'001;
inline constexpr long NSModalResponseContinue           =  -1'002;
inline constexpr long NSModalResponseSkip               = -10'000;
inline constexpr long NSModalResponseSkipAll            = -10'001;
inline constexpr long NSModalResponseDeletePermanently  = -10'002;
inline constexpr long NSModalResponseOverwrite          = -10'003;
inline constexpr long NSModalResponseOverwriteOld       = -10'004;
inline constexpr long NSModalResponseAppend             = -10'005;
inline constexpr long NSModalResponseRetry              = -10'006;

}

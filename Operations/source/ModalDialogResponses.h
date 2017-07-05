#pragma once

namespace nc::ops {

inline constexpr long NSModalResponseOK                 = 1;
inline constexpr long NSModalResponseCancel             = 0;
inline constexpr long NSModalResponseStop               = -1000;
inline constexpr long NSModalResponseAbort              = -1001;
inline constexpr long NSModalResponseContinue           = -1002;
inline constexpr long NSModalResponseSkip               = -10'000;
inline constexpr long NSModalResponseSkipAll            = -10'001;
inline constexpr long NSModalResponseDeletePermanently  = -10'002;

}

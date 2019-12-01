#pragma once

#include <atomic>

namespace ctrail {
class Registry;
}

namespace nc::panel::Counters {

void Register( ctrail::Registry &_registry );

namespace Ctrl {
    extern std::atomic_int64_t RefreshPanel;
    extern std::atomic_int64_t ForceRefreshPanel;
    extern std::atomic_int64_t OnPathChanged;
    extern std::atomic_int64_t GoToDirWithContext;
}

}

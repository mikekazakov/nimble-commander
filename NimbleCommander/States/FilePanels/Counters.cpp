#include "Counters.h" 
#include <ctrail/Registry.h>

namespace nc::panel::Counters {

namespace Ctrl {
std::atomic_int64_t RefreshPanel{0};
std::atomic_int64_t ForceRefreshPanel{0};
std::atomic_int64_t OnPathChanged{0};
std::atomic_int64_t GoToDirWithContext{0};
}

void Register( ctrail::Registry &_registry )
{
    _registry.add("panel.ctrl.RefreshPanel", Ctrl::RefreshPanel);
    _registry.add("panel.ctrl.ForceRefreshPanel", Ctrl::ForceRefreshPanel);
    _registry.add("panel.ctrl.OnPathChanged", Ctrl::OnPathChanged);
    _registry.add("panel.ctrl.GoToDirWithContext", Ctrl::GoToDirWithContext);
}

}

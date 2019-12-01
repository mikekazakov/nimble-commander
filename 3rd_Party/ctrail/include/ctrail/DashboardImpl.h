#pragma once

#include "Dashboard.h"
#include "RegistrySnapshot.h"

namespace ctrail {

class DashboardImpl : public Dashboard {
public:
    DashboardImpl(const RegistrySnapshot& _registry);
    const std::vector<std::string>& names() const override;
    std::vector<std::int64_t> values() const override;

private:
    void gatherInt32s(std::int64_t* _target) const noexcept;
    void gatherUInt32s(std::int64_t* _target) const noexcept;
    void gatherInt64s(std::int64_t* _target) const noexcept;
    void gatherUInt64s(std::int64_t* _target) const noexcept;
    void gatherAtomicInt32s(std::int64_t* _target) const noexcept;
    void gatherAtomicUInt32s(std::int64_t* _target) const noexcept;
    void gatherAtomicInt64s(std::int64_t* _target) const noexcept;
    void gatherAtomicUInt64s(std::int64_t* _target) const noexcept;
    void gatherPullers(std::int64_t* _target) const noexcept;

    RegistrySnapshot m_Registry;
};

} // namespace ctrail

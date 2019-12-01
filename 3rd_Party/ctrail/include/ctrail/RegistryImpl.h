#pragma once

#include <ctrail/Registry.h>
#include <string>
#include <unordered_set>
#include <vector>

namespace ctrail {

class RegistrySnapshot;

class RegistryImpl : public Registry {
public:
    RegistryImpl();
    ~RegistryImpl();

    void add(std::string_view _name, const std::int32_t& _counter) override;
    void add(std::string_view _name, const std::uint32_t& _counter) override;
    void add(std::string_view _name, const std::int64_t& _counter) override;
    void add(std::string_view _name, const std::uint64_t& _counter) override;
    void add(std::string_view _name,
             const std::atomic_int32_t& _counter) override;
    void add(std::string_view _name,
             const std::atomic_uint32_t& _counter) override;
    void add(std::string_view _name,
             const std::atomic_int64_t& _counter) override;
    void add(std::string_view _name,
             const std::atomic_uint64_t& _counter) override;
    void add(std::string_view _name,
             std::function<std::int64_t()> _puller) override;

    RegistrySnapshot bake() const;

private:
    void noteNewName(std::string_view _name);

    std::unordered_set<std::string> m_RegisteredNames;
    std::vector<std::pair<std::string, const std::int32_t*>> m_Int32s;
    std::vector<std::pair<std::string, const std::uint32_t*>> m_UInt32s;
    std::vector<std::pair<std::string, const std::int64_t*>> m_Int64s;
    std::vector<std::pair<std::string, const std::uint64_t*>> m_UInt64s;
    std::vector<std::pair<std::string, const std::atomic_int32_t*>>
        m_AtomicInt32s;
    std::vector<std::pair<std::string, const std::atomic_uint32_t*>>
        m_AtomicUInt32s;
    std::vector<std::pair<std::string, const std::atomic_int64_t*>>
        m_AtomicInt64s;
    std::vector<std::pair<std::string, const std::atomic_uint64_t*>>
        m_AtomicUInt64s;
    std::vector<std::pair<std::string, std::function<std::int64_t()>>>
        m_Pullers;
};

} // namespace ctrail

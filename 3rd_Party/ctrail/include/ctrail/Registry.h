#pragma once

#include <atomic>
#include <functional>
#include <string_view>

namespace ctrail {

class Registry {
public:
    virtual ~Registry() = 0;
    virtual void add(std::string_view _name, const std::int32_t& _counter) = 0;
    virtual void add(std::string_view _name, const std::uint32_t& _counter) = 0;
    virtual void add(std::string_view _name, const std::int64_t& _counter) = 0;
    virtual void add(std::string_view _name, const std::uint64_t& _counter) = 0;
    virtual void add(std::string_view _name,
                     const std::atomic_int32_t& _counter) = 0;
    virtual void add(std::string_view _name,
                     const std::atomic_uint32_t& _counter) = 0;
    virtual void add(std::string_view _name,
                     const std::atomic_int64_t& _counter) = 0;
    virtual void add(std::string_view _name,
                     const std::atomic_uint64_t& _counter) = 0;
    virtual void add(std::string_view _name,
                     std::function<std::int64_t()> _puller) = 0;
};

} // namespace ctrail

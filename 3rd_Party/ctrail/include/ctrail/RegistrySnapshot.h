#pragma once

#include <atomic>
#include <functional>
#include <string>
#include <vector>

namespace ctrail {

class RegistrySnapshot {
public:
    template <typename T> using vector = std::vector<T>;

    vector<std::string> names;
    vector<std::pair<std::size_t, const std::int32_t*>> int32s;
    vector<std::pair<std::size_t, const std::uint32_t*>> uint32s;
    vector<std::pair<std::size_t, const std::int64_t*>> int64s;
    vector<std::pair<std::size_t, const std::uint64_t*>> uint64s;
    vector<std::pair<std::size_t, const std::atomic_int32_t*>> atomic_int32s;
    vector<std::pair<std::size_t, const std::atomic_uint32_t*>> atomic_uint32s;
    vector<std::pair<std::size_t, const std::atomic_int64_t*>> atomic_int64s;
    vector<std::pair<std::size_t, const std::atomic_uint64_t*>> atomic_uint64s;
    vector<std::pair<std::size_t, std::function<std::int64_t()>>> pullers;
};

} // namespace ctrail

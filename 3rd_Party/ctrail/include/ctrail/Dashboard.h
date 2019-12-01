#pragma once

#include <cstdint>
#include <string>
#include <vector>

namespace ctrail {

class Dashboard {
public:
    virtual ~Dashboard() = 0;
    virtual const std::vector<std::string>& names() const = 0;
    virtual std::vector<std::int64_t> values() const = 0;
};

} // namespace ctrail

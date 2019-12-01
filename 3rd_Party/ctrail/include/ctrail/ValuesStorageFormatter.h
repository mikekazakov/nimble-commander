#pragma once

#include <ctrail/ValuesStorage.h>

namespace ctrail {

class ValuesStorageFormatter {
public:
    enum class Options { none = 0, differential = 1, skip_empty = 2 };

    std::string format(const ValuesStorage& _storage,
                       Options _options = Options::none);
};

} // namespace ctrail

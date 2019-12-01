#pragma once

#include <time.h>

namespace ctrail::internal {

struct tm localtime(time_t _time) noexcept; 
struct tm gmtime(time_t _time) noexcept;

}

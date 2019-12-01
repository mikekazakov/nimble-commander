#pragma once

#include "ValuesStorage.h"

#include <vector>

namespace ctrail {

class MonotonicValuesStorage {
public:
    using time_point = ValuesStorage::time_point;

    MonotonicValuesStorage(const std::vector<std::string> &_counters_names);
    ~MonotonicValuesStorage();

    void addValues(time_point _time_point, const std::int64_t* _values,
                   std::size_t _values_number);

    std::size_t timePointsNumber() const;
    time_point timePoint(std::size_t _index) const;
    void copyValuesByTimePoint(std::size_t _index, std::int64_t* _buffer,
                               std::size_t _buffer_elements) const;

    std::size_t countersNumber() const;
    const std::string &counterName(std::size_t _index) const;
    void copyValuesByCounter(std::size_t _index, std::int64_t* _buffer,
                             std::size_t _buffer_elements) const;

private:
    std::size_t m_CountersNumber;
    std::vector<time_point> m_TimePoints;
    std::vector<std::int64_t> m_Values;
    std::vector<std::string> m_CountersNames;    
};

} // namespace ctrail

#pragma once

#include <ctrail/ValuesStorageExporter.h>
#include <string>

namespace ctrail {

class ChromeTraceExporter /* conforms to the ValuesStorageExporter 'concept' */
{
public:
    struct Formatting {
        std::chrono::milliseconds tombstone_offset = std::chrono::milliseconds(100); 
        std::int64_t tombstone_value = 0;
    };
    using Options = ValuesStorageExporter::Options;

    ChromeTraceExporter();
    ChromeTraceExporter( const Formatting &_formatting );
    
    std::string format(const ValuesStorage &_values, Options _options) const;

    std::string composeCounter(const ValuesStorage &_values, std::size_t _counter_index,
                               std::int64_t *_tmp_buffer, std::size_t _tmp_buffer_size,
                               Options _options) const;

private:
    static bool isIdle(const std::int64_t * const _values, const std::size_t _size) noexcept;
    
    Formatting m_Formatting;
};

}

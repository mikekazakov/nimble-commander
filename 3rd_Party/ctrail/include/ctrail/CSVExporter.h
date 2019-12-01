#pragma once

#include <ctrail/ValuesStorageExporter.h>
#include <string>

namespace ctrail {

class CSVExporter /* conforms to the ValuesStorageExporter 'concept' */
{
public:
    struct Formatting {
        std::string counters_column_title = "counter";
        std::string values_delimiter = ",";
        std::string newline_delimiter = "\n";
    };
    using Options = ValuesStorageExporter::Options;
    
    CSVExporter();
    CSVExporter( const Formatting &_formatting );
    
    std::string format(const ValuesStorage &_values, Options _options) const;

    std::string composeHeaders(const ValuesStorage &_values, Options _options) const;
    std::string composeRow(const ValuesStorage &_values, std::size_t _counter_index,
                           std::int64_t *_tmp_buffer, std::size_t _tmp_buffer_size,
                           Options _options) const;
private:
    static bool isIdle(const std::int64_t * const _values, const std::size_t _size) noexcept;
    static std::string fmtTime(std::chrono::system_clock::time_point _tp);    

    Formatting m_Formatting;
};
    
}

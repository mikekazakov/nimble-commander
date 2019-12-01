#pragma once

#include "Dashboard.h"
#include "ValuesStorageExporter.h"
#include "CSVExporter.h"

#include <memory>
#include <chrono>
#include <functional>
#include <thread>

namespace ctrail {

class OneShotMonitor
{
public:
    struct Params {
        const Dashboard *dashboard = nullptr;
        std::chrono::nanoseconds period = std::chrono::milliseconds{100};
        std::chrono::nanoseconds duration = std::chrono::seconds{1};
        ValuesStorageExporter exporter = ValuesStorageExporter{ CSVExporter{} };
        ValuesStorageExporter::Options export_options = ValuesStorageExporter::Options::none;        
        std::function<void(std::string _exported_trail)> save;        
    };
    OneShotMonitor( Params _params );
    OneShotMonitor( const OneShotMonitor & ) = delete;
    virtual ~OneShotMonitor();
    OneShotMonitor& operator=(const OneShotMonitor & ) = delete;
    
protected:
    virtual std::chrono::system_clock::time_point nowOnSystemClock() const noexcept;
    virtual void fire( std::chrono::nanoseconds _period, std::chrono::nanoseconds _duration, std::function<void()> _job );
    void join();

private:
    void monitor();
    void save( std::string _exported_trail );
    static const Dashboard *throwIfNull(const Dashboard *dashboard);

    std::thread m_WorkerThread;
    const Dashboard * const m_Dashboard = nullptr;
    const std::chrono::nanoseconds m_Period;
    const std::chrono::nanoseconds m_Duration;
    const ValuesStorageExporter m_Exporter;    
    const ValuesStorageExporter::Options m_ExportOptions;
    ValuesStorage m_Storage;
    const std::function<void(std::string)> m_Save;
};

}

// Copyright (C) 2015-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <memory>
#include <mutex>

namespace nc::base {

class IdleSleepPreventer
{
public:
    class Promise
    {
    public:
        ~Promise();

    private:
        Promise();
        Promise(Promise &) = delete;
        void operator=(Promise &) = delete;
        friend class IdleSleepPreventer;
    };

    static IdleSleepPreventer &Instance();
    static std::unique_ptr<Promise> GetPromise();

private:
    void Add();
    void Release();

    std::mutex m_Lock;
    int m_Promises = 0;
    uint32_t m_ID = 0; // zero means ID is not acquired

    friend class Promise;
};

} // namespace nc::base

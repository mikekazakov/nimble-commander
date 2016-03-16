//
//  IdleSleepPreventer.h
//  Files
//
//  Created by Michael G. Kazakov on 16/04/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include <memory>
#include <mutex>

class IdleSleepPreventer
{
public:
    class Promise
    {
    public:
        ~Promise();
    private:
        Promise();
        Promise(Promise&) = delete;
        void operator=(Promise&) = delete;
        friend class IdleSleepPreventer;
    };

    static IdleSleepPreventer &Instance();
    std::unique_ptr<Promise> GetPromise();
    
private:
    void Add();
    void Release();
    
    std::mutex  m_Lock;
    int         m_Promises = 0;
    uint32_t    m_ID = 0; // zero means ID is not acquired
    
    friend class Promise;
};

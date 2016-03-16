//
//  IdleSleepPreventer.cpp
//  Files
//
//  Created by Michael G. Kazakov on 16/04/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#include <IOKit/pwr_mgt/IOPMLib.h>
#include <CoreFoundation/CoreFoundation.h>
#include <Habanero/IdleSleepPreventer.h>

IdleSleepPreventer::Promise::Promise()
{
    IdleSleepPreventer::Instance().Add();
}

IdleSleepPreventer::Promise::~Promise()
{
    IdleSleepPreventer::Instance().Release();
}

IdleSleepPreventer &IdleSleepPreventer::Instance()
{
    static auto i = new IdleSleepPreventer;
    return *i;
}

std::unique_ptr<IdleSleepPreventer::Promise> IdleSleepPreventer::GetPromise()
{
    return std::unique_ptr<IdleSleepPreventer::Promise>(new Promise);
}

void IdleSleepPreventer::Add()
{
    std::lock_guard<std::mutex> lock(m_Lock);
    m_Promises++;
    
    if( m_ID == kIOPMNullAssertionID ) {
        static CFStringRef reason = CFStringCreateWithFormat(nullptr, nullptr, CFSTR("%@ is performing an operation"), CFBundleGetIdentifier(CFBundleGetMainBundle()) );
        IOPMAssertionCreateWithName(kIOPMAssertionTypeNoIdleSleep,
                                    kIOPMAssertionLevelOn,
                                    reason,
                                    &m_ID);
    }
}

void IdleSleepPreventer::Release()
{
    std::lock_guard<std::mutex> lock(m_Lock);
    m_Promises--;

    if( m_Promises == 0 && m_ID != kIOPMNullAssertionID ) {
        IOPMAssertionRelease(m_ID);
        m_ID = kIOPMNullAssertionID;
    }
}

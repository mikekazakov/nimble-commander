// Copyright (C) 2015-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include <IOKit/pwr_mgt/IOPMLib.h>
#include <CoreFoundation/CoreFoundation.h>
#include <Base/IdleSleepPreventer.h>

namespace nc::base {

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
    [[clang::no_destroy]] static IdleSleepPreventer i;
    return i;
}

std::unique_ptr<IdleSleepPreventer::Promise> IdleSleepPreventer::GetPromise()
{
    return std::unique_ptr<IdleSleepPreventer::Promise>(new Promise);
}

void IdleSleepPreventer::Add()
{
    const std::lock_guard<std::mutex> lock(m_Lock);
    m_Promises++;

    if( m_ID == kIOPMNullAssertionID ) {
        static CFStringRef reason = CFStringCreateWithFormat(
            nullptr, nullptr, CFSTR("%@ is performing an operation"), CFBundleGetIdentifier(CFBundleGetMainBundle()));
        IOPMAssertionCreateWithName(kIOPMAssertionTypeNoIdleSleep, kIOPMAssertionLevelOn, reason, &m_ID);
    }
}

void IdleSleepPreventer::Release()
{
    const std::lock_guard<std::mutex> lock(m_Lock);
    m_Promises--;

    if( m_Promises == 0 && m_ID != kIOPMNullAssertionID ) {
        IOPMAssertionRelease(m_ID);
        m_ID = kIOPMNullAssertionID;
    }
}

} // namespace nc::base

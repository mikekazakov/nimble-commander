/* Copyright (c) 2015 Michael G. Kazakov
 * Permission is hereby granted, free of charge, to any person obtaining a copy of this software
 * and associated documentation files (the "Software"), to deal in the Software without restriction,
 * including without limitation the rights to use, copy, modify, merge, publish, distribute,
 * sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * The above copyright notice and this permission notice shall be included in all copies or
 * substantial portions of the Software.
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
 * BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
 * DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */
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
        static CFStringRef reason = CFStringCreateWithFormat(nullptr,
                                                             nullptr,
                                                             CFSTR("%@ is performing an operation"),
                                                             CFBundleGetIdentifier(CFBundleGetMainBundle()));
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

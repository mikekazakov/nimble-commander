/* Copyright (c) 2016-2017 Michael G. Kazakov
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
#pragma once

#include <CoreFoundation/CoreFoundation.h>
#include <string>
#include <vector>
#include <atomic>
#include "spinlock.h"

class GoogleAnalytics
{
public:
    GoogleAnalytics( /* disabled */ ); 
    GoogleAnalytics(const char *_tracking_id,
                    bool _use_https = true,
                    bool _filter_redundant_messages = true
                    );
    GoogleAnalytics(const GoogleAnalytics&) = delete;
    void operator=(const GoogleAnalytics&) = delete;

    static CFStringRef const g_DefaultsClientIDKey;
    static CFStringRef const g_DefaultsTrackingEnabledKey;
    
    /**
     * Returns current state of service, is it enabled or not.
     */
    bool IsEnabled() const noexcept;
    
    /**
     * Will check defaults value to permit or prohibit GA logging.
     * IsEnabled() might change after this call.
     */
    void UpdateEnabledStatus();

    /**
     * Posts specified event to GA if service is enabled.
     * Screen title must not be a nullptr.
     */
    void PostScreenView(const char *_screen);
    
    /**
     * Posts specified event to GA if service is enabled.
     * All strings must not be a nullptr.
     */
    void PostEvent(const char *_category,
                   const char *_action,
                   const char *_label,
                   unsigned _value = 1);
    
private:
    void AcceptMessage(std::string _message);
    void PostMessages();
    void MarkDirty();
    
    std::atomic_flag            m_SendingScheduled{ false };
    spinlock                    m_MessagesLock;
    std::vector<std::string>    m_Messages;
    
    const std::string           m_TrackingID;
    const std::string           m_ClientID;
    const std::string           m_AppName;
    const std::string           m_AppVersion;
    const std::string           m_UserLanguage;
    std::string                 m_PayloadPrefix;
    bool                        m_Enabled = false;
    const bool                  m_UseHTTPS = true;
    const bool                  m_FilterRedundantMessages = true;
};

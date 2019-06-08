// Copyright (C) 2016-2017 Michael Kazakov. Subject to GNU General Public License version 3.
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

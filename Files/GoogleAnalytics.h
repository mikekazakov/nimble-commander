#pragma once

class GoogleAnalytics
{
public:
    static GoogleAnalytics& Instance();
    
    void PostScreenView(const char *_screen);
    void PostEvent(const char *_category, const char *_action, const char *_label, unsigned _value = 1);
    
private:
    GoogleAnalytics();
    GoogleAnalytics(const GoogleAnalytics&) = delete;

    void AcceptMessage(string _message);
    void PostMessages();
    void MarkDirty();
    
    atomic_flag     m_SendingScheduled{ false };
    spinlock        m_MessagesLock;
    vector<string>  m_Messages;
    
    const string    m_ClientID;
    const string    m_AppName;
    const string    m_AppVersion;
    string          m_PayloadPrefix;
};

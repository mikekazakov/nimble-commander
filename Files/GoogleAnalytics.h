#pragma once

class GoogleAnalytics
{
public:
    static GoogleAnalytics& Instance();
    
    void PostPageview(const char *_page);
    
private:
    GoogleAnalytics();
    
    
    const string m_ClientID;
    const string m_AppName;
    const string m_AppVersion;
};

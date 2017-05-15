#pragma once

#include <VFS/VFS.h>

namespace nc::core {

struct LauchServicesHandlers
{
    /**
     * unsorted apps list
     */
    vector<string>  paths{};
    
    /**
     * common UTI if any (if there was different UTI before merge - this field will be "")
     */
    string          uti = "";
    
    string          default_handler_path;
    
    static LauchServicesHandlers GetForItem(const VFSListingItem &_item);
    static void DoMerge(const vector<LauchServicesHandlers>& _input, LauchServicesHandlers& _result);
    static bool SetDefaultHandler(const string &_uti, const string &_path);
};

class LaunchServiceHandler
{
public:
    LaunchServiceHandler( const string &_handler_path ); // may throw on fetch error
    
    const string &Path() const noexcept;
    NSString     *Name() const noexcept;
    NSImage      *Icon() const noexcept;
    NSString     *Version() const noexcept;
    NSString     *Identifier() const noexcept;
    
private:
    string     m_Path;
    NSString   *m_AppName;
    NSImage    *m_AppIcon;
    NSString   *m_AppVersion;
    NSString   *m_AppID;
};

}

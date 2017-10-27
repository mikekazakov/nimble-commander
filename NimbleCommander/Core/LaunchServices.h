// Copyright (C) 2013-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>

namespace nc::core {

class LauchServicesHandlers
{
public:
    LauchServicesHandlers( );
    LauchServicesHandlers( const VFSListingItem &_item );
    LauchServicesHandlers( const vector<LauchServicesHandlers>& _handlers_to_merge );

    const vector<string> &HandlersPaths() const noexcept;
    const string &DefaultHandlerPath() const noexcept; // may be empty after merge
    const string &CommonUTI() const noexcept; // may be empty after merge

private:
    vector<string>  m_Paths;
    string          m_UTI;
    string          m_DefaultHandlerPath;
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
    
    bool SetAsDefaultHandlerForUTI(const string &_uti) const;
    
private:
    string     m_Path;
    NSString   *m_AppName;
    NSImage    *m_AppIcon;
    NSString   *m_AppVersion;
    NSString   *m_AppID;
};

}

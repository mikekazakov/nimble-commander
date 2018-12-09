// Copyright (C) 2013-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>

namespace nc::core {

class LauchServicesHandlers
{
public:
    LauchServicesHandlers( );
    LauchServicesHandlers( const VFSListingItem &_item );
    LauchServicesHandlers( const std::vector<LauchServicesHandlers>& _handlers_to_merge );

    const std::vector<std::string> &HandlersPaths() const noexcept;
    const std::string &DefaultHandlerPath() const noexcept; // may be empty after merge
    const std::string &CommonUTI() const noexcept; // may be empty after merge

private:
    std::vector<std::string> m_Paths;
    std::string m_UTI;
    std::string m_DefaultHandlerPath;
};

class LaunchServiceHandler
{
public:
    LaunchServiceHandler( const std::string &_handler_path ); // may throw on fetch error
    
    const std::string &Path() const noexcept;
    NSString     *Name() const noexcept;
    NSImage      *Icon() const noexcept;
    NSString     *Version() const noexcept;
    NSString     *Identifier() const noexcept;
    
    bool SetAsDefaultHandlerForUTI(const std::string &_uti) const;
    
private:
    std::string m_Path;
    NSString   *m_AppName;
    NSImage    *m_AppIcon;
    NSString   *m_AppVersion;
    NSString   *m_AppID;
};

}

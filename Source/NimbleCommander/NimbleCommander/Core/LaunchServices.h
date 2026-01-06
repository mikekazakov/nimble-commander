// Copyright (C) 2013-2026 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>
#include <Utility/UTI.h>
#include <string_view>

namespace nc::core {

class LauchServicesHandlers
{
public:
    LauchServicesHandlers();
    LauchServicesHandlers(const VFSListingItem &_item, const nc::utility::UTIDB &_uti_db);
    LauchServicesHandlers(std::string_view _item_path, VFSHost &_host, const nc::utility::UTIDB &_uti_db);
    LauchServicesHandlers(const std::vector<LauchServicesHandlers> &_handlers_to_merge);

    [[nodiscard]] const std::vector<std::string> &HandlersPaths() const noexcept;
    [[nodiscard]] const std::string &DefaultHandlerPath() const noexcept; // may be empty after merge
    [[nodiscard]] const std::string &CommonUTI() const noexcept;          // may be empty after merge

private:
    std::vector<std::string> m_Paths;
    std::string m_UTI;
    std::string m_DefaultHandlerPath;
};

class LaunchServiceHandler
{
public:
    LaunchServiceHandler(const std::string &_handler_path); // may throw on fetch error

    [[nodiscard]] const std::string &Path() const noexcept;
    [[nodiscard]] NSString *Name() const noexcept;
    [[nodiscard]] NSImage *Icon() const noexcept;
    [[nodiscard]] NSString *Version() const noexcept;
    [[nodiscard]] NSString *Identifier() const noexcept;

    [[nodiscard]] bool SetAsDefaultHandlerForUTI(const std::string &_uti) const;

private:
    std::string m_Path;
    NSString *m_AppName;
    NSImage *m_AppIcon;
    NSString *m_AppVersion;
    NSString *m_AppID;
};

} // namespace nc::core

// Copyright (C) 2018-2020 Michael Kazakov. Subject to GNU General Public License version 3.

#pragma once

#include <functional>
#include <string>
#include <vector>
#include <Cocoa/Cocoa.h>
#include <VFS/Native.h>

@class NCMainWindowController;

namespace nc::core {

class ServicesHandler
{
public:
    ServicesHandler(std::function<NCMainWindowController *()> _window_provider, VFSHostPtr _native_host);

    // NSService
    void OpenFolder(NSPasteboard *_pboard, NSString *_user_data, __strong NSString **_error);
    void RevealItem(NSPasteboard *_pboard, NSString *_user_data, __strong NSString **_error);

    // application:openFile: and application:openFiles:
    void OpenFiles(NSArray<NSString *> *_paths);

private:
    void GoToFolder(const std::string &_path);
    void RevealItems(const std::vector<std::string> &_paths);

    std::function<NCMainWindowController *()> m_WindowProvider;
    VFSHostPtr m_NativeHost;
};

} // namespace nc::core

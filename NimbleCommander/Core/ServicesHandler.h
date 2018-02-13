// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.

#pragma once

@class MainWindowController;

namespace nc::core {

class ServicesHandler
{
public:
    ServicesHandler( function<MainWindowController*()> _window_provider );

    // NSService
    void OpenFolder(NSPasteboard *_pboard, NSString *_user_data, __strong NSString **_error);
    void RevealItem(NSPasteboard *_pboard, NSString *_user_data, __strong NSString **_error);
    
    // application:openFile: and application:openFiles:
    void OpenFiles(NSArray<NSString *> *_paths);
    
private:
    void RevealItems(const vector<string> &_paths);
    
    function<MainWindowController*()> m_WindowProvider;
};
    
}

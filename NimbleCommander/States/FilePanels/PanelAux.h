// Copyright (C) 2013-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include <VFS/VFS.h>
#include <Operations/CopyingOptions.h>

@class PanelController;
class ExternalEditorStartupInfo;

namespace nc::panel {

// this class allows opening file in VFS with regular [NSWorkspace open]
// after refactoring the need to keep this class at all is in doubts
// opening files in writable non-native vfs will start background changes tracking and uploading changes back
class PanelVFSFileWorkspaceOpener
{
public:
    // can be called from main thread - it will execute it's job in background
    static void Open(std::string _filepath,
                     VFSHostPtr _host,
                     PanelController *_panel
                     );
    
    static void Open(std::string _filepath,
                     VFSHostPtr _host,
                     std::string _with_app_path, // can be "", use default app in such case
                     PanelController *_panel
                     );
    
    static void Open(std::vector<std::string> _filepaths,
                     VFSHostPtr _host,
                     NSString *_with_app_bundle, // can be nil, use default app in such case
                     PanelController *_panel
                     );
    
    static void OpenInExternalEditorTerminal(std::string _filepath,
                                             VFSHostPtr _host,
                                             std::shared_ptr<ExternalEditorStartupInfo> _ext_ed,
                                             std::string _file_title,
                                             PanelController *_panel);
};

bool IsEligbleToTryToExecuteInConsole(const VFSListingItem& _item);
nc::ops::CopyingOptions MakeDefaultFileCopyOptions();
nc::ops::CopyingOptions MakeDefaultFileMoveOptions();
bool IsExtensionInArchivesWhitelist( const char *_ext ) noexcept;
bool ShowQuickLookAsFloatingPanel() noexcept;
    
}

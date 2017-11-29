// Copyright (C) 2013-2017 Michael Kazakov. Subject to GNU General Public License version 3.
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
    static void Open(string _filepath,
                     VFSHostPtr _host,
                     PanelController *_panel
                     );
    
    static void Open(string _filepath,
                     VFSHostPtr _host,
                     string _with_app_path, // can be "", use default app in such case
                     PanelController *_panel
                     );
    
    static void Open(vector<string> _filepaths,
                     VFSHostPtr _host,
                     NSString *_with_app_bundle, // can be nil, use default app in such case
                     PanelController *_panel
                     );
    
    static void OpenInExternalEditorTerminal(string _filepath,
                                             VFSHostPtr _host,
                                             shared_ptr<ExternalEditorStartupInfo> _ext_ed,
                                             string _file_title,
                                             PanelController *_panel);
};

bool IsEligbleToTryToExecuteInConsole(const VFSListingItem& _item);
nc::ops::CopyingOptions MakeDefaultFileCopyOptions();
nc::ops::CopyingOptions MakeDefaultFileMoveOptions();
bool IsExtensionInArchivesWhitelist( const char *_ext ) noexcept;
bool ShowQuickLookAsFloatingPanel() noexcept;
    
}

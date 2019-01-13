// Copyright (C) 2013-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include <VFS/VFS.h>
#include <Operations/CopyingOptions.h>

@class PanelController;
class ExternalEditorStartupInfo;

namespace nc::utility {
    class TemporaryFileStorage;
}

namespace nc::panel {

// this class allows opening file in VFS with regular [NSWorkspace open]
// after refactoring the need to keep this class at all is in doubts
// opening files in writable non-native vfs will start background changes tracking and uploading changes back
class FileOpener
{
public:
    FileOpener(nc::utility::TemporaryFileStorage &_temp_storage);
    
    // can be called from main thread - it will execute it's job in background
    void Open(std::string _filepath,
              VFSHostPtr _host,
              PanelController *_panel
              );
    
    void Open(std::string _filepath,
              VFSHostPtr _host,
              std::string _with_app_path, // can be "", use default app in such case
              PanelController *_panel
              );
    
    void Open(std::vector<std::string> _filepaths,
              VFSHostPtr _host,
              NSString *_with_app_bundle, // can be nil, use default app in such case
              PanelController *_panel
              );
    
    void OpenInExternalEditorTerminal(std::string _filepath,
                                      VFSHostPtr _host,
                                      std::shared_ptr<ExternalEditorStartupInfo> _ext_ed,
                                      std::string _file_title,
                                      PanelController *_panel);
private:
    nc::utility::TemporaryFileStorage &m_TemporaryFileStorage;
};

bool IsEligbleToTryToExecuteInConsole(const VFSListingItem& _item);
nc::ops::CopyingOptions MakeDefaultFileCopyOptions();
nc::ops::CopyingOptions MakeDefaultFileMoveOptions();
bool IsExtensionInArchivesWhitelist( const char *_ext ) noexcept;
bool ShowQuickLookAsFloatingPanel() noexcept;
    
}

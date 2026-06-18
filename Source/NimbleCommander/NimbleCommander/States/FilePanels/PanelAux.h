// Copyright (C) 2013-2026 Michael Kazakov. Subject to GNU General Public License version 3.
#include <VFS/VFS.h>
#include <Operations/CopyingOptions.h>
#include <string_view>

@class PanelController;
class ExternalEditorStartupInfo;

namespace nc::utility {
class TemporaryFileStorage;
class UTIDB;
} // namespace nc::utility

namespace nc::panel {

// This class allows opening file in VFS with e.g. regular [NSWorkspace open].
// Opening files in writable non-native vfs will start background changes tracking and uploading changes back.
// The instances of the class used to open the file must be kept alive until the opening is finished.
class FileOpener
{
public:
    FileOpener(nc::utility::TemporaryFileStorage &_temp_storage, nc::utility::UTIDB &_uti_db);

    // Open the specified file with either a default of a specified application.
    // Can be called from main thread - it will execute it's job in background.
    void Open(std::string_view _filepath,
              VFSHostPtr _host,
              PanelController *_panel,
              std::string_view _with_app_at_path = {} // can be "", use default app in such case
    );

    void Open(std::vector<std::string> _filepaths,
              VFSHostPtr _host,
              NSString *_with_app_bundle, // can be nil, use default app in such case
              PanelController *_panel);

    void OpenInExternalEditorTerminal(std::string _filepath,
                                      VFSHostPtr _host,
                                      std::shared_ptr<ExternalEditorStartupInfo> _ext_ed,
                                      std::string _file_title,
                                      PanelController *_panel);

private:
    // May return nil if no default app was found
    [[nodiscard]] NSString *DeduceDefaultAppBundleForOpeningFiles(std::span<std::string> _filepaths,
                                                                  VFSHostPtr _host) const;

    nc::utility::TemporaryFileStorage &m_TemporaryFileStorage;
    nc::utility::UTIDB &m_UTIDB;
};

bool IsEligbleToTryToExecuteInConsole(const VFSListingItem &_item);
nc::ops::CopyingOptions MakeDefaultFileCopyOptions();
nc::ops::CopyingOptions MakeDefaultFileMoveOptions();
bool IsExtensionInArchivesWhitelist(std::string_view _ext) noexcept;
bool ShowQuickLookAsFloatingPanel() noexcept;

} // namespace nc::panel

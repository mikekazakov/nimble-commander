// Copyright (C) 2014-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>

class ExternalEditorStartupInfo
{
public:
    ExternalEditorStartupInfo() noexcept;
    
    const std::string   &Name()         const noexcept;
    const std::string   &Path()         const noexcept;
    const std::string   &Arguments()    const noexcept;
    const std::string   &Mask()         const noexcept;
    bool            OnlyFiles()         const noexcept;
    uint64_t        MaxFileSize()       const noexcept;
    bool            OpenInTerminal()    const noexcept;

    bool IsValidForItem(const VFSListingItem&_item) const;
    
    /**
     * Returns arguments in UTF8 form where %% appearances are changed to specified file path.
     * Treat empty arguments as @"%%" string. _path is escaped with backward slashes.
     */
    std::string SubstituteFileName(const std::string &_path) const;


private:
    std::string m_Name;
    std::string m_Path;
    std::string m_Arguments;
    std::string m_Mask;
    uint64_t m_MaxFileSize;
    bool m_OnlyFiles;
    bool m_OpenInTerminal;
    friend struct ExternalEditorsPersistence;
    friend class ExternalEditorsStorage;
};

// STA api design, access only from main thread!
class ExternalEditorsStorage
{
public:
    ExternalEditorsStorage(const char* _config_path);

    std::shared_ptr<ExternalEditorStartupInfo> ViableEditorForItem(const VFSListingItem&_item) const;
    std::vector<std::shared_ptr<ExternalEditorStartupInfo>> AllExternalEditors() const;
    
    void SetExternalEditors( const std::vector<std::shared_ptr<ExternalEditorStartupInfo>>& _editors );

private:
    void LoadFromConfig();
    void SaveToConfig();

    std::vector<std::shared_ptr<ExternalEditorStartupInfo>> m_ExternalEditors;
    const char* const m_ConfigPath;
};

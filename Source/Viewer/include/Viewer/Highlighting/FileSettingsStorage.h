// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#include "SettingsStorage.h"
#include <Base/UnorderedUtil.h>
#include <Utility/FileMask.h>
#include <filesystem>
#include <vector>

namespace nc::viewer::hl {

class FileSettingsStorage : public SettingsStorage
{
public:
    FileSettingsStorage(const std::filesystem::path &_base_dir, const std::filesystem::path &_overrides_dir);
    FileSettingsStorage(const FileSettingsStorage &) = delete;
    ~FileSettingsStorage();
    FileSettingsStorage &operator=(const FileSettingsStorage &) = delete;

    std::optional<std::string> Language(std::string_view _filename) noexcept override;

    std::vector<std::string> List() override;

    std::shared_ptr<const std::string> Settings(std::string_view _lang) override;

private:
    struct Lang {
        std::string name;
        std::string settings_filename;
        nc::utility::FileMask mask;
    };

    // Loads and parses the contents of the "Main.json" file
    static std::vector<Lang> LoadLangs(const std::filesystem::path &_path);

    void ReloadLangs();

    void SubscribeToOverridesChanges();
    void UnsubscribeFromOverridesChanges();
    void OverridesChanged();

    std::filesystem::path m_BaseDir;
    std::filesystem::path m_OverridesDir;
    uint64_t m_OverridesObservationToken = 0;
    bool m_Outdated = false;

    std::vector<Lang> m_Langs;
    ankerl::unordered_dense::
        map<std::string, std::shared_ptr<const std::string>, UnorderedStringHashEqual, UnorderedStringHashEqual>
            m_Settings;
};

} // namespace nc::viewer::hl

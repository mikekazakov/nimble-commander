// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#include "SettingsStorage.h"
#include <Base/RobinHoodUtil.h>
#include <Utility/FileMask.h>
#include <filesystem>
#include <vector>

namespace nc::viewer::hl {

class FileSettingsStorage : public SettingsStorage
{
public:
    FileSettingsStorage(const std::filesystem::path &_base_dir, const std::filesystem::path &_overrides_dir);

    std::optional<std::string> Language(std::string_view _filename) noexcept override;

    std::shared_ptr<const std::string> Settings(std::string_view _lang) override;

private:
    struct Lang {
        std::string name;
        std::string settings_filename;
        nc::utility::FileMask mask;
    };

    // Loads and parses the contents of the "Main.json" file
    std::vector<Lang> LoadLangs(const std::filesystem::path &_path) const;

    std::filesystem::path m_BaseDir;
    std::filesystem::path m_OverridesDir;
    std::vector<Lang> m_Langs;
    robin_hood::unordered_flat_map<std::string,
                                   std::shared_ptr<const std::string>,
                                   RHTransparentStringHashEqual,
                                   RHTransparentStringHashEqual>
        m_Settings;
};

} // namespace nc::viewer::hl

// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Utility/FileMask.h>
#include <Base/RobinHoodUtil.h>
#include <string>
#include <filesystem>
#include <string_view>
#include <memory>
#include <vector>

namespace nc::viewer::hl {

class SettingsStorage
{
public:
    virtual ~SettingsStorage() = default;

    virtual std::string Language(std::string_view _filename) = 0;

    virtual std::shared_ptr<const std::string> Settings(std::string_view _lang) = 0;
};

class DummySettingsStorage : public SettingsStorage
{
public:
    std::string Language(std::string_view _filename) override;
    
    std::shared_ptr<const std::string> Settings(std::string_view _lang) override;
};

class FileSettingsStorage : public SettingsStorage
{
public:
    FileSettingsStorage(const std::filesystem::path &_base_dir, const std::filesystem::path &_overrides_dir);

    std::string Language(std::string_view _filename) override;
    
    std::shared_ptr<const std::string> Settings(std::string_view _lang) override;

private:
    struct Lang {
        std::string name;
        std::string settings_filename;
        nc::utility::FileMask mask;
    };

    void LoadLangs();

    std::filesystem::path m_BaseDir;
    std::vector<Lang> m_Langs;
    robin_hood::unordered_flat_map<std::string,
                                   std::shared_ptr<const std::string>,
                                   RHTransparentStringHashEqual,
                                   RHTransparentStringHashEqual>
        m_Settings;
};

} // namespace nc::viewer::hl

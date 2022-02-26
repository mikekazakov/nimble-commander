// Copyright (C) 2022 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Utility/ActionShortcut.h>
#include <Habanero/Observable.h>
#include <Config/Config.h>

#include <string>
#include <vector>
#include <span>
#include <mutex>

/**
- produces % symbol:  %%
- dialog value: %?, %"some text"?
- directory path: %r, %-r
- current path: %p, %-p
- filename: %f, %-f
- filename without extension: %n, %-n
- file extension: %e, %-e
- selected filenames as parameters: %F, %-F, %10F, %-10F
- selected filepaths as parameters: %P, %-P, %10P, %-10P
- list of selected files:
  - filenames: %LF, %-LF, %L10F, %-L50F
  - filepaths: %LP, %-LP, %L50P, %-L50P
- toggle left/right instead of source/target and vice versa: %-
- limit maxium total amount of files output %2T, %15T
**/

namespace nc::panel {

class ExternalToolsParameters
{
public:
    enum class Location : uint8_t
    {
        Source,
        Target,
        Left,
        Right
    };

    enum class FileInfo : uint8_t
    {
        DirectoryPath,
        Path,
        Filename,
        FilenameWithoutExtension,
        FileExtension
    };

    struct UserDefined {
        std::string text;
    };

    struct EnterValue {
        std::string name;
    };

    struct CurrentItem {
        Location location;
        FileInfo what;
    };

    struct SelectedItems {
        Location location;
        FileInfo what;
        int max;            // maximum of selected items to use as a parameters or as a list content
        bool as_parameters; // as a list inside a temp file otherwise
        friend bool operator==(SelectedItems _lhs, SelectedItems _rhs) noexcept;
        friend bool operator!=(SelectedItems _lhs, SelectedItems _rhs) noexcept;
    };

    enum class ActionType : uint8_t
    {
        UserDefined,
        EnterValue,
        CurrentItem,
        SelectedItems
    };

    struct Step {
        ActionType type;
        uint16_t index;
        Step(ActionType type, uint16_t index);
        friend bool operator==(Step _lhs, Step _rhs) noexcept;
        friend bool operator!=(Step _lhs, Step _rhs) noexcept;
    };

    std::span<const Step> Steps() const noexcept;
    const Step &StepNo(size_t _number) const;
    size_t StepsAmount() const;

    const UserDefined &GetUserDefined(size_t _index) const;
    const EnterValue &GetEnterValue(size_t _index) const;
    const CurrentItem &GetCurrentItem(size_t _index) const;
    const SelectedItems &GetSelectedItems(size_t _index) const;
    unsigned GetMaximumTotalFiles() const;

private:
    void InsertUserDefinedText(UserDefined _ud);
    void InsertValueRequirement(EnterValue _ev);
    void InsertCurrentItem(CurrentItem _ci);
    void InsertSelectedItem(SelectedItems _si);

    std::vector<Step> m_Steps;
    std::vector<UserDefined> m_UserDefined;
    std::vector<EnterValue> m_EnterValues;
    std::vector<CurrentItem> m_CurrentItems;
    std::vector<SelectedItems> m_SelectedItems;
    unsigned m_MaximumTotalFiles = 0;

    friend class ExternalToolsParametersParser;
};

class ExternalToolsParametersParser
{
public:
    ExternalToolsParameters Parse(const std::string &_source, std::function<void(std::string)> _parse_error = {});

private:
};

class ExternalTool
{
public:
    enum class StartupMode : int
    {
        Automatic = 0,
        RunInTerminal = 1,
        RunDeatached = 2
    };

    std::string m_Title;
    std::string m_ExecutablePath; // app by bundle?
    std::string m_Parameters;
    utility::ActionShortcut m_Shorcut;
    StartupMode m_StartupMode = StartupMode::Automatic;

    friend bool operator==(const ExternalTool &_lhs, const ExternalTool &_rhs) noexcept;
    friend bool operator!=(const ExternalTool &_lhs, const ExternalTool &_rhs) noexcept;

    // run in terminal
    // allow VFS
    // string directory
};

// supposed to be thread-safe
class ExternalToolsStorage : public ObservableBase
{
public:
    ExternalToolsStorage(const char *_config_path, nc::config::Config &_config);

    size_t ToolsCount() const;
    std::shared_ptr<const ExternalTool> GetTool(size_t _no) const; // will return nullptr on invalid index
    std::vector<std::shared_ptr<const ExternalTool>> GetAllTools() const;

    void ReplaceTool(ExternalTool _tool, size_t _at_index);
    void InsertTool(ExternalTool _tool); // adds tool at the end
    void RemoveTool(size_t _at_index);
    void MoveTool(size_t _at_index, size_t _to_index);

    using ObservationTicket = ObservableBase::ObservationTicket;
    ObservationTicket ObserveChanges(std::function<void()> _callback);

private:
    void LoadToolsFromConfig();
    void WriteToolsToConfig() const;
    void CommitChanges();

    mutable std::mutex m_ToolsLock;
    std::vector<std::shared_ptr<const ExternalTool>> m_Tools;
    const char *m_ConfigPath;
    nc::config::Config &m_Config;
    std::vector<nc::config::Token> m_ConfigObservations;
};

} // namespace nc::panel

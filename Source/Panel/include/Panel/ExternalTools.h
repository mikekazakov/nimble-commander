// Copyright (C) 2022-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "PanelData.h"

#include <Utility/ActionShortcut.h>
#include <Utility/TemporaryFileStorage.h>

#include <Base/Observable.h>
#include <Base/UUID.h>

#include <Config/Config.h>

#include <string>
#include <vector>
#include <span>
#include <mutex>
#include <compare>
#include <expected>
#include <filesystem>

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
    enum class Location : uint8_t {
        Source,
        Target,
        Left,
        Right
    };

    enum class FileInfo : uint8_t {
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
        Location location = Location::Source;
        FileInfo what = FileInfo::Filename;
        unsigned max = 0;          // maximum of selected items to use as a parameters or as a list content
        bool as_parameters = true; // as a list inside a temp file otherwise
        friend constexpr auto operator<=>(SelectedItems _lhs, SelectedItems _rhs) noexcept = default;
    };

    enum class ActionType : uint8_t {
        UserDefined,
        EnterValue,
        CurrentItem,
        SelectedItems
    };

    struct Step {
        ActionType type;
        uint16_t index;
        bool partial = false;
        Step(ActionType _type, uint16_t _index, bool _partial = false);
        friend auto operator<=>(Step _lhs, Step _rhs) noexcept = default;
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
    void InsertUserDefinedText(UserDefined _ud, bool _partial = false);
    void InsertValueRequirement(EnterValue _ev, bool _partial = false);
    void InsertCurrentItem(CurrentItem _ci, bool _partial = false);
    void InsertSelectedItem(SelectedItems _si, bool _partial = false);

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
    static std::expected<ExternalToolsParameters, std::string> Parse(std::string_view _source);

private:
};

class ExternalTool
{
public:
    enum class StartupMode : uint8_t {
        Automatic = 0,
        RunInTerminal = 1,
        RunDeatached = 2
    };
    enum class GUIArgumentInterpretation : uint8_t {
        PassAllAsArguments = 0,
        PassExistingPathsAsURLs = 1
    };

    nc::base::UUID m_UUID;
    std::string m_Title;
    std::string m_ExecutablePath; // app by bundle?
    std::string m_Parameters;
    utility::ActionShortcut m_Shorcut;
    StartupMode m_StartupMode = StartupMode::Automatic;
    GUIArgumentInterpretation m_GUIArgumentInterpretation = GUIArgumentInterpretation::PassExistingPathsAsURLs;

    friend bool operator==(const ExternalTool &_lhs, const ExternalTool &_rhs) noexcept = default;
    friend bool operator!=(const ExternalTool &_lhs, const ExternalTool &_rhs) noexcept = default;

    // run in terminal
    // allow VFS
    // string directory
};

class ExternalToolExecution
{
public:
    enum class PanelFocus : uint8_t {
        left,
        right
    };
    struct Context {
        const data::Model *left_data = nullptr;  // not retained
        const data::Model *right_data = nullptr; // not retained
        int left_cursor_pos = -1;
        int right_cursor_pos = -1;
        PanelFocus focus = PanelFocus::left;
        utility::TemporaryFileStorage *temp_storage = nullptr; // not retained
    };

    ExternalToolExecution(const Context &_ctx, const ExternalTool &_et);

    bool RequiresUserInput() const noexcept;
    std::span<const std::string> UserInputPrompts() const noexcept;
    void CommitUserInput(std::span<const std::string> _input);

    std::vector<std::string> BuildArguments() const;

    ExternalTool::StartupMode DeduceStartupMode() const;

    bool IsBundle() const;

    std::filesystem::path ExecutablePath() const;

    // returns a pid (that can already be -1 if the process quit too fast) or an error description
    // automatically deduces if the app should be started via UI (StartDetachedUI) or as headless fork
    // (StartDetachedFork)
    std::expected<pid_t, std::string> StartDetached();

    std::expected<pid_t, std::string> StartDetachedFork() const;

    std::expected<pid_t, std::string> StartDetachedUI();

private:
    Context m_Ctx;
    ExternalTool m_ET;
    ExternalToolsParameters m_Params;
    std::vector<std::string> m_UserInputPrompts;
    std::vector<std::string> m_UserInput;
};

// supposed to be thread-safe
class ExternalToolsStorage : public base::ObservableBase
{
public:
    enum class WriteChanges : uint8_t {
        Immediate,
        Background
    };

    ExternalToolsStorage(const char *_config_path,
                         nc::config::Config &_config,
                         WriteChanges _write_changes = WriteChanges::Background);

    size_t ToolsCount() const;
    std::shared_ptr<const ExternalTool> GetTool(size_t _no) const;              // will return nullptr on invalid index
    std::shared_ptr<const ExternalTool> GetTool(const base::UUID &_uuid) const; // will return nullptr on invalid uuid

    std::vector<std::shared_ptr<const ExternalTool>> GetAllTools() const;

    void ReplaceTool(ExternalTool _tool, size_t _at_index);
    void InsertTool(ExternalTool _tool); // adds tool at the end
    void RemoveTool(size_t _at_index);
    void MoveTool(size_t _at_index, size_t _to_index);

    // Generates a new unique title for a new tool
    std::string NewTitle() const;

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
    WriteChanges m_WriteChanges;
};

} // namespace nc::panel

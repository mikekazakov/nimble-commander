// Copyright (C) 2016-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

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

#include <Habanero/Observable.h>
#include <Utility/ActionShortcut.h>
#include "../../Bootstrap/Config.h"

class ExternalToolsParameters
{
public:
    enum class Location {
        Source,
        Target,
        Left,
        Right
    };
    
    enum class FileInfo {
        DirectoryPath,
        Path,
        Filename,
        FilenameWithoutExtension,
        FileExtension
    };
    
    struct UserDefined
    {
        std::string text;
    };
    
    struct EnterValue
    {
        std::string name;
    };
    
    struct CurrentItem
    {
        Location location;
        FileInfo what;
    };

    struct SelectedItems
    {
        Location    location;
        FileInfo    what;
        int         max; // maximum of selected items to use as a parameters or as a list content
        bool        as_parameters; // as a list inside a temp file otherwise
    };
    
    enum class ActionType : short
    {
        UserDefined,
        EnterValue,
        CurrentItem,
        SelectedItems
    };
    
    struct Step
    {
        ActionType  type;
        uint16_t    index;
        Step(ActionType t, uint16_t i);
    };
    
    const Step &StepNo(unsigned _number) const;
    unsigned StepsAmount() const;
    const UserDefined   &GetUserDefined  ( unsigned _index ) const;
    const EnterValue    &GetEnterValue   ( unsigned _index ) const;
    const CurrentItem   &GetCurrentItem  ( unsigned _index ) const;
    const SelectedItems &GetSelectedItems( unsigned _index ) const;
    unsigned             GetMaximumTotalFiles() const;
    
private:
    void    InsertUserDefinedText(UserDefined _ud);
    void    InsertValueRequirement(EnterValue _ev);
    void    InsertCurrentItem(CurrentItem _ci);
    void    InsertSelectedItem(SelectedItems _si);
    
    std::vector<Step>           m_Steps;
    std::vector<UserDefined>    m_UserDefined;
    std::vector<EnterValue>     m_EnterValues;
    std::vector<CurrentItem>    m_CurrentItems;
    std::vector<SelectedItems>  m_SelectedItems;
    unsigned                m_MaximumTotalFiles = 0;
    
    friend class ExternalToolsParametersParser;
};

class ExternalToolsParametersParser
{
public:
    ExternalToolsParameters Parse(const std::string &_source,
                                  std::function<void(std::string)> _parse_error = nullptr );
    
private:
};

class ExternalTool
{
public:
    enum class StartupMode : int
    {
        Automatic       = 0,
        RunInTerminal   = 1,
        RunDeatached    = 2
    };
    
    std::string     m_Title;
    std::string     m_ExecutablePath; // app by bundle?
    std::string     m_Parameters;
    nc::utility::ActionShortcut m_Shorcut;
    StartupMode     m_StartupMode = StartupMode::Automatic;
    
    bool operator==(const ExternalTool &_rhs) const;
    bool operator!=(const ExternalTool &_rhs) const;
    
    // run in terminal
    // allow VFS
    // string directory
};

// supposed to be thread-safe
class ExternalToolsStorage : public ObservableBase
{
public:
    ExternalToolsStorage(const char*_config_path);
    
    size_t                                  ToolsCount() const;
    std::shared_ptr<const ExternalTool>     GetTool(size_t _no) const; // will return nullptr on invalid index
    std::vector<std::shared_ptr<const ExternalTool>>GetAllTools() const;
    
    void                                    ReplaceTool( ExternalTool _tool, size_t _at_index );
    void                                    InsertTool( ExternalTool _tool ); // adds tool at the end
    void                                    RemoveTool( size_t _at_index );
    void                                    MoveTool( size_t _at_index, size_t _to_index );
    
    using ObservationTicket = ObservableBase::ObservationTicket;
    ObservationTicket ObserveChanges( std::function<void()> _callback );
    
private:
    void LoadToolsFromConfig();
    void WriteToolsToConfig() const;
    void CommitChanges();
    
    mutable spinlock                                m_ToolsLock;
    std::vector<std::shared_ptr<const ExternalTool>>m_Tools;
    const char*                                     m_ConfigPath;
    std::vector<nc::config::Token>                  m_ConfigObservations;
};


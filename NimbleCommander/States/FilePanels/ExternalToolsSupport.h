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

#include "../../../Files/ActionShortcut.h"
#include "../../../Files/Config.h"

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
        string text;
    };
    
    struct EnterValue
    {
        string name;
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
    
    vector<Step>            m_Steps;
    vector<UserDefined>     m_UserDefined;
    vector<EnterValue>      m_EnterValues;
    vector<CurrentItem>     m_CurrentItems;
    vector<SelectedItems>   m_SelectedItems;
    unsigned                m_MaximumTotalFiles = 0;
    
    friend class ExternalToolsParametersParser;
};

class ExternalToolsParametersParser
{
public:
    ExternalToolsParameters Parse( const string &_source, function<void(string)> _parse_error = nullptr );
    
private:
};

class ExternalTool
{
public:
    string          m_Title;
    string          m_ExecutablePath; // app by bundle?
    string          m_Parameters;
    ActionShortcut  m_Shorcut;
    
    bool operator==(const ExternalTool &_rhs) const;
    bool operator!=(const ExternalTool &_rhs) const;
    
    // run in terminal
    // allow VFS
    // string directory
};

// supposed to be thread-safe
class ExternalToolsStorage
{
public:
    ExternalToolsStorage(const char*_config_path);
    
    size_t                                  ToolsCount() const;
    shared_ptr<const ExternalTool>          GetTool(size_t _no) const; // will return nullptr on invalid index
    vector<shared_ptr<const ExternalTool>>  GetAllTools() const;
    
    void                                    ReplaceTool( ExternalTool _tool, size_t _at_index );
    void                                    InsertTool( ExternalTool _tool ); // adds tool at the end
    void                                    RemoveTool( size_t _at_index );
    void                                    MoveTool( size_t _at_index, size_t _to_index );
    
    struct ChangesObserver
    {
        function<void()>    callback;
        bool                enabled = true;
    };
    
    shared_ptr<ChangesObserver>             ObserveChanges( function<void()> _callback );
    
private:
    void LoadToolsFromConfig();
    void FireObservers();
    
    mutable spinlock                                m_ToolsLock;
    vector<shared_ptr<const ExternalTool>>          m_Tools;
    const char*                                     m_ConfigPath;
    vector<GenericConfig::ObservationTicket>        m_ConfigObservations;
    mutable spinlock                                m_ObserversLock;
    vector<weak_ptr<ChangesObserver>>               m_Observers;
};


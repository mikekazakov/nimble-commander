// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ExecuteExternalTool.h"
#include "../ExternalToolsSupport.h"
#include <boost/algorithm/string/replace.hpp>
#include <VFS/VFS.h>
#include <VFS/Native.h>
#include "../PanelController.h"
#include "../PanelView.h"
#include "../MainWindowFilePanelState.h"
#include <NimbleCommander/Core/TemporaryNativeFileStorage.h>
#include <NimbleCommander/Bootstrap/ActivationManager.h>
#include <NimbleCommander/States/MainWindowController.h>
#include <NimbleCommander/Core/AnyHolder.h>
#include <Term/Task.h>
#include "../ExternalToolParameterValueSheetController.h"

namespace nc::panel::actions {
    
static string EscapeSpaces(string _str);
static string UnescapeSpaces(string _str);
static vector<string> SplitByEscapedSpaces( const string &_str );
static string ExtractParamInfoFromListingItem(ExternalToolsParameters::FileInfo _what,
                                              const VFSListingItem &_i );
static string ExtractParamInfoFromContext(ExternalToolsParameters::FileInfo _what,
                                          PanelController *_pc );
static string CombineStringsIntoEscapedSpaceSeparatedString( const vector<string> &_l );
static string CombineStringsIntoNewlineSeparatedString( const vector<string> &_l );
static bool IsBundle( const string& _path );
static string GetExecutablePathForBundle( const string& _path );
static vector<string> FindEnterValueParameters(const ExternalToolsParameters &_p);
static PanelController *ExternalToolParametersContextFromLocation
    (ExternalToolsParameters::Location _loc,
     MainWindowFilePanelState *_target);
static string BuildParametersStringForExternalTool(const ExternalToolsParameters&_par,
                                                   const vector<string>& _entered_values,
                                                   MainWindowFilePanelState *_target);
static void RunExtTool(const ExternalTool &_tool,
                       const string& _cooked_params,
                       MainWindowFilePanelState *_target);
    
void ExecuteExternalTool::Perform( MainWindowFilePanelState *_target, id _sender ) const
{
    if( [_sender respondsToSelector:@selector(representedObject)] ) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wstrict-selector-match"
        id rep_obj = [_sender representedObject];
#pragma clang diagnostic pop
        if( auto any_holder = objc_cast<AnyHolder>(rep_obj) )
            if( auto tool = any_cast<shared_ptr<const ExternalTool>>(&any_holder.any) )
                if( tool->get() )
                    Execute(*tool->get(), _target);
    }
}
    
void ExecuteExternalTool::Execute(const ExternalTool &_tool,
                                  MainWindowFilePanelState *_target) const
{
    dispatch_assert_main_queue();
    
    // do nothing for invalid tools
    if( _tool.m_ExecutablePath.empty() )
        return;
    
    auto parameters = ExternalToolsParametersParser().Parse(_tool.m_Parameters);
    vector<string> enter_values_names = FindEnterValueParameters(parameters);
    
    if( enter_values_names.empty() ) {
        string cooked_parameters = BuildParametersStringForExternalTool(parameters, {}, _target);
        RunExtTool(_tool, cooked_parameters, _target);
    }
    else {
        auto sheet = [[ExternalToolParameterValueSheetController alloc] initWithValueNames:enter_values_names];
        [sheet beginSheetForWindow:_target.window completionHandler:^(NSModalResponse returnCode) {
            if( returnCode == NSModalResponseOK ) {
                string cooked_parameters = BuildParametersStringForExternalTool(parameters, sheet.values, _target);
                RunExtTool(_tool, cooked_parameters, _target);
            }
        }];
    }
    
        
}

    

static string EscapeSpaces(string _str)
{
    boost::replace_all(_str, " ", "\\ ");
    return _str;
}

static string UnescapeSpaces(string _str)
{
    boost::replace_all(_str, "\\ ",  " ");
    return _str;
}

static vector<string> SplitByEscapedSpaces( const string &_str )
{
    vector<string> results;
    if( !_str.empty() )
        results.emplace_back();
    
    char prev = 0;
    for( auto c: _str ) {
        if( c == ' ' ) {
            if( prev == '\\' )
                results.back().push_back(' ');
            else {
                if( !results.back().empty() )
                    results.emplace_back();
            }
        }
        else {
            results.back().push_back(c);
        }
        prev = c;
    }

    if( !results.empty() && results.back().empty() )
        results.pop_back();
    
    return results;
}

static string ExtractParamInfoFromListingItem(ExternalToolsParameters::FileInfo _what,
                                              const VFSListingItem &_i )
{
    if( !_i )
        return {};
    
    if( _what == ExternalToolsParameters::FileInfo::Path )
        return _i.Path();
    if( _what == ExternalToolsParameters::FileInfo::Filename )
        return _i.Filename();
    if( _what == ExternalToolsParameters::FileInfo::FilenameWithoutExtension )
        return _i.FilenameWithoutExt();
    if( _what == ExternalToolsParameters::FileInfo::FileExtension )
        return _i.ExtensionIfAny();
    if( _what == ExternalToolsParameters::FileInfo::DirectoryPath )
        return _i.Directory();
    
    return {};
}

static string ExtractParamInfoFromContext(ExternalToolsParameters::FileInfo _what,
                                          PanelController *_pc )
{
    if( !_pc )
        return {};
    
    if( _what == ExternalToolsParameters::FileInfo::DirectoryPath )
        if( _pc.isUniform)
            return _pc.currentDirectoryPath;
    
    return {};
}

static string CombineStringsIntoEscapedSpaceSeparatedString( const vector<string> &_l )
{
    string result;
    if( !_l.empty() )
        result += EscapeSpaces(_l.front());
    for( size_t i = 1, e = _l.size(); i < e; ++i )
        result += " "s + EscapeSpaces(_l[i]);
    return result;
}

static string CombineStringsIntoNewlineSeparatedString( const vector<string> &_l )
{
    string result;
    if( !_l.empty() )
        result += _l.front();
    for( size_t i = 1, e = _l.size(); i < e; ++i )
        result += "\n"s + _l[i];
    return result;
}

static bool IsBundle( const string& _path )
{
    NSBundle *b = [NSBundle bundleWithPath:[NSString stringWithUTF8StdString:_path]];
    return b != nil;
}

static string GetExecutablePathForBundle( const string& _path )
{
    NSBundle *b = [NSBundle bundleWithPath:[NSString stringWithUTF8StdString:_path]];
    if( !b )
        return "";
    NSURL *u = b.executableURL;
    if( !u )
        return "";
    const char *fsr = u.fileSystemRepresentation;
    if( !fsr )
        return "";
    return fsr;
}

static vector<string> FindEnterValueParameters(const ExternalToolsParameters &_p)
{
    vector<string> ev;
    for( int i = 0, e = (int)_p.StepsAmount(); i != e; ++i )
        if( _p.StepNo(i).type == ExternalToolsParameters::ActionType::EnterValue )
            ev.emplace_back( _p.GetEnterValue(_p.StepNo(i).index).name  );
    return ev;
}

static bool IsRunnableExecutable( const string &_path )
{
    VFSStat st;
    return VFSNativeHost::SharedHost()->Stat(_path.c_str(), st, 0, nullptr) == VFSError::Ok &&
        st.mode_bits.reg  &&
        st.mode_bits.rusr &&
        st.mode_bits.xusr ;
}

static void RunExtTool(const ExternalTool &_tool,
                       const string& _cooked_params,
                       MainWindowFilePanelState *_target)
{
    dispatch_assert_main_queue();
    auto startup_mode = _tool.m_StartupMode;
    const bool tool_is_bundle = IsBundle( _tool.m_ExecutablePath );
    
    if( startup_mode == ExternalTool::StartupMode::Automatic ) {
        if( tool_is_bundle )
            startup_mode = ExternalTool::StartupMode::RunDeatached;
        else
            startup_mode = ExternalTool::StartupMode::RunInTerminal;
    }
    
    if( startup_mode == ExternalTool::StartupMode::RunInTerminal ) {
        if( !ActivationManager::Instance().HasTerminal() )
            return;
        
        if( tool_is_bundle ) {
            // bundled UI tool starting in terminal
            string exec_path = _tool.m_ExecutablePath;
            if( !IsRunnableExecutable(exec_path) )
                exec_path = GetExecutablePathForBundle(_tool.m_ExecutablePath);

            [(NCMainWindowController*)_target.window.delegate requestTerminalExecutionWithFullPath:exec_path.c_str()
                                                                               withParameters:_cooked_params.c_str()];
        }
        else {
            // console tool starting in terminal
            [(NCMainWindowController*)_target.window.delegate requestTerminalExecutionWithFullPath:_tool.m_ExecutablePath.c_str()
                                                                               withParameters:_cooked_params.c_str()];
        }
    }
    else if( startup_mode == ExternalTool::StartupMode::RunDeatached ) {
        auto pars = SplitByEscapedSpaces(_cooked_params);
        for(auto &s: pars)
            s = UnescapeSpaces(s);
        
        if( tool_is_bundle ) {
            // regular UI start
            
            NSURL *app_url = [NSURL fileURLWithPath:[NSString stringWithUTF8StdString:_tool.m_ExecutablePath]];
            
            NSMutableArray *params_url = [NSMutableArray new];
            NSMutableArray *params_text = [NSMutableArray new];
            for( auto &s: pars) {
                if( !s.empty() &&
                   s.front() == '/' &&
                   VFSNativeHost::SharedHost()->Exists(s.c_str()) )
                    [params_url addObject:[NSURL fileURLWithPath:[NSString stringWithUTF8StdString:s]]];
                else
                    [params_text addObject:[NSString stringWithUTF8StdString:s]];
            }
            
            [NSWorkspace.sharedWorkspace openURLs:params_url
                             withApplicationAtURL:app_url
                                          options:0
                                    configuration:@{NSWorkspaceLaunchConfigurationArguments: params_text}
                                            error:nil];
        }
        else {
            // need to start a console tool in background
            nc::term::Task::RunDetachedProcess(_tool.m_ExecutablePath, pars);
        }
    }
}

static PanelController *ExternalToolParametersContextFromLocation(ExternalToolsParameters::Location _loc,
                                                                  MainWindowFilePanelState *_target)
{
    dispatch_assert_main_queue();
    if( _loc == ExternalToolsParameters::Location::Left )
        return _target.leftPanelController;
    if( _loc == ExternalToolsParameters::Location::Right )
        return _target.rightPanelController;
    if( _loc == ExternalToolsParameters::Location::Source )
        return _target.activePanelController;
    if( _loc == ExternalToolsParameters::Location::Target )
        return _target.oppositePanelController;
    return nil;
}

static string BuildParametersStringForExternalTool(const ExternalToolsParameters&_par,
                                                   const vector<string>& _entered_values,
                                                   MainWindowFilePanelState *_target)
{
    dispatch_assert_main_queue();
    
    // TODO: there's no VFS files fetching currently.
    // this should be async!
    string params;
    int max_files_left = _par.GetMaximumTotalFiles() ? _par.GetMaximumTotalFiles() : numeric_limits<int>::max();
    
    for( unsigned n = 0; n < _par.StepsAmount(); ++n ) {
        auto step = _par.StepNo(n);
        if( step.type == ExternalToolsParameters::ActionType::UserDefined ) {
            auto &v = _par.GetUserDefined(step.index);
            params += v.text;
        }
        else if( step.type == ExternalToolsParameters::ActionType::EnterValue ) {
            if( step.index < _entered_values.size() )
                params += _entered_values.at(step.index);
        }
        else if( step.type == ExternalToolsParameters::ActionType::CurrentItem ) {
            auto &v = _par.GetCurrentItem(step.index);
            if( PanelController *context = ExternalToolParametersContextFromLocation(v.location, _target) )
                if( max_files_left > 0 ) {
                    if( auto entry = context.view.item )
                        params += EscapeSpaces( ExtractParamInfoFromListingItem( v.what, entry ) );
                    else
                        params += EscapeSpaces( ExtractParamInfoFromContext( v.what, context ) );
                    max_files_left--;
                }
        }
        else if( step.type == ExternalToolsParameters::ActionType::SelectedItems ) {
            auto &v = _par.GetSelectedItems(step.index);
            if( PanelController *context = ExternalToolParametersContextFromLocation(v.location, _target) ) {
                auto selected_items = context.selectedEntriesOrFocusedEntry;
                if( v.max > 0 && v.max < (int)selected_items.size() )
                    selected_items.resize( v.max );
                if( (int)selected_items.size() > max_files_left )
                    selected_items.resize( max_files_left );
            
                if( !selected_items.empty() ) {
                    vector<string> selected_info;
                    for( auto &i: selected_items )
                        selected_info.emplace_back( ExtractParamInfoFromListingItem(v.what, i) );
                    
                    if( v.as_parameters ) {
                        params += CombineStringsIntoEscapedSpaceSeparatedString( selected_info );
                        
                    }
                    else {
                        string file = CombineStringsIntoNewlineSeparatedString(selected_info);
                        if( auto list_name = TemporaryNativeFileStorage::Instance().WriteStringIntoTempFile(file) )
                            params += *list_name;
                    }
                    
                    max_files_left -= selected_items.size();
                }
            }
        }
    }

    return params;
}
    
}

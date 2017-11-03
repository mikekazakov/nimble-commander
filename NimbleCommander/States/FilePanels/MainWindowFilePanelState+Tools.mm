// Copyright (C) 2016-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include <boost/algorithm/string/replace.hpp>
#include "ExternalToolsSupport.h"
#include <VFS/Native.h>
#include "PanelController.h"
#include "PanelView.h"
#include "MainWindowFilePanelState+Tools.h"
#include <NimbleCommander/Core/TemporaryNativeFileStorage.h>
#include <NimbleCommander/States/MainWindowController.h>
#include <NimbleCommander/Bootstrap/AppDelegate.h>
#include "ExternalToolParameterValueSheetController.h"
#include <NimbleCommander/Bootstrap/ActivationManager.h>
#include <Term/Task.h>

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

static string ExtractParamInfoFromListingItem( ExternalToolsParameters::FileInfo _what, const VFSListingItem &_i )
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

@implementation MainWindowFilePanelState (ToolsSupport)

- (void) runExtTool:(shared_ptr<const ExternalTool>)_tool
{
    dispatch_assert_main_queue();
    if( !_tool )
        return;
    
    auto &et = *_tool;
    
    // do nothing for invalid tools
    if( et.m_ExecutablePath.empty() )
        return;
    
    auto parameters = ExternalToolsParametersParser().Parse(et.m_Parameters);
    vector<string> enter_values_names = FindEnterValueParameters(parameters);
    
    if( enter_values_names.empty() ) {
        string cooked_parameters = [self buildParametersStringForExternalTool:parameters userEnteredValues:{}];
        [self runExtTool:_tool withCookedParameters:cooked_parameters];
    }
    else {
        ExternalToolParameterValueSheetController *sheet = [[ExternalToolParameterValueSheetController alloc] initWithValueNames:enter_values_names];
        [sheet beginSheetForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
            if( returnCode == NSModalResponseOK ) {
                string cooked_parameters = [self buildParametersStringForExternalTool:parameters userEnteredValues:sheet.values];
                [self runExtTool:_tool withCookedParameters:cooked_parameters];
            }
        }];
    }
}

static bool IsRunnableExecutable( const string &_path )
{
    VFSStat st;
    return VFSNativeHost::SharedHost()->Stat(_path.c_str(), st, 0, nullptr) == VFSError::Ok &&
        st.mode_bits.reg  &&
        st.mode_bits.rusr &&
        st.mode_bits.xusr ;
}

- (void) runExtTool:(shared_ptr<const ExternalTool>)_tool withCookedParameters:(const string&)_cooked_params
{
    dispatch_assert_main_queue();
    auto &et = *_tool;
    auto startup_mode = et.m_StartupMode;
    const bool tool_is_bundle = IsBundle( et.m_ExecutablePath );
    
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
            string exec_path = et.m_ExecutablePath;
            if( !IsRunnableExecutable(exec_path) )
                exec_path = GetExecutablePathForBundle(et.m_ExecutablePath);

            [(MainWindowController*)self.window.delegate requestTerminalExecutionWithFullPath:exec_path.c_str()
                                                                               withParameters:_cooked_params.c_str()];
        }
        else {
            // console tool starting in terminal
            [(MainWindowController*)self.window.delegate requestTerminalExecutionWithFullPath:et.m_ExecutablePath.c_str()
                                                                               withParameters:_cooked_params.c_str()];
        }
    }
    else if( startup_mode == ExternalTool::StartupMode::RunDeatached ) {
        auto pars = SplitByEscapedSpaces(_cooked_params);
        for(auto &s: pars)
            s = UnescapeSpaces(s);
        
        if( tool_is_bundle ) {
            // regular UI start
            
            NSURL *app_url = [NSURL fileURLWithPath:[NSString stringWithUTF8StdString:et.m_ExecutablePath]];
            
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
            nc::term::Task::RunDetachedProcess(et.m_ExecutablePath, pars);
        }
    }
}

- (PanelController *) externalToolParametersContextFromLocation:(ExternalToolsParameters::Location) _loc
{
    dispatch_assert_main_queue();
    if( _loc == ExternalToolsParameters::Location::Left )
        return self.leftPanelController;
    if( _loc == ExternalToolsParameters::Location::Right )
        return self.rightPanelController;
    if( _loc == ExternalToolsParameters::Location::Source )
        return self.activePanelController;
    if( _loc == ExternalToolsParameters::Location::Target )
        return self.oppositePanelController;
    return nil;
}

- (string)buildParametersStringForExternalTool:(const ExternalToolsParameters&)_par userEnteredValues:(const vector<string>&)_entered_values
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
            if( PanelController *context = [self externalToolParametersContextFromLocation:v.location] )
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
            if( PanelController *context = [self externalToolParametersContextFromLocation:v.location] ) {
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

@end

#include <boost/algorithm/string/replace.hpp>
#include "../NimbleCommander/States/FilePanels/ExternalToolsSupport.h"
#include "vfs/vfs_native.h"
#include "PanelController.h"
#include "PanelView.h"
#include "MainWindowFilePanelState+Tools.h"
#include "TemporaryNativeFileStorage.h"
#include "MainWindowController.h"
#include "AppDelegate.h"

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

static bool ShouldStartToolInTerminal( const string& _path )
{
    NSBundle *b = [NSBundle bundleWithPath:[NSString stringWithUTF8StdString:_path]];
    if( b != nil )
        return false;
    
    return true;
}

//static string WriteStringIntoTemporaryFile()

//vector<string> selected_info;
//for( auto &i: selected_items )
//selected_info.emplace_back( ExtractParamInfoFromListingItem(v.what, i) );
//
//if( v.as_parameters ) {
//    for( auto &s: selected_info )
//        params += EscapeSpaces(s) + " ";


@implementation MainWindowFilePanelState (ToolsSupport)

- (void) runExtTool:(shared_ptr<const ExternalTool>)_tool
{
    if( !_tool )
        return;
    
//    auto s = "\\";

//    if( AppDelegate.me.externalTools.ToolsCount() == 0 )
//        return;
    auto et = *_tool;
    
//    ExternalTool et;
////    et.m_ExecutablePath = "/Applications/TextEdit.app";
//    et.m_ExecutablePath = "/bin/ls";
//    
/////Applications/TextEdit.app/Contents/MacOS/TextEdit -NSShowAllViews YES
//    
////    et.m_ExecutablePath = "/Applications/Sublime Text.app";
////    et.m_Parameters = "abra cadabra\\ forever!!! %LP";
////    et.m_Parameters = "-NSShowAllViews YES %5-LP";
//    
//    et.m_Parameters = "-alh %P";

    //    -NSShowAllViews YES

    auto parameters = ExternalToolsParametersParser().Parse(et.m_Parameters);
    string cooked_parameters = [self buildParametersStringForExternalTool:parameters];
    
    bool in_terminal = ShouldStartToolInTerminal( et.m_ExecutablePath );
    
//    + (NSURL *)
    
    
//    m_ExecutablePath
    //Handle url==nil
//    NSError *error = nil;
    
    // think: launchApplication vs openURL
    
    //UnescapeSpaces
    
//    NSArray *arguments = [NSArray arrayWithObjects:[NSString stringWithUTF8StdString:cooked_parameters], nil];
//    [workspace launchApplicationAtURL:url
//                              options:/*NSWorkspaceLaunchNewInstance*/0
//                        configuration:[NSDictionary dictionaryWithObject:arguments forKey:NSWorkspaceLaunchConfigurationArguments]
//                                error:nil];
    
//    if( true ) // some flags?
//    {
//        NSMutableArray *params = [NSMutableArray new];
//        for( auto &s: pars)
//            [params addObject:[NSString stringWithUTF8StdString:s]];
//        
//        [workspace launchApplicationAtURL:url
//                                  options:/*NSWorkspaceLaunchNewInstance*/0
//                            configuration:[NSDictionary dictionaryWithObject:params forKey:NSWorkspaceLaunchConfigurationArguments]
//                                    error:nil];
//    }
    
    
    // if only filepaths generated by NC
//    if( false )
//    {
//        NSMutableArray *urls = [NSMutableArray new];
//        for( auto &s: pars)
//            [urls addObject:[NSURL fileURLWithPath:[NSString stringWithUTF8StdString:s]]];
//        
//        [workspace openURLs:urls
//       withApplicationAtURL:url
//                    options:0
//              configuration:@{}
//                      error:nil];
//    }
    
    if( in_terminal ) {
        [(MainWindowController*)self.window.delegate requestTerminalExecutionWithFullPath:et.m_ExecutablePath.c_str()
                                                                           withParameters:cooked_parameters.c_str()];
    }

    if( !in_terminal ) {
        auto pars = SplitByEscapedSpaces(cooked_parameters);
        for(auto &s: pars)
            s = UnescapeSpaces(s);
        
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
    
    
//- (nullable NSRunningApplication *)openURLs:(NSArray<NSURL *> *)urls
//   
//   withApplicationAtURL:(NSURL *)applicationURL
//                options:(NSWorkspaceLaunchOptions)options
//          configuration:(NSDictionary<NSString *, id> *)configuration
//                  error:(NSError **)error NS_AVAILABLE_MAC(10_10);
     
    
//- (nullable NSRunningApplication *)openURL:(NSURL *)url options:(NSWorkspaceLaunchOptions)options configuration:(NSDictionary<NSString *, id> *)configuration error:(NSError **)error NS_AVAILABLE_MAC(10_10);
    
    //Handle error
    
}

- (PanelController *) externalToolParametersContextFromLocation:(ExternalToolsParameters::Location) _loc
{
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



- (string)buildParametersStringForExternalTool:(const ExternalToolsParameters&)_par
{
    // TODO: there's no VFS files fetching currently.
    // this should be async!
    string params;
    
    for( unsigned n = 0; n < _par.StepsAmount(); ++n ) {
        auto step = _par.StepNo(n);
        if( step.type == ExternalToolsParameters::ActionType::UserDefined ) {
            auto &v = _par.GetUserDefined(step.index);
            params += v.text;
        }
        else if( step.type == ExternalToolsParameters::ActionType::EnterValue ) {
            // later, onvolves more complex architecture
            
        }
        else if( step.type == ExternalToolsParameters::ActionType::CurrentItem ) {
            auto &v = _par.GetCurrentItem(step.index);
            if( PanelController *context = [self externalToolParametersContextFromLocation:v.location] ) {
                params += EscapeSpaces( ExtractParamInfoFromListingItem( v.what, context.view.item ) );
            }
        }
        else if( step.type == ExternalToolsParameters::ActionType::SelectedItems ) {
            auto &v = _par.GetSelectedItems(step.index);
            if( PanelController *context = [self externalToolParametersContextFromLocation:v.location] ) {
                auto selected_items = context.selectedEntriesOrFocusedEntry;
                if( v.max > 0 && v.max < selected_items.size() )
                    selected_items.resize( v.max );
            
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
            }
        }
    }

    return params;
}

@end

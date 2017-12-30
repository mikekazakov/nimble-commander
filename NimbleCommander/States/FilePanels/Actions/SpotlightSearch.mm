// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include <boost/algorithm/string/replace.hpp>
#include <boost/algorithm/string/split.hpp>
#include <Habanero/algo.h>
#include <VFS/Native.h>
#include <VFS/VFSListingInput.h>
#include "../PanelController.h"
#include "../Views/SpotlightSearchPopupViewController.h"
#include "SpotlightSearch.h"
#include <NimbleCommander/Bootstrap/Config.h>
#include "../PanelView.h"

namespace nc::panel::actions {

static const auto g_ConfigSpotlightFormat = "filePanel.spotlight.format";
static const auto g_ConfigSpotlightMaxCount = "filePanel.spotlight.maxCount";

static string CookSpotlightSearchQuery( const string& _format, const string &_input )
{
    bool should_split =
        _format.find("#{query1}") != string::npos ||
        _format.find("#{query2}") != string::npos ||
        _format.find("#{query3}") != string::npos ||
        _format.find("#{query4}") != string::npos ||
        _format.find("#{query5}") != string::npos ||
        _format.find("#{query6}") != string::npos ||
        _format.find("#{query7}") != string::npos ||
        _format.find("#{query8}") != string::npos ||
        _format.find("#{query9}") != string::npos;
    
    if( !should_split )
        return boost::replace_all_copy( _format, "#{query}", _input );

    vector<string> words;
    boost::split(words,
                 _input,
                 [](char _c){ return _c == ' ';},
                 boost::token_compress_on
                 );
    
    string result = _format;
    boost::replace_all(result, "#{query}" , _input );
    boost::replace_all(result, "#{query1}", words.size() > 0 ? words[0] : "" );
    boost::replace_all(result, "#{query2}", words.size() > 1 ? words[1] : "" );
    boost::replace_all(result, "#{query3}", words.size() > 2 ? words[2] : "" );
    boost::replace_all(result, "#{query4}", words.size() > 3 ? words[3] : "" );
    boost::replace_all(result, "#{query5}", words.size() > 4 ? words[4] : "" );
    boost::replace_all(result, "#{query6}", words.size() > 5 ? words[5] : "" );
    boost::replace_all(result, "#{query7}", words.size() > 6 ? words[6] : "" );
    boost::replace_all(result, "#{query8}", words.size() > 7 ? words[7] : "" );
    boost::replace_all(result, "#{query9}", words.size() > 8 ? words[8] : "" );
    
    return result;
}

static vector<string> FetchSpotlightResults(const string& _query)
{
    string format = CookSpotlightSearchQuery( GlobalConfig().GetString(g_ConfigSpotlightFormat).value_or("kMDItemFSName == '*#{query}*'cd"),
                                              _query );
    
    MDQueryRef query = MDQueryCreate( nullptr, (CFStringRef)[NSString stringWithUTF8StdString:format], nullptr, nullptr );
    if( !query )
        return {};
    auto clear_query = at_scope_end([=]{ CFRelease(query); });
    
    MDQuerySetMaxCount( query, GlobalConfig().GetInt(g_ConfigSpotlightMaxCount) );
    
    Boolean query_result = MDQueryExecute( query, kMDQuerySynchronous );
    if( !query_result)
        return {};
    
    vector<string> result;
    for( long i = 0, e = MDQueryGetResultCount( query ); i < e; ++i ) {

        MDItemRef item = (MDItemRef)MDQueryGetResultAtIndex( query, i );
        
        CFStringRef item_path = (CFStringRef)MDItemCopyAttribute(item, kMDItemPath);
        auto clear_item_path = at_scope_end([=]{ CFRelease(item_path); });
        
        result.emplace_back( CFStringGetUTF8StdString(item_path) );
    }

    // make results unique - spotlight sometimes produces duplicates
    sort( begin(result), end(result) );
    result.erase( unique(begin(result), end(result)), result.end() );
    
    return result;
}

static shared_ptr<VFSListing> FetchSearchResultsAsListing(const vector<string> &_file_paths,
                                                          VFSHost &_vfs,
                                                          unsigned long _fetch_flags,
                                                          const VFSCancelChecker &_cancel_checker)
{
    vector<VFSListingPtr> listings;
    
    for( auto &p: _file_paths ) {
        VFSListingPtr listing;
        int ret = _vfs.FetchSingleItemListing( p.c_str(), listing, _fetch_flags, _cancel_checker);
        if( ret == 0 )
            listings.emplace_back( listing );
    }

    return VFSListing::Build( VFSListing::Compose(listings) );
}

void SpotlightSearch::Perform( PanelController *_target, id _sender ) const
{
    const auto view = [[SpotlightSearchPopupViewController alloc] init];
    __weak PanelController *wp = _target;
    view.handler = [wp](const string& _query){
        if( PanelController *panel = wp ) {
            auto task = [=]( const function<bool()> &_cancelled ) {
                if( auto l = FetchSearchResultsAsListing(FetchSpotlightResults(_query),
                                                         *VFSNativeHost::SharedHost(),
                                                         panel.vfsFetchingFlags,
                                                         _cancelled
                                                         ) )
                    dispatch_to_main_queue([=]{
                        [panel loadListing:l];
                    });
            };
            [panel commitCancelableLoadingTask:move(task)];
        }
    };
    
    [_target.view showPopoverUnderPathBarWithView:view andDelegate:view];
}

};

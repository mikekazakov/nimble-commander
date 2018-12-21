// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "SpotlightSearch.h"
#include <boost/algorithm/string/replace.hpp>
#include <boost/algorithm/string/split.hpp>
#include <Habanero/algo.h>
#include <VFS/Native.h>
#include <VFS/VFSListingInput.h>
#include "../PanelController.h"
#include "../Views/SpotlightSearchPopupViewController.h"
#include <NimbleCommander/Bootstrap/Config.h>
#include "../PanelView.h"
#include <Utility/StringExtras.h>
#include <Habanero/dispatch_cpp.h>

namespace nc::panel::actions {

static const auto g_ConfigSpotlightFormat = "filePanel.spotlight.format";
static const auto g_ConfigSpotlightMaxCount = "filePanel.spotlight.maxCount";

static std::string CookSpotlightSearchQuery( const std::string& _format, const std::string &_input )
{
    const auto npos = std::string::npos;
    bool should_split =
        _format.find("#{query1}") != npos ||
        _format.find("#{query2}") != npos ||
        _format.find("#{query3}") != npos ||
        _format.find("#{query4}") != npos ||
        _format.find("#{query5}") != npos ||
        _format.find("#{query6}") != npos ||
        _format.find("#{query7}") != npos ||
        _format.find("#{query8}") != npos ||
        _format.find("#{query9}") != npos;
    
    if( !should_split )
        return boost::replace_all_copy( _format, "#{query}", _input );

    std::vector<std::string> words;
    boost::split(words,
                 _input,
                 [](char _c){ return _c == ' ';},
                 boost::token_compress_on
                 );
    
    std::string result = _format;
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

static std::vector<std::string> FetchSpotlightResults(const std::string& _query)
{
    auto fmt = GlobalConfig().Has(g_ConfigSpotlightFormat) ? 
        GlobalConfig().GetString(g_ConfigSpotlightFormat) : 
        "kMDItemFSName == '*#{query}*'cd";
    
    std::string format = CookSpotlightSearchQuery( fmt, _query );
    
    MDQueryRef query = MDQueryCreate( nullptr, (CFStringRef)[NSString stringWithUTF8StdString:format], nullptr, nullptr );
    if( !query )
        return {};
    auto clear_query = at_scope_end([=]{ CFRelease(query); });
    
    MDQuerySetMaxCount( query, GlobalConfig().GetInt(g_ConfigSpotlightMaxCount) );
    
    Boolean query_result = MDQueryExecute( query, kMDQuerySynchronous );
    if( !query_result)
        return {};
    
    std::vector<std::string> result;
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

static std::shared_ptr<VFSListing> FetchSearchResultsAsListing
    (const std::vector<std::string> &_file_paths,
     VFSHost &_vfs,
     unsigned long _fetch_flags,
     const VFSCancelChecker &_cancel_checker)
{
    std::vector<VFSListingPtr> listings;
    
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
    view.handler = [wp](const std::string& _query){
        if( PanelController *panel = wp ) {
            auto task = [=]( const std::function<bool()> &_cancelled ) {
                if( auto l = FetchSearchResultsAsListing(FetchSpotlightResults(_query),
                                                         *VFSNativeHost::SharedHost(),
                                                         panel.vfsFetchingFlags,
                                                         _cancelled
                                                         ) )
                    dispatch_to_main_queue([=]{
                        [panel loadListing:l];
                    });
            };
            [panel commitCancelableLoadingTask:std::move(task)];
        }
    };
    
    [_target.view showPopoverUnderPathBarWithView:view andDelegate:view];
}

};

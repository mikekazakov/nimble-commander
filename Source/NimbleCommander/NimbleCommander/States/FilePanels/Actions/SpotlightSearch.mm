// Copyright (C) 2017-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "SpotlightSearch.h"
#include <Base/algo.h>
#include <VFS/Native.h>
#include <VFS/VFSListingInput.h>
#include "../PanelController.h"
#include "../Views/SpotlightSearchPopupViewController.h"
#include <NimbleCommander/Bootstrap/Config.h>
#include <NimbleCommander/Bootstrap/NativeVFSHostInstance.h>
#include "../PanelView.h"
#include <Utility/StringExtras.h>
#include <Base/dispatch_cpp.h>

#include <algorithm>

namespace nc::panel::actions {

static const auto g_ConfigSpotlightFormat = "filePanel.spotlight.format";
static const auto g_ConfigSpotlightMaxCount = "filePanel.spotlight.maxCount";

static std::string CookSpotlightSearchQuery(const std::string &_format, const std::string &_input)
{
    const auto npos = std::string::npos;
    const bool should_split =
        _format.find("#{query1}") != npos || _format.find("#{query2}") != npos || _format.find("#{query3}") != npos ||
        _format.find("#{query4}") != npos || _format.find("#{query5}") != npos || _format.find("#{query6}") != npos ||
        _format.find("#{query7}") != npos || _format.find("#{query8}") != npos || _format.find("#{query9}") != npos;

    if( !should_split )
        return base::ReplaceAll(_format, "#{query}", _input);

    const std::vector<std::string> words = base::SplitByDelimiters(_input, " ");

    std::string result = _format;
    result = base::ReplaceAll(result, "#{query}", _input);
    result = base::ReplaceAll(result, "#{query1}", !words.empty() ? words[0] : "");
    result = base::ReplaceAll(result, "#{query2}", words.size() > 1 ? words[1] : "");
    result = base::ReplaceAll(result, "#{query3}", words.size() > 2 ? words[2] : "");
    result = base::ReplaceAll(result, "#{query4}", words.size() > 3 ? words[3] : "");
    result = base::ReplaceAll(result, "#{query5}", words.size() > 4 ? words[4] : "");
    result = base::ReplaceAll(result, "#{query6}", words.size() > 5 ? words[5] : "");
    result = base::ReplaceAll(result, "#{query7}", words.size() > 6 ? words[6] : "");
    result = base::ReplaceAll(result, "#{query8}", words.size() > 7 ? words[7] : "");
    result = base::ReplaceAll(result, "#{query9}", words.size() > 8 ? words[8] : "");

    return result;
}

static std::vector<std::string> FetchSpotlightResults(const std::string &_query)
{
    auto fmt = GlobalConfig().Has(g_ConfigSpotlightFormat) ? GlobalConfig().GetString(g_ConfigSpotlightFormat)
                                                           : "kMDItemFSName == '*#{query}*'cd";

    const std::string format = CookSpotlightSearchQuery(fmt, _query);

    MDQueryRef query =
        MDQueryCreate(nullptr, static_cast<CFStringRef>([NSString stringWithUTF8StdString:format]), nullptr, nullptr);
    if( !query )
        return {};
    auto clear_query = at_scope_end([=] { CFRelease(query); });

    MDQuerySetMaxCount(query, GlobalConfig().GetInt(g_ConfigSpotlightMaxCount));

    const Boolean query_result = MDQueryExecute(query, kMDQuerySynchronous);
    if( !query_result )
        return {};

    std::vector<std::string> result;
    for( long i = 0, e = MDQueryGetResultCount(query); i < e; ++i ) {

        MDItemRef item = static_cast<MDItemRef>(const_cast<void *>(MDQueryGetResultAtIndex(query, i)));

        CFStringRef item_path = static_cast<CFStringRef>(MDItemCopyAttribute(item, kMDItemPath));
        auto clear_item_path = at_scope_end([=] { CFRelease(item_path); });

        result.emplace_back(base::CFStringGetUTF8StdString(item_path));
    }

    // make results unique - spotlight sometimes produces duplicates
    std::ranges::sort(result);
    result.erase(std::ranges::unique(result).begin(), result.end());

    return result;
}

static VFSListingPtr FetchSearchResultsAsListing(const std::vector<std::string> &_file_paths,
                                                 VFSHost &_vfs,
                                                 unsigned long _fetch_flags,
                                                 const VFSCancelChecker &_cancel_checker)
{
    std::vector<VFSListingPtr> listings;

    for( auto &p : _file_paths ) {
        const std::expected<VFSListingPtr, Error> listing =
            _vfs.FetchSingleItemListing(p, _fetch_flags, _cancel_checker);
        if( listing )
            listings.emplace_back(*listing);
    }

    return VFSListing::Build(VFSListing::Compose(listings));
}

void SpotlightSearch::Perform(PanelController *_target, id /*_sender*/) const
{
    const auto view = [[SpotlightSearchPopupViewController alloc] init];
    __weak PanelController *wp = _target;
    view.handler = [wp](const std::string &_query) {
        if( PanelController *const panel = wp ) {
            auto task = [=](const std::function<bool()> &_cancelled) {
                if( auto l = FetchSearchResultsAsListing(FetchSpotlightResults(_query),
                                                         nc::bootstrap::NativeVFSHostInstance(),
                                                         panel.vfsFetchingFlags,
                                                         _cancelled) )
                    dispatch_to_main_queue([=] { [panel loadListing:l]; });
            };
            [panel commitCancelableLoadingTask:std::move(task)];
        }
    };

    [_target.view showPopoverUnderPathBarWithView:view andDelegate:view];
}

}; // namespace nc::panel::actions

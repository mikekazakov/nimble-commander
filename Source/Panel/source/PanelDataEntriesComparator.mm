// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelDataEntriesComparator.h"
#include <CoreServices/CoreServices.h>
#include <Panel/Log.h>
#include <memory_resource>

namespace nc::panel::data {

// See for details:
// https://stackoverflow.com/questions/78960444/why-could-nsstring-localizedstandardcompare-produce-different-results
static bool isLocalizedStandardCompareSane() noexcept
{
    const NSComparisonResult cmp1 = [@"A 2" localizedStandardCompare:@"a 10"];
    const NSComparisonResult cmp2 = [@"A 2" localizedStandardCompare:@"a 10"];
    const bool sane = cmp1 == NSOrderedAscending && cmp2 == NSOrderedAscending;
    Log::Info("Detecting localizedStandardCompare sanity: {} ({}, {})",
              sane ? "sane" : "insane",
              static_cast<int>(cmp1),
              static_cast<int>(cmp2));
    return sane;
}

int ListingComparatorBase::NaturalCompare(CFStringRef _1st, CFStringRef _2nd) noexcept
{
    assert(_1st != nullptr);
    assert(_2nd != nullptr);
    static const bool is_localizedStandardCompare_sane = isLocalizedStandardCompareSane();
    if( is_localizedStandardCompare_sane ) {
        // Use the recommended way, i.e. the blackbox 'localizedStandardCompare'.
        NSString *const lhs = (__bridge NSString *)(_1st);
        NSString *const rhs = (__bridge NSString *)(_2nd);
        const NSComparisonResult cmp = [lhs localizedStandardCompare:rhs];
        return static_cast<int>(cmp);
    }
    else {
        // Backup strategy if 'localizedStandardCompare' went south: use the Carbon-based collation:
        // https://developer.apple.com/library/archive/qa/qa1159/_index.html
        std::array<char, 4096> mem_buffer;
        std::pmr::monotonic_buffer_resource mem_resource(mem_buffer.data(), mem_buffer.size());

        std::pmr::vector<unsigned short> lhs_buf(&mem_resource);
        const long lhs_len = CFStringGetLength(_1st);
        const unsigned short *lhs_chars = CFStringGetCharactersPtr(_1st);
        if( lhs_chars == nullptr ) {
            lhs_buf.resize(lhs_len);
            CFStringGetCharacters(_1st, CFRangeMake(0, lhs_len), lhs_buf.data());
            lhs_chars = lhs_buf.data();
        }

        std::pmr::vector<unsigned short> rhs_buf(&mem_resource);
        const long rhs_len = CFStringGetLength(_2nd);
        const unsigned short *rhs_chars = CFStringGetCharactersPtr(_2nd);
        if( rhs_chars == nullptr ) {
            rhs_buf.resize(rhs_len);
            CFStringGetCharacters(_2nd, CFRangeMake(0, rhs_len), rhs_buf.data());
            rhs_chars = rhs_buf.data();
        }

        int result = 0;
        const UCCollateOptions options = kUCCollateComposeInsensitiveMask | kUCCollateWidthInsensitiveMask |
                                         kUCCollateCaseInsensitiveMask | kUCCollateDigitsOverrideMask |
                                         kUCCollateDigitsAsNumberMask | kUCCollatePunctuationSignificantMask;
        UCCompareTextDefault(options, lhs_chars, lhs_len, rhs_chars, rhs_len, nullptr, &result);
        return std::clamp(result, -1, 1);
    }
}

} // namespace nc::panel::data

// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelDataFilter.h"
#include <VFS/VFS.h>
#include <Base/CFPtr.h>
#include <Base/CFStackAllocator.h>
#include <memory_resource>

namespace nc::panel::data {

static_assert(sizeof(TextualFilter) == 10);
static_assert(sizeof(HardFilter) == 11);

bool TextualFilter::operator==(const TextualFilter &_r) const noexcept
{
    if( type != _r.type )
        return false;

    if( text == nil && _r.text != nil )
        return false;

    if( text != nil && _r.text == nil )
        return false;

    if( text == nil && _r.text == nil )
        return true;

    return [text isEqualToString:_r.text]; // no decomposion here
}

bool TextualFilter::operator!=(const TextualFilter &_r) const noexcept
{
    return !(*this == _r);
}

TextualFilter::Where TextualFilter::WhereFromInt(int _v) noexcept
{
    if( _v >= 0 && _v <= Fuzzy )
        return Where(_v);
    return Anywhere;
}

TextualFilter TextualFilter::NoFilter() noexcept
{
    TextualFilter filter;
    filter.type = Anywhere;
    filter.text = nil;
    filter.ignore_dot_dot = true;
    return filter;
}

bool TextualFilter::IsValidItem(const VFSListingItem &_item) const
{
    QuickSearchHiglight hl;
    return IsValidItem(_item, hl);
}

static bool FuzzySearchSatisfiable(CFStringRef _hay,
                                   size_t _hay_len,
                                   size_t _hay_start,
                                   NSString *_needle,
                                   size_t _needle_start) noexcept
{
    const base::CFStackAllocator alloc;
    const auto needle_len = _needle.length;

    size_t pos = _hay_start;
    for( size_t idx = _needle_start; idx < needle_len; ++idx ) {
        const UniChar c = [_needle characterAtIndex:idx];
        const auto cs =
            base::CFPtr<CFStringRef>::adopt(CFStringCreateWithCharactersNoCopy(alloc, &c, 1, kCFAllocatorNull));
        CFRange result = {0, 0};
        const bool found = CFStringFindWithOptions(
            _hay, cs.get(), CFRangeMake(pos, _hay_len - pos), kCFCompareCaseInsensitive, &result);
        if( !found )
            return false; // cannot be satisfied - filename doesn't contain a sparse sequence of chars from text
        pos = result.location + 1;
    }
    return true;
}

std::optional<QuickSearchHiglight> FuzzySearch(NSString *_filename, NSString *_text) noexcept
{
    assert(_filename != nil);
    assert(_text != nil);

    const base::CFPtr<CFStringRef> cf_filename =
        base::CFPtr<CFStringRef>::adopt(static_cast<CFStringRef>(CFBridgingRetain(_filename)));

    const auto filename_len = _filename.length;

    // 1st - check satisfiability in general
    if( !FuzzySearchSatisfiable(cf_filename.get(), filename_len, 0, _text, 0) )
        return {};

    // 2nd - now start to greadily look for longest substrings - O(n^2)
    std::array<char, 16384> mem_buffer;
    std::pmr::monotonic_buffer_resource mem_resource(mem_buffer.data(), mem_buffer.size());
    std::pmr::vector<QuickSearchHiglight::Range> found(&mem_resource);
    unsigned long filename_pos = 0;
    NSString *text = _text;
    while( true ) {
        const size_t text_length = text.length;
        if( text_length == 0 ) {
            break; // done.
        }

        for( size_t length = text_length; true; --length ) {
            if( length == 0 ) {
                return {}; // invalid case?
            }

            const NSRange result = [_filename rangeOfString:[text substringToIndex:length]
                                                    options:NSCaseInsensitiveSearch
                                                      range:NSMakeRange(filename_pos, filename_len - filename_pos)];
            if( result.length == 0 ) {
                continue; // cannot found a substring this long
            }

            // found one, check that the whole criterion is still satisfiable
            if( !FuzzySearchSatisfiable(
                    cf_filename.get(), filename_len, result.location + result.length, text, length) ) {
                continue; // too greedy - the rest of the criterion is not satisfiable
            }

            // ok, seems legit, memorize and carry on with the leftovers
            found.push_back({result.location, result.length});
            filename_pos = result.location + result.length;
            text = [text substringFromIndex:result.length];
            break;
        }
    }

    return QuickSearchHiglight({found.data(), found.size()}); // might discard some results here
}

bool TextualFilter::IsValidItem(const VFSListingItem &_item, QuickSearchHiglight &_found_range) const
{
    _found_range = {};

    if( text == nil )
        return true; // nothing to filter with - just say yes

    if( ignore_dot_dot && _item.IsDotDot() )
        return true; // never filter out the Holy Dot-Dot directory!

    const auto textlen = text.length;
    if( textlen == 0 )
        return true; // will return true on any item with @"" filter

    NSString *const name = _item.DisplayNameNS();
    const auto namelen = name.length;
    if( textlen > namelen )
        return false; // unsatisfiable by definition

    if( type == Anywhere ) {
        const NSRange result = [name rangeOfString:text options:NSCaseInsensitiveSearch];
        if( result.length == 0 )
            return false;

        QuickSearchHiglight::Range hlrange;
        hlrange.offset = result.location;
        hlrange.length = result.length;
        _found_range = QuickSearchHiglight({&hlrange, 1});
        return true;
    }
    else if( type == Beginning ) {
        const NSRange result = [name rangeOfString:text options:NSCaseInsensitiveSearch | NSAnchoredSearch];

        if( result.length == 0 )
            return false;

        QuickSearchHiglight::Range hlrange;
        hlrange.offset = result.location;
        hlrange.length = result.length;
        _found_range = QuickSearchHiglight({&hlrange, 1});
        return true;
    }
    else if( type == Ending || type == BeginningOrEnding ) {
        if( type == BeginningOrEnding ) { // look at beginning
            const NSRange result = [name rangeOfString:text options:NSCaseInsensitiveSearch | NSAnchoredSearch];
            if( result.length != 0 ) {
                QuickSearchHiglight::Range hlrange;
                hlrange.offset = result.location;
                hlrange.length = result.length;
                _found_range = QuickSearchHiglight({&hlrange, 1});
                return true;
            }
        }

        if( _item.HasExtension() ) {
            // slow path here - look before extension
            const NSRange dotrange = [name rangeOfString:@"." options:NSBackwardsSearch];
            if( dotrange.length != 0 && dotrange.location > textlen ) {
                const NSRange result =
                    [name rangeOfString:text
                                options:NSCaseInsensitiveSearch | NSAnchoredSearch | NSBackwardsSearch
                                  range:NSMakeRange(dotrange.location - textlen, textlen)];
                if( result.length != 0 ) {
                    QuickSearchHiglight::Range hlrange;
                    hlrange.offset = result.location;
                    hlrange.length = result.length;
                    _found_range = QuickSearchHiglight({&hlrange, 1});
                    return true;
                }
            }
        }

        // look at the end at last
        const NSRange result = [name rangeOfString:text
                                           options:NSCaseInsensitiveSearch | NSAnchoredSearch | NSBackwardsSearch];
        if( result.length != 0 ) {
            QuickSearchHiglight::Range hlrange;
            hlrange.offset = result.location;
            hlrange.length = result.length;
            _found_range = QuickSearchHiglight({&hlrange, 1});
            return true;
        }
        else
            return false;
    }
    else if( type == Fuzzy ) {
        if( auto res = FuzzySearch(name, text) ) {
            _found_range = *res;
            return true;
        }
        else {
            return false;
        }
    }
    return false;
}

void TextualFilter::OnPanelDataLoad()
{
    if( clear_on_new_listing )
        text = nil;
}

bool TextualFilter::IsFiltering() const noexcept
{
    return text != nil && text.length > 0;
}

//////////////////////////////////////////////////////////////////////////////////////////////////////
// HardFilter
//////////////////////////////////////////////////////////////////////////////////////////////////////

bool HardFilter::IsValidItem(const VFSListingItem &_item, QuickSearchHiglight &_found_range) const
{
    if( !show_hidden && _item.IsHidden() )
        return false;

    return text.IsValidItem(_item, _found_range);
}

bool HardFilter::IsFiltering() const noexcept
{
    return !show_hidden || text.IsFiltering();
}

} // namespace nc::panel::data

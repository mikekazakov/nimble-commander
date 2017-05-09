#include "PanelDataFilter.h"
#include <VFS/VFS.h>

PanelDataTextualFilter::PanelDataTextualFilter() noexcept :
    text{nil},
    type{Anywhere},
    ignore_dot_dot{true},
    clear_on_new_listing{false},
    hightlight_results{true}
{
}

bool PanelDataTextualFilter::operator==(const PanelDataTextualFilter& _r) const noexcept
{
    if(type != _r.type)
        return false;
    
    if(text == nil && _r.text != nil)
        return false;
    
    if(text != nil && _r.text == nil)
        return false;
    
    if(text == nil && _r.text == nil)
        return true;
    
    return [text isEqualToString:_r.text]; // no decomposion here
}

bool PanelDataTextualFilter::operator!=(const PanelDataTextualFilter& _r) const noexcept
{
    return !(*this == _r);
}

PanelDataTextualFilter::Where PanelDataTextualFilter::WhereFromInt(int _v) noexcept
{
    if(_v >= 0 && _v <= BeginningOrEnding)
        return Where(_v);
    return Anywhere;
}

PanelDataTextualFilter PanelDataTextualFilter::NoFilter() noexcept
{
    PanelDataTextualFilter filter;
    filter.type = Anywhere;
    filter.text = nil;
    filter.ignore_dot_dot = true;
    return filter;
}

static PanelDataTextualFilter::FoundRange g_DummyFoundRange;

bool PanelDataTextualFilter::IsValidItem(const VFSListingItem& _item) const
{
    return IsValidItem( _item, g_DummyFoundRange );
}

bool PanelDataTextualFilter::IsValidItem(const VFSListingItem& _item,
                                           FoundRange &_found_range) const
{
    _found_range = {0, 0};
    
    if( text == nil )
        return true; // nothing to filter with - just say yes
    
    if( ignore_dot_dot && _item.IsDotDot() )
        return true; // never filter out the Holy Dot-Dot directory!
    
    const auto textlen = text.length;
    if( textlen == 0 )
        return true; // will return true on any item with @"" filter
    
    NSString *name = _item.NSDisplayName();
    if( type == Anywhere ) {
        NSRange result = [name rangeOfString:text
                                     options:NSCaseInsensitiveSearch];
        if( result.length == 0 )
            return false;

        _found_range.first = result.location;
        _found_range.second = result.location + result.length;
        
        return true;
    }
    else if( type == Beginning ) {
        NSRange result = [name rangeOfString:text
                                     options:NSCaseInsensitiveSearch|NSAnchoredSearch];
        
        if( result.length == 0 )
            return false;
        
        _found_range.first = result.location;
        _found_range.second = result.location + result.length;
        
        return true;
    }
    else if( type == Ending || type == BeginningOrEnding ) {
        if( type == BeginningOrEnding) { // look at beginning
            NSRange result = [name rangeOfString:text
                                         options:NSCaseInsensitiveSearch|NSAnchoredSearch];
            if( result.length != 0  ) {
                _found_range.first = result.location;
                _found_range.second = result.location + result.length;
                return true;
            }
        }
        
        if( _item.HasExtension() ) {
            // slow path here - look before extension
            NSRange dotrange = [name rangeOfString:@"." options:NSBackwardsSearch];
            if(dotrange.length != 0 &&
               dotrange.location > textlen) {
                NSRange result = [name rangeOfString:text
                                     options:NSCaseInsensitiveSearch|NSAnchoredSearch|NSBackwardsSearch
                                       range:NSMakeRange(dotrange.location - textlen, textlen)];
                if( result.length != 0 ) {
                    _found_range.first = result.location;
                    _found_range.second = result.location + result.length;
                    return true;
                }
            }
        }
        
        // look at the end at last
        NSRange result = [name rangeOfString:text
                                     options:NSCaseInsensitiveSearch|NSAnchoredSearch|NSBackwardsSearch];
        if( result.length != 0 ) {
            _found_range.first = result.location;
            _found_range.second = result.location + result.length;
            return true;
        }
        else
            return false;
    }
    
    return false;
}

void PanelDataTextualFilter::OnPanelDataLoad()
{
    if( clear_on_new_listing )
        text = nil;
}

bool PanelDataTextualFilter::IsFiltering() const noexcept
{
    return text != nil && text.length > 0;
}

//////////////////////////////////////////////////////////////////////////////////////////////////////
// HardFilter
//////////////////////////////////////////////////////////////////////////////////////////////////////

bool PanelDataHardFilter::IsValidItem(const VFSListingItem& _item,
                                        PanelDataTextualFilter::FoundRange &_found_range) const
{
    if( show_hidden == false && _item.IsHidden() )
        return false;
    
    return text.IsValidItem(_item, _found_range);
}
    
bool PanelDataHardFilter::IsFiltering() const noexcept
{
    return !show_hidden || text.IsFiltering();
}

bool PanelDataHardFilter::operator==(const PanelDataHardFilter& _r) const noexcept
{
    return show_hidden == _r.show_hidden && text == _r.text;
}

bool PanelDataHardFilter::operator!=(const PanelDataHardFilter& _r) const noexcept
{
    return show_hidden != _r.show_hidden || text != _r.text;
}

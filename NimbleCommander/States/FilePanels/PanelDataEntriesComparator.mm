// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelDataEntriesComparator.h"
#include "PanelDataItemVolatileData.h"
#include "PanelDataExternalEntryKey.h"

namespace nc::panel::data {

ListingComparatorBase::ListingComparatorBase(const VFSListing &_items,
                                             const vector<ItemVolatileData>& _vd,
                                             SortMode _sort_mode):
    l{ _items },
    vd{ _vd },
    sort_mode{ _sort_mode },
    plain_compare{ _sort_mode.case_sens ? strcmp : strcasecmp},
    str_comp_flags{ (_sort_mode.case_sens ? 0 : kCFCompareCaseInsensitive) |
        (_sort_mode.numeric_sort ? kCFCompareNumerically : 0) }
{
}
    
int ListingComparatorBase::Compare( CFStringRef _1st, CFStringRef _2nd ) const noexcept
{
    return CFStringCompare( _1st, _2nd, str_comp_flags );
}

int ListingComparatorBase::Compare( const char *_1st, const char *_2nd ) const noexcept
{
    return plain_compare( _1st, _2nd );
}

IndirectListingComparator::IndirectListingComparator(
    const VFSListing &_items,
    const vector<ItemVolatileData>& _vd,
    SortMode sort_mode):
        ListingComparatorBase(_items, _vd, sort_mode)
{
}

bool IndirectListingComparator::operator()(unsigned _1, unsigned _2) const
{
    using _ = SortMode::Mode;
    
    if( sort_mode.sep_dirs ) {
        if( l.IsDir(_1) && !l.IsDir(_2) ) return true;
        if(!l.IsDir(_1) &&  l.IsDir(_2) ) return false;
    }
    
    switch( sort_mode.sort ) {
        case _::SortByName:         return IsLessByName(_1, _2);
        case _::SortByNameRev:      return IsLessByNameReversed(_1, _2);
        case _::SortByExt:          return IsLessByExension(_1, _2);
        case _::SortByExtRev:       return IsLessByExensionReversed(_1, _2);
        case _::SortByModTime:      return IsLessByModificationTime(_1, _2);
        case _::SortByModTimeRev:   return IsLessByModificationTimeReversed(_1, _2);
        case _::SortByBirthTime:    return IsLessByBirthTime(_1, _2);
        case _::SortByBirthTimeRev: return IsLessByBirthTimeReversed(_1, _2);
        case _::SortByAddTime:      return IsLessByAddedTime(_1, _2);
        case _::SortByAddTimeRev:   return IsLessByAddedTimeReversed(_1, _2);
        case _::SortBySize:         return IsLessBySize(_1, _2);
        case _::SortBySizeRev:      return IsLessBySizeReversed(_1, _2);
        case _::SortByRawCName:     return IsLessByFilesystemRepresentation(_1, _2);
        default:                    return false;
    };
}

bool IndirectListingComparator::IsLessByFilesystemRepresentation(unsigned _1, unsigned _2) const
{
    return l.Filename(_1) < l.Filename(_2);
}

bool IndirectListingComparator::IsLessBySizeReversed(unsigned _1, unsigned _2) const
{
    constexpr auto invalid_size = ItemVolatileData::invalid_size;
    const auto s1 = vd[_1].size, s2 = vd[_2].size;
    if( s1 != invalid_size && s2 != invalid_size )
        if( s1 != s2 )
            return s1 < s2;
    if( s1 != invalid_size && s2 == invalid_size )
        return true;
    if( s1 == invalid_size && s2 != invalid_size )
        return false;
    return CompareNames(_1, _2) > 0; // fallback case
}

bool IndirectListingComparator::IsLessBySize(unsigned _1, unsigned _2) const
{
    constexpr auto invalid_size = ItemVolatileData::invalid_size;
    const auto s1 = vd[_1].size, s2 = vd[_2].size;
    if( s1 != invalid_size && s2 != invalid_size )
        if( s1 != s2 )
            return s1 > s2;
    if( s1 != invalid_size && s2 == invalid_size )
        return false;
    if( s1 == invalid_size && s2 != invalid_size )
        return true;
    return CompareNames(_1, _2) < 0; // fallback case
}

bool IndirectListingComparator::IsLessByAddedTimeReversed(unsigned _1, unsigned _2) const
{
    const auto h1 = l.HasAddTime(_1), h2 = l.HasAddTime(_2);
    if( h1 && h2 ) {
        const auto v1 = l.AddTime(_1), v2 = l.AddTime(_2);
        if( v1 != v2 )
            return v1 < v2;
    }
    if( h1 && !h2 ) return false;
    if( h2 && !h1 ) return true;
    return CompareNames(_1, _2) > 0; // fallback case
}

bool IndirectListingComparator::IsLessByAddedTime(unsigned _1, unsigned _2) const
{
    const auto h1 = l.HasAddTime(_1), h2 = l.HasAddTime(_2);
    if( h1 && h2 ) {
        const auto v1 = l.AddTime(_1), v2 = l.AddTime(_2);
        if( v1 != v2 )
            return v1 > v2;
    }
    if( h1 && !h2 ) return true;
    if( h2 && !h1 ) return false;
    return CompareNames(_1, _2) < 0; // fallback case
}

bool IndirectListingComparator::IsLessByBirthTimeReversed(unsigned _1, unsigned _2) const
{
    const auto v1 = l.BTime(_1), v2 = l.BTime(_2);
    if( v1 != v2 )
        return v1 < v2;
    return CompareNames(_1, _2) > 0;
}

bool IndirectListingComparator::IsLessByBirthTime(unsigned _1, unsigned _2) const
{
    const auto v1 = l.BTime(_1), v2 = l.BTime(_2);
    if( v1 != v2 )
        return v1 > v2;
    return CompareNames(_1, _2) < 0;
}

bool IndirectListingComparator::IsLessByModificationTimeReversed(unsigned _1, unsigned _2) const
{
    const auto v1 = l.MTime(_1), v2 = l.MTime(_2);
    if( v1 != v2 )
        return v1 < v2;
    return CompareNames(_1, _2) > 0;
}

bool IndirectListingComparator::IsLessByModificationTime(unsigned _1, unsigned _2) const
{
    const auto v1 = l.MTime(_1), v2 = l.MTime(_2);
    if( v1 != v2 )
        return v1 > v2;
    return CompareNames(_1, _2) < 0;
}

bool IndirectListingComparator::IsLessByExensionReversed(unsigned _1, unsigned _2) const
{
    const auto first_has_extension = l.HasExtension(_1) &&
        (!sort_mode.extensionless_dirs || !l.IsDir(_1));
    const auto second_has_extension = l.HasExtension(_2) &&
        (!sort_mode.extensionless_dirs || !l.IsDir(_2));
    if( first_has_extension && second_has_extension ) {
        const auto r = Compare(l.Extension(_1), l.Extension(_2));
        if(r < 0)
            return false;
        if(r > 0)
            return true;
        return CompareNames(_1, _2) > 0;
    }
    if(  first_has_extension && !second_has_extension )
        return true;
    if( !first_has_extension &&  second_has_extension )
        return false;
    return CompareNames(_1, _2) > 0;
}

bool IndirectListingComparator::IsLessByExension(unsigned _1, unsigned _2) const
{
    const auto first_has_extension = l.HasExtension(_1) &&
        (!sort_mode.extensionless_dirs || !l.IsDir(_1));
    const auto second_has_extension = l.HasExtension(_2) &&
        (!sort_mode.extensionless_dirs || !l.IsDir(_2));
    if( first_has_extension && second_has_extension ) {
        const auto r = Compare(l.Extension(_1), l.Extension(_2));
        if(r < 0)
            return true;
        if(r > 0)
            return false;
        return CompareNames(_1, _2) < 0;
    }
    if(  first_has_extension && !second_has_extension )
        return false;
    if( !first_has_extension &&  second_has_extension )
        return true;
    return CompareNames(_1, _2) < 0;
}

bool IndirectListingComparator::IsLessByName(unsigned _1, unsigned _2) const
{
    return CompareNames(_1, _2) < 0;
}

bool IndirectListingComparator::IsLessByNameReversed(unsigned _1, unsigned _2) const
{
    return CompareNames(_1, _2) > 0;
}

int IndirectListingComparator::CompareNames(unsigned _1, unsigned _2) const
{
    return Compare(l.DisplayFilenameCF(_1), l.DisplayFilenameCF(_2));
}


ExternalListingComparator::ExternalListingComparator(const VFSListing &_items,
                                                     const vector<ItemVolatileData>& _vd,
                                                     SortMode sort_mode):
    ListingComparatorBase(_items, _vd, sort_mode)
{}

bool ExternalListingComparator::operator()(unsigned _1, const ExternalEntryKey &_val2) const
{
    using _ = SortMode::Mode;
    const auto invalid_size = ItemVolatileData::invalid_size;
    
    if( sort_mode.sep_dirs ) {
        if( l.IsDir(_1) && !_val2.is_dir) return true;
        if(!l.IsDir(_1) &&  _val2.is_dir) return false;
    }
    
    const auto by_name = [&] { return Compare(l.DisplayFilenameCF(_1),
                                              (__bridge CFStringRef)_val2.display_name); };
    
    switch(sort_mode.sort)
    {
        case _::SortByName: return by_name() < 0;
        case _::SortByNameRev: return by_name() > 0;
        case _::SortByExt: {
            const bool first_has_extension = l.HasExtension(_1) &&
                (!sort_mode.extensionless_dirs || !l.IsDir(_1));
            const bool second_has_extension = !_val2.extension.empty() &&
                (!sort_mode.extensionless_dirs || !_val2.is_dir);
            if( first_has_extension && second_has_extension ) {
                int r = Compare(l.Extension(_1), _val2.extension.c_str());
                if(r < 0) return true;
                if(r > 0) return false;
                return by_name() < 0;
            }
            if(  first_has_extension && !second_has_extension ) return false;
            if( !first_has_extension &&  second_has_extension ) return true;
            return by_name() < 0; // fallback case
        }
        case _::SortByExtRev: {
            const bool first_has_extension = l.HasExtension(_1) &&
                (!sort_mode.extensionless_dirs || !l.IsDir(_1));
            const bool second_has_extension = !_val2.extension.empty() &&
                (!sort_mode.extensionless_dirs || !_val2.is_dir);
            if( first_has_extension && second_has_extension ) {
                int r = Compare(l.Extension(_1), _val2.extension.c_str());
                if(r < 0) return false;
                if(r > 0) return true;
                return by_name() > 0;
            }
            if(  first_has_extension && !second_has_extension ) return true;
            if( !first_has_extension &&  second_has_extension ) return false;
            return by_name() > 0; // fallback case
        }
        case _::SortByModTime: {
            if( l.MTime(_1) != _val2.mtime  )
                return l.MTime(_1) > _val2.mtime;
            return by_name() < 0;
        }
        case _::SortByModTimeRev: {
            if( l.MTime(_1) != _val2.mtime  )
                return l.MTime(_1) < _val2.mtime;
            return by_name() > 0;
        }
        case _::SortByBirthTime: {
            if( l.BTime(_1) != _val2.btime )
                return l.BTime(_1) > _val2.btime;
            return by_name() < 0;
        }
        case _::SortByBirthTimeRev: {
            if( l.BTime(_1) != _val2.btime )
                return l.BTime(_1) < _val2.btime;
            return by_name() > 0;
        }
        case _::SortByAddTime: {
            const auto h1 = l.HasAddTime(_1), h2 = _val2.add_time >= 0;
            if( h1 && h2 )
                if( l.AddTime(_1) != _val2.add_time )
                    return l.AddTime(_1) > _val2.add_time;
            if( h1 && !h2 ) return true;
            if( h2 && !h1 ) return false;
            return by_name() < 0; // fallback case
        }
        case _::SortByAddTimeRev: {
            const auto h1 = l.HasAddTime(_1), h2 = _val2.add_time >= 0;
            if( h1 && h2 )
                if( l.AddTime(_1) != _val2.add_time )
                    return l.AddTime(_1) < _val2.add_time;
            if( h1 && !h2 ) return false;
            if( h2 && !h1 ) return true;
            return by_name() > 0; // fallback case
        }
        case _::SortBySize: {
            auto s1 = vd[_1].size;
            if( s1 != invalid_size && _val2.size != invalid_size )
                if( s1 != _val2.size )
                    return s1 > _val2.size;
            if( s1 != invalid_size && _val2.size == invalid_size )
                return false;
            if( s1 == invalid_size && _val2.size != invalid_size )
                return true;
            return by_name() < 0; // fallback case
        }
        case _::SortBySizeRev: {
            auto s1 = vd[_1].size;
            if( s1 != invalid_size && _val2.size != invalid_size )
                if( s1 != _val2.size )
                    return s1 < _val2.size;
            if( s1 != invalid_size && _val2.size == invalid_size )
                return true;
            if( s1 == invalid_size && _val2.size != invalid_size )
                return false;
            return by_name() > 0; // fallback case
        }
        case _::SortByRawCName:
            return l.Filename(_1) < _val2.name;
            break;
        case _::SortNoSort:
            assert(0); // meaningless sort call
            break;
        default:;
    };
    
    return false;
}


}

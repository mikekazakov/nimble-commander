#include <Habanero/algo.h>
#include "../NimbleCommander/Core/FileMask.h"
#include "ExtensionLowercaseComparison.h"
#include "PanelData.h"

static void DoRawSort(const VFSListing &_from, PanelData::DirSortIndT &_to);

static inline PanelData::PanelSortMode DefaultSortMode()
{
    PanelData::PanelSortMode mode;
    mode.sep_dirs = true;
    mode.sort = PanelData::PanelSortMode::SortByName;
    return mode;
    
}

// returned string IS NOT NULL TERMINATED and MAY CONTAIN ZEROES INSIDE
// a bit overkill, need to consider some simplier kind of keys
static string LongEntryKey(const VFSListing& _l, unsigned _i)
{
    // host + dir + filename
    union {
        void *v;
        char b[ sizeof(void*) ];
    } host_addr;
    host_addr.v = _l.Host(_i).get();
    
    auto &directory = _l.Directory(_i);
    auto &filename = _l.Filename(_i);
    
    string key;
    key.reserve( sizeof(host_addr) + directory.size() + filename.size() + 1 );
    key.append( begin(host_addr.b), end(host_addr.b) );
    key.append( directory );
    key.append( filename );
    return key;
}

static vector<string> ProduceLongKeysForListing( const VFSListing& _l )
{
    vector<string> keys;
    keys.reserve( _l.Count() );
    for( unsigned i = 0, e = _l.Count(); i != e; ++i )
        keys.emplace_back( LongEntryKey(_l, i) );
    return keys;
}

static vector<unsigned> ProduceSortedIndirectIndecesForLongKeys(const vector<string>& _keys)
{
    vector<unsigned> src_keys_ind( _keys.size() );
    generate( begin(src_keys_ind), end(src_keys_ind), linear_generator(0, 1) );
    sort( begin(src_keys_ind), end(src_keys_ind), [&_keys](auto _1, auto _2) { return _keys[_1] < _keys[_2]; } );
    return src_keys_ind;
}

bool PanelData::EntrySortKeys::is_valid() const noexcept
{
    return !name.empty() && display_name != nil;
}

//////////////////////////////////////////////////////////////////////////////////////////////////////
// PanelVolatileData
//////////////////////////////////////////////////////////////////////////////////////////////////////
bool PanelData::PanelVolatileData::is_selected() const noexcept
{
    return (flags & flag_selected) != 0;
};

bool PanelData::PanelVolatileData::is_shown() const noexcept
{
    return (flags & flag_shown) != 0;
}

bool PanelData::PanelVolatileData::is_size_calculated() const noexcept
{
    return size != invalid_size;
}

void PanelData::PanelVolatileData::toggle_selected( bool _v ) noexcept
{
    flags = (flags & ~flag_selected) | (_v ? flag_selected : 0);
}

void PanelData::PanelVolatileData::toggle_shown( bool _v ) noexcept
{
    flags = (flags & ~flag_shown) | (_v ? flag_shown : 0);
}

bool PanelData::PanelVolatileData::operator==(PanelVolatileData&_rhs) const noexcept
{
    return size  == _rhs.size  &&
           flags == _rhs.flags &&
           icon  == _rhs.icon   ;
}

bool PanelData::PanelVolatileData::operator!=(PanelVolatileData&_rhs) const noexcept
{
    return !(*this == _rhs);
}

//////////////////////////////////////////////////////////////////////////////////////////////////////
// Statistics
//////////////////////////////////////////////////////////////////////////////////////////////////////
bool PanelData::Statistics::operator ==(const PanelData::Statistics& _r) const noexcept
{
    return
    bytes_in_raw_reg_files    == _r.bytes_in_raw_reg_files    &&
    raw_reg_files_amount      == _r.raw_reg_files_amount      &&
    bytes_in_selected_entries == _r.bytes_in_selected_entries &&
    selected_entries_amount   == _r.selected_entries_amount   &&
    selected_reg_amount       == _r.selected_reg_amount       &&
    selected_dirs_amount      == _r.selected_dirs_amount;
}

bool PanelData::Statistics::operator !=(const PanelData::Statistics& _r) const noexcept
{
    return !(*this == _r);
}

//////////////////////////////////////////////////////////////////////////////////////////////////////
// TextualFilter
//////////////////////////////////////////////////////////////////////////////////////////////////////

bool PanelData::TextualFilter::operator==(const TextualFilter& _r) const noexcept
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

bool PanelData::TextualFilter::operator!=(const TextualFilter& _r) const noexcept
{
    return !(*this == _r);
}

PanelData::TextualFilter::Where PanelData::TextualFilter::WhereFromInt(int _v) noexcept
{
    if(_v >= 0 && _v <= BeginningOrEnding)
        return Where(_v);
    return Anywhere;
}

PanelData::TextualFilter PanelData::TextualFilter::NoFilter() noexcept
{
    TextualFilter filter;
    filter.type = Anywhere;
    filter.text = nil;
    filter.ignoredotdot = true;
    return filter;
}

bool PanelData::TextualFilter::IsValidItem(const VFSListingItem& _item) const
{
    if(text == nil)
        return true;
    
    if(ignoredotdot && _item.IsDotDot())
        return true; // never filter out the Holy Dot-Dot directory!
    
    auto textlen = text.length;
    if(textlen == 0)
        return true; // will return true on any item with @"" filter
    
    NSString *name = _item.NSDisplayName();
    if(type == Anywhere) {
        return [name rangeOfString:text
                           options:NSCaseInsensitiveSearch].length != 0;
    }
    else if(type == Beginning) {
        return [name rangeOfString:text
                           options:NSCaseInsensitiveSearch|NSAnchoredSearch].length != 0;
    }
    else if(type == Ending || type == BeginningOrEnding) {
        if((type == BeginningOrEnding) &&
           [name rangeOfString:text // look at beginning
                       options:NSCaseInsensitiveSearch|NSAnchoredSearch].length != 0)
            return true;
        
        if(_item.HasExtension())
        { // slow path here - look before extension
            NSRange dotrange = [name rangeOfString:@"." options:NSBackwardsSearch];
            if(dotrange.length != 0 &&
               dotrange.location > textlen) {
                auto r = [name rangeOfString:text
                                     options:NSCaseInsensitiveSearch|NSAnchoredSearch|NSBackwardsSearch
                                       range:NSMakeRange(dotrange.location - textlen, textlen)];
                if(r.length != 0)
                    return true;
            }
        }
        
        return [name rangeOfString:text // look at the end at last
                           options:NSCaseInsensitiveSearch|NSAnchoredSearch|NSBackwardsSearch].length != 0;
    }
    
    assert(0); // should never came here!
    return true;
}

void PanelData::TextualFilter::OnPanelDataLoad()
{
    if( clearonnewlisting )
        text = nil;
}

bool PanelData::TextualFilter::IsFiltering() const noexcept
{
    return text != nil && text.length > 0;
}

//////////////////////////////////////////////////////////////////////////////////////////////////////
// HardFilter
//////////////////////////////////////////////////////////////////////////////////////////////////////

bool PanelData::HardFilter::IsValidItem(const VFSListingItem& _item) const
{
    if(show_hidden == false && _item.IsHidden())
        return false;
    
    return text.IsValidItem(_item);
}
    
bool PanelData::HardFilter::IsFiltering() const noexcept
{
    return !show_hidden || text.IsFiltering();
}

bool PanelData::HardFilter::operator==(const HardFilter& _r) const noexcept
{
    return show_hidden == _r.show_hidden && text == _r.text;
}

bool PanelData::HardFilter::operator!=(const HardFilter& _r) const noexcept
{
    return show_hidden != _r.show_hidden || text != _r.text;
}

//////////////////////////////////////////////////////////////////////////////////////////////////////
// PanelData
//////////////////////////////////////////////////////////////////////////////////////////////////////

PanelData::PanelData():
    m_SortExecGroup(DispatchGroup::High),
    m_Listing(VFSListing::EmptyListing()),
    m_CustomSortMode(DefaultSortMode())
{
}

static void InitVolatileDataWithListing( vector<PanelData::PanelVolatileData> &_vd, const VFSListing &_listing)
{
    _vd.clear();
    _vd.resize(_listing.Count());
    for( unsigned i = 0, e = _listing.Count(); i != e; ++i )
        if( !_listing.IsDir(i) )
            _vd[i].size = _listing.Size(i);
}

void PanelData::Load(const shared_ptr<VFSListing> &_listing, PanelType _type)
{
    assert(dispatch_is_main_queue()); // STA api design
    
    if( !_listing )
        throw logic_error("PanelData::Load: listing can't be nullptr");
    
    m_Listing = _listing;
    m_Type = _type;
    InitVolatileDataWithListing(m_VolatileData, *m_Listing);
    
    m_HardFiltering.text.OnPanelDataLoad();
    m_SoftFiltering.OnPanelDataLoad();
    
    // now sort our new data
    m_SortExecGroup.Run([=]{ DoRawSort(*m_Listing, m_EntriesByRawName); });
    m_SortExecGroup.Run([=]{ DoSortWithHardFiltering(); });
    m_SortExecGroup.Wait();
    BuildSoftFilteringIndeces();
    // update stats
    UpdateStatictics();
}

void PanelData::ReLoad(const shared_ptr<VFSListing> &_listing)
{
    assert(dispatch_is_main_queue()); // STA api design
    
    // sort new entries by raw c name for sync-swapping needs
    DirSortIndT dirbyrawcname;
    DoRawSort(*_listing, dirbyrawcname);
    
    vector<PanelVolatileData> new_vd;
    InitVolatileDataWithListing(new_vd, *_listing);
    
    if( _listing->IsUniform() && m_Listing->IsUniform() ) {
        // transfer custom data to new array using sorted indeces arrays based in raw C filename.
        // assumes that there can't be more than one file with same filenamr
        unsigned dst_i = 0, dst_e = _listing->Count(),
        src_i = 0, src_e = m_Listing->Count();
        for( ;src_i != src_e && dst_i != dst_e; ++src_i ) {
            int src = m_EntriesByRawName[src_i];
        check:  int dst = dirbyrawcname[dst_i];
            int cmp = m_Listing->Filename(src).compare( _listing->Filename(dst) );
            if( cmp == 0 ) {
                new_vd[ dst ] = m_VolatileData[ src ];
                
                ++dst_i;                    // check this! we assume that normal directory can't hold two files with a same name
            }
            else if( cmp > 0 ) {
                dst_i++;
                if(dst_i == dst_e)
                    break;
                goto check;
            }
        }
    }
    else if( !_listing->IsUniform() && !m_Listing->IsUniform() ) {
        auto src_keys = ProduceLongKeysForListing( *m_Listing );
        auto src_keys_ind = ProduceSortedIndirectIndecesForLongKeys(src_keys);
        auto dst_keys = ProduceLongKeysForListing( *_listing  );
        auto dst_keys_ind = ProduceSortedIndirectIndecesForLongKeys(dst_keys);
        
        // TODO: consider moving into separate algorithm
        unsigned dst_i = 0, dst_e = (unsigned)dst_keys.size(),
                 src_i = 0, src_e = (unsigned)src_keys.size();
        for( ;src_i != src_e && dst_i != dst_e; ++src_i ) {
            int src = src_keys_ind[src_i];
    check2: int dst = dst_keys_ind[dst_i];
            int cmp = src_keys[src].compare( dst_keys[dst] );
            if( cmp == 0 ) {
                new_vd[ dst ] = m_VolatileData[ src ];
                ++dst_i;
            }
            else if( cmp > 0 ) {
                dst_i++;
                if(dst_i == dst_e)
                    break;
                goto check2;
            }
        }
    }
    else
        throw invalid_argument("PanelData::ReLoad: incompatible listing type!");
    
    // put a new data in a place
    m_Listing = move(_listing);
    m_VolatileData = move(new_vd);
    m_EntriesByRawName = move(dirbyrawcname);
    
    // now sort our new data with custom sortings
    DoSortWithHardFiltering();
    BuildSoftFilteringIndeces();
    UpdateStatictics();
}

const shared_ptr<VFSHost> &PanelData::Host() const
{
    if( !m_Listing->HasCommonHost() )
        throw logic_error("PanelData::Host was called with no common host in listing");
    return m_Listing->Host(0);
}

const VFSListing &PanelData::Listing() const
{
    return *m_Listing;
}

PanelData::PanelType PanelData::Type() const noexcept
{
    return m_Type;
}

const PanelData::DirSortIndT& PanelData::SortedDirectoryEntries() const
{
    return m_EntriesByCustomSort;
}

PanelData::PanelVolatileData& PanelData::VolatileDataAtRawPosition( int _pos )
{
    if( _pos < 0 || _pos >= m_VolatileData.size() )
        throw out_of_range("PanelData::VolatileDataAtRawPosition: index can't be out of range");
    
    return m_VolatileData[_pos];
}

const PanelData::PanelVolatileData& PanelData::VolatileDataAtRawPosition( int _pos ) const
{
    if( _pos < 0 || _pos >= m_VolatileData.size() )
        throw out_of_range("PanelData::VolatileDataAtRawPosition: index can't be out of range");
    
    return m_VolatileData[_pos];
}

PanelData::PanelVolatileData& PanelData::VolatileDataAtSortPosition( int _pos )
{
    return VolatileDataAtRawPosition( RawIndexForSortIndex(_pos) );
}

const PanelData::PanelVolatileData& PanelData::VolatileDataAtSortPosition( int _pos ) const
{
    return VolatileDataAtRawPosition( RawIndexForSortIndex(_pos) );
}


string PanelData::FullPathForEntry(int _raw_index) const
{
    if(_raw_index < 0 || _raw_index >= m_Listing->Count())
        return "";

    auto entry = m_Listing->Item(_raw_index);
    if( !entry.IsDotDot() )
        return entry.Path();
    else {
        auto t = entry.Directory();
        auto i = t.rfind('/');
        if(i == 0)
            t.resize(i+1);
        else if(i != string::npos)
            t.resize(i);
        return t;
    }
}

int PanelData::RawIndexForName(const char *_filename) const
{
    assert(m_EntriesByRawName.size() == m_Listing->Count()); // consistency check

    if(_filename == nullptr)
        return -1;
    
    if(_filename[0] == 0)
        return -1; // can't handle empty filenames
    
    // TODO! not accounting possibility of repeating filenames in listing.
    // it's possible with flexible listing
    
    // performing binary search on m_EntriesByRawName
    auto begin = m_EntriesByRawName.begin(), end = m_EntriesByRawName.end();
    auto i = lower_bound(begin, end, _filename,
                         [=](unsigned _i, const char* _s) {
                             return m_Listing->Filename(_i) < _s;
                         });
    if(i < end &&
       m_Listing->Filename(*i) == _filename)
        return *i;
    
    return -1;
}

int PanelData::SortedIndexForRawIndex(int _desired_raw_index) const
{
    if(_desired_raw_index < 0 ||
       _desired_raw_index >= m_Listing->Count())
        return -1;
    
    // TODO: consider creating reverse (raw entry->sorted entry) map to speed up performance
    // ( if the code below will every became a problem - we can change it from O(n) to O(1) )
    auto i = find_if(m_EntriesByCustomSort.begin(), m_EntriesByCustomSort.end(),
            [=](unsigned t) {return t == _desired_raw_index;} );
    if( i < m_EntriesByCustomSort.end() )
        return int(i - m_EntriesByCustomSort.begin());
    return -1;
}

string PanelData::DirectoryPathWithoutTrailingSlash() const
{
    if( !m_Listing->HasCommonDirectory() )
        return "";

    string path = m_Listing->Directory(0);
    if( path.size() > 1 )
        path.pop_back();
    
    return path;
}

string PanelData::DirectoryPathWithTrailingSlash() const
{
    if(!m_Listing->HasCommonDirectory())
        return "";
    return m_Listing->Directory();
}

string PanelData::DirectoryPathShort() const
{    
    string tmp = DirectoryPathWithoutTrailingSlash();
    auto i = tmp.rfind('/');
    if(i != string::npos)
        return tmp.c_str() + i + 1;
    return "";
}

string PanelData::VerboseDirectoryFullPath() const
{
    if( !m_Listing || !m_Listing->IsUniform())
        return "";
    array<VFSHost*, 32> hosts;
    int hosts_n = 0;

    VFSHost *cur = m_Listing->Host().get();
    while(cur)
    {
        hosts[hosts_n++] = cur;
        cur = cur->Parent().get();
    }
    
    string s;
    while(hosts_n > 0)
        s += hosts[--hosts_n]->Configuration().VerboseJunction();
    s += m_Listing->Directory();
    if(s.back() != '/') s += '/';
    return s;
    return "";
}

struct SortPredLessBase
{
protected:
    const VFSListing&                       l;
    const vector<PanelData::PanelVolatileData>& vd;
    const PanelData::PanelSortMode          sort_mode;
    const CFStringCompareFlags              str_comp_flags;
    typedef int (*CompareExtensionsT)(const char *, const char *);
    const CompareExtensionsT                compare_extensions;
public:
    SortPredLessBase(const VFSListing &_items, const vector<PanelData::PanelVolatileData>& _vd, PanelData::PanelSortMode _sort_mode):
        l(_items),
        vd(_vd),
        sort_mode{ _sort_mode },
        compare_extensions{ _sort_mode.case_sens ? strcmp : strcasecmp},
        str_comp_flags{ (_sort_mode.case_sens ? 0 : kCFCompareCaseInsensitive) | (_sort_mode.numeric_sort ? kCFCompareNumerically : 0) }
    {
    }
};

struct SortPredLessIndToInd : public SortPredLessBase
{
    SortPredLessIndToInd(const VFSListing &_items, const vector<PanelData::PanelVolatileData>& _vd, PanelData::PanelSortMode sort_mode): SortPredLessBase(_items, _vd, sort_mode) {}
    
    bool operator()(unsigned _1, unsigned _2) const
    {
        using _ = PanelData::PanelSortMode::Mode;
        const auto invalid_size = PanelData::PanelVolatileData::invalid_size;
        
        if(sort_mode.sep_dirs) {
            if( l.IsDir(_1) && !l.IsDir(_2) ) return true;
            if(!l.IsDir(_1) &&  l.IsDir(_2) ) return false;
        }
        
        auto by_name = [&] { return CFStringCompare( l.DisplayFilenameCF(_1), l.DisplayFilenameCF(_2), str_comp_flags); };
        
        switch(sort_mode.sort)
        {
            case _::SortByName:
                return by_name() < 0;
            case _::SortByNameRev:
                return by_name() > 0;
            case _::SortByExt:
                if( l.HasExtension(_1) && l.HasExtension(_2) ) {
                    int r = compare_extensions(l.Extension(_1), l.Extension(_2));
                    if(r < 0) return true;
                    if(r > 0) return false;
                    return by_name() < 0;
                }
                if( l.HasExtension(_1) && !l.HasExtension(_2) ) return false;
                if(!l.HasExtension(_1) &&  l.HasExtension(_2) ) return true;
                return by_name() < 0; // fallback case
            case _::SortByExtRev:
                if( l.HasExtension(_1) && l.HasExtension(_2) ) {
                    int r = compare_extensions(l.Extension(_1), l.Extension(_2));
                    if(r < 0) return false;
                    if(r > 0) return true;
                    return by_name() > 0;
                }
                if( l.HasExtension(_1) && !l.HasExtension(_2) ) return true;
                if(!l.HasExtension(_1) &&  l.HasExtension(_2) ) return false;
                return by_name() > 0; // fallback case
            case _::SortByModTime:    return l.MTime(_1) > l.MTime(_2);
            case _::SortByModTimeRev: return l.MTime(_1) < l.MTime(_2);
            case _::SortByBirthTime:    return l.BTime(_1) > l.BTime(_2);
            case _::SortByBirthTimeRev: return l.BTime(_1) < l.BTime(_2);
            case _::SortBySize: {
                auto s1 = vd[_1].size, s2 = vd[_2].size;
                if(s1 != invalid_size && s2 != invalid_size)
                    if(s1 != s2)
                        return s1 > s2;
                if(s1 != invalid_size && s2 == invalid_size) return false;
                if(s1 == invalid_size && s2 != invalid_size) return true;
                return by_name() < 0; // fallback case
            }
            case _::SortBySizeRev: {
                auto s1 = vd[_1].size, s2 = vd[_2].size;
                if(s1 != invalid_size && s2 != invalid_size)
                    if(s1 != s2)
                        return s1 < s2;
                if(s1 != invalid_size && s2 == invalid_size) return true;
                if(s1 == invalid_size && s2 != invalid_size) return false;
                return by_name() > 0; // fallback case
            }
            case _::SortByRawCName:
                return l.Filename(_1) < l.Filename(_2);
                break;
            case _::SortNoSort:
                assert(0); // meaningless sort call
                break;
                
            default:;
        };
        
        return false;
    }
};

struct SortPredLessIndToKeys : public SortPredLessBase
{
    SortPredLessIndToKeys(const VFSListing &_items, const vector<PanelData::PanelVolatileData>& _vd, PanelData::PanelSortMode sort_mode): SortPredLessBase(_items, _vd, sort_mode) {}
    
    bool operator()(unsigned _1, const PanelData::EntrySortKeys &_val2) const
    {
        using _ = PanelData::PanelSortMode::Mode;
        const auto invalid_size = PanelData::PanelVolatileData::invalid_size;
        
        if(sort_mode.sep_dirs) {
            if( l.IsDir(_1) && !_val2.is_dir) return true;
            if(!l.IsDir(_1) &&  _val2.is_dir) return false;
        }
        
        auto by_name = [&] { return CFStringCompare( l.DisplayFilenameCF(_1), (CFStringRef)_val2.display_name, str_comp_flags); };

        switch(sort_mode.sort)
        {
            case _::SortByName: return by_name() < 0;
            case _::SortByNameRev: return by_name() > 0;
            case _::SortByExt:
                if( l.HasExtension(_1) && !_val2.extension.empty() ) {
                    int r = compare_extensions(l.Extension(_1), _val2.extension.c_str());
                    if(r < 0) return true;
                    if(r > 0) return false;
                    return by_name() < 0;
                }
                if( l.HasExtension(_1) &&  _val2.extension.empty() ) return false;
                if(!l.HasExtension(_1) && !_val2.extension.empty() ) return true;
                return by_name() < 0; // fallback case
            case _::SortByExtRev:
                if( l.HasExtension(_1) && !_val2.extension.empty() ) {
                    int r = compare_extensions(l.Extension(_1), _val2.extension.c_str());
                    if(r < 0) return false;
                    if(r > 0) return true;
                    return by_name() > 0;
                }
                if( l.HasExtension(_1) &&  _val2.extension.empty() ) return true;
                if(!l.HasExtension(_1) && !_val2.extension.empty() ) return false;
                return by_name() > 0; // fallback case
            case _::SortByModTime:    return l.MTime(_1) > _val2.mtime;
            case _::SortByModTimeRev: return l.MTime(_1) < _val2.mtime;
            case _::SortByBirthTime:    return l.BTime(_1) > _val2.btime;
            case _::SortByBirthTimeRev: return l.BTime(_1) < _val2.btime;
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
};

// this function will erase data from _to, make it size of _form->size(), and fill it with indeces according to raw sort mode
static void DoRawSort(const VFSListing &_from, PanelData::DirSortIndT &_to)
{
    _to.resize(_from.Count());
    generate( begin(_to), end(_to), linear_generator(0, 1) );
    
    sort(begin(_to),
         end(_to),
         [&_from](unsigned _1, unsigned _2) { return _from.Filename(_1) < _from.Filename(_2); }
         );
}

void PanelData::SetSortMode(PanelSortMode _mode)
{
    if(m_CustomSortMode == _mode)
        return;
    
    m_CustomSortMode = _mode;
    DoSortWithHardFiltering();
    BuildSoftFilteringIndeces();
    UpdateStatictics();
}

// need to call UpdateStatictics() after this method since we alter selected set
void PanelData::ClearSelectedFlagsFromHiddenElements()
{
    for(auto &vd: m_VolatileData)
        if( !vd.is_shown() && vd.is_selected() )
            vd.toggle_selected(false);
}

PanelData::PanelSortMode PanelData::SortMode() const
{
    return m_CustomSortMode;
}

void PanelData::UpdateStatictics()
{
    m_Stats = Statistics();
    if(m_Listing.get() == nullptr)
        return;
    assert( m_Listing->Count() == m_VolatileData.size() );
    
    // calculate totals for directory
    for(const auto &i: *m_Listing)
        if( i.IsReg() ) {
            m_Stats.bytes_in_raw_reg_files += i.Size();
            m_Stats.raw_reg_files_amount++;
        }
    
    // calculate totals for selected. look only for entries which is visible (sorted/filtered ones)
    for(auto n: m_EntriesByCustomSort) {
        const auto &vd = m_VolatileData[n];
        if( vd.is_selected() ) {
            m_Stats.bytes_in_selected_entries += vd.is_size_calculated() ? vd.size : 0;
            
            m_Stats.selected_entries_amount++;
            if( m_Listing->IsDir(n) )
                m_Stats.selected_dirs_amount++;
            else
                m_Stats.selected_reg_amount++;
        }
    }
}

int PanelData::SortIndexForEntry(const VFSListingItem& _item) const noexcept
{
    if( _item.Listing() != m_Listing )
        return -1;

    const auto it = find( begin(m_EntriesByCustomSort), end(m_EntriesByCustomSort), _item.Index() );
    if( it != end(m_EntriesByCustomSort) )
        return (int)distance( begin(m_EntriesByCustomSort), it );
    else
        return -1;
}

int PanelData::RawIndexForSortIndex(int _index) const noexcept
{
    if(_index < 0 || _index >= m_EntriesByCustomSort.size())
        return -1;
    return m_EntriesByCustomSort[_index];
}

VFSListingItem PanelData::EntryAtRawPosition(int _pos) const noexcept
{
    if( _pos >= 0 &&
        _pos < m_Listing->Count() )
        return m_Listing->Item(_pos);
    return {};
}

VFSListingItem PanelData::EntryAtSortPosition(int _pos) const noexcept
{
    return EntryAtRawPosition(RawIndexForSortIndex(_pos));
}

void PanelData::CustomFlagsSelectRaw(int _at_raw_pos, bool _is_selected)
{
    if( _at_raw_pos < 0 || _at_raw_pos >= m_Listing->Count() )
        return;
    
    if( m_Listing->IsDotDot(_at_raw_pos) )
        return; // assuming we can't select dotdot entry
    
    auto &vd = m_VolatileData[_at_raw_pos];
    
    if( vd.is_selected() == _is_selected ) // check if item is already selected
        return;
    
    auto sz = vd.is_size_calculated() ? vd.size : 0;
    if(_is_selected) {
        m_Stats.bytes_in_selected_entries += sz;
        m_Stats.selected_entries_amount++;
        if( m_Listing->IsDir(_at_raw_pos) )
            m_Stats.selected_dirs_amount++;
        else
            m_Stats.selected_reg_amount++; // mb another check for reg here?
    }
    else {
        m_Stats.bytes_in_selected_entries = m_Stats.bytes_in_selected_entries >= sz ? m_Stats.bytes_in_selected_entries - sz : 0;
        
        assert(m_Stats.selected_entries_amount > 0); // sanity check
        m_Stats.selected_entries_amount--;
        if( m_Listing->IsDir(_at_raw_pos) ) {
            assert(m_Stats.selected_dirs_amount > 0);
            m_Stats.selected_dirs_amount--;
        }
        else {
            assert(m_Stats.selected_reg_amount > 0);
            m_Stats.selected_reg_amount--;
        }
    }
    vd.toggle_selected(_is_selected);
}

void PanelData::CustomFlagsSelectSorted(int _at_pos, bool _is_selected)
{
    if(_at_pos < 0 || _at_pos >= m_EntriesByCustomSort.size())
        return;
    
    CustomFlagsSelectRaw(m_EntriesByCustomSort[_at_pos], _is_selected);
}

void PanelData::CustomFlagsSelectAllSorted(bool _select)
{
    for(auto i: m_EntriesByCustomSort)
        if( !m_Listing->IsDotDot(i) )
            m_VolatileData[i].toggle_selected(_select);

    UpdateStatictics();
}

void PanelData::CustomFlagsSelectInvert()
{
    for(auto i: m_EntriesByCustomSort)
        if( !m_Listing->IsDotDot(i) )
            m_VolatileData[i].toggle_selected( !m_VolatileData[i].is_selected() );
    UpdateStatictics();
}

vector<string> PanelData::SelectedEntriesFilenames() const
{
    vector<string> list;
    for(int i = 0, e = (int)m_VolatileData.size(); i != e; ++i)
        if( m_VolatileData[i].is_selected() )
            list.emplace_back( m_Listing->Filename(i) );
    return list;
}

vector<VFSListingItem> PanelData::SelectedEntries() const
{
    vector<VFSListingItem> list;
    for(int i = 0, e = (int)m_VolatileData.size(); i != e; ++i)
        if( m_VolatileData[i].is_selected() )
            list.emplace_back( m_Listing->Item(i) );
    return list;
}

bool PanelData::SetCalculatedSizeForDirectory(const char *_entry, uint64_t _size)
{
    if(_entry    == nullptr ||
       _entry[0] == 0       ||
       _size == PanelVolatileData::invalid_size )
        return false;
    
    int n = RawIndexForName(_entry);
    if(n >= 0) {
        if( m_Listing->IsDir(n) ) {
            auto &vd = m_VolatileData[n];
            if( vd.size == _size)
                return true;
            
            vd.size = _size;
            
            // double-check me
            DoSortWithHardFiltering();
            ClearSelectedFlagsFromHiddenElements();
            BuildSoftFilteringIndeces();
            UpdateStatictics();
            
            return true;
        }
    }
    return false;
}

bool PanelData::SetCalculatedSizeForDirectory(const char *_filename, const char *_directory, uint64_t _size)
{
    if(_filename    == nullptr ||
       _filename[0] == 0       ||
       _directory == nullptr   ||
       _directory[0] == 0      ||
       _size == PanelVolatileData::invalid_size )
        return false;
    
    // dumb linear search here
    for( unsigned i = 0, e = m_Listing->Count(); i != e; ++i )
        if( m_Listing->IsDir(i) &&
            m_Listing->Filename(i) == _filename &&
            m_Listing->Directory(i) == _directory ) {
            auto &vd = m_VolatileData[i];
            if( vd.size == _size)
                return true;
            
            vd.size = _size;
            
            // double-check me
            DoSortWithHardFiltering();
            ClearSelectedFlagsFromHiddenElements();
            BuildSoftFilteringIndeces();
            UpdateStatictics();
            
            return true;
        }
    return false;
}

void PanelData::CustomIconClearAll()
{
    for(auto &vd: m_VolatileData)
        vd.icon = 0;
}

int PanelData::SortedIndexForName(const char *_filename) const
{
    return SortedIndexForRawIndex(RawIndexForName(_filename));
}

unsigned PanelData::CustomFlagsSelectAllSortedByMask(NSString* _mask, bool _select, bool _ignore_dirs)
{
    if( !_mask )
        return 0;
    
    FileMask mask(_mask.UTF8String);
    unsigned counter = 0;
    
    for(auto i: m_EntriesByCustomSort) {
        if( _ignore_dirs && m_Listing->IsDir(i) )
            continue;
        
        if( m_Listing->IsDotDot(i) )
            continue;
        
        if( mask.MatchName(m_Listing->DisplayFilename(i)) ) {
            CustomFlagsSelectRaw(i, _select);
            counter++;
        }
    }
    
    return counter;
}

unsigned PanelData::CustomFlagsSelectAllSortedByExtension(const string &_extension, bool _select, bool _ignore_dirs)
{
    const auto extension = ExtensionLowercaseComparison::Instance().ExtensionToLowercase(_extension);
    const bool empty = extension.empty();
    unsigned counter = 0;
    for(auto i: m_EntriesByCustomSort) {
        if( _ignore_dirs && m_Listing->IsDir(i) )
            continue;
        
        if( m_Listing->IsDotDot(i) )
            continue;

        bool legit = false;
        if( m_Listing->HasExtension(i) ) {
            if(ExtensionLowercaseComparison::Instance().Equal(m_Listing->Extension(i), extension))
                legit = true;
        }
        else if( empty )
            legit = true;

        if( legit ) {
            CustomFlagsSelectRaw(i, _select);
            counter++;
        }
    }
    
    return counter;
}

bool PanelData::ClearTextFiltering()
{
    if(m_SoftFiltering.text == nil &&
       m_HardFiltering.text.text == nil)
        return false;
    
    m_SoftFiltering.text = nil;
    m_HardFiltering.text.text = nil;
    
    DoSortWithHardFiltering();
    ClearSelectedFlagsFromHiddenElements(); // not sure if this is needed here
    BuildSoftFilteringIndeces();
    UpdateStatictics();
    return true;
}

void PanelData::SetHardFiltering(const HardFilter &_filter)
{
    if(m_HardFiltering == _filter)
        return;
    
    m_HardFiltering = _filter;
    
    DoSortWithHardFiltering();
    ClearSelectedFlagsFromHiddenElements();
    BuildSoftFilteringIndeces();
    UpdateStatictics();
}

PanelData::HardFilter PanelData::HardFiltering() const
{
    return m_HardFiltering;
}

void PanelData::DoSortWithHardFiltering()
{
    m_EntriesByCustomSort.clear();
    
    int size = m_Listing->Count();
    
    if(size == 0)
        return;

    m_EntriesByCustomSort.reserve(size);
    for(auto &vd: m_VolatileData)
        vd.toggle_shown(true);
  
    if(m_HardFiltering.IsFiltering())
    {
        for(int i = 0; i < size; ++i)
            if( m_HardFiltering.IsValidItem(m_Listing->Item(i)) )
                m_EntriesByCustomSort.push_back(i);
            else
                m_VolatileData[i].toggle_shown(false);
    }
    else
    {
        m_EntriesByCustomSort.resize(m_Listing->Count());
        generate( begin(m_EntriesByCustomSort), end(m_EntriesByCustomSort), linear_generator(0, 1) );
    }

    if(m_EntriesByCustomSort.empty() ||
       m_CustomSortMode.sort == PanelSortMode::SortNoSort)
        return; // we're already done
    
    SortPredLessIndToInd pred(*m_Listing, m_VolatileData, m_CustomSortMode);
    DirSortIndT::iterator start = begin(m_EntriesByCustomSort);
    
    // do not touch dotdot directory. however, in some cases (root dir for example) there will be no dotdot dir
    // also assume that no filtering will exclude dotdot dir
    if( m_Listing->IsDotDot(0) )
        start++;
    
    sort(start, end(m_EntriesByCustomSort), pred);
}

void PanelData::SetSoftFiltering(const TextualFilter &_filter)
{
    m_SoftFiltering = _filter;
    BuildSoftFilteringIndeces();
}

PanelData::TextualFilter PanelData::SoftFiltering() const
{
    return m_SoftFiltering;
}

const PanelData::DirSortIndT& PanelData::EntriesBySoftFiltering() const
{
    return m_EntriesBySoftFiltering;
}

void PanelData::BuildSoftFilteringIndeces()
{
    if(m_SoftFiltering.IsFiltering()) {
        m_EntriesBySoftFiltering.clear();
        m_EntriesBySoftFiltering.reserve(m_EntriesByCustomSort.size());
        int i = 0, e = (int)m_EntriesByCustomSort.size();
        for(;i!=e;++i)
            if(m_SoftFiltering.IsValidItem( m_Listing->Item(m_EntriesByCustomSort[i])) )
                m_EntriesBySoftFiltering.push_back(i);
    }
    else {
        m_EntriesBySoftFiltering.resize(m_EntriesByCustomSort.size());
        generate( begin(m_EntriesBySoftFiltering), end(m_EntriesBySoftFiltering), linear_generator(0, 1) );
    }
}

PanelData::EntrySortKeys PanelData::ExtractSortKeysFromEntry(const VFSListingItem& _item, const PanelVolatileData &_item_vd)
{
    EntrySortKeys keys;
    keys.name = _item.Name();
    keys.display_name = _item.NSDisplayName();
    keys.extension = _item.HasExtension() ? _item.Extension() : "";
    keys.size = _item_vd.size;
    keys.mtime = _item.MTime();
    keys.btime = _item.BTime();
    keys.is_dir = _item.IsDir();
    return keys;
}

PanelData::EntrySortKeys PanelData::EntrySortKeysAtSortPosition(int _pos) const
{
    auto item = EntryAtSortPosition(_pos);
    if( !item )
        throw invalid_argument("PanelData::EntrySortKeysAtSortPosition: invalid item position");
    return ExtractSortKeysFromEntry(item, VolatileDataAtSortPosition(_pos));
}

int PanelData::SortLowerBoundForEntrySortKeys(const EntrySortKeys& _keys) const
{
    if( !_keys.is_valid() )
        return -1;
    
    auto it = lower_bound(begin(m_EntriesByCustomSort),
                          end(m_EntriesByCustomSort),
                          _keys,
                          SortPredLessIndToKeys(*m_Listing,
                                                m_VolatileData,
                                                m_CustomSortMode)
                          );
    if( it != end(m_EntriesByCustomSort) )
        return (int)distance( begin(m_EntriesByCustomSort), it );
    return -1;
}

static const auto g_RestorationSepDirsKey = "separateDirectories";
static const auto g_RestorationShowHiddenKey = "showHidden";
static const auto g_RestorationCaseSensKey = "caseSensitive";
static const auto g_RestorationNumericSortKey = "numericSort";
static const auto g_RestorationSortModeKey = "sortMode";

rapidjson::StandaloneValue PanelData::EncodeSortingOptions() const
{
    rapidjson::StandaloneValue json(rapidjson::kObjectType);
    auto add_bool = [&](const char*_name, bool _v) {
        json.AddMember(rapidjson::StandaloneValue(_name, rapidjson::g_CrtAllocator), rapidjson::StandaloneValue(_v), rapidjson::g_CrtAllocator); };
    auto add_int = [&](const char*_name, int _v) {
        json.AddMember(rapidjson::StandaloneValue(_name, rapidjson::g_CrtAllocator), rapidjson::StandaloneValue(_v), rapidjson::g_CrtAllocator); };
    add_bool(g_RestorationSepDirsKey, SortMode().sep_dirs);
    add_bool(g_RestorationShowHiddenKey, HardFiltering().show_hidden);
    add_bool(g_RestorationCaseSensKey, SortMode().case_sens);
    add_bool(g_RestorationNumericSortKey, SortMode().numeric_sort);
    add_int(g_RestorationSortModeKey, (int)SortMode().sort);
    return json;
}

void PanelData::DecodeSortingOptions(const rapidjson::StandaloneValue& _options)
{
    if( !_options.IsObject() )
        return;
    
    auto sort_mode = SortMode();
    if( _options.HasMember(g_RestorationSepDirsKey) && _options[g_RestorationSepDirsKey].IsBool() )
        sort_mode.sep_dirs = _options[g_RestorationSepDirsKey].GetBool();
    if( _options.HasMember(g_RestorationCaseSensKey) && _options[g_RestorationCaseSensKey].IsBool() )
        sort_mode.case_sens = _options[g_RestorationCaseSensKey].GetBool();
    if( _options.HasMember(g_RestorationNumericSortKey) && _options[g_RestorationNumericSortKey].IsBool() )
        sort_mode.numeric_sort = _options[g_RestorationNumericSortKey].GetBool();
    if( _options.HasMember(g_RestorationSortModeKey) && _options[g_RestorationSortModeKey].IsInt() )
        if( PanelSortMode::validate( (PanelSortMode::Mode)_options[g_RestorationSortModeKey].GetInt()) )
            sort_mode.sort = (PanelSortMode::Mode)_options[g_RestorationSortModeKey].GetInt();
    SetSortMode(sort_mode);
    
    auto hard_filtering = HardFiltering();
    if( _options.HasMember(g_RestorationShowHiddenKey) && _options[g_RestorationShowHiddenKey].IsBool() )
        hard_filtering.show_hidden = _options[g_RestorationShowHiddenKey].GetBool();
    SetHardFiltering(hard_filtering);
}

const PanelData::Statistics &PanelData::Stats() const
{
    return m_Stats;
}

void PanelData::__InvariantCheck() const
{
    assert( m_Listing != nullptr );
    assert( m_VolatileData.size() == m_Listing->Count() );
    assert( m_EntriesByRawName.size() == m_Listing->Count() );
    assert( m_EntriesByCustomSort.size() <= m_Listing->Count() );
    assert( m_EntriesBySoftFiltering.size() <= m_EntriesByCustomSort.size() );    
}

int PanelData::RawEntriesCount() const noexcept
{
    return m_Listing ? (int)m_Listing->Count() : 0;
}

int PanelData::SortedEntriesCount() const noexcept
{
    return (int)m_EntriesByCustomSort.size();
}

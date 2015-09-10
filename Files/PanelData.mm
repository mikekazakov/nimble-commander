#import "PanelData.h"
#import <CoreFoundation/CoreFoundation.h>
#import "Common.h"
#import "chained_strings.h"
#import "FileMask.h"

static void DoRawSort(const VFSFlexibleListing &_from, PanelData::DirSortIndT &_to);

static inline PanelSortMode DefaultSortMode()
{
    PanelSortMode mode;
    mode.sep_dirs = true;
    mode.sort = PanelSortMode::SortByName;
    return mode;
    
}

PanelData::PanelData():
    m_SortExecGroup(DispatchGroup::High),
    m_Listing(VFSFlexibleListing::EmptyListing()),
    m_CustomSortMode(DefaultSortMode())
{
}

void PanelData::Load(const shared_ptr<VFSFlexibleListing> &_listing)
{
    assert(dispatch_is_main_queue()); // STA api design
    
    if( !_listing )
        throw logic_error("PanelData::Load: listing can't be nullptr");
    
    m_Listing = move(_listing);
    
    m_VolatileData.clear();
    m_VolatileData.resize(m_Listing->Count());
    
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

//void PanelData::ReLoad(unique_ptr<VFSListing> _listing)
//{
//    assert(dispatch_is_main_queue()); // STA api design
//    
//    // sort new entries by raw c name for sync-swapping needs
//    DirSortIndT dirbyrawcname;
//    DoRawSort(*_listing, dirbyrawcname);
//    
//    // transfer custom data to new array using sorted indeces arrays
//    size_t dst_i = 0, dst_e = _listing->Count(),
//    src_i = 0, src_e = m_Listing->Count();
//    for(;src_i < src_e && dst_i < dst_e; ++src_i)
//    {
//        int src = m_EntriesByRawName[src_i];
//    check:  int dst = (dirbyrawcname)[dst_i];
//        int cmp = strcmp((*m_Listing)[src].Name(), (*_listing)[dst].Name());
//        if( cmp == 0 )
//        {
//            auto &item_dst = (*_listing)[dst];
//            const auto &item_src = (*m_Listing)[src];
//            
//            item_dst.SetCFlags(item_src.CFlags());
//            item_dst.SetCIcon(item_src.CIcon());
//            
//            if(item_dst.Size() == VFSListingItem::InvalidSize)
//                item_dst.SetSize(item_src.Size()); // transfer sizes for folders - it can be calculated earlier
//            
//            ++dst_i;                    // check this! we assume that normal directory can't hold two files with a same name
//            if(dst_i == dst_e) break;
//        }
//        else if( cmp > 0 )
//        {
//            dst_i++;
//            if(dst_i == dst_e) break;
//            goto check;
//        }
//    }
//    
//    // put a new data in a place
//    m_Listing = move(_listing);
//    m_EntriesByRawName.swap(dirbyrawcname);
//    
//    // now sort our new data with custom sortings
//    DoSortWithHardFiltering();
//    BuildSoftFilteringIndeces();
//    UpdateStatictics();
//}

const shared_ptr<VFSHost> &PanelData::Host() const
{
    // TODO:!!!!
    assert( m_Listing->HasCommonHost() );
    return m_Listing->Host(0);
}

const VFSFlexibleListing &PanelData::Listing() const
{
    return *m_Listing;
}

const PanelData::DirSortIndT& PanelData::SortedDirectoryEntries() const
{
    return m_EntriesByCustomSort;
}

PanelVolatileData& PanelData::VolatileDataAtRawPosition( int _pos )
{
    if( _pos < 0 || _pos >= m_VolatileData.size() )
        throw out_of_range("PanelData::VolatileDataAtRawPosition: index can't be out of range");
    
    return m_VolatileData[_pos];
}

PanelVolatileData& PanelData::VolatileDataAtSortPosition( int _pos )
{
    return VolatileDataAtRawPosition( RawIndexForSortIndex(_pos) );
}

string PanelData::FullPathForEntry(int _raw_index) const
{
    if(_raw_index < 0 || _raw_index >= m_Listing->Count())
        return "";

//    const auto &entry = m_Listing->At(_raw_index);
    auto entry = m_Listing->Item(_raw_index);
    if( !entry.IsDotDot() ) {
        return entry.Directory() + entry.Name();
//        return DirectoryPathWithTrailingSlash() + entry.Name();
    }
    else {
        auto t = entry.Directory();
//        auto t = DirectoryPathWithoutTrailingSlash();
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
//                             return strcmp((*m_Listing)[_i].Name(), _s) < 0;
                             return strcmp( m_Listing->Filename(_i).c_str(), _s) < 0;
                         });
    if(i < end &&
//       strcmp(_filename, (*m_Listing)[*i].Name()) == 0)
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
    
//    string path = m_Listing->RelativePath();
//    if(path.size() > 0 && path.back() != '/')
//        path.push_back('/');
    
    return m_Listing->Directory(0);
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
    // TODO:
    
//    if(m_Listing == nullptr)
//        return "";
//    array<VFSHost*, 32> hosts;
//    int hosts_n = 0;
//
//    VFSHost *cur = m_Listing->Host().get();
//    while(cur)
//    {
//        hosts[hosts_n++] = cur;
//        cur = cur->Parent().get();
//    }
//    
//    string s;
//    while(hosts_n > 0)
//        s += hosts[--hosts_n]->Configuration().VerboseJunction();
//    s += m_Listing->RelativePath();
//    if(s.back() != '/') s += '/';
//    return s;
    return "";
}

struct SortPredLessBase
{
protected:
    const VFSFlexibleListing&               ind_tar;
    PanelSortMode                   sort_mode;
    CFStringCompareFlags            str_comp_flags;
public:
    SortPredLessBase(const VFSFlexibleListing &_items, PanelSortMode sort_mode):
        ind_tar(_items),
        sort_mode(sort_mode)
    {
        str_comp_flags = (sort_mode.case_sens ? 0 : kCFCompareCaseInsensitive) |
        (sort_mode.numeric_sort ? kCFCompareNumerically : 0);
    }
};

struct SortPredLessIndToInd : public SortPredLessBase
{
    SortPredLessIndToInd(const VFSFlexibleListing &_items, PanelSortMode sort_mode): SortPredLessBase(_items, sort_mode) {}
    
    bool operator()(unsigned _1, unsigned _2) const
    {
        using _ = PanelSortMode::Mode;
        const auto invalid_size = VFSListingItem::InvalidSize; // this is not a case anymore
        const VFSFlexibleListing& L = ind_tar;
//        const auto &val1 = ind_tar[_1];
//        const auto &val2 = ind_tar[_2];
        
        if(sort_mode.sep_dirs) {
            if( L.IsDir(_1) && !L.IsDir(_2) ) return true;
            if(!L.IsDir(_1) &&  L.IsDir(_2) ) return false;
        }
        
        auto by_name = [&] { return CFStringCompare( L.DisplayFilenameCF(_1), L.DisplayFilenameCF(_2), str_comp_flags); };
        
        switch(sort_mode.sort)
        {
            case _::SortByName:
                return by_name() < 0;
            case _::SortByNameRev:
                return by_name() > 0;
            case _::SortByExt:
                if( L.HasExtension(_1) && L.HasExtension(_2) ) {
                    int r = strcmp(L.Extension(_1), L.Extension(_2));
                    if(r < 0) return true;
                    if(r > 0) return false;
                    return by_name() < 0;
                }
                if( L.HasExtension(_1) && !L.HasExtension(_2) ) return false;
                if(!L.HasExtension(_1) &&  L.HasExtension(_2) ) return true;
                return by_name() < 0; // fallback case
            case _::SortByExtRev:
                if( L.HasExtension(_1) && L.HasExtension(_2) ) {
                    int r = strcmp(L.Extension(_1), L.Extension(_2));
                    if(r < 0) return false;
                    if(r > 0) return true;
                    return by_name() > 0;
                }
                if( L.HasExtension(_1) && !L.HasExtension(_2) ) return true;
                if(!L.HasExtension(_1) &&  L.HasExtension(_2) ) return false;
                return by_name() > 0; // fallback case
            case _::SortByMTime:    return L.MTime(_1) > L.MTime(_2);
            case _::SortByMTimeRev: return L.MTime(_1) < L.MTime(_2);
            case _::SortByBTime:    return L.BTime(_1) > L.BTime(_2);
            case _::SortByBTimeRev: return L.BTime(_1) < L.BTime(_2);
            case _::SortBySize: {
                auto s1 = L.Size(_1), s2 = L.Size(_2);
                // special cases for dirs, include volatile listing data
//                if(val1.Size() != invalid_size && val2.Size() != invalid_size)
                    if(s1 != s2)
                        return s1 > s2;
//                if(val1.Size() != invalid_size && val2.Size() == invalid_size) return false;
//                if(val1.Size() == invalid_size && val2.Size() != invalid_size) return true;
                return by_name() < 0; // fallback case
            }
            case _::SortBySizeRev: {
                auto s1 = L.Size(_1), s2 = L.Size(_2);
                if(s1 != s2)
                    return s1 < s2;
//                if(val1.Size() != invalid_size && val2.Size() != invalid_size)
//                    if(val1.Size() != val2.Size())
//                        return val1.Size() < val2.Size();
//                if(val1.Size() != invalid_size && val2.Size() == invalid_size) return true;
//                if(val1.Size() == invalid_size && val2.Size() != invalid_size) return false;
                return by_name() > 0; // fallback case
            }
            case _::SortByRawCName:
//                return strcmp(val1.Name(), val2.Name()) < 0;
                return strcmp( L.Filename(_1).c_str() , L.Filename(_2).c_str()) < 0;
                break;
            case _::SortNoSort:
                assert(0); // meaningless sort call
                break;
                
            default:;
        };
        
        return false;
    }
};

//struct SortPredLessIndToInd : public SortPredLessBase
//{
//    SortPredLessIndToInd(const VFSListing &_items, PanelSortMode sort_mode): SortPredLessBase(_items, sort_mode) {}
//    
//  	bool operator()(unsigned _1, unsigned _2) const
//    {
//        using _ = PanelSortMode::Mode;
//        const auto invalid_size = VFSListingItem::InvalidSize;
//        const auto &val1 = ind_tar[_1];
//        const auto &val2 = ind_tar[_2];
//        
//        if(sort_mode.sep_dirs) {
//            if(val1.IsDir() && !val2.IsDir()) return true;
//            if(!val1.IsDir() && val2.IsDir()) return false;
//        }
//        
//        auto by_name = [&] { return CFStringCompare(val1.CFDisplayName(), val2.CFDisplayName(), str_comp_flags); };
//        
//        switch(sort_mode.sort)
//        {
//            case _::SortByName:
//                return by_name() < 0;
//            case _::SortByNameRev:
//                return by_name() > 0;
//            case _::SortByExt:
//                if(val1.HasExtension() && val2.HasExtension() ) {
//                    int r = strcmp(val1.Extension(), val2.Extension());
//                    if(r < 0) return true;
//                    if(r > 0) return false;
//                    return by_name() < 0;
//                }
//                if(val1.HasExtension() && !val2.HasExtension() ) return false;
//                if(!val1.HasExtension() && val2.HasExtension() ) return true;
//                return by_name() < 0; // fallback case
//            case _::SortByExtRev:
//                if(val1.HasExtension() && val2.HasExtension() ) {
//                    int r = strcmp(val1.Extension(), val2.Extension());
//                    if(r < 0) return false;
//                    if(r > 0) return true;
//                    return by_name() > 0;
//                }
//                if(val1.HasExtension() && !val2.HasExtension() ) return true;
//                if(!val1.HasExtension() && val2.HasExtension() ) return false;
//                return by_name() > 0; // fallback case
//            case _::SortByMTime:    return val1.MTime() > val2.MTime();
//            case _::SortByMTimeRev: return val1.MTime() < val2.MTime();
//            case _::SortByBTime:    return val1.BTime() > val2.BTime();
//            case _::SortByBTimeRev: return val1.BTime() < val2.BTime();
//            case _::SortBySize:
//                if(val1.Size() != invalid_size && val2.Size() != invalid_size)
//                    if(val1.Size() != val2.Size())
//                        return val1.Size() > val2.Size();
//                if(val1.Size() != invalid_size && val2.Size() == invalid_size) return false;
//                if(val1.Size() == invalid_size && val2.Size() != invalid_size) return true;
//                return by_name() < 0; // fallback case
//            case _::SortBySizeRev:
//                if(val1.Size() != invalid_size && val2.Size() != invalid_size)
//                    if(val1.Size() != val2.Size())
//                        return val1.Size() < val2.Size();
//                if(val1.Size() != invalid_size && val2.Size() == invalid_size) return true;
//                if(val1.Size() == invalid_size && val2.Size() != invalid_size) return false;
//                return by_name() > 0; // fallback case
//            case _::SortByRawCName:
//                return strcmp(val1.Name(), val2.Name()) < 0;
//                break;
//            case _::SortNoSort:
//                assert(0); // meaningless sort call
//                break;
//
//            default:;
//        };
//
//        return false;
//    }
//};

//struct SortPredLessIndToKeys : public SortPredLessBase
//{
//    SortPredLessIndToKeys(const VFSListing &_items, PanelSortMode sort_mode): SortPredLessBase(_items, sort_mode) {}
//    
//    bool operator()(unsigned _1, const PanelData::EntrySortKeys &_val2) const
//    {
//        using _ = PanelSortMode::Mode;
//        const auto invalid_size = VFSListingItem::InvalidSize;
//        const auto &val1 = ind_tar[_1];
//        
//        if(sort_mode.sep_dirs) {
//            if(val1.IsDir() && !_val2.is_dir) return true;
//            if(!val1.IsDir() && _val2.is_dir) return false;
//        }
//        
//        auto by_name = [&] { return CFStringCompare(val1.CFDisplayName(), (CFStringRef)_val2.display_name, str_comp_flags); };
//
//        switch(sort_mode.sort)
//        {
//            case _::SortByName: return by_name() < 0;
//            case _::SortByNameRev: return by_name() > 0;
//            case _::SortByExt:
//                if(val1.HasExtension() && !_val2.extension.empty() ) {
//                    int r = strcmp(val1.Extension(), _val2.extension.c_str());
//                    if(r < 0) return true;
//                    if(r > 0) return false;
//                    return by_name() < 0;
//                }
//                if(val1.HasExtension() && _val2.extension.empty() ) return false;
//                if(!val1.HasExtension() && !_val2.extension.empty() ) return true;
//                return by_name() < 0; // fallback case
//            case _::SortByExtRev:
//                if(val1.HasExtension() && !_val2.extension.empty() ) {
//                    int r = strcmp(val1.Extension(), _val2.extension.c_str());
//                    if(r < 0) return false;
//                    if(r > 0) return true;
//                    return by_name() > 0;
//                }
//                if(val1.HasExtension() && _val2.extension.empty() ) return true;
//                if(!val1.HasExtension() && !_val2.extension.empty() ) return false;
//                return by_name() > 0; // fallback case
//            case _::SortByMTime:    return val1.MTime() > _val2.mtime;
//            case _::SortByMTimeRev: return val1.MTime() < _val2.mtime;
//            case _::SortByBTime:    return val1.BTime() > _val2.btime;
//            case _::SortByBTimeRev: return val1.BTime() < _val2.btime;
//            case _::SortBySize:
//                if( val1.Size() != invalid_size && _val2.size != invalid_size )
//                    if( val1.Size() != _val2.size )
//                        return val1.Size() > _val2.size;
//                if( val1.Size() != invalid_size && _val2.size == invalid_size )
//                    return false;
//                if( val1.Size() == invalid_size && _val2.size != invalid_size )
//                    return true;
//                return by_name() < 0; // fallback case
//            case _::SortBySizeRev:
//                if( val1.Size() != invalid_size && _val2.size != invalid_size )
//                    if( val1.Size() != _val2.size )
//                        return val1.Size() < _val2.size;
//                if( val1.Size() != invalid_size && _val2.size == invalid_size )
//                    return true;
//                if( val1.Size() == invalid_size && _val2.size != invalid_size )
//                    return false;
//                return by_name() > 0; // fallback case
//            case _::SortByRawCName:
//                return strcmp(val1.Name(), _val2.name.c_str()) < 0;
//                break;
//            case _::SortNoSort:
//                assert(0); // meaningless sort call
//                break;
//            default:;
//        };
//        
//        return false;
//    }
//};

// this function will erase data from _to, make it size of _form->size(), and fill it with indeces according to raw sort mode
static void DoRawSort(const VFSFlexibleListing &_from, PanelData::DirSortIndT &_to)
{
    if(_from.Count() == 0) {
        _to.clear();
        return;
    }
  
    _to.resize(_from.Count());

    unsigned index = 0;
    generate( begin(_to), end(_to), [&]{return index++;} );
    
    sort(begin(_to),
         end(_to),
         [&_from](unsigned _1, unsigned _2) { return strcmp(_from.Filename(_1).c_str(), _from.Filename(_2).c_str()) < 0; }
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

PanelSortMode PanelData::SortMode() const
{
    return m_CustomSortMode;
}

void PanelData::UpdateStatictics()
{
    m_Stats = PanelDataStatistics();
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
            m_Stats.bytes_in_selected_entries += vd.is_size_calculated() ? vd.calculated_size : m_Listing->Size(n);
            
            m_Stats.selected_entries_amount++;
            if( m_Listing->IsDir(n) )
                m_Stats.selected_dirs_amount++;
            else
                m_Stats.selected_reg_amount++;
        }
    }
}

int PanelData::RawIndexForSortIndex(int _index) const
{
    if(_index < 0 || _index >= m_EntriesByCustomSort.size())
        return -1;
    return m_EntriesByCustomSort[_index];
}

VFSFlexibleListingItem PanelData::EntryAtRawPosition(int _pos) const
{
    if( _pos >= 0 &&
        _pos < m_Listing->Count() )
        return m_Listing->Item(_pos);
    return {};
}

VFSFlexibleListingItem PanelData::EntryAtSortPosition(int _pos) const
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
    
    auto sz = vd.is_size_calculated() ? vd.calculated_size : m_Listing->Size(_at_raw_pos);
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
            m_VolatileData[i].toggle_selected( !m_VolatileData[i].is_shown() );
    UpdateStatictics();
}

chained_strings PanelData::StringsFromSelectedEntries() const
{
    chained_strings str;
//    for(auto const &i: *m_Listing)
//        if(i.CFIsSelected())
//            str.push_back(i.Name(), (int)i.NameLen(), nullptr);
    return str;
}

vector<string> PanelData::SelectedEntriesFilenames() const
{
    vector<string> list;
//    for(auto const &i: *m_Listing)
//        if(i.CFIsSelected())
//            list.emplace_back(i.Name(), i.NameLen());
    return list;
}

bool PanelData::SetCalculatedSizeForDirectory(const char *_entry, uint64_t _size)
{
//    if(_entry    == nullptr ||
//       _entry[0] == 0       ||
//       _size == VFSListingItem::InvalidSize )
//        return false;
//    
//    int n = RawIndexForName(_entry);
//    if(n >= 0)
//    {
//        auto &i = (*m_Listing)[n];
//        if(i.IsDir())
//        {
//            if(i.Size() == _size)
//                return true;
//            
//            if(i.CFIsSelected())
//            { // need to adjust our selected bytes statistic
//                if(i.Size() != VFSListingItem::InvalidSize)
//                {
//                    assert(i.Size() <= m_Stats.bytes_in_selected_entries);
//                    m_Stats.bytes_in_selected_entries -= i.Size();
//                }
//                m_Stats.bytes_in_selected_entries += _size;
//            }
//
//            i.SetSize(_size);
//
//            if(m_CustomSortMode.sort & m_CustomSortMode.SortBySizeMask)
//            {
//                // double-check me
//                DoSortWithHardFiltering();
//                ClearSelectedFlagsFromHiddenElements();
//                BuildSoftFilteringIndeces();
//                UpdateStatictics();
//            }            
//            
//            return true;
//        }
//    }
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

int PanelData::CustomFlagsSelectAllSortedByMask(NSString* _mask, bool _select, bool _ignore_dirs)
{
    FileMask mask(_mask);
    int counter = 0;
    
    for(auto i: m_EntriesByCustomSort) {
        if( _ignore_dirs && m_Listing->IsDir(i) )
            continue;
        
        if( m_Listing->IsDotDot(i) )
            continue;
        
        if( mask.MatchName(m_Listing->DisplayFilenameNS(i)) ) {
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

void PanelData::SetHardFiltering(PanelDataHardFiltering _filter)
{
    if(m_HardFiltering == _filter)
        return;
    
    m_HardFiltering = _filter;
    
    DoSortWithHardFiltering();
    ClearSelectedFlagsFromHiddenElements();
    BuildSoftFilteringIndeces();
    UpdateStatictics();
}

bool PanelDataTextFiltering::IsValidItem(const VFSFlexibleListingItem& _item) const
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

bool PanelDataHardFiltering::IsValidItem(const VFSFlexibleListingItem& _item) const
{
    if(show_hidden == false && _item.IsHidden())
        return false;
    
    return text.IsValidItem(_item);
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
        unsigned index = 0;
        generate( begin(m_EntriesByCustomSort), end(m_EntriesByCustomSort), [&]{return index++;} );
    }

    if(m_EntriesByCustomSort.empty() ||
       m_CustomSortMode.sort == PanelSortMode::SortNoSort)
        return; // we're already done
    
    SortPredLessIndToInd pred(*m_Listing, m_CustomSortMode);
    DirSortIndT::iterator start = begin(m_EntriesByCustomSort);
    
    // do not touch dotdot directory. however, in some cases (root dir for example) there will be no dotdot dir
    // also assume that no filtering will exclude dotdot dir
    if( m_Listing->IsDotDot(0) )
        start++;
    
    sort(start, end(m_EntriesByCustomSort), pred);
}

void PanelData::SetSoftFiltering(PanelDataTextFiltering _filter)
{
    m_SoftFiltering = _filter;
    BuildSoftFilteringIndeces();
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
        unsigned index = 0;
        generate( begin(m_EntriesBySoftFiltering), end(m_EntriesBySoftFiltering), [&]{return index++;} );
    }
}

PanelData::EntrySortKeys PanelData::ExtractSortKeysFromEntry(const VFSListingItem& _item)
{
    EntrySortKeys keys;
    keys.name = _item.Name();
    keys.display_name = [_item.NSDisplayName() copy];
    keys.extension = _item.HasExtension() ? _item.Extension() : "";
    keys.size = _item.Size();
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
// TODO!
    //    return ExtractSortKeysFromEntry(*item);
    return {};
}

int PanelData::SortLowerBoundForEntrySortKeys(const EntrySortKeys& _keys) const
{
    // TODO!
//    auto it = lower_bound(begin(m_EntriesByCustomSort),
//                          end(m_EntriesByCustomSort),
//                          _keys,
//                          SortPredLessIndToKeys(*m_Listing,
//                                                 m_CustomSortMode)
//                          );
//    if( it != end(m_EntriesByCustomSort) )
//        return (int)distance( begin(m_EntriesByCustomSort), it );
    return -1;
}

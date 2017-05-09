#include "PanelData.h"
#include "PanelDataItemVolatileData.h"
#include "PanelDataEntriesComparator.h"
#include <Habanero/DispatchGroup.h>
#include <VFS/VFS.h>

static_assert( sizeof(PanelData::TextualFilter) == 10 );
static_assert( sizeof(PanelData::HardFilter) == 11 );

static void DoRawSort(const VFSListing &_from, vector<unsigned> &_to);

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
    iota( begin(src_keys_ind), end(src_keys_ind), 0 );
    sort( begin(src_keys_ind),
          end(src_keys_ind),
          [&_keys](auto _1, auto _2) { return _keys[_1] < _keys[_2]; } );
    return src_keys_ind;
}

PanelData::PanelData():
    m_Listing(VFSListing::EmptyListing()),
    m_CustomSortMode(DefaultSortMode())
{
}

PanelData::~PanelData()
{
}

static void InitVolatileDataWithListing( vector<PanelData::VolatileData> &_vd, const VFSListing &_listing)
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
    DispatchGroup exec_group{DispatchGroup::High};
    exec_group.Run([=]{ DoRawSort(*m_Listing, m_EntriesByRawName); });
    exec_group.Run([=]{ DoSortWithHardFiltering(); });
    exec_group.Wait();
    BuildSoftFilteringIndeces();
    // update stats
    UpdateStatictics();
}

void PanelData::ReLoad(const shared_ptr<VFSListing> &_listing)
{
    assert(dispatch_is_main_queue()); // STA api design
    
    // sort new entries by raw c name for sync-swapping needs
    vector<unsigned> dirbyrawcname;
    DoRawSort(*_listing, dirbyrawcname);
    
    vector<VolatileData> new_vd;
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

const VFSListingPtr& PanelData::ListingPtr() const
{
    return m_Listing;
}

PanelData::PanelType PanelData::Type() const noexcept
{
    return m_Type;
}

const vector<unsigned>& PanelData::SortedDirectoryEntries() const noexcept
{
    return m_EntriesByCustomSort;
}

PanelData::VolatileData& PanelData::VolatileDataAtRawPosition( int _pos )
{
    if( _pos < 0 || _pos >= m_VolatileData.size() )
        throw out_of_range("PanelData::VolatileDataAtRawPosition: index can't be out of range");
    
    return m_VolatileData[_pos];
}

const PanelData::VolatileData& PanelData::VolatileDataAtRawPosition( int _pos ) const
{
    if( _pos < 0 || _pos >= m_VolatileData.size() )
        throw out_of_range("PanelData::VolatileDataAtRawPosition: index can't be out of range");
    
    return m_VolatileData[_pos];
}

PanelData::VolatileData& PanelData::VolatileDataAtSortPosition( int _pos )
{
    return VolatileDataAtRawPosition( RawIndexForSortIndex(_pos) );
}

const PanelData::VolatileData& PanelData::VolatileDataAtSortPosition( int _pos ) const
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
}

static void DoRawSort(const VFSListing &_from, vector<unsigned> &_to)
{
    _to.resize(_from.Count());
    iota(begin(_to), end(_to), 0);
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
    m_Stats = Statistics{};
    if(m_Listing.get() == nullptr)
        return;
    assert( m_Listing->Count() == m_VolatileData.size() );
 
    m_Stats.total_entries_amount = m_Listing->Count();
    if( !m_Listing->Empty() && m_Listing->IsDotDot(0) )
        m_Stats.total_entries_amount--;
    
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

bool PanelData::IsValidSortPosition(int _pos) const noexcept
{
    return RawIndexForSortIndex(_pos) >= 0;
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
    if( _is_selected ) {
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

bool PanelData::CustomFlagsSelectSorted(const vector<bool>& _is_selected)
{
    bool changed = false;
    for( int i = 0, e = (int)min(_is_selected.size(), m_EntriesByCustomSort.size()); i != e; ++i ) {
        const auto raw_pos = m_EntriesByCustomSort[i];
        if( !m_Listing->IsDotDot(raw_pos) ) {
            if( !changed ) {
                if( m_VolatileData[raw_pos].is_selected() != _is_selected[i] ) {
                    m_VolatileData[raw_pos].toggle_selected( _is_selected[i] );
                    changed = true;
                }
            }
            else {
                m_VolatileData[raw_pos].toggle_selected( _is_selected[i] );
            }
        }
    }
    if( changed )
        UpdateStatictics();
    return changed;
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
       _size == VolatileData::invalid_size )
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
       _size == VolatileData::invalid_size )
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

void PanelData::CustomFlagsClearHighlights()
{
    for( auto &vd: m_VolatileData )
        vd.toggle_highlight(false);
}

int PanelData::SortedIndexForName(const char *_filename) const
{
    return SortedIndexForRawIndex(RawIndexForName(_filename));
}

bool PanelData::ClearTextFiltering()
{
    if(m_SoftFiltering.text == nil &&
       m_HardFiltering.text.text == nil)
        return false;
    
    m_SoftFiltering.text = nil;
    m_HardFiltering.text.text = nil;
    
    for( auto &vd: m_VolatileData ) {
        vd.qs_highlight_begin = 0;
        vd.qs_highlight_end = 0;
    }
    
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
    
    const int size = m_Listing->Count();
    
    if( size == 0 )
        return;

    m_EntriesByCustomSort.reserve(size);
    for( auto &vd: m_VolatileData ) {
        vd.qs_highlight_begin = 0;
        vd.qs_highlight_end = 0;
        vd.toggle_shown(true);
    }
  
    if( m_HardFiltering.IsFiltering() ) {
        TextualFilter::FoundRange found_range;
        for( int i = 0; i < size; ++i )
            if( m_HardFiltering.IsValidItem(m_Listing->Item(i), found_range) ) {
                if( m_HardFiltering.text.hightlight_results ) {
                    m_VolatileData[i].qs_highlight_begin = found_range.first;
                    m_VolatileData[i].qs_highlight_end = found_range.second;
                }
                m_EntriesByCustomSort.push_back(i);
            }
            else {
                m_VolatileData[i].toggle_shown(false);
            }
    }
    else {
        m_EntriesByCustomSort.resize( m_Listing->Count() );
        iota(begin(m_EntriesByCustomSort), end(m_EntriesByCustomSort), 0);
    }

    if(m_EntriesByCustomSort.empty() ||
       m_CustomSortMode.sort == PanelSortMode::SortNoSort)
        return; // we're already done
    
    // do not touch dotdot directory. however, in some cases (root dir for example) there will be
    // no dotdot dir. also assumes that no filtering will exclude dotdot dir
    sort(next( begin(m_EntriesByCustomSort), m_Listing->IsDotDot(0) ?  1 : 0 ),
         end( m_EntriesByCustomSort ),
         nc::panel::data::IndirectListingComparator{ *m_Listing, m_VolatileData, m_CustomSortMode });
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

const vector<unsigned>& PanelData::EntriesBySoftFiltering() const noexcept
{
    return m_EntriesBySoftFiltering;
}

void PanelData::BuildSoftFilteringIndeces()
{
    if( m_SoftFiltering.IsFiltering() ) {
        m_EntriesBySoftFiltering.clear();
        m_EntriesBySoftFiltering.reserve(m_EntriesByCustomSort.size());
        
        int i = 0, e = (int)m_EntriesByCustomSort.size();
        for( ; i != e; ++i ) {
            TextualFilter::FoundRange found_range{0,0};
            const int raw_index = m_EntriesByCustomSort[i];
            if( m_SoftFiltering.IsValidItem( m_Listing->Item(raw_index), found_range ) )
                m_EntriesBySoftFiltering.push_back(i);
            
            if( m_SoftFiltering.hightlight_results ) {
                m_VolatileData[raw_index].qs_highlight_begin = found_range.first;
                m_VolatileData[raw_index].qs_highlight_end = found_range.second;
            }
        }
    }
    else {
        m_EntriesBySoftFiltering.resize(m_EntriesByCustomSort.size());
        iota(begin(m_EntriesBySoftFiltering), end(m_EntriesBySoftFiltering), 0);
    }
}

PanelData::ExternalEntryKey PanelData::EntrySortKeysAtSortPosition(int _pos) const
{
    auto item = EntryAtSortPosition(_pos);
    if( !item )
        throw invalid_argument("PanelData::EntrySortKeysAtSortPosition: invalid item position");
    return ExternalEntryKey{item, VolatileDataAtSortPosition(_pos)};
}

int PanelData::SortLowerBoundForEntrySortKeys(const ExternalEntryKey& _keys) const
{
    if( !_keys.is_valid() )
        return -1;
    
    auto it = lower_bound(begin(m_EntriesByCustomSort),
                          end(m_EntriesByCustomSort),
                          _keys,
                          nc::panel::data::ExternalListingComparator(*m_Listing,
                                                           m_VolatileData,
                                                           m_CustomSortMode)
                          );
    if( it != end(m_EntriesByCustomSort) )
        return (int)distance( begin(m_EntriesByCustomSort), it );
    return -1;
}

const PanelData::Statistics &PanelData::Stats() const noexcept
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

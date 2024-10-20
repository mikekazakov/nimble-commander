// Copyright (C) 2013-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelData.h"
#include "Log.h"
#include "PanelDataEntriesComparator.h"
#include "PanelDataExternalEntryKey.h"
#include "PanelDataItemVolatileData.h"
#include <Base/DispatchGroup.h>
#include <VFS/VFS.h>
#include <algorithm>
#include <magic_enum.hpp>
#include <numeric>
#include <pstld/pstld.h>

namespace nc::panel::data {

// Don't bother with parallelism unless we have at least 10'000 items in a listing
constexpr inline size_t g_ParallelSortThresh = 10'000;

static void DoRawSort(const VFSListing &_from, std::vector<unsigned> &_to);

static inline SortMode DefaultSortMode()
{
    SortMode mode;
    mode.sep_dirs = true;
    mode.sort = SortMode::SortByName;
    return mode;
}

// returned string IS NOT NULL TERMINATED and MAY CONTAIN ZEROES INSIDE
// a bit overkill, need to consider some simplier kind of keys
static std::string LongEntryKey(const VFSListing &_l, unsigned _i)
{
    // host + dir + filename
    union {
        void *v;
        char b[sizeof(void *)];
    } host_addr;
    host_addr.v = _l.Host(_i).get();

    auto &directory = _l.Directory(_i);
    auto &filename = _l.Filename(_i);

    std::string key;
    key.reserve(sizeof(host_addr) + directory.size() + filename.size() + 1);
    key.append(std::begin(host_addr.b), std::end(host_addr.b));
    key.append(directory);
    key.append(filename);
    return key;
}

static std::vector<std::string> ProduceLongKeysForListing(const VFSListing &_l)
{
    std::vector<std::string> keys;
    keys.reserve(_l.Count());
    for( unsigned i = 0, e = _l.Count(); i != e; ++i )
        keys.emplace_back(LongEntryKey(_l, i));
    return keys;
}

static std::vector<unsigned> ProduceSortedIndirectIndecesForLongKeys(const std::vector<std::string> &_keys)
{
    std::vector<unsigned> src_keys_ind(_keys.size());
    std::iota(src_keys_ind.begin(), src_keys_ind.end(), 0); // NOLINT - Xcode16 doesn't have std::ranges::iota
    std::ranges::sort(src_keys_ind, [&_keys](auto _1, auto _2) { return _keys[_1] < _keys[_2]; });
    return src_keys_ind;
}

Model::Model() : m_Listing(VFSListing::EmptyListing()), m_CustomSortMode(DefaultSortMode())
{
}

Model::Model(const Model &) = default;

Model::Model(Model &&) noexcept = default;

Model::~Model() = default;

Model &Model::operator=(const Model &) = default;

Model &Model::operator=(Model &&) noexcept = default;

bool Model::IsLoaded() const noexcept
{
    return m_Listing != VFSListing::EmptyListing();
}

static void InitVolatileDataWithListing(std::vector<ItemVolatileData> &_vd, const VFSListing &_listing)
{
    _vd.clear();
    _vd.resize(_listing.Count());
    for( unsigned i = 0, e = _listing.Count(); i != e; ++i ) {
        if( _listing.IsDir(i) ) {
            if( _listing.HasSize(i) ) {
                const auto sz = _listing.Size(i);
                if( sz != std::numeric_limits<uint64_t>::max() )
                    _vd[i].size = sz;
            }
        }
        else {
            _vd[i].size = _listing.Size(i);
        }
    }
}

void Model::Load(const VFSListingPtr &_listing, PanelType _type)
{
    assert(dispatch_is_main_queue()); // STA api design

    if( !_listing )
        throw std::logic_error("PanelData::Load: listing can't be nullptr");

    Log::Info("Loading {} listing, {} entries, {}",
              magic_enum::enum_name(_type),
              _listing->Count(),
              _listing->IsUniform() ? _listing->Directory().c_str() : "N/A");

    m_Listing = _listing;
    m_Type = _type;
    InitVolatileDataWithListing(m_VolatileData, *m_Listing);

    m_HardFiltering.text.OnPanelDataLoad();
    m_SoftFiltering.OnPanelDataLoad();

    // now sort our new data
    const base::DispatchGroup exec_group{base::DispatchGroup::High};
    exec_group.Run([this] { DoRawSort(*m_Listing, m_EntriesByRawName); });
    exec_group.Run([this] { DoSortWithHardFiltering(); });
    exec_group.Wait();
    BuildSoftFilteringIndeces();
    // update stats
    UpdateStatictics();
}

static void UpdateWithExisingVD(ItemVolatileData &_new_vd, const ItemVolatileData &_ex_vd)
{
    if( _new_vd.size == ItemVolatileData::invalid_size ) {
        _new_vd = _ex_vd;
    }
    else {
        const auto sz = _new_vd.size;
        _new_vd = _ex_vd;
        _new_vd.size = sz;
    }
}

void Model::ReLoad(const VFSListingPtr &_listing)
{
    assert(dispatch_is_main_queue()); // STA api design

    Log::Info("ReLoading listing, {} entries, {}",
              _listing->Count(),
              _listing->IsUniform() ? _listing->Directory().c_str() : "N/A");

    // sort new entries by raw c name for sync-swapping needs
    std::vector<unsigned> dirbyrawcname;
    DoRawSort(*_listing, dirbyrawcname);

    std::vector<ItemVolatileData> new_vd;
    InitVolatileDataWithListing(new_vd, *_listing);

    if( _listing->IsUniform() && m_Listing->IsUniform() ) {
        // transfer custom data to new array using sorted indeces arrays based in raw C filename.
        // assumes that there can't be more than one file with same filenamr
        unsigned dst_i = 0;
        const unsigned dst_e = _listing->Count();
        unsigned src_i = 0;
        const unsigned src_e = m_Listing->Count();
        for( ; src_i != src_e && dst_i != dst_e; ++src_i ) {
            const int src = m_EntriesByRawName[src_i];
        check:
            const int dst = dirbyrawcname[dst_i];
            const int cmp = m_Listing->Filename(src).compare(_listing->Filename(dst));
            if( cmp == 0 ) {

                //                new_vd[ dst ] = m_VolatileData[ src ];
                UpdateWithExisingVD(new_vd[dst], m_VolatileData[src]);

                ++dst_i; // check this! we assume that normal directory can't hold
                         // two files with a same name
            }
            else if( cmp > 0 ) {
                dst_i++;
                if( dst_i == dst_e )
                    break;
                goto check;
            }
        }
    }
    else if( !_listing->IsUniform() && !m_Listing->IsUniform() ) {
        auto src_keys = ProduceLongKeysForListing(*m_Listing);
        auto src_keys_ind = ProduceSortedIndirectIndecesForLongKeys(src_keys);
        auto dst_keys = ProduceLongKeysForListing(*_listing);
        auto dst_keys_ind = ProduceSortedIndirectIndecesForLongKeys(dst_keys);

        // TODO: consider moving into separate algorithm
        unsigned dst_i = 0;
        const unsigned dst_e = static_cast<unsigned>(dst_keys.size());
        unsigned src_i = 0;
        const unsigned src_e = static_cast<unsigned>(src_keys.size());
        for( ; src_i != src_e && dst_i != dst_e; ++src_i ) {
            const int src = src_keys_ind[src_i];
        check2:
            const int dst = dst_keys_ind[dst_i];
            const int cmp = src_keys[src].compare(dst_keys[dst]);
            if( cmp == 0 ) {
                //                new_vd[ dst ] = m_VolatileData[ src ];
                UpdateWithExisingVD(new_vd[dst], m_VolatileData[src]);
                ++dst_i;
            }
            else if( cmp > 0 ) {
                dst_i++;
                if( dst_i == dst_e )
                    break;
                goto check2;
            }
        }
    }
    else
        throw std::invalid_argument("PanelData::ReLoad: incompatible listing type!");

    // put a new data in a place
    m_Listing = _listing;
    m_VolatileData = std::move(new_vd);
    m_EntriesByRawName = std::move(dirbyrawcname);

    // now sort our new data with custom sortings
    DoSortWithHardFiltering();
    BuildSoftFilteringIndeces();
    UpdateStatictics();
}

const std::shared_ptr<VFSHost> &Model::Host() const
{
    if( !m_Listing->HasCommonHost() )
        throw std::logic_error("PanelData::Host was called with no common host in listing");
    return m_Listing->Host(0);
}

const VFSListing &Model::Listing() const noexcept
{
    return *m_Listing;
}

const VFSListingPtr &Model::ListingPtr() const noexcept
{
    return m_Listing;
}

Model::PanelType Model::Type() const noexcept
{
    return m_Type;
}

const std::vector<unsigned> &Model::SortedDirectoryEntries() const noexcept
{
    return m_EntriesByCustomSort;
}

ItemVolatileData &Model::VolatileDataAtRawPosition(int _pos)
{
    const size_t pos = _pos;
    if( pos >= m_VolatileData.size() ) // assuming we won't have more than 2^31 elements
        throw std::out_of_range("PanelData::VolatileDataAtRawPosition: index can't be out of range");

    return m_VolatileData[pos];
}

const ItemVolatileData &Model::VolatileDataAtRawPosition(int _pos) const
{
    const size_t pos = _pos;
    if( pos >= m_VolatileData.size() ) // assuming we won't have more than 2^31 elements
        throw std::out_of_range("PanelData::VolatileDataAtRawPosition: index can't be out of range");

    return m_VolatileData[pos];
}

ItemVolatileData &Model::VolatileDataAtSortPosition(int _pos)
{
    return VolatileDataAtRawPosition(RawIndexForSortIndex(_pos));
}

const ItemVolatileData &Model::VolatileDataAtSortPosition(int _pos) const
{
    return VolatileDataAtRawPosition(RawIndexForSortIndex(_pos));
}

std::string Model::FullPathForEntry(int _raw_index) const
{
    if( _raw_index < 0 || _raw_index >= static_cast<int>(m_Listing->Count()) )
        return "";

    auto entry = m_Listing->Item(_raw_index);
    if( !entry.IsDotDot() )
        return entry.Path();
    else {
        auto t = entry.Directory();
        auto i = t.rfind('/');
        if( i == 0 )
            t.resize(i + 1);
        else if( i != std::string::npos )
            t.resize(i);
        return t;
    }
}

int Model::RawIndexForName(std::string_view _filename) const noexcept
{
    assert(m_EntriesByRawName.size() == m_Listing->Count()); // consistency check

    if( _filename.empty() )
        return -1; // can't handle empty filenames

    const auto listing = m_Listing.get();
    assert(listing != nullptr);

    // performing binary search on m_EntriesByRawName
    const auto begin = m_EntriesByRawName.begin();
    const auto end = m_EntriesByRawName.end();
    const auto i = std::lower_bound(
        begin, end, _filename, [listing](unsigned _i, std::string_view _s) { return listing->Filename(_i) < _s; });
    if( i < end && listing->Filename(*i) == _filename )
        return *i;

    return -1;
}

std::span<const unsigned> Model::RawIndicesForName(std::string_view _filename) const noexcept
{
    assert(m_EntriesByRawName.size() == m_Listing->Count()); // consistency check

    if( _filename.empty() )
        return {};

    struct Cmp {
        const VFSListing *listing;
        bool operator()(unsigned _i, std::string_view _s) const noexcept { return listing->Filename(_i) < _s; }
        bool operator()(std::string_view _s, unsigned _i) const noexcept { return _s < listing->Filename(_i); }
    };

    const auto begin = m_EntriesByRawName.begin();
    const auto end = m_EntriesByRawName.end();

    // O( 2 * logN )
    const auto [first, last] = std::equal_range(begin, end, _filename, Cmp{m_Listing.get()});

    return {m_EntriesByRawName.data() + std::distance(begin, first),
            m_EntriesByRawName.data() + std::distance(begin, last)};
}

std::string Model::DirectoryPathWithoutTrailingSlash() const
{
    if( !m_Listing->HasCommonDirectory() )
        return "";

    std::string path = m_Listing->Directory(0);
    if( path.size() > 1 )
        path.pop_back();

    return path;
}

std::string Model::DirectoryPathWithTrailingSlash() const
{
    if( !m_Listing->HasCommonDirectory() )
        return "";
    return m_Listing->Directory();
}

std::string Model::DirectoryPathShort() const
{
    const std::string tmp = DirectoryPathWithoutTrailingSlash();
    auto i = tmp.rfind('/');
    if( i != std::string::npos )
        return tmp.c_str() + i + 1;
    return "";
}

std::string Model::VerboseDirectoryFullPath() const
{
    if( !m_Listing || !m_Listing->IsUniform() )
        return "";
    std::array<VFSHost *, 32> hosts;
    int hosts_n = 0;

    VFSHost *cur = m_Listing->Host().get();
    while( cur ) {
        hosts[hosts_n++] = cur;
        cur = cur->Parent().get();
    }

    std::string s;
    while( hosts_n > 0 )
        s += hosts[--hosts_n]->Configuration().VerboseJunction();
    s += m_Listing->Directory();
    if( s.back() != '/' )
        s += '/';
    return s;
}

static void DoRawSort(const VFSListing &_from, std::vector<unsigned> &_to)
{
    _to.resize(_from.Count());
    std::iota(_to.begin(), _to.end(), 0); // NOLINT - Xcode16 doesn't have std::ranges::iota
    std::ranges::sort(_to, [&_from](unsigned _1, unsigned _2) { return _from.Filename(_1) < _from.Filename(_2); });
}

void Model::SetSortMode(struct SortMode _mode)
{
    if( m_CustomSortMode == _mode )
        return;

    m_CustomSortMode = _mode;
    DoSortWithHardFiltering();
    BuildSoftFilteringIndeces();
    UpdateStatictics();
}

// need to call UpdateStatictics() after this method since we alter selected set
void Model::ClearSelectedFlagsFromHiddenElements()
{
    for( auto &vd : m_VolatileData )
        if( !vd.is_shown() && vd.is_selected() )
            vd.toggle_selected(false);
}

SortMode Model::SortMode() const
{
    return m_CustomSortMode;
}

void Model::UpdateStatictics()
{
    m_Stats = Statistics{};
    if( m_Listing.get() == nullptr )
        return;
    assert(m_Listing->Count() == m_VolatileData.size());

    m_Stats.total_entries_amount = m_Listing->Count();
    if( !m_Listing->Empty() && m_Listing->IsDotDot(0) )
        m_Stats.total_entries_amount--;

    // calculate totals for directory
    for( const auto &i : *m_Listing )
        if( i.IsReg() ) {
            m_Stats.bytes_in_raw_reg_files += i.Size();
            m_Stats.raw_reg_files_amount++;
        }

    // calculate totals for selected. look only for entries which is visible (sorted/filtered ones)
    for( auto n : m_EntriesByCustomSort ) {
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

int Model::SortedIndexForRawIndex(int _index) const noexcept
{
    if( _index < 0 || static_cast<size_t>(_index) >= m_ReverseToCustomSort.size() )
        return -1;

    const unsigned reverse = m_ReverseToCustomSort[_index];
    if( reverse == std::numeric_limits<unsigned>::max() )
        return -1;
    else
        return static_cast<int>(reverse);
}

int Model::RawIndexForSortIndex(int _index) const noexcept
{
    if( _index < 0 || _index >= static_cast<int>(m_EntriesByCustomSort.size()) )
        return -1;
    return m_EntriesByCustomSort[_index];
}

VFSListingItem Model::EntryAtRawPosition(int _pos) const noexcept
{
    if( _pos >= 0 && _pos < static_cast<int>(m_Listing->Count()) )
        return m_Listing->Item(_pos);
    return {};
}

bool Model::IsValidSortPosition(int _pos) const noexcept
{
    return RawIndexForSortIndex(_pos) >= 0;
}

VFSListingItem Model::EntryAtSortPosition(int _pos) const noexcept
{
    return EntryAtRawPosition(RawIndexForSortIndex(_pos));
}

int Model::SortPositionOfEntry(const VFSListingItem &_item) const noexcept
{
    if( _item.Listing() != m_Listing ) {
        Log::Warn("Model::SortPositionOfEntry has been provided with an unrelated vfs item");
        return -1;
    }
    return SortedIndexForRawIndex(_item.Index());
}

void Model::CustomFlagsSelectRaw(int _at_raw_pos, bool _is_selected)
{
    if( _at_raw_pos < 0 || _at_raw_pos >= static_cast<int>(m_Listing->Count()) )
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
        m_Stats.bytes_in_selected_entries =
            m_Stats.bytes_in_selected_entries >= static_cast<int64_t>(sz) ? m_Stats.bytes_in_selected_entries - sz : 0;

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

void Model::CustomFlagsSelectSorted(int _at_sorted_pos, bool _is_selected)
{
    if( _at_sorted_pos < 0 || _at_sorted_pos >= static_cast<int>(m_EntriesByCustomSort.size()) )
        return;

    CustomFlagsSelectRaw(m_EntriesByCustomSort[_at_sorted_pos], _is_selected);
}

bool Model::CustomFlagsSelectSorted(const std::vector<bool> &_is_selected)
{
    bool changed = false;
    for( int i = 0, e = static_cast<int>(std::min(_is_selected.size(), m_EntriesByCustomSort.size())); i != e; ++i ) {
        const auto raw_pos = m_EntriesByCustomSort[i];
        if( !m_Listing->IsDotDot(raw_pos) ) {
            if( !changed ) {
                if( m_VolatileData[raw_pos].is_selected() != _is_selected[i] ) {
                    m_VolatileData[raw_pos].toggle_selected(_is_selected[i]);
                    changed = true;
                }
            }
            else {
                m_VolatileData[raw_pos].toggle_selected(_is_selected[i]);
            }
        }
    }
    if( changed )
        UpdateStatictics();
    return changed;
}

std::vector<std::string> Model::SelectedEntriesFilenames() const
{
    std::vector<std::string> list;
    for( int i = 0, e = static_cast<int>(m_VolatileData.size()); i != e; ++i )
        if( m_VolatileData[i].is_selected() )
            list.emplace_back(m_Listing->Filename(i));
    return list;
}

std::vector<VFSListingItem> Model::SelectedEntriesUnsorted() const
{
    std::vector<VFSListingItem> list;
    for( int i = 0, e = static_cast<int>(m_VolatileData.size()); i != e; ++i )
        if( m_VolatileData[i].is_selected() )
            list.emplace_back(m_Listing->Item(i));
    return list;
}

std::vector<VFSListingItem> Model::SelectedEntriesSorted() const
{
    std::vector<VFSListingItem> list;
    const auto sorted_count = SortedEntriesCount();
    for( int i = 0; i < sorted_count; ++i ) {
        assert(i < static_cast<int>(m_EntriesByCustomSort.size()));
        const auto raw_index = m_EntriesByCustomSort[i];
        assert(raw_index < m_VolatileData.size());
        if( m_VolatileData[raw_index].is_selected() )
            list.emplace_back(m_Listing->Item(raw_index));
    }
    return list;
}

bool Model::SetCalculatedSizeForDirectory(std::string_view _filename, std::string_view _directory, uint64_t _size)
{
    if( _filename.empty() || _directory.empty() || _size == ItemVolatileData::invalid_size )
        return false;

    // O(logN) - binary search over all elements
    const auto raw_indices = RawIndicesForName(_filename);

    // O(N) over the items with the same filename, usually N=1
    for( const auto raw_index : raw_indices ) {
        assert(m_Listing->Filename(raw_index) == _filename);
        if( m_Listing->IsDir(raw_index) && m_Listing->Directory(raw_index) == _directory ) {
            auto &vd = m_VolatileData[raw_index];
            if( vd.size == _size )
                return true;

            vd.size = _size;

            FinalizeSettingCalculatedSizes();
            return true;
        }
    }

    return false;
}

size_t Model::SetCalculatedSizesForDirectories(std::span<const std::string_view> _filenames,
                                               std::span<const std::string_view> _directories,
                                               std::span<const uint64_t> _sizes)
{
    if( _filenames.size() != _directories.size() || _filenames.size() != _sizes.size() )
        return 0;

    size_t num_set = 0;
    size_t num_changed = 0;
    const auto listing = m_Listing.get();

    // O(N) iterate over the entire input set
    for( size_t ind = 0; ind != _filenames.size(); ++ind ) {
        const auto filename = _filenames[ind];
        const auto directory = _directories[ind];
        const auto size = _sizes[ind];

        // O(logN) - binary search over all elements in the listing
        const auto raw_indices = RawIndicesForName(filename);

        // O(N) over the items with the same filename, usually N=1
        for( const auto raw_index : raw_indices ) {
            assert(listing->Filename(raw_index) == filename);
            if( listing->IsDir(raw_index) && listing->Directory(raw_index) == directory ) {
                ++num_set;
                auto &vd = m_VolatileData[raw_index];
                if( vd.size != size ) {
                    vd.size = size;
                    ++num_changed;
                }
                break;
            }
        }
    }

    if( num_changed != 0 )
        FinalizeSettingCalculatedSizes();

    return num_set;
}

size_t Model::SetCalculatedSizesForDirectories(std::span<const unsigned> _raw_items_indices,
                                               std::span<const uint64_t> _sizes)
{
    if( _raw_items_indices.size() != _sizes.size() )
        return 0;

    size_t num_set = 0;
    size_t num_changed = 0;
    const auto listing = m_Listing.get();
    const auto items_count = listing->Count();

    // O(N) iterate over the entire input set
    for( size_t ind = 0; ind != _raw_items_indices.size(); ++ind ) {
        const unsigned raw_index = _raw_items_indices[ind];
        const uint64_t size = _sizes[ind];
        if( raw_index >= items_count )
            throw std::out_of_range("SetCalculatedSizesForDirectories: invalid index");

        if( listing->IsDir(raw_index) ) {
            ++num_set;
            auto &vd = m_VolatileData[raw_index];
            if( vd.size != size ) {
                vd.size = size;
                ++num_changed;
            }
        }
    }

    if( num_changed != 0 )
        FinalizeSettingCalculatedSizes();

    return num_set;
}

void Model::FinalizeSettingCalculatedSizes()
{
    // double-check me
    DoSortWithHardFiltering();
    ClearSelectedFlagsFromHiddenElements();
    BuildSoftFilteringIndeces();
    UpdateStatictics();
}

void Model::CustomIconClearAll()
{
    for( auto &vd : m_VolatileData )
        vd.icon = 0;
}

void Model::CustomFlagsClearHighlights()
{
    for( auto &vd : m_VolatileData )
        vd.toggle_highlight(false);
}

int Model::SortedIndexForName(std::string_view _filename) const noexcept
{
    return SortedIndexForRawIndex(RawIndexForName(_filename));
}

bool Model::ClearTextFiltering()
{
    if( m_SoftFiltering.text == nil && m_HardFiltering.text.text == nil )
        return false;

    m_SoftFiltering.text = nil;
    m_HardFiltering.text.text = nil;

    for( auto &vd : m_VolatileData ) {
        vd.highlight = {};
    }

    DoSortWithHardFiltering();
    ClearSelectedFlagsFromHiddenElements(); // not sure if this is needed here
    BuildSoftFilteringIndeces();
    UpdateStatictics();
    return true;
}

void Model::SetHardFiltering(const HardFilter &_filter)
{
    if( m_HardFiltering == _filter )
        return;

    m_HardFiltering = _filter;

    DoSortWithHardFiltering();
    ClearSelectedFlagsFromHiddenElements();
    BuildSoftFilteringIndeces();
    UpdateStatictics();
}

HardFilter Model::HardFiltering() const
{
    return m_HardFiltering;
}

void Model::DoSortWithHardFiltering()
{
    m_EntriesByCustomSort.clear();
    m_ReverseToCustomSort.clear();

    const unsigned size = m_Listing->Count();

    if( size == 0 )
        return;

    m_EntriesByCustomSort.reserve(size);
    for( auto &vd : m_VolatileData ) {
        vd.highlight = {};
        vd.toggle_shown(true);
    }

    if( m_HardFiltering.IsFiltering() ) {
        auto filter = [&](const VFSListingItem &_item) -> std::optional<QuickSearchHiglight> {
            QuickSearchHiglight found_range;
            const bool valid = m_HardFiltering.IsValidItem(_item, found_range);
            if( valid )
                return found_range;
            return {};
        };
        std::vector<std::optional<QuickSearchHiglight>> found_ranges(size);
        pstld::transform(m_Listing->begin(), m_Listing->end(), found_ranges.begin(), filter);

        const bool hightlight_results = m_HardFiltering.text.hightlight_results;
        for( unsigned i = 0; i != size; ++i ) {
            if( !found_ranges[i] ) {
                m_VolatileData[i].toggle_shown(false);
            }
            else {
                if( hightlight_results ) {
                    m_VolatileData[i].highlight = *found_ranges[i];
                }
                m_EntriesByCustomSort.push_back(i);
            }
        }
    }
    else {
        m_EntriesByCustomSort.resize(m_Listing->Count());
        // NOLINTNEXTLINE - Xcode16 doesn't have std::ranges::iota
        std::iota(m_EntriesByCustomSort.begin(), m_EntriesByCustomSort.end(), 0);
    }

    if( m_EntriesByCustomSort.empty() || m_CustomSortMode.sort == SortMode::SortNoSort )
        return; // we're already done

    // do not touch dotdot directory. however, in some cases (root dir for example) there will be
    // no dotdot dir. also assumes that no filtering will exclude dotdot dir
    const auto first = std::next(m_EntriesByCustomSort.begin(), m_Listing->IsDotDot(0) ? 1 : 0);
    const auto last = std::end(m_EntriesByCustomSort);

    if( m_EntriesByCustomSort.size() < g_ParallelSortThresh )
        std::sort(first, last, IndirectListingComparator{*m_Listing, m_VolatileData, m_CustomSortMode});
    else
        pstld::sort(first, last, IndirectListingComparator{*m_Listing, m_VolatileData, m_CustomSortMode});

    m_ReverseToCustomSort.resize(size);
    std::ranges::fill(m_ReverseToCustomSort, std::numeric_limits<unsigned>::max());
    for( unsigned i = 0, e = static_cast<unsigned>(m_EntriesByCustomSort.size()); i != e; ++i ) {
        const unsigned forward_index = m_EntriesByCustomSort[i];
        assert(forward_index < size);
        m_ReverseToCustomSort[forward_index] = i;
    }
}

void Model::SetSoftFiltering(const TextualFilter &_filter)
{
    m_SoftFiltering = _filter;
    BuildSoftFilteringIndeces();
}

TextualFilter Model::SoftFiltering() const
{
    return m_SoftFiltering;
}

const std::vector<unsigned> &Model::EntriesBySoftFiltering() const noexcept
{
    return m_EntriesBySoftFiltering;
}

void Model::BuildSoftFilteringIndeces()
{
    if( m_SoftFiltering.IsFiltering() ) {
        m_EntriesBySoftFiltering.clear();
        m_EntriesBySoftFiltering.reserve(m_EntriesByCustomSort.size());

        int i = 0;
        const int e = static_cast<int>(m_EntriesByCustomSort.size());
        for( ; i != e; ++i ) {
            QuickSearchHiglight found_range;
            const int raw_index = m_EntriesByCustomSort[i];
            if( m_SoftFiltering.IsValidItem(m_Listing->Item(raw_index), found_range) )
                m_EntriesBySoftFiltering.push_back(i);

            if( m_SoftFiltering.hightlight_results ) {
                m_VolatileData[raw_index].highlight = found_range;
            }
        }
    }
    else {
        m_EntriesBySoftFiltering.resize(m_EntriesByCustomSort.size());
        // NOLINTNEXTLINE - Xcode16 doesn't have std::ranges::iota
        std::iota(m_EntriesBySoftFiltering.begin(), m_EntriesBySoftFiltering.end(), 0);
    }
}

ExternalEntryKey Model::EntrySortKeysAtSortPosition(int _pos) const
{
    auto item = EntryAtSortPosition(_pos);
    if( !item )
        throw std::invalid_argument("PanelData::EntrySortKeysAtSortPosition: invalid item position");
    return ExternalEntryKey{item, VolatileDataAtSortPosition(_pos)};
}

int Model::SortLowerBoundForEntrySortKeys(const ExternalEntryKey &_keys) const
{
    if( !_keys.is_valid() )
        return -1;

    // NOLINTNEXTLINE
    auto it = std::lower_bound(std::begin(m_EntriesByCustomSort),
                               std::end(m_EntriesByCustomSort),
                               _keys,
                               ExternalListingComparator(*m_Listing, m_VolatileData, m_CustomSortMode));
    if( it != std::end(m_EntriesByCustomSort) )
        return static_cast<int>(std::distance(std::begin(m_EntriesByCustomSort), it));
    return -1;
}

const Statistics &Model::Stats() const noexcept
{
    return m_Stats;
}

void Model::__InvariantCheck() const
{
    assert(m_Listing != nullptr);
    assert(m_VolatileData.size() == m_Listing->Count());
    assert(m_EntriesByRawName.size() == m_Listing->Count());
    assert(m_EntriesByCustomSort.size() <= m_Listing->Count());
    assert(m_EntriesBySoftFiltering.size() <= m_EntriesByCustomSort.size());
}

int Model::RawEntriesCount() const noexcept
{
    return m_Listing ? static_cast<int>(m_Listing->Count()) : 0;
}

int Model::SortedEntriesCount() const noexcept
{
    return static_cast<int>(m_EntriesByCustomSort.size());
}

} // namespace nc::panel::data

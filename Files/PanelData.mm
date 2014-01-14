#import "PanelData.h"
#import <algorithm>
#import <string.h>
#import <assert.h>
#import <CoreFoundation/CoreFoundation.h>
#import "Common.h"
#import "chained_strings.h"
#import "FileMask.h"

static inline PanelSortMode DefaultSortMode()
{
    PanelSortMode mode;
    mode.sep_dirs = true;
    mode.sort = PanelSortMode::SortByName;
    return mode;
    
}

PanelData::PanelData():
    m_SortExecGroup(DispatchGroup::High),
    m_Listing(make_shared<VFSListing>("", shared_ptr<VFSHost>(0))),
    m_CustomSortMode(DefaultSortMode())
{
}

void PanelData::Load(shared_ptr<VFSListing> _listing)
{
    assert(dispatch_is_main_queue()); // STA api design
    
    m_Listing = _listing;
    
    m_HardFiltering.text.OnPanelDataLoad();
    m_SoftFiltering.OnPanelDataLoad();
    
    // now sort our new data
    m_SortExecGroup.Run(^{ DoRawSort(m_Listing, m_EntriesByRawName); });
    m_SortExecGroup.Run(^{ DoSortWithHardFiltering(); });
    m_SortExecGroup.Wait();
    BuildSoftFilteringIndeces();
    // update stats
    UpdateStatictics();
}

void PanelData::ReLoad(shared_ptr<VFSListing> _listing)
{
    assert(dispatch_is_main_queue()); // STA api design
    
    // sort new entries by raw c name for sync-swapping needs
    DirSortIndT dirbyrawcname;
    DoRawSort(_listing, dirbyrawcname);
    
    // transfer custom data to new array using sorted indeces arrays
    size_t dst_i = 0, dst_e = _listing->Count(),
    src_i = 0, src_e = m_Listing->Count();
    for(;src_i < src_e && dst_i < dst_e; ++src_i)
    {
        int src = m_EntriesByRawName[src_i];
    check:  int dst = (dirbyrawcname)[dst_i];
        int cmp = strcmp((*m_Listing)[src].Name(), (*_listing)[dst].Name());
        if( cmp == 0 )
        {
            auto &item_dst = (*_listing)[dst];
            const auto &item_src = (*m_Listing)[src];
            
            item_dst.SetCFlags(item_src.CFlags());
            item_dst.SetCIcon(item_src.CIcon());
            
            if(item_dst.Size() == VFSListingItem::InvalidSize)
                item_dst.SetSize(item_src.Size()); // transfer sizes for folders - it can be calculated earlier
            
            ++dst_i;                    // check this! we assume that normal directory can't hold two files with a same name
            if(dst_i == dst_e) break;
        }
        else if( cmp > 0 )
        {
            dst_i++;
            if(dst_i == dst_e) break;
            goto check;
        }
    }
    
    // put a new data in a place
    m_Listing = _listing;
    m_EntriesByRawName.swap(dirbyrawcname);
    
    // now sort our new data with custom sortings
    DoSortWithHardFiltering();
    BuildSoftFilteringIndeces();
    UpdateStatictics();
}

shared_ptr<VFSHost> PanelData::Host() const
{
    return m_Listing->Host();
}

shared_ptr<VFSListing> PanelData::Listing() const
{
    return m_Listing;
}

const VFSListing& PanelData::DirectoryEntries() const
{
    return *m_Listing.get();
}

const PanelData::DirSortIndT& PanelData::SortedDirectoryEntries() const
{
    return m_EntriesByCustomSort;
}

string PanelData::FullPathForEntry(int _raw_index) const
{
    if(_raw_index < 0 || _raw_index >= m_Listing->Count())
        return "";

    const auto &entry = m_Listing->At(_raw_index);
    if(!entry.IsDotDot()) {
        return DirectoryPathWithTrailingSlash() + entry.Name();
    }
    else {
        auto t = DirectoryPathWithoutTrailingSlash();
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
    
    // performing binary search on m_EntriesByRawName
    auto begin = m_EntriesByRawName.begin(), end = m_EntriesByRawName.end();
    auto i = lower_bound(begin, end, _filename,
                         [=](unsigned _i, const char* _s) {
                             return strcmp((*m_Listing)[_i].Name(), _s) < 0;
                         });
    if(i < end &&
       strcmp(_filename, (*m_Listing)[*i].Name()) == 0)
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
    if(m_Listing.get() == 0)
        return "";
    
    string path = m_Listing->RelativePath();
    if(path.size() > 1 && path.back() == '/')
        path.pop_back();
    
    return path;
}

string PanelData::DirectoryPathWithTrailingSlash() const
{
    if(m_Listing.get() == 0)
        return "";
    
    string path = m_Listing->RelativePath();
    if(path.size() > 0 && path.back() != '/')
        path.push_back('/');
    
    return path;
}

string PanelData::DirectoryPathShort() const
{    
    string tmp = DirectoryPathWithoutTrailingSlash();
    auto i = tmp.rfind('/');
    if(i != string::npos)
        return tmp.c_str() + i + 1;
    return "";
}

void PanelData::GetDirectoryFullHostsPathWithTrailingSlash(char _buf[MAXPATHLEN*8]) const
{
    if(m_Listing.get() == 0) {
        strcpy(_buf, "");
        return;
    }
    
    VFSHost *hosts[32];
    int hosts_n = 0;

    VFSHost *cur = m_Listing->Host().get();
    while(cur && cur->Parent().get() != 0) // skip the root host
    {
        hosts[hosts_n++] = cur;
        cur = cur->Parent().get();
    }
    
    strcpy(_buf, "");
    while(hosts_n > 0)
        strcat(_buf, hosts[--hosts_n]->JunctionPath());
    
    strcat(_buf, m_Listing->RelativePath());
    if(_buf[strlen(_buf)-1]!='/') strcat(_buf, "/"); // TODO: optimize me later
}

struct SortPredLess
{
private:
    shared_ptr<VFSListing>          ind_tar;
    PanelSortMode                   sort_mode;
    CFStringCompareFlags            str_comp_flags;
public:
    SortPredLess(shared_ptr<VFSListing> _items, PanelSortMode sort_mode):
        ind_tar(_items),
        sort_mode(sort_mode)
    {
        str_comp_flags = (sort_mode.case_sens ? 0 : kCFCompareCaseInsensitive) |
            (sort_mode.numeric_sort ? kCFCompareNumerically : 0);
        
    }
    
  	bool operator()(unsigned _1, unsigned _2) const
    {
        const auto &val1 = (*ind_tar)[_1];
        const auto &val2 = (*ind_tar)[_2];
        
        if(sort_mode.sep_dirs)
        {
            if(val1.IsDir() && !val2.IsDir()) return true;
            if(!val1.IsDir() && val2.IsDir()) return false;
        }
        
        switch(sort_mode.sort)
        {
            case PanelSortMode::SortByName:
                return CFStringCompare(val1.CFName(), val2.CFName(), str_comp_flags) < 0;
            case PanelSortMode::SortByNameRev:
                return CFStringCompare(val1.CFName(), val2.CFName(), str_comp_flags) > 0;
            case PanelSortMode::SortByExt:
                if(val1.HasExtension() && val2.HasExtension() )
                {
                    int r = strcmp(val1.Extension(), val2.Extension());
                    if(r < 0) return true;
                    if(r > 0) return false;
                    return CFStringCompare(val1.CFName(), val2.CFName(), str_comp_flags) < 0;
                }
                if(val1.HasExtension() && !val2.HasExtension() ) return false;
                if(!val1.HasExtension() && val2.HasExtension() ) return true;
                return CFStringCompare(val1.CFName(), val2.CFName(), str_comp_flags) < 0; // fallback case
            case PanelSortMode::SortByExtRev:
                if(val1.HasExtension() && val2.HasExtension() )
                {
                    int r = strcmp(val1.Extension(), val2.Extension());
                    if(r < 0) return false;
                    if(r > 0) return true;
                    return CFStringCompare(val1.CFName(), val2.CFName(), str_comp_flags) > 0;
                }
                if(val1.HasExtension() && !val2.HasExtension() ) return true;
                if(!val1.HasExtension() && val2.HasExtension() ) return false;
                return CFStringCompare(val1.CFName(), val2.CFName(), str_comp_flags) > 0; // fallback case
            case PanelSortMode::SortByMTime:    return val1.MTime() > val2.MTime();
            case PanelSortMode::SortByMTimeRev: return val1.MTime() < val2.MTime();
            case PanelSortMode::SortByBTime:    return val1.BTime() > val2.BTime();
            case PanelSortMode::SortByBTimeRev: return val1.BTime() < val2.BTime();
            case PanelSortMode::SortBySize:
                if(val1.Size() != VFSListingItem::InvalidSize && val2.Size() != VFSListingItem::InvalidSize)
                    if(val1.Size() != val2.Size()) return val1.Size() > val2.Size();
                if(val1.Size() != VFSListingItem::InvalidSize && val2.Size() == VFSListingItem::InvalidSize) return false;
                if(val1.Size() == VFSListingItem::InvalidSize && val2.Size() != VFSListingItem::InvalidSize) return true;
                return CFStringCompare(val1.CFName(), val2.CFName(), str_comp_flags) < 0; // fallback case
            case PanelSortMode::SortBySizeRev:
                if(val1.Size() != VFSListingItem::InvalidSize && val2.Size() != VFSListingItem::InvalidSize)
                    if(val1.Size() != val2.Size()) return val1.Size() < val2.Size();
                if(val1.Size() != VFSListingItem::InvalidSize && val2.Size() == VFSListingItem::InvalidSize) return true;
                if(val1.Size() == VFSListingItem::InvalidSize && val2.Size() != VFSListingItem::InvalidSize) return false;
                return CFStringCompare(val1.CFName(), val2.CFName(), str_comp_flags) > 0; // fallback case
            case PanelSortMode::SortByRawCName:
                return strcmp(val1.Name(), val2.Name()) < 0;
                break;
            case PanelSortMode::SortNoSort:
                assert(0); // meaningless sort call
                break;

            default:;
        };

        return false;
    }
};

void PanelData::DoRawSort(shared_ptr<VFSListing> _from, PanelData::DirSortIndT &_to)
{
    if(_from->Count() == 0) {
        _to.clear();
        return;
    }
  
    _to.resize(_from->Count());

    unsigned index = 0;
    generate( begin(_to), end(_to), [&]{return index++;} );
    
    const VFSListing *from = _from.get();
    sort(begin(_to),
         end(_to),
         [=](unsigned _1, unsigned _2) { return strcmp(from->At(_1).Name(), from->At(_2).Name()) < 0; }
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
    int s = m_Listing->Count();
    for(int i =0; i < s; ++i)
        if(m_EntriesShownFlags[i] == false &&
           (*m_Listing)[i].CFIsSelected() )
            (*m_Listing)[i].UnsetCFlag(VFSListingItem::Flags::Selected);
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
    
    // calculate totals for directory
    for(const auto &i: *m_Listing)
        if(i.IsReg()) {
            m_Stats.bytes_in_raw_reg_files += i.Size();
            m_Stats.raw_reg_files_amount++;
        }
    
    // calculate totals for selected. look only for entries which is visible (sorted/filtered ones)
    for(auto n: m_EntriesByCustomSort) {
        const auto &i = m_Listing->At(n);
        if(i.CFIsSelected()) {
            if(i.Size() != VFSListingItem::InvalidSize)
                m_Stats.bytes_in_selected_entries += i.Size();
            m_Stats.selected_entries_amount++;
            if(i.IsDir())  m_Stats.selected_dirs_amount++;
            else           m_Stats.selected_reg_amount++;
        }
    }
}

int PanelData::RawIndexForSortIndex(int _index) const
{
    if(_index < 0 || _index >= m_EntriesByCustomSort.size())
        return -1;
    return m_EntriesByCustomSort[_index];
}

const VFSListingItem* PanelData::EntryAtRawPosition(int _pos) const
{
    if( m_Listing &&
        _pos >= 0 &&
        _pos < m_Listing->Count() )
        return &m_Listing->At(_pos);
    return nullptr;
}

void PanelData::CustomFlagsSelectRaw(int _at_raw_pos, bool _is_selected)
{
    auto &entry = m_Listing->At(_at_raw_pos);
    
    if(entry.IsDotDot())
        return; // assuming we can't select dotdot entry
    
    if(entry.CFIsSelected() == _is_selected) // check if item is already selected
        return;
    
    if(_is_selected)
    {
        if(entry.Size() != VFSListingItem::InvalidSize)
            m_Stats.bytes_in_selected_entries += entry.Size();
        m_Stats.selected_entries_amount++;
        
        if(entry.IsDir()) m_Stats.selected_dirs_amount++;
        else              m_Stats.selected_reg_amount++; // mb another check for reg here?
        
        entry.SetCFlag(VFSListingItem::Flags::Selected);
    }
    else
    {
        if(entry.Size() != VFSListingItem::InvalidSize)
        {
            assert(m_Stats.bytes_in_selected_entries >= entry.Size()); // sanity check
            m_Stats.bytes_in_selected_entries -= entry.Size();
        }
        assert(m_Stats.selected_entries_amount > 0); // sanity check
        m_Stats.selected_entries_amount--;
        if(entry.IsDir())
        {
            assert(m_Stats.selected_dirs_amount > 0);
            m_Stats.selected_dirs_amount--;
        }
        else
        {
            assert(m_Stats.selected_reg_amount > 0);
            m_Stats.selected_reg_amount--;
        }
        entry.UnsetCFlag(VFSListingItem::Flags::Selected);
    }
}

void PanelData::CustomFlagsSelectSorted(int _at_pos, bool _is_selected)
{
    if(_at_pos < 0 || _at_pos >= m_EntriesByCustomSort.size())
        return;
    
    CustomFlagsSelectRaw(m_EntriesByCustomSort[_at_pos], _is_selected);
}

void PanelData::CustomFlagsSelectAllSorted(bool _select)
{
    for(auto i: m_EntriesByCustomSort) {
        auto &ent = m_Listing->At(i);
        if(!ent.IsDotDot()) {
            if(_select)
                ent.SetCFlag(VFSListingItem::Flags::Selected);
            else
                ent.UnsetCFlag(VFSListingItem::Flags::Selected);
        }
    }

    UpdateStatictics();
}

chained_strings PanelData::StringsFromSelectedEntries() const
{
    chained_strings str;
    for(auto const &i: *m_Listing)
        if(i.CFIsSelected())
            str.push_back(i.Name(), (int)i.NameLen(), nullptr);
    return str;
}

bool PanelData::SetCalculatedSizeForDirectory(const char *_entry, uint64_t _size)
{
    if(_entry    == nullptr ||
       _entry[0] == 0       ||
       _size == VFSListingItem::InvalidSize )
        return false;
    
    int n = RawIndexForName(_entry);
    if(n >= 0)
    {
        auto &i = (*m_Listing)[n];
        if(i.IsDir())
        {
            if(i.CFIsSelected())
            { // need to adjust our selected bytes statistic
                if(i.Size() != VFSListingItem::InvalidSize)
                {
                    assert(i.Size() <= m_Stats.bytes_in_selected_entries);
                    m_Stats.bytes_in_selected_entries -= i.Size();
                }
                m_Stats.bytes_in_selected_entries += _size;
            }

            i.SetSize(_size);

            return true;
        }
    }
    return false;
}

void PanelData::CustomIconSet(size_t _at_raw_pos, unsigned short _icon_id)
{
    assert(_at_raw_pos < m_Listing->Count());
    auto &entry = (*m_Listing)[_at_raw_pos];
    entry.SetCIcon(_icon_id);
}

void PanelData::CustomIconClearAll()
{
    for (auto &entry : *m_Listing)
        entry.SetCIcon(0);
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
        const auto &entry = (*m_Listing)[i];
        
        if(_ignore_dirs && entry.IsDir())
            continue;
        
        if(entry.IsDotDot())
            continue;
        
        if(mask.MatchName((__bridge NSString*)entry.CFName())) {
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

bool PanelDataTextFiltering::IsValidItem(const VFSListingItem& _item) const
{
    if(text == nil)
        return true;
    
    if(ignoredotdot && _item.IsDotDot())
        return true; // never filter out the Holy Dot-Dot directory!
    
    auto textlen = text.length;
    if(textlen == 0)
        return true; // will return true on any item with @"" filter
    
    NSString *name = (__bridge NSString*) _item.CFName();
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

bool PanelDataHardFiltering::IsValidItem(const VFSListingItem& _item) const
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
    m_EntriesShownFlags.resize(size, true);
  
    if(m_HardFiltering.IsFiltering())
    {
        for(int i = 0; i < size; ++i)
            if( m_HardFiltering.IsValidItem(m_Listing->At(i)) )
                m_EntriesByCustomSort.push_back(i);
            else
                m_EntriesShownFlags[i] = false;
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
    
    SortPredLess pred(m_Listing, m_CustomSortMode);
    DirSortIndT::iterator start = begin(m_EntriesByCustomSort);
    
    // do not touch dotdot directory. however, in some cases (root dir for example) there will be no dotdot dir
    // also assume that no filtering will exclude dotdot dir
    if( m_Listing->At(0).IsDotDot() )
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
            if(m_SoftFiltering.IsValidItem(m_Listing->At(m_EntriesByCustomSort[i])))
                m_EntriesBySoftFiltering.push_back(i);
    }
    else {
        m_EntriesBySoftFiltering.resize(m_EntriesByCustomSort.size());
        unsigned index = 0;
        generate( begin(m_EntriesBySoftFiltering), end(m_EntriesBySoftFiltering), [&]{return index++;} );
    }
}

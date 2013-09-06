#import "PanelData.h"
#import <algorithm>
#import <string.h>
#import <assert.h>
#import <CoreFoundation/CoreFoundation.h>
#import "Common.h"
#import "FlexChainedStringsChunk.h"

PanelData::PanelData()
{
//    m_Entries = new DirEntryInfoT;
    m_EntriesByRawName = new DirSortIndT;
    m_EntriesByHumanName = new DirSortIndT;
    m_EntriesByCustomSort = new DirSortIndT;
    m_TotalBytesInDirectory = 0;
    m_TotalFilesInDirectory = 0;
    m_SelectedItemsSizeBytes = 0;
    m_SelectedItemsCount = 0;
    m_SelectedItemsFilesCount = 0;
    m_SelectedItemsDirectoriesCount = 0;
    m_CustomSortMode.sep_dirs = true;
    m_CustomSortMode.sort = m_CustomSortMode.SortByName;
    m_CustomSortMode.show_hidden = false;
    m_SortExecGroup = dispatch_group_create();
    m_SortExecQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    m_Listing = std::make_shared<VFSListing>("", std::shared_ptr<VFSHost>(0));
}

PanelData::~PanelData()
{
    delete m_EntriesByRawName;
    delete m_EntriesByHumanName;
    delete m_EntriesByCustomSort;
    dispatch_release(m_SortExecGroup);
}

void PanelData::Load(std::shared_ptr<VFSListing> _listing)
{
    m_Listing = _listing;
    
    // now sort our new data
    dispatch_group_async(m_SortExecGroup, m_SortExecQueue, ^{
        PanelSortMode sort;
        sort.sort = PanelSortMode::SortByRawCName;
        sort.sep_dirs = false;
        DoSort(m_Listing, m_EntriesByRawName, sort); });
    dispatch_group_async(m_SortExecGroup, m_SortExecQueue, ^{
        PanelSortMode mode;
        mode.sep_dirs = false;
        mode.sort = PanelSortMode::SortByName;
        mode.show_hidden = m_CustomSortMode.show_hidden;
        mode.case_sens = false;
        mode.numeric_sort = false;
        DoSort(m_Listing, m_EntriesByHumanName, mode); });
    dispatch_group_async(m_SortExecGroup, m_SortExecQueue, ^{
        DoSort(m_Listing, m_EntriesByCustomSort, m_CustomSortMode); });
    dispatch_group_wait(m_SortExecGroup, DISPATCH_TIME_FOREVER);
    
    // update stats
    UpdateStatictics();
}

void PanelData::ReLoad(std::shared_ptr<VFSListing> _listing)
{
    // sort new entries by raw c name for sync-swapping needs
    auto *dirbyrawcname = new DirSortIndT;
    PanelSortMode rawsortmode;
    rawsortmode.sort = PanelSortMode::SortByRawCName;
    rawsortmode.sep_dirs = false;
    rawsortmode.show_hidden = true;
    rawsortmode.numeric_sort = false;
    
    DoSort(_listing, dirbyrawcname, rawsortmode);
    
    // transfer custom data to new array using sorted indeces arrays
    size_t dst_i = 0, dst_e = _listing->Count(),
    src_i = 0, src_e = m_Listing->Count();
    for(;src_i < src_e; ++src_i)
    {
        int src = (*m_EntriesByRawName)[src_i];
    check:  int dst = (*dirbyrawcname)[dst_i];
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
    
    // erase old data
    delete m_EntriesByRawName;
    
    // put a new data in a place
    m_Listing = _listing;
    m_EntriesByRawName = dirbyrawcname;
    
    // now sort our new data with custom sortings
    dispatch_group_async(m_SortExecGroup, m_SortExecQueue, ^{
        PanelSortMode mode;
        mode.sep_dirs = false;
        mode.sort = PanelSortMode::SortByName;
        mode.show_hidden = m_CustomSortMode.show_hidden;
        mode.case_sens = false;
        mode.numeric_sort = false;
        DoSort(m_Listing, m_EntriesByHumanName, mode); });
    dispatch_group_async(m_SortExecGroup, m_SortExecQueue, ^{
        DoSort(m_Listing, m_EntriesByCustomSort, m_CustomSortMode); });
    dispatch_group_wait(m_SortExecGroup, DISPATCH_TIME_FOREVER);
    
    // update stats
    UpdateStatictics();
}

const VFSListing& PanelData::DirectoryEntries() const
{
    return *m_Listing.get();
}

const PanelData::DirSortIndT& PanelData::SortedDirectoryEntries() const
{
    return *m_EntriesByCustomSort;
}

void PanelData::ComposeFullPathForEntry(int _entry_no, char _buf[__DARWIN_MAXPATHLEN])
{
    const char *ent_name = (*m_Listing)[_entry_no].Name();
    
    if(strcmp(ent_name, ".."))
    {
        strcpy(_buf, m_Listing->RelativePath());
        if(_buf[strlen(_buf)-1] != '/') strcat(_buf, "/");
        strcat(_buf, ent_name);
    }
    else
    {
        // need to cut the last slash
        strcpy(_buf, m_Listing->RelativePath());
        if(_buf[strlen(_buf)-1] == '/') _buf[strlen(_buf)-1] = 0; // cut trailing slash
        char *s = strrchr(_buf, '/');
        if(s != _buf) *s = 0;
        else *(s+1) = 0;
    }
}

int PanelData::FindEntryIndex(const char *_filename) const
{
    assert(m_EntriesByRawName->size() == m_Listing->Count()); // consistency check
    assert(_filename != 0);
    
    if(strcmp(_filename, "..") == 0)
    {
        // special case - need to process it separately since dot-dot entry don't obey sort direction
        if(m_Listing->Count() && (*m_Listing)[0].IsDotDot())
            return 0;
        return -1;
    }
    
    // performing binary search on m_EntriesByRawName
    int imin = 0, imax = (int)m_EntriesByRawName->size()-1;
    if(imin <= imax && (*m_Listing)[(*m_EntriesByRawName)[imin]].IsDotDot() )
        imin++; // exclude dot-dot entry from searching since it causes a nasty side-effect

    while(imax >= imin)
    {
        int imid = (imin + imax) / 2;
        
        unsigned indx = (*m_EntriesByRawName)[imid];
        assert(indx < m_Listing->Count());
        
        int res = strcmp(_filename, (*m_Listing)[indx].Name());

        if(res < 0)
            imax = imid - 1;
        else if(res > 0)
            imin = imid + 1;
        else
            return indx;
    }
    
    return -1;
}

int PanelData::FindSortedEntryIndex(unsigned _desired_value) const
{
    // TODO: consider creating reverse (raw entry->sorted entry) map to speed up performance
    // ( if the code below will every became a problem - we can change it from O(n) to O(1) )
    size_t i = 0, e = m_EntriesByCustomSort->size();
    const auto *v = m_EntriesByCustomSort->data();
    for(;i<e;++i)
        if(v[i] == _desired_value)
            return (int)i;
    return -1;
}

void PanelData::GetDirectoryPath(char _buf[__DARWIN_MAXPATHLEN]) const
{
    if(m_Listing.get() == 0) {
        strcpy(_buf, "");
        return;
    }
    strcpy(_buf, m_Listing->RelativePath());
    if(_buf[strlen(_buf)-1] == '/' && strlen(_buf) > 1)
        _buf[strlen(_buf)-1] = 0; // TODO: optimize me later
//    char *slash = strrchr(_buf, '/');
//    if (slash && slash != _buf) *slash = 0;
}

void PanelData::GetDirectoryPathWithTrailingSlash(char _buf[__DARWIN_MAXPATHLEN]) const
{
    if(m_Listing.get() == 0) {
        strcpy(_buf, "");
        return;
    }
    strcpy(_buf, m_Listing->RelativePath());
    if(_buf[strlen(_buf)-1]!='/') strcat(_buf, "/"); // TODO: optimize me later
    
}

void PanelData::GetDirectoryPathShort(char _buf[__DARWIN_MAXPATHLEN]) const
{
    if(m_Listing.get() == 0) {
        strcpy(_buf, "");
        return;
    }
    
    if(strlen(m_Listing->RelativePath()) == 0)
    {
        _buf[0] = 0;
    }
    else
    {
        // TODO: optimize me later
        char tmp[MAXPATHLEN];
//        strcpy(tmp, m_Listing->RelativePath());
        GetDirectoryPathWithTrailingSlash(tmp);
        if(char *s = strrchr(tmp, '/')) *s = 0; // cut trailing slash
        if(char *s = strrchr(tmp, '/')) strcpy(_buf, s+1);
        else                            strcpy(_buf, tmp);
    }
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
    while(cur->Parent().get() != 0) // skip the root host
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
    const std::shared_ptr<VFSListing> ind_tar;
    PanelSortMode                   sort_mode;
    CFStringCompareFlags            str_comp_flags;
public:
    SortPredLess(const std::shared_ptr<VFSListing> _items, PanelSortMode sort_mode):
        ind_tar(_items),
        sort_mode(sort_mode)
    {
        str_comp_flags = (sort_mode.case_sens ? 0 : kCFCompareCaseInsensitive) |
            (sort_mode.numeric_sort ? kCFCompareNumerically : 0);
        
    }
    
  	bool operator()(unsigned _1, unsigned _2)
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

void PanelData::DoSort(const std::shared_ptr<VFSListing> _from, PanelData::DirSortIndT *_to, PanelSortMode _mode)
{
    _to->clear();
    _to->resize(_from->Count());
    if(_to->empty())
        return;
  
    if(_mode.show_hidden)
    {
        size_t i = 0, e = _from->Count();
        for(; i < e; ++i)
            (*_to)[i] = (unsigned)i;
    }
    else
    {
        size_t nsrc = 0, ndst = 0;
        size_t ssrc = _from->Count();
        for(;nsrc<ssrc;++nsrc)
            if( (*_from)[nsrc].IsHidden() == false )
            {
                (*_to)[ndst] = (unsigned) nsrc;
                ++ndst;
            }
        _to->resize(ndst); // now have only elements that are not hidden
    }
    
    if(_mode.sort == PanelSortMode::SortNoSort)
        return; // we're already done
 
    SortPredLess pred(_from, _mode);
    DirSortIndT::iterator start=_to->begin(), end=_to->end();
    if( (*_from)[0].IsDotDot() ) start++; // do not touch dotdot directory. however, in some cases (root dir for example) there will be no dotdot dir
    
    std::sort(start, end, pred);
}

void PanelData::SetCustomSortMode(PanelSortMode _mode)
{
    if(m_CustomSortMode != _mode)
    {
        if(m_CustomSortMode.show_hidden == _mode.show_hidden)
        {
            m_CustomSortMode = _mode;
            DoSort(m_Listing, m_EntriesByCustomSort, m_CustomSortMode);
        }
        else
        {
            m_CustomSortMode = _mode;
            // need to update fast search indeces also, since there are structural changes
            dispatch_group_async(m_SortExecGroup, m_SortExecQueue, ^{
                PanelSortMode mode;
                mode.sep_dirs = false;
                mode.sort = PanelSortMode::SortByName;
                mode.show_hidden = m_CustomSortMode.show_hidden;
                mode.case_sens = false;
                DoSort(m_Listing, m_EntriesByHumanName, mode); });
            dispatch_group_async(m_SortExecGroup, m_SortExecQueue, ^{
                DoSort(m_Listing, m_EntriesByCustomSort, m_CustomSortMode); });
            dispatch_group_wait(m_SortExecGroup, DISPATCH_TIME_FOREVER);
            
            UpdateStatictics(); // we need to update statistics since some selected enties may become invisible and hence should be deselected
        }
    }
}

PanelSortMode PanelData::GetCustomSortMode() const
{
    return m_CustomSortMode;
}

void PanelData::UpdateStatictics()
{
    if(m_Listing.get() == 0)
    {
        m_TotalBytesInDirectory = 0;
        m_TotalFilesInDirectory = 0;
        m_SelectedItemsSizeBytes = 0;
        m_SelectedItemsCount = 0;
        m_SelectedItemsDirectoriesCount = 0;
        m_SelectedItemsFilesCount = 0;
        return;
    }
    
    unsigned long totalbytes = 0;
    unsigned totalfiles = 0;
    unsigned long totalselectedbytes = 0;
    unsigned totalselected = 0;
    unsigned totalselectedfiles = 0;
    unsigned totalselecteddirs = 0;

    // calculate totals for directory
    for(const auto &i: *m_Listing)
        if(i.IsReg())
        {
            totalbytes += i.Size();
            totalfiles++;
        }
    
    // calculate totals for selected. look only for entries which is visible (sorted/filtered ones)
    for(auto n: *m_EntriesByCustomSort)
    {
        const auto &i = (*m_Listing)[n];
        if(i.CFIsSelected())
        {
            if(i.Size() != VFSListingItem::InvalidSize)
                totalselectedbytes += i.Size();
            totalselected++;
            if(i.IsDir())  totalselecteddirs++;
            else           totalselectedfiles++;
        }
    }
    
    m_TotalBytesInDirectory = totalbytes;
    m_TotalFilesInDirectory = totalfiles;
    m_SelectedItemsSizeBytes = totalselectedbytes;
    m_SelectedItemsCount = totalselected;
    m_SelectedItemsDirectoriesCount = totalselecteddirs;
    m_SelectedItemsFilesCount = totalselectedfiles;
}

unsigned long PanelData::GetTotalBytesInDirectory() const
{
    return m_TotalBytesInDirectory;
}

unsigned PanelData::GetTotalFilesInDirectory() const
{
    return m_TotalFilesInDirectory;
}

int PanelData::SortPosToRawPos(int _pos) const
{
    assert(_pos >= 0 && _pos < m_EntriesByCustomSort->size());
    return (*m_EntriesByCustomSort)[_pos];
}

//const DirectoryEntryInformation& PanelData::EntryAtRawPosition(int _pos) const
const VFSListingItem& PanelData::EntryAtRawPosition(int _pos) const
{
    assert(m_Listing.get());
    assert(_pos >= 0 && _pos < m_Listing->Count());
    return (*m_Listing)[_pos];
}

void PanelData::CustomFlagsSelect(size_t _at_pos, bool _is_selected)
{
    assert(m_Listing.get());
    assert(_at_pos < m_Listing->Count());
    auto &entry = (*m_Listing)[_at_pos];
    assert(entry.IsDotDot() == false); // assuming we can't select dotdot entry
    if(entry.CFIsSelected() == _is_selected) // check if item is already selected
        return;
    if(_is_selected)
    {
        if(entry.Size() != VFSListingItem::InvalidSize)
            m_SelectedItemsSizeBytes += entry.Size();
        m_SelectedItemsCount++;

        if(entry.IsDir()) m_SelectedItemsDirectoriesCount++;
        else              m_SelectedItemsFilesCount++;

        entry.SetCFlag(VFSListingItem::Flags::Selected);
    }
    else
    {
        if(entry.Size() != VFSListingItem::InvalidSize)
        {
            assert(m_SelectedItemsSizeBytes >= entry.Size()); // sanity check
            m_SelectedItemsSizeBytes -= entry.Size();
        }
        assert(m_SelectedItemsCount >= 0); // sanity check
        m_SelectedItemsCount--;
        if(entry.IsDir())
        {
            assert(m_SelectedItemsDirectoriesCount >= 0);
            m_SelectedItemsDirectoriesCount--;
        }
        else
        {
            assert(m_SelectedItemsFilesCount >= 0);
            m_SelectedItemsFilesCount--;
        }
        entry.UnsetCFlag(VFSListingItem::Flags::Selected);
    }
}

void PanelData::CustomFlagsSelectAll(bool _select)
{
    assert(m_Listing.get());
    size_t i = 0, e = m_Listing->Count();
    if(e > 0 && (*m_Listing)[i].IsDotDot()) ++i;
    for(;i<e;++i)
        CustomFlagsSelect((int)i, _select);
}

void PanelData::CustomFlagsSelectAllSorted(bool _select)
{
    auto sz = m_Listing->Count();
    if(_select)
        for(auto i: *m_EntriesByCustomSort)
        {
            assert(i < sz);
            auto &ent = (*m_Listing)[i];
            if(!ent.IsDotDot())
                ent.SetCFlag(VFSListingItem::Flags::Selected);
        }
    else
        for(auto i: *m_EntriesByCustomSort)
        {
            assert(i < sz);
            auto &ent = (*m_Listing)[i];
            if(!ent.IsDotDot())
                ent.UnsetCFlag(VFSListingItem::Flags::Selected);
        }    

    UpdateStatictics();
}

unsigned PanelData::GetSelectedItemsCount() const
{
    return m_SelectedItemsCount;
}

unsigned long PanelData::GetSelectedItemsSizeBytes() const
{
    return m_SelectedItemsSizeBytes;
}

unsigned PanelData::GetSelectedItemsFilesCount() const
{
    return m_SelectedItemsFilesCount;
}

unsigned PanelData::GetSelectedItemsDirectoriesCount() const
{
    return m_SelectedItemsDirectoriesCount;
}

FlexChainedStringsChunk* PanelData::StringsFromSelectedEntries() const
{
    FlexChainedStringsChunk *chunk = FlexChainedStringsChunk::Allocate();
    FlexChainedStringsChunk *last = chunk;
    
    for(auto const &i: *m_Listing)
        if(i.CFIsSelected())
            last = last->AddString(i.Name(), (int)i.NameLen(), 0);
    
    return chunk;
}

bool PanelData::FindSuitableEntry(CFStringRef _prefix, unsigned _desired_offset, unsigned *_out, unsigned *_range)
{
    if(m_EntriesByHumanName->empty())
        return false;
    
    int preflen = (int)CFStringGetLength(_prefix);
    assert(preflen > 0);

    // performing binary search on m_EntriesByHumanName
    int imin = 0, imax = (int)m_EntriesByHumanName->size()-1;
    while(imax >= imin)
    {
        int imid = (imin + imax) / 2;
        
        unsigned indx = (*m_EntriesByHumanName)[imid];
        auto const &item = (*m_Listing)[indx];
        
        int itemlen = (int)CFStringGetLength(item.CFName());
        CFRange range = CFRangeMake(0, itemlen >= preflen ? preflen : itemlen );

        CFComparisonResult res = CFStringCompareWithOptions(item.CFName(),
                                                            _prefix,
                                                            range,
                                                            kCFCompareCaseInsensitive);
        if(res == kCFCompareLessThan)
        {
            imin = imid + 1;
        }
        else if(res == kCFCompareGreaterThan)
        {
            imax = imid - 1;
        }
        else
        {
            if(itemlen < preflen)
            {
                imin = imid + 1;
            }
            else
            {
                // now find the first and last suitable element to be able to form a range of such elements
                // TODO: here is an inefficient implementation, need to find the first and the last elements with range search
                int start = imid, last = imid;
                range = CFRangeMake(0, preflen);
                while(start > 0)
                {
                    auto const &item = (*m_Listing)[(*m_EntriesByHumanName)[start - 1]];
                    if(CFStringGetLength(item.CFName()) < preflen)
                        break;
                    if(CFStringCompareWithOptions(item.CFName(), _prefix, range, kCFCompareCaseInsensitive) != kCFCompareEqualTo)
                        break;
                    start--;
                }
                
                while(last < m_EntriesByHumanName->size() - 1)
                {
                    auto const &item = (*m_Listing)[(*m_EntriesByHumanName)[last + 1]];
                    if(CFStringGetLength(item.CFName()) < preflen)
                        break;
                    if(CFStringCompareWithOptions(item.CFName(), _prefix, range, kCFCompareCaseInsensitive) != kCFCompareEqualTo)
                        break;
                    last++;
                }
                
                // our filterd result is in [start, last] range
                int ind = start + _desired_offset;
                if(ind > last) ind = last;
                
                *_out = (*m_EntriesByHumanName)[ind];
                *_range = last - start;
                
                return true;
            }
        }
    }

    return false;
}

bool PanelData::SetCalculatedSizeForDirectory(const char *_entry, unsigned long _size)
{
    assert(_size != VFSListingItem::InvalidSize);
    int n = FindEntryIndex(_entry);
    if(n >= 0)
    {
        auto &i = (*m_Listing)[n];
        if(i.IsDir())
        {
            if(i.CFIsSelected())
            { // need to adjust our selected bytes statistic
                if(i.Size() != VFSListingItem::InvalidSize)
                {
                    assert(i.Size() <= m_SelectedItemsSizeBytes);
                    m_SelectedItemsSizeBytes -= i.Size();
                }
                m_SelectedItemsSizeBytes += _size;
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

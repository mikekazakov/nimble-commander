#import "PanelData.h"
#import "PanelController.h"
#import <algorithm>
#import <string.h>
#import <assert.h>
#import <CoreFoundation/CoreFoundation.h>
#import "Common.h"
#import "FlexChainedStringsChunk.h"

PanelData::PanelData()
{
    m_Entries = new DirEntryInfoT;
    m_EntriesByRawName = new DirSortIndT;
    m_EntriesByHumanName = new DirSortIndT;
    m_EntriesByCustomSort = new DirSortIndT;
    m_TotalBytesInDirectory = 0;
    m_TotalFilesInDirectory = 0;
    m_SelectedItemsSizeBytes = 0;
    m_SelectedItemsCount = 0;
    m_SelectedItemsFilesCount = 0;
    m_SelectedItemsDirectoriesCount = 0;
    m_CustomSortMode.sepdir = true;
    m_CustomSortMode.sort = m_CustomSortMode.SortByName;
    m_CustomSortMode.show_hidden = false;
    m_SortExecGroup = dispatch_group_create();
    m_SortExecQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
}

PanelData::~PanelData()
{
    DestroyCurrentData();
    delete m_EntriesByRawName;
    delete m_EntriesByHumanName;
    delete m_EntriesByCustomSort;
}

void PanelData::DestroyCurrentData()
{
    if(m_Entries == 0)
        return;
    for(auto i = m_Entries->begin(); i < m_Entries->end(); ++i)
        (*i).destroy();
    delete m_Entries;
    m_Entries = 0;
}

bool PanelData::GoToDirectory(const char *_path)
{
    auto *entries = new std::deque<DirectoryEntryInformation>;
    
    if(FetchDirectoryListing(_path, entries, nil) == 0)
    {
        GoToDirectoryInternal(entries, _path);
        return true; // can fail sometimes
    }
    else
    {
        // error handling?
        delete entries;
        return false;
    }
}

void PanelData::GoToDirectoryWithContext(DirectoryChangeContext *_context)
{
    GoToDirectoryInternal(_context->entries, _context->path);
    free(_context);
}

void PanelData::GoToDirectoryInternal(DirEntryInfoT *_entries, const char *_path)
{
    DestroyCurrentData();
    m_Entries = _entries;
    
    strcpy(m_DirectoryPath, _path);
    if( m_DirectoryPath[strlen(m_DirectoryPath)-1] != '/' )
        strcat(m_DirectoryPath, "/");
    
    // now sort our new data
    dispatch_group_async(m_SortExecGroup, m_SortExecQueue, ^{
        DoSort(m_Entries, m_EntriesByRawName, PanelSortMode(PanelSortMode::SortByRawCName, false)); });
    dispatch_group_async(m_SortExecGroup, m_SortExecQueue, ^{
        PanelSortMode mode;
        mode.sepdir = false;
        mode.sort = PanelSortMode::SortByName;
        mode.show_hidden = m_CustomSortMode.show_hidden;
        DoSort(m_Entries, m_EntriesByHumanName, mode); });
    dispatch_group_async(m_SortExecGroup, m_SortExecQueue, ^{
        DoSort(m_Entries, m_EntriesByCustomSort, m_CustomSortMode); });
    dispatch_group_wait(m_SortExecGroup, DISPATCH_TIME_FOREVER);
    
    // update stats
    UpdateStatictics();
}

void PanelData::ReloadDirectoryWithContext(DirectoryChangeContext *_context)
{
    assert(strcmp(_context->path, m_DirectoryPath) == 0);
    ReloadDirectoryInternal(_context->entries);
    free(_context);
}

bool PanelData::ReloadDirectory()
{
    // TODO: this process should be asynchronous
    char path[__DARWIN_MAXPATHLEN];
    GetDirectoryPathWithTrailingSlash(path);
    
    auto *entries = new std::deque<DirectoryEntryInformation>;
    if(FetchDirectoryListing(path, entries, nil) == 0)
    {
        ReloadDirectoryInternal(entries);
        return true;
    }
    else
    {
        delete entries;
        return false;
    }
}

void PanelData::ReloadDirectoryInternal(DirEntryInfoT *_entries)
{
    // sort new entries by raw c name for sync-swapping needs
    auto *dirbyrawcname = new DirSortIndT;
    PanelSortMode rawsortmode;
    rawsortmode.sort = PanelSortMode::SortByRawCName;
    rawsortmode.sepdir = false;
    rawsortmode.show_hidden = true;
    
    DoSort(_entries, dirbyrawcname, rawsortmode);
        
    // transfer custom data to new array using sorted indeces arrays
    size_t dst_i = 0, dst_e = _entries->size(),
    src_i = 0, src_e = m_Entries->size();
    for(;src_i < src_e; ++src_i)
    {
        int src = (*m_EntriesByRawName)[src_i];
check:  int dst = (*dirbyrawcname)[dst_i];
        int cmp = strcmp((*m_Entries)[src].namec(), (*_entries)[dst].namec());
        if( cmp == 0 )
        {
            auto &item_dst = (*_entries)[dst];
            const auto &item_src = (*m_Entries)[src];
                
            item_dst.cflags = item_src.cflags;
            if(item_dst.size == DIRENTINFO_INVALIDSIZE)
                item_dst.size = item_src.size; // transfer sizes for folders - it can be calculated earlier
                
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
    DestroyCurrentData();
    delete m_EntriesByRawName;
        
    // put a new data in a place
    m_Entries = _entries;
    m_EntriesByRawName = dirbyrawcname;
        
    // now sort our new data with custom sortings
    dispatch_group_async(m_SortExecGroup, m_SortExecQueue, ^{
        PanelSortMode mode;
        mode.sepdir = false;
        mode.sort = PanelSortMode::SortByName;
        mode.show_hidden = m_CustomSortMode.show_hidden;
        DoSort(m_Entries, m_EntriesByHumanName, mode); });
    dispatch_group_async(m_SortExecGroup, m_SortExecQueue, ^{
        DoSort(m_Entries, m_EntriesByCustomSort, m_CustomSortMode); });
    dispatch_group_wait(m_SortExecGroup, DISPATCH_TIME_FOREVER);
    
    // update stats
    UpdateStatictics();
}

const PanelData::DirEntryInfoT& PanelData::DirectoryEntries() const
{
    return *m_Entries;
}

const PanelData::DirSortIndT& PanelData::SortedDirectoryEntries() const
{
    return *m_EntriesByCustomSort;
}

void PanelData::ComposeFullPathForEntry(int _entry_no, char _buf[__DARWIN_MAXPATHLEN])
{
    const char *ent_name = (*m_Entries)[_entry_no].namec();
    
    if(strcmp(ent_name, ".."))
    {
        strcpy(_buf, m_DirectoryPath);
        strcat(_buf, ent_name);
    }
    else
    {
        // need to cut the last slash
        strcpy(_buf, m_DirectoryPath);
        if(_buf[strlen(_buf)-1] == '/') _buf[strlen(_buf)-1] = 0; // cut trailing slash
        char *s = strrchr(_buf, '/');
        if(s != _buf) *s = 0;
        else *(s+1) = 0;
    }
}

int PanelData::FindEntryIndex(const char *_filename) const
{
    // bruteforce appoach for now
    // TODO: optimize
    int n = 0;
    for(auto i = m_Entries->begin(); i < m_Entries->end(); ++i, ++n)
        if(strcmp((*i).namec(), _filename) == 0)
            return n;
    return -1;
}

int PanelData::FindSortedEntryIndex(unsigned _desired_value) const
{
    // bruteforce appoach for now
    // TODO: optimize
    int n = 0;
    for(auto i = m_EntriesByCustomSort->begin(); i < m_EntriesByCustomSort->end(); ++i, ++n)
        if(*i == _desired_value)
            return n;
    return -1;
}

void PanelData::GetDirectoryPath(char _buf[__DARWIN_MAXPATHLEN]) const
{
    strcpy(_buf, m_DirectoryPath);
    if( char *s = strrchr(_buf, '/') ) *s = 0;
}

void PanelData::GetDirectoryPathWithTrailingSlash(char _buf[__DARWIN_MAXPATHLEN]) const
{
    strcpy(_buf, m_DirectoryPath);    
}

void PanelData::GetDirectoryPathShort(char _buf[__DARWIN_MAXPATHLEN]) const
{
    if(strlen(m_DirectoryPath) == 0)
    {
        _buf[0] = 0;
    }
    else
    {
        char tmp[MAXPATHLEN];
        strcpy(tmp, m_DirectoryPath);
        if(char *s = strrchr(tmp, '/')) *s = 0; // cut trailing slash
        if(char *s = strrchr(tmp, '/')) strcpy(_buf, s+1);
        else                            strcpy(_buf, tmp);
    }
}

struct SortPredLess
{
    const PanelData::DirEntryInfoT* ind_tar;
    PanelSortMode                   sort_mode;
    
  	bool operator()(unsigned _1, unsigned _2)
    {
        const auto &val1 = (*ind_tar)[_1];
        const auto &val2 = (*ind_tar)[_2];
        
        if(sort_mode.sepdir)
        {
            if(val1.isdir() && !val2.isdir()) return true;
            if(!val1.isdir() && val2.isdir()) return false;
        }
        
        switch(sort_mode.sort)
        {
            case PanelSortMode::SortByName:
                return CFStringCompare(val1.cf_name, val2.cf_name, kCFCompareCaseInsensitive) < 0;
            case PanelSortMode::SortByNameRev:
                return CFStringCompare(val1.cf_name, val2.cf_name, kCFCompareCaseInsensitive) > 0;
            case PanelSortMode::SortByExt:
                if(val1.hasextension() && val2.hasextension() )
                {
                    int r = strcmp(val1.extensionc(), val2.extensionc());
                    if(r < 0) return true;
                    if(r > 0) return false;
                    return CFStringCompare(val1.cf_name, val2.cf_name, kCFCompareCaseInsensitive) < 0;
                }
                if(val1.hasextension() && !val2.hasextension() ) return false;
                if(!val1.hasextension() && val2.hasextension() ) return true;
                return CFStringCompare(val1.cf_name, val2.cf_name, kCFCompareCaseInsensitive) < 0; // fallback case
            case PanelSortMode::SortByExtRev:
                if(val1.hasextension() && val2.hasextension() )
                {
                    int r = strcmp(val1.extensionc(), val2.extensionc());
                    if(r < 0) return false;
                    if(r > 0) return true;
                    return CFStringCompare(val1.cf_name, val2.cf_name, kCFCompareCaseInsensitive) > 0;
                }
                if(val1.hasextension() && !val2.hasextension() ) return true;
                if(!val1.hasextension() && val2.hasextension() ) return false;
                return CFStringCompare(val1.cf_name, val2.cf_name, kCFCompareCaseInsensitive) > 0; // fallback case
            case PanelSortMode::SortByMTime:    return val1.mtime > val2.mtime;
            case PanelSortMode::SortByMTimeRev: return val1.mtime < val2.mtime;
            case PanelSortMode::SortByBTime:    return val1.btime > val2.btime;
            case PanelSortMode::SortByBTimeRev: return val1.btime < val2.btime;
            case PanelSortMode::SortBySize:
                if(val1.size != DIRENTINFO_INVALIDSIZE && val2.size != DIRENTINFO_INVALIDSIZE) return val1.size > val2.size;
                if(val1.size != DIRENTINFO_INVALIDSIZE && val2.size == DIRENTINFO_INVALIDSIZE) return false;
                if(val1.size == DIRENTINFO_INVALIDSIZE && val2.size != DIRENTINFO_INVALIDSIZE) return true;
                return strcmp(val1.namec(), val2.namec()) < 0;  // fallback case
            case PanelSortMode::SortBySizeRev:
                if(val1.size != DIRENTINFO_INVALIDSIZE && val2.size != DIRENTINFO_INVALIDSIZE) return val1.size < val2.size;
                if(val1.size != DIRENTINFO_INVALIDSIZE && val2.size == DIRENTINFO_INVALIDSIZE) return true;
                if(val1.size == DIRENTINFO_INVALIDSIZE && val2.size != DIRENTINFO_INVALIDSIZE) return false;
                return strcmp(val1.namec(), val2.namec()) > 0;  // fallback case
                
            case PanelSortMode::SortByRawCName:
                return strcmp(val1.namec(), val2.namec()) < 0;
                break;

            case PanelSortMode::SortNoSort:
                assert(0); // meaningless sort call
                break;

            default:;
        };

        return false;
    }
};

void PanelData::DoSort(const PanelData::DirEntryInfoT* _from, PanelData::DirSortIndT *_to, PanelSortMode _mode)
{
    _to->clear();
    _to->resize(_from->size());
    if(_to->empty())
        return;
  
    if(_mode.show_hidden)
    {
        size_t i = 0, e = _from->size();
        for(; i < e; ++i)
            (*_to)[i] = (unsigned)i;
    }
    else
    {
        size_t nsrc = 0, ndst = 0;
        size_t ssrc = _from->size();
        for(;nsrc<ssrc;++nsrc)
            if( (*_from)[nsrc].ishidden() == false )
            {
                (*_to)[ndst] = (unsigned) nsrc;
                ++ndst;
            }
        _to->resize(ndst); // now have only elements that are not hidden
    }
    
    if(_mode.sort == PanelSortMode::SortNoSort)
        return; // we're already done
 
    SortPredLess pred;
    pred.ind_tar = _from;
    pred.sort_mode = _mode;

    DirSortIndT::iterator start=_to->begin(), end=_to->end();
    if( (*_from)[0].isdotdot() ) start++; // do not touch dotdot directory. however, in some cases (root dir for example) there will be no dotdot dir
    
    std::sort(start, end, pred);
}

void PanelData::SetCustomSortMode(PanelSortMode _mode)
{
    if(m_CustomSortMode != _mode)
    {
        if(m_CustomSortMode.show_hidden == _mode.show_hidden)
        {
            m_CustomSortMode = _mode;
            DoSort(m_Entries, m_EntriesByCustomSort, m_CustomSortMode);
        }
        else
        {
            m_CustomSortMode = _mode;
            // need to update fast search indeces also, since there are structural changes
            dispatch_group_async(m_SortExecGroup, m_SortExecQueue, ^{
                PanelSortMode mode;
                mode.sepdir = false;
                mode.sort = PanelSortMode::SortByName;
                mode.show_hidden = m_CustomSortMode.show_hidden;
                DoSort(m_Entries, m_EntriesByHumanName, mode); });
            dispatch_group_async(m_SortExecGroup, m_SortExecQueue, ^{
                DoSort(m_Entries, m_EntriesByCustomSort, m_CustomSortMode); });
            dispatch_group_wait(m_SortExecGroup, DISPATCH_TIME_FOREVER);
        }
    }
}

PanelSortMode PanelData::GetCustomSortMode() const
{
    return m_CustomSortMode;
}

void PanelData::UpdateStatictics()
{
    unsigned long totalbytes = 0;
    unsigned totalfiles = 0;
    unsigned long totalselectedbytes = 0;
    unsigned totalselected = 0;
    unsigned totalselectedfiles = 0;
    unsigned totalselecteddirs = 0;

    for(const auto &i: *m_Entries)
    {
        if(i.isreg())
        {
            totalbytes += i.size;
            totalfiles++;
        }
        if(i.cf_isselected())
        {
            if(i.size != DIRENTINFO_INVALIDSIZE)
                totalselectedbytes += i.size;
            totalselected++;
            if(i.isdir()) totalselecteddirs++;
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

const DirectoryEntryInformation& PanelData::EntryAtRawPosition(int _pos) const
{
    assert(_pos >= 0 && _pos < m_Entries->size());
    return (*m_Entries)[_pos];
}

void PanelData::CustomFlagsSelect(int _at_pos, bool _is_selected)
{
    assert(_at_pos >= 0 && _at_pos < m_Entries->size());
    auto &entry = (*m_Entries)[_at_pos];
    if(entry.cf_isselected() == _is_selected) // check if item is already selected
        return;
    if(_is_selected)
    {
        if(entry.size != DIRENTINFO_INVALIDSIZE)
            m_SelectedItemsSizeBytes += entry.size;
        m_SelectedItemsCount++;

        if(entry.isdir()) m_SelectedItemsDirectoriesCount++;
        else              m_SelectedItemsFilesCount++;

        entry.cf_setflag(DirectoryEntryCustomFlags::Selected);
    }
    else
    {
        if(entry.size != DIRENTINFO_INVALIDSIZE)
        {
            assert(m_SelectedItemsSizeBytes >= entry.size); // sanity check
            m_SelectedItemsSizeBytes -= entry.size;
        }
        assert(m_SelectedItemsCount >= 0); // sanity check
        m_SelectedItemsCount--;
        if(entry.isdir())
        {
            assert(m_SelectedItemsDirectoriesCount >= 0);
            m_SelectedItemsDirectoriesCount--;
        }
        else
        {
            assert(m_SelectedItemsFilesCount >= 0);
            m_SelectedItemsFilesCount--;
        }
        entry.cf_unsetflag(DirectoryEntryCustomFlags::Selected);
    }
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

    for(auto const &i: *m_Entries)
        if(i.cf_isselected())
            last = last->AddString(i.namec(), i.namelen, 0);
    
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
        auto const &item = (*m_Entries)[indx];
        
        int itemlen = (int)CFStringGetLength(item.cf_name);
        CFRange range = CFRangeMake(0, itemlen >= preflen ? preflen : itemlen );

        CFComparisonResult res = CFStringCompareWithOptions(item.cf_name,
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
                    auto const &item = (*m_Entries)[(*m_EntriesByHumanName)[start - 1]];
                    if(CFStringGetLength(item.cf_name) <  preflen)
                        break;
                    if(CFStringCompareWithOptions(item.cf_name, _prefix, range, kCFCompareCaseInsensitive) != kCFCompareEqualTo)
                        break;
                    start--;
                }
                
                while(last < m_EntriesByHumanName->size() - 1)
                {
                    auto const &item = (*m_Entries)[(*m_EntriesByHumanName)[last + 1]];
                    if(CFStringGetLength(item.cf_name) <  preflen)
                        break;
                    if(CFStringCompareWithOptions(item.cf_name, _prefix, range, kCFCompareCaseInsensitive) != kCFCompareEqualTo)
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
    assert(_size != DIRENTINFO_INVALIDSIZE);
    int n = FindEntryIndex(_entry);
    if(n >= 0)
    {
        auto &i = (*m_Entries)[n];
        if(i.isdir())
        {
            if(i.cf_isselected())
            { // need to adjust our selected bytes statistic
                if(i.size != DIRENTINFO_INVALIDSIZE)
                {
                    assert(i.size <= m_SelectedItemsSizeBytes);
                    m_SelectedItemsSizeBytes -= i.size;
                }
                m_SelectedItemsSizeBytes += _size;
            }

            i.size = _size;

            return true;
        }
    }
    return false;
}

void PanelData::LoadFSDirectoryAsync(const char *_path,
                                     void (^_on_completion) (DirectoryChangeContext*),
                                     void (^_on_fail) (const char*, int),
                                     FetchDirectoryListing_CancelChecker _checker
                                     )

{    
    if(_checker())
    {
        free( (void*) _path);
        return;
    }

    auto *entries = new std::deque<DirectoryEntryInformation>;
    int ret = FetchDirectoryListing(_path, entries, _checker);
    
//    sleep(5);

    if( !_checker() )
    {
        if(ret == 0)
        {
            DirectoryChangeContext *c = (DirectoryChangeContext*) malloc(sizeof(DirectoryChangeContext));
            c->entries = entries; // giving ownership
            strcpy(c->path, _path);
            _on_completion(c);
        }
        else
        {
            for(auto &i:*entries)
                i.destroy();
            delete entries;
            _on_fail(_path, ret);
        }
    }
    else
    {
        for(auto &i:*entries)
            i.destroy();
        delete entries;
    }

    free( (void*) _path);
}



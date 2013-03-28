#include "PanelData.h"

#include <algorithm>
#include <string.h>
#include <assert.h>
#include <CoreFoundation/CoreFoundation.h>
#include "Common.h"
#include "FlexChainedStringsChunk.h"

PanelData::PanelData()
{
    m_Entries = new DirEntryInfoT;
    m_EntriesByRawName = new DirSortIndT;
    m_EntriesByCustomSort = new DirSortIndT;
    m_TotalBytesInDirectory = 0;
    m_TotalFilesInDirectory = 0;
    m_SelectedItemsSizeBytes = 0;
    m_SelectedItemsCount = 0;
    m_SelectedItemsFilesCount = 0;
    m_SelectedItemsDirectoriesCount = 0;
    m_CustomSortMode.sepdir = true;
    m_CustomSortMode.sort = m_CustomSortMode.SortByName;
}

PanelData::~PanelData()
{
    
    
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
    // TODO: this process should be asynchronous
    
    auto *entries = new std::deque<DirectoryEntryInformation>;
    
    if(FetchDirectoryListing(_path, entries) == 0)
    {
        DestroyCurrentData();
        m_Entries = entries;

        strcpy(m_DirectoryPath, _path);
        if( m_DirectoryPath[strlen(m_DirectoryPath)-1] == '/' )
            m_DirectoryPath[strlen(m_DirectoryPath)-1] = 0;
        
        // now sort our new data
        DoSort(m_Entries, m_EntriesByRawName, PanelSortMode(PanelSortMode::SortByRawCName, false));
        DoSort(m_Entries, m_EntriesByCustomSort, m_CustomSortMode);

        // update stats
        UpdateStatictics();
        
        return true; // can fail sometimes
    }
    else
    {
        // error handling?
        delete entries;
        return false;
    }
}

bool PanelData::ReloadDirectory()
{
    // TODO: this process should be asynchronous    
    char path[__DARWIN_MAXPATHLEN];
    GetDirectoryPathWithTrailingSlash(path);
    
    auto *entries = new std::deque<DirectoryEntryInformation>;
    if(FetchDirectoryListing(path, entries) == 0)
    {
        // sort new entries by raw c name for sync-swapping needs        
        auto *dirbyrawcname = new DirSortIndT;
        DoSort(entries, dirbyrawcname, PanelSortMode(PanelSortMode::SortByRawCName, false));
        
        // transfer custom data to new array using sorted indeces arrays
        size_t dst_i = 0, dst_e = entries->size(),
               src_i = 0, src_e = m_Entries->size();
        for(;src_i < src_e; ++src_i)
        {
            int src = (*m_EntriesByRawName)[src_i];
check:      int dst = (*dirbyrawcname)[dst_i];
            int cmp = strcmp((*m_Entries)[src].namec(), (*entries)[dst].namec());
            if( cmp == 0 )
            {
                (*entries)[dst].cflags = (*m_Entries)[src].cflags;
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
        m_Entries = entries;
        m_EntriesByRawName = dirbyrawcname;

        // now sort our new data
        DoSort(m_Entries, m_EntriesByCustomSort, m_CustomSortMode);
        
        // update stats
        UpdateStatictics();
        
        return true;
    }
    else
    {
        delete entries;
        return false;
    }
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
        strcat(_buf, "/");
        strcat(_buf, ent_name);
    }
    else
    {
        // need to cut the last slash
        strcpy(_buf, m_DirectoryPath);
        char *s = _buf + strlen(_buf);
        while(*s != '/')
        {
            --s;
            
            if(s == _buf) // we're on root dir now
            {
                ++s;
                break;
            }
        }
        *s = 0;
    }
}

int PanelData::FindEntryIndex(const char *_filename)
{
    // bruteforce appoach for now
    int n = 0;
    for(auto i = m_Entries->begin(); i < m_Entries->end(); ++i, ++n)
        if(strcmp((*i).namec(), _filename) == 0)
            return n;
    return -1;
}

int PanelData::FindSortedEntryIndex(unsigned _desired_value)
{
    // bruteforce appoach for now
    int n = 0;
    for(auto i = m_EntriesByCustomSort->begin(); i < m_EntriesByCustomSort->end(); ++i, ++n)
        if(*i == _desired_value)
            return n;
    return -1;
}

void PanelData::GetDirectoryPath(char _buf[__DARWIN_MAXPATHLEN]) const
{
    strcpy(_buf, m_DirectoryPath);
}

void PanelData::GetDirectoryPathWithTrailingSlash(char _buf[__DARWIN_MAXPATHLEN]) const
{
    // TODO: optimize
    if(strlen(m_DirectoryPath) > 0)
    {
        strcpy(_buf, m_DirectoryPath);
        strcat(_buf, "/");
    }
    else
    {
        _buf[0] = '/';
        _buf[1] = 0;
    }
}

void PanelData::GetDirectoryPathShort(char _buf[__DARWIN_MAXPATHLEN]) const
{
    if(strcmp(m_DirectoryPath, "") == 0)
    {
        _buf[0] = 0;
    }
    else
    {
        const char *s = m_DirectoryPath + strlen(m_DirectoryPath);
        while(*(s-1) != '/')
        {
            --s;
            assert(s > m_DirectoryPath); // sanity check - this should never happen
        }
        strcpy(_buf, s);
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
                if(val1.hasextension() && val2.hasextension() ) return strcmp(val1.extensionc(), val2.extensionc()) < 0;
                if(val1.hasextension() && !val2.hasextension() ) return false;
                if(!val1.hasextension() && val2.hasextension() ) return true;
                return strcmp(val1.namec(), val2.namec()) < 0; // fallback case
            case PanelSortMode::SortByExtRev:
                if(val1.hasextension() && val2.hasextension() ) return strcmp(val1.extensionc(), val2.extensionc()) > 0;
                if(val1.hasextension() && !val2.hasextension() ) return true;
                if(!val1.hasextension() && val2.hasextension() ) return false;
                return strcmp(val1.namec(), val2.namec()) > 0; // fallback case
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
    
    for(int i = 0; i < _from->size(); ++i)
        (*_to)[i] = i;
    
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
    // carefully check some other flags when they wll appear in PanelSortMode
    if(m_CustomSortMode.sort != _mode.sort || m_CustomSortMode.sepdir != _mode.sepdir)
    {
        m_CustomSortMode = _mode;
        DoSort(m_Entries, m_EntriesByCustomSort, m_CustomSortMode);
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
    return (*m_EntriesByCustomSort)[_pos];
}

const DirectoryEntryInformation& PanelData::EntryAtRawPosition(int _pos) const
{
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

FlexChainedStringsChunk* PanelData::StringsFromSelectedEntries()
{
    FlexChainedStringsChunk *chunk = FlexChainedStringsChunk::Allocate();
    FlexChainedStringsChunk *last = chunk;

    size_t i = 0, e = (int)m_Entries->size();
    for(;i!=e;++i)
    {
        const auto &item = (*m_Entries)[i];
        if(item.cf_isselected())
            last = last->AddString(item.namec(), item.namelen, 0);
    }
    return chunk;
}




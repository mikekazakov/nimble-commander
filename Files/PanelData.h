#pragma once
#include <sys/dirent.h>
#include <vector>


#import "VFS.h"

struct FlexChainedStringsChunk;

struct PanelSortMode
{
    // TODO: add sensivity flags, numerical flags

    
    enum Mode
    {
        SortNoSort      = 0x000,
        SortByName      = 0x001,
        SortByNameRev   = 0x002,
        SortByExt       = SortByName    << 2,
        SortByExtRev    = SortByNameRev << 2,
        SortBySize      = SortByName    << 4,
        SortBySizeRev   = SortByNameRev << 4,
        SortByMTime     = SortByName    << 6,
        SortByMTimeRev  = SortByNameRev << 6,
        SortByBTime     = SortByName    << 8,
        SortByBTimeRev  = SortByNameRev << 8,
        // for internal usage, seems to be meaningless for human reading (sort by internal UTF8 representation)
        SortByRawCName  = 0xF0000000,
        SortByNameMask  = SortByName | SortByNameRev,
        SortByExtMask   = SortByExt  | SortByExtRev,
        SortBySizeMask  = SortBySize | SortBySizeRev,
        SortByMTimeMask = SortByMTime| SortByMTimeRev,
        SortByBTimeMask = SortByBTime| SortByBTimeRev
    };
    
    Mode sort;
    bool sep_dirs;      // separate directories from files, like win-like
    bool show_hidden;   // shown hidden files (which are: begining with "." or having hidden flag)
    bool case_sens;     // case sensitivity when comparing filenames, ignored on Raw Sorting (SortByRawCName)
    bool numeric_sort;  // try to treat filenames as numbers and use them as compare basis
    
    inline PanelSortMode():
        sort(SortByRawCName),
        sep_dirs(false),
        show_hidden(true),
        case_sens(false),
        numeric_sort(false)
    {}
    
    inline bool isdirect() const
    {
        return sort == SortByName || sort == SortByExt || sort == SortBySize || sort == SortByMTime || sort == SortByBTime;
    }
    inline bool isrevert() const
    {
        return sort == SortByNameRev || sort == SortByExtRev || sort == SortBySizeRev || sort == SortByMTimeRev || sort == SortByBTimeRev;        
    }
    inline bool operator ==(const PanelSortMode& _r) const
    {
        return sort == _r.sort && sep_dirs == _r.sep_dirs && show_hidden == _r.show_hidden && case_sens == _r.case_sens && numeric_sort == _r.numeric_sort;
    }
    inline bool operator !=(const PanelSortMode& _r) const
    {
        return !(*this == _r);
    }
};
    
class PanelData
{
public:
    typedef vector<unsigned>                 DirSortIndT; // value in this array is an index for DirEntryInfoT
    
    PanelData();
    ~PanelData();
    
    // these methods should be called by a controller, since some view's props have to be updated
    // PanelData is solely sync class - it does not give a fuck about concurrency,
    // any parallelism should be done by callers (i.e. controller)
    // just like Metallica:
    void Load(shared_ptr<VFSListing> _listing);
    void ReLoad(shared_ptr<VFSListing> _listing);

    shared_ptr<VFSHost> Host() const;
    const VFSListing&       DirectoryEntries() const;
    const DirSortIndT&      SortedDirectoryEntries() const;
    FlexChainedStringsChunk* StringsFromSelectedEntries() const;
    
    int SortPosToRawPos(int _pos) const; // does SortedDirectoryEntries()[_pos]
    const VFSListingItem& EntryAtRawPosition(int _pos) const;
    
    void ComposeFullPathForEntry(int _entry_no, char _buf[__DARWIN_MAXPATHLEN]);
    
    int RawIndexForName(const char *_filename) const;
        // TODO: improve this by using a name-sorted list
        // performs a bruteforce case-sensivitive search
        // return -1 if didn't found
        // returning value is in raw land, that is DirectoryEntries[N], not sorted ones
    
    int SortedIndexForName(const char *_filename) const;
        // return -1 if didn't found
        // returned value is in sorted indxs land
    
    int SortedIndexForRawIndex(unsigned _desired_raw_index) const;
        // return -1 if didn't found
        // _desired_value - raw item index
    
    void GetDirectoryPathWithoutTrailingSlash(char _buf[__DARWIN_MAXPATHLEN]) const;
        // return current directory in long variant starting from /
    void GetDirectoryPathWithTrailingSlash(char _buf[__DARWIN_MAXPATHLEN]) const;
        // same as above but path will ends with slash
    void GetDirectoryPathShort(char _buf[__DARWIN_MAXPATHLEN]) const;
        // return name of a current directory in a parent directory
        // returns a zero string for a root dir
    
    void GetDirectoryFullHostsPathWithTrailingSlash(char _buf[MAXPATHLEN*8]) const;
    
    // sorting
    void SetCustomSortMode(PanelSortMode _mode);
    PanelSortMode GetCustomSortMode() const;
    
    // fast search support
    // _desired_offset is a offset from first suitable element.
    // if _desired_offset causes going out of fitting ranges - the nearest valid element will be returned
    // return raw index number if any
    bool FindSuitableEntry(CFStringRef _prefix, unsigned _desired_offset, unsigned *_ind_out, unsigned *_range);
    
    // files statistics - notes below
    void UpdateStatictics();
    unsigned long GetTotalBytesInDirectory() const;
    unsigned GetTotalFilesInDirectory() const;
    unsigned GetSelectedItemsCount() const;
    unsigned GetSelectedItemsFilesCount() const;
    unsigned GetSelectedItemsDirectoriesCount() const;
    unsigned long GetSelectedItemsSizeBytes() const;
    
    // manupulation with user flags for directory entries
    void CustomFlagsSelect(size_t _at_raw_pos, bool _is_selected);
    void CustomFlagsSelectAllSorted(bool _select);
    void CustomFlagsSelectAll(bool _select);
    
    void CustomIconSet(size_t _at_raw_pos, unsigned short _icon_id);
    void CustomIconClearAll();
    
    bool SetCalculatedSizeForDirectory(const char *_entry, unsigned long _size); // return true if changed something
private:    
    PanelData(const PanelData&) = delete;
    void operator=(const PanelData&) = delete;
    
    // this function will erase data from _to, make it size of _form->size(), and fill it with indeces according to _mode
    static void DoSort(const shared_ptr<VFSListing> _from, DirSortIndT *_to, PanelSortMode _mode);
    
    // m_Listing container will change every time directory change/reloads,
    // while the following sort-indeces(except for m_EntriesByRawName) will be permanent with it's content changing
    shared_ptr<VFSListing>             m_Listing;

    DirSortIndT                             *m_EntriesByRawName;   // sorted with raw strcmp comparison
    DirSortIndT                             *m_EntriesByHumanName; // sorted with human-reasonable literal sort
    DirSortIndT                             *m_EntriesByCustomSort; // custom defined sort
    PanelSortMode                           m_CustomSortMode;
    dispatch_group_t                        m_SortExecGroup;
    
    // statistics
    unsigned long                           m_TotalBytesInDirectory; // assuming regular files ONLY!
    unsigned                                m_TotalFilesInDirectory; // NOT DIRECTORIES! only regular files, maybe + symlinks and other stuff
    unsigned long                           m_SelectedItemsSizeBytes;
    unsigned                                m_SelectedItemsCount;
    unsigned                                m_SelectedItemsFilesCount;
    unsigned                                m_SelectedItemsDirectoriesCount;
};

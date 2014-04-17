#pragma once
#include <vector>
#include "DispatchQueue.h"
#include "VFS.h"

struct PanelSortMode
{
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
    bool case_sens;     // case sensitivity when comparing filenames, ignored on Raw Sorting (SortByRawCName)
    bool numeric_sort;  // try to treat filenames as numbers and use them as compare basis
    
    inline PanelSortMode():
        sort(SortByRawCName),
        sep_dirs(false),
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
        return sort == _r.sort && sep_dirs == _r.sep_dirs && case_sens == _r.case_sens && numeric_sort == _r.numeric_sort;
    }
    inline bool operator !=(const PanelSortMode& _r) const
    {
        return !(*this == _r);
    }
};

struct PanelDataTextFiltering
{
    enum WhereEnum // persistancy-bound values, don't change it
    {
        Anywhere            = 0,
        Beginning           = 1,
        Ending              = 2, // handling extensions somehow
        BeginningOrEnding   = 3
    };
    
    WhereEnum type = Anywhere;
    NSString *text = nil;
    bool      ignoredotdot = true; // will not apply filter on dot-dot entries
    bool      clearonnewlisting = false; // if true then PanelData will automatically
                                         // set text to nil on Load method call
    
    inline bool operator==(const PanelDataTextFiltering& _r) const
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
    
    inline bool operator!=(const PanelDataTextFiltering& _r) const
    {
        return !(*this == _r);
    }
    
    inline static WhereEnum WhereFromInt(int _v)
    {
        if(_v >= 0 && _v <= BeginningOrEnding)
            return WhereEnum(_v);
        return Anywhere;
    }
    
    inline static PanelDataTextFiltering NoFiltering()
    {
        PanelDataTextFiltering filter;
        filter.type = Anywhere;
        filter.text = nil;
        filter.ignoredotdot = true;
        return filter;
    }
    
    bool IsValidItem(const VFSListingItem& _item) const;
    
    void OnPanelDataLoad()
    {
        if(clearonnewlisting)
            text = nil;
    }

    inline bool IsFiltering() const
    {
        return text != nil && text.length > 0;
    }
};

struct PanelDataHardFiltering
{
    bool show_hidden = true;
    PanelDataTextFiltering text = PanelDataTextFiltering::NoFiltering();
    bool IsValidItem(const VFSListingItem& _item) const;

    bool IsFiltering() const
    {
        return !show_hidden || text.IsFiltering();
    }
    
    inline bool operator==(const PanelDataHardFiltering& _r) const
    {
        return show_hidden == _r.show_hidden && text == _r.text;
    }
    
    inline bool operator!=(const PanelDataHardFiltering& _r) const
    {
        return show_hidden != _r.show_hidden || text != _r.text;
    }
};

struct PanelDataStatistics
{
    /**
     * All regular files in listing, including hidden ones.
     * Not counting directories even when it's size was calculated.
     */
    uint64_t bytes_in_raw_reg_files = 0;
    
    /**
     * Amount of regular files in directory listing, regardless of sorting.
     * Includes the possibly hidden ones.
     */
    uint32_t raw_reg_files_amount = 0;
    
    /**
     * Total bytes in all selected entries, including reg files and directories (if it's size was calculated).
     *
     */
    uint64_t bytes_in_selected_entries = 0;
    
    // trivial
    uint32_t selected_entries_amount = 0;
    uint32_t selected_reg_amount = 0;
    uint32_t selected_dirs_amount = 0;
    
    inline bool operator ==(const PanelDataStatistics& _r) const
    {
        return memcmp(this, &_r, sizeof(_r)) == 0;
    }
    inline bool operator !=(const PanelDataStatistics& _r) const
    {
        return memcmp(this, &_r, sizeof(_r)) != 0;
    }
};

/**
 * PanelData actually does the following things:
 * - sorting provided data
 * - handling reloading with preserving of custom entries data
 * - searching
 * - paths accessing
 * - custom information setting/getting
 * - statistics
 */
class PanelData
{
public:
    typedef vector<unsigned> DirSortIndT; // value in this array is an index for VFSListing
    
    PanelData();
    
    // these methods should be called by a controller, since some view's props have to be updated
    // PanelData is solely sync class - it does not give a fuck about concurrency,
    // any parallelism should be done by callers (i.e. controller)
    // just like Metallica:
    void Load(shared_ptr<VFSListing> _listing);
    void ReLoad(shared_ptr<VFSListing> _listing);

    const shared_ptr<VFSHost>     &Host() const;
    const shared_ptr<VFSListing>  &Listing() const;
    
    const VFSListing&       DirectoryEntries() const;
    const DirSortIndT&      SortedDirectoryEntries() const;
    
    
    /**
     * EntriesBySoftFiltering return a vector of filtered indeces of sorted entries (not raw ones)
     */
    const DirSortIndT&      EntriesBySoftFiltering() const;
    
    const VFSListingItem*   EntryAtRawPosition(int _pos) const;
    chained_strings         StringsFromSelectedEntries() const;

    /**
     * will redirect ".." upwards
     */
    string FullPathForEntry(int _raw_index) const;
    
    /**
     * Converts sorted index into raw index. Returns -1 on any errors.
     */
    int RawIndexForSortIndex(int _index) const;
    
    /**
     * Performs a binary case-sensivitive search.
     * Return -1 if didn't found.
     * Returning value is in raw land, that is DirectoryEntries[N], not sorted ones.
     */
    int RawIndexForName(const char *_filename) const;
    
    /**
     * return -1 if didn't found.
     * returned value is in sorted indxs land.
     */
    int SortedIndexForName(const char *_filename) const;
    
    /**
     * does bruteforce O(N) search.
     * return -1 if didn't found.
     * _desired_raw_index - raw item index.
     */
    int SortedIndexForRawIndex(int _desired_raw_index) const;
    
    /**
     * return current directory in long variant starting from /
     */
    string DirectoryPathWithoutTrailingSlash() const;

    /**
     * same as DirectoryPathWithoutTrailingSlash() but path will ends with slash
     */
    string DirectoryPathWithTrailingSlash() const;
    
    /**
     * return name of a current directory in a parent directory.
     * returns a zero string for a root dir.
     */
    string DirectoryPathShort() const;
    
    
    // TODO: refactor:    
    void GetDirectoryFullHostsPathWithTrailingSlash(char _buf[MAXPATHLEN*8]) const;
    
    // sorting
    void SetSortMode(PanelSortMode _mode);
    PanelSortMode SortMode() const;
    
    // hard filtering filtering
    void SetHardFiltering(PanelDataHardFiltering _filter);
    inline PanelDataHardFiltering HardFiltering() const { return m_HardFiltering; }
    
    void SetSoftFiltering(PanelDataTextFiltering _filter);
    inline PanelDataTextFiltering SoftFiltering() const { return m_SoftFiltering; }

    /**
     * ClearTextFiltering() efficiently sets SoftFiltering.text = nil and HardFiltering.text.text = nil.
     * It's better than consequent calls of SetHardFiltering()+SetSoftFiltering() - less indeces rebuilding.
     * Return true if calling of this method changed anything, and false if indeces was unchanged
     */
    bool ClearTextFiltering();
    
    const PanelDataStatistics &Stats() const;
    
    // manupulation with user flags for directory entries
    void CustomFlagsSelectSorted(int _at_sorted_pos, bool _is_selected);
    void CustomFlagsSelectAllSorted(bool _select);
    int  CustomFlagsSelectAllSortedByMask(NSString* _mask, bool _select, bool _ignore_dirs);
    
    void CustomIconSet(size_t _at_raw_pos, unsigned short _icon_id);
    void CustomIconClearAll();
    
    /**
     * Searches for _entry using binary search with case-sensitive comparison,
     * return true if changed something, false otherwise.
     * _size should be less than uint64_t(-1).
     */
    bool SetCalculatedSizeForDirectory(const char *_entry, uint64_t _size);
private:    
    PanelData(const PanelData&) = delete;
    void operator=(const PanelData&) = delete;
    
    // this function will erase data from _to, make it size of _form->size(), and fill it with indeces according to raw sort mode
    static void DoRawSort(shared_ptr<VFSListing> _from, DirSortIndT &_to);
    void DoSortWithHardFiltering();
    void CustomFlagsSelectRaw(int _at_raw_pos, bool _is_selected);
    void ClearSelectedFlagsFromHiddenElements();
    void UpdateStatictics();
    void BuildSoftFilteringIndeces();
    
    // m_Listing container will change every time directory change/reloads,
    // while the following sort-indeces(except for m_EntriesByRawName) will be permanent with it's content changing
    shared_ptr<VFSListing> m_Listing;

    DirSortIndT             m_EntriesByRawName;    // sorted with raw strcmp comparison
    DirSortIndT             m_EntriesByCustomSort; // custom defined sort
    DirSortIndT             m_EntriesBySoftFiltering; // points at m_EntriesByCustomSort indeces, not raw ones
    vector<bool>            m_EntriesShownFlags;
    
    PanelSortMode           m_CustomSortMode;
    PanelDataHardFiltering  m_HardFiltering;
    PanelDataTextFiltering  m_SoftFiltering;
    DispatchGroup           m_SortExecGroup;
    PanelDataStatistics     m_Stats;
};

inline const PanelDataStatistics &PanelData::Stats() const
{
    return m_Stats;
}

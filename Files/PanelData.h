#pragma once
#include <Habanero/DispatchQueue.h>
#include "vfs/VFS.h"
#include "rapidjson.h"

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

    enum class PanelType
    {
        Directory,
        Temporary
    };
    
    struct EntrySortKeys
    {
        string      name;
        NSString   *display_name;
        string      extension;
        uint64_t    size;
        time_t      mtime;
        time_t      btime;
        bool        is_dir;
        bool        is_valid() const noexcept;
    };
    
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
        
        PanelSortMode();
        bool isdirect() const;
        bool isrevert() const;
        static bool validate(Mode _mode);
        bool operator ==(const PanelSortMode& _r) const;
        bool operator !=(const PanelSortMode& _r) const;
    };

    struct PanelVolatileData
    {
        enum {
            invalid_size = (0xFFFFFFFFFFFFFFFFu),
            flag_selected   = 1 << 0,
            flag_shown      = 1 << 1
        };
        
        uint64_t size = invalid_size; // for directories will contain invalid_size or actually calculated size. for other types will contain the original size from listing.
        uint32_t flags = 0;
        uint16_t icon = 0;   // custom icon ID. zero means invalid value. volatile - can be changed. saved upon directory reload.
        
        bool is_selected() const noexcept;
        bool is_shown() const noexcept;
        bool is_size_calculated() const noexcept;
        void toggle_selected( bool _v ) noexcept;
        void toggle_shown( bool _v ) noexcept;
    };
    
    struct Statistics
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
        
        bool operator ==(const Statistics& _r) const noexcept;
        bool operator !=(const Statistics& _r) const noexcept;
    };
    
    PanelData();
    
    // these methods should be called by a controller, since some view's props have to be updated
    // PanelData is solely sync class - it does not give a fuck about concurrency,
    // any parallelism should be done by callers (i.e. controller)
    // just like Metallica:
    void Load  (const shared_ptr<VFSListing> &_listing, PanelType _type);
    void ReLoad(const shared_ptr<VFSListing> &_listing);

    /**
     * Will throw logic_error if called on listing with no common host.
     */
    const shared_ptr<VFSHost>&  Host() const;
    const VFSListing&   Listing() const;
    PanelType                        Type() const noexcept;
    
    const DirSortIndT&      SortedDirectoryEntries() const;
    
    
    /**
     * EntriesBySoftFiltering return a vector of filtered indeces of sorted entries (not raw ones)
     */
    const DirSortIndT&      EntriesBySoftFiltering() const;
    
    VFSListingItem   EntryAtRawPosition(int _pos) const noexcept; // will return an "empty" item upon invalid index
    PanelVolatileData&       VolatileDataAtRawPosition( int _pos ); // will throw an exception upon invalid index
    const PanelVolatileData& VolatileDataAtRawPosition( int _pos ) const; // will throw an exception upon invalid index
    
    VFSListingItem   EntryAtSortPosition(int _pos) const noexcept; // will return an "empty" item upon invalid index
    PanelVolatileData&       VolatileDataAtSortPosition( int _pos ); // will throw an exception upon invalid index
    const PanelVolatileData& VolatileDataAtSortPosition( int _pos ) const; // will throw an exception upon invalid index
    vector<string>          SelectedEntriesFilenames() const;
    vector<VFSListingItem> SelectedEntries() const;
    
    /**
     * Will throw an invalid_argument on invalid _pos.
     */
    EntrySortKeys           EntrySortKeysAtSortPosition(int _pos) const;
    
    /**
     * will redirect ".." upwards
     */
    string FullPathForEntry(int _raw_index) const;
    
    /**
     * Converts sorted index into raw index. Returns -1 on any errors.
     */
    int RawIndexForSortIndex(int _index) const noexcept;
    
    /**
     * Performs a binary case-sensivitive search.
     * Return -1 if didn't found.
     * Returning value is in raw land, that is DirectoryEntries[N], not sorted ones.
     */
    int RawIndexForName(const char *_filename) const;
    
    /**
     * Performs a search using current sort settings with prodived keys.
     * Return a lower bound entry - first entry with is not less than a key from _keys.
     * Returns -1 if such entry wasn't found.
     */
    int SortLowerBoundForEntrySortKeys(const EntrySortKeys& _keys) const;
    
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
    
    
    string VerboseDirectoryFullPath() const;
    
    // sorting
    void SetSortMode(PanelSortMode _mode);
    PanelSortMode SortMode() const;
    
    rapidjson::StandaloneValue EncodeSortingOptions() const;
    void DecodeSortingOptions(const rapidjson::StandaloneValue& _options);
    
    // hard filtering filtering
    void SetHardFiltering(const PanelDataHardFiltering &_filter);
    inline PanelDataHardFiltering HardFiltering() const { return m_HardFiltering; }
    
    void SetSoftFiltering(const PanelDataTextFiltering &_filter);
    inline PanelDataTextFiltering SoftFiltering() const { return m_SoftFiltering; }

    /**
     * ClearTextFiltering() efficiently sets SoftFiltering.text = nil and HardFiltering.text.text = nil.
     * It's better than consequent calls of SetHardFiltering()+SetSoftFiltering() - less indeces rebuilding.
     * Return true if calling of this method changed anything, and false if indeces was unchanged
     */
    bool ClearTextFiltering();
    
    const Statistics &Stats() const;
    
    // manupulation with user flags for directory entries
    void CustomFlagsSelectSorted(int _at_sorted_pos, bool _is_selected);
    void CustomFlagsSelectAllSorted(bool _select);
    void CustomFlagsSelectInvert();
    unsigned CustomFlagsSelectAllSortedByMask(NSString* _mask, bool _select, bool _ignore_dirs);
    unsigned CustomFlagsSelectAllSortedByExtension(const string &_extension, bool _select, bool _ignore_dirs);
    
    void CustomIconClearAll();
    
    /**
     * Searches for _entry using binary search with case-sensitive comparison,
     * return true if changed something, false otherwise.
     * _size should be less than uint64_t(-1).
     */
    bool SetCalculatedSizeForDirectory(const char *_entry, uint64_t _size);
    bool SetCalculatedSizeForDirectory(const char *_filename, const char *_directory, uint64_t _size);
    
private:    
    PanelData(const PanelData&) = delete;
    void operator=(const PanelData&) = delete;
    
    void DoSortWithHardFiltering();
    void CustomFlagsSelectRaw(int _at_raw_pos, bool _is_selected);
    void ClearSelectedFlagsFromHiddenElements();
    void UpdateStatictics();
    void BuildSoftFilteringIndeces();
    static EntrySortKeys ExtractSortKeysFromEntry(const VFSListingItem& _item, const PanelVolatileData &_item_vd);
    
    // m_Listing container will change every time directory change/reloads,
    // while the following sort-indeces(except for m_EntriesByRawName) will be permanent with it's content changing
    shared_ptr<VFSListing>  m_Listing;
    vector<PanelVolatileData>       m_VolatileData;
    DirSortIndT             m_EntriesByRawName;    // sorted with raw strcmp comparison
    DirSortIndT             m_EntriesByCustomSort; // custom defined sort
    DirSortIndT             m_EntriesBySoftFiltering; // points at m_EntriesByCustomSort indeces, not raw ones
    
    PanelSortMode           m_CustomSortMode;
    PanelDataHardFiltering  m_HardFiltering;
    PanelDataTextFiltering  m_SoftFiltering;
    DispatchGroup           m_SortExecGroup;
    Statistics              m_Stats;
    PanelType               m_Type;
};

#pragma once

#include <Habanero/SerialQueue.h>
#include <Habanero/DispatchGroup.h>
#include <VFS/VFS.h>
#include "../../Core/rapidjson.h"
#include "PanelDataSortMode.h"
#include "PanelDataStatistics.h"
#include "PanelDataItemVolatileData.h"

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
        time_t      add_time; // -1 means absent
        bool        is_dir;
        bool        is_valid() const noexcept;
    };
    
    using PanelSortMode = PanelDataSortMode;
    using Statistics = PanelDataStatistics;
    using VolatileData = PanelDataItemVolatileData;
    
    struct TextualFilter
    {
        enum Where // persistancy-bound values, don't change it
        {
            Anywhere            = 0,
            Beginning           = 1,
            Ending              = 2, // handling extensions somehow
            BeginningOrEnding   = 3
        };
        
        using FoundRange = pair<int16_t, int16_t>; // begin-end indeces range in DispayName string, {0,0} mean empty
        
        Where     type = Anywhere;
        NSString *text = nil;
        bool      ignoredotdot = true; // will not apply filter on dot-dot entries
        bool      clearonnewlisting = false; // if true then PanelData will automatically set text to nil on Load method call
        
        bool operator==(const TextualFilter& _r) const noexcept;
        bool operator!=(const TextualFilter& _r) const noexcept;
        static Where WhereFromInt(int _v) noexcept;
        static TextualFilter NoFilter() noexcept;
        bool IsValidItem(const VFSListingItem& _item, FoundRange *_found_range = nullptr) const;
        void OnPanelDataLoad();
        bool IsFiltering() const noexcept;
    };
    
    struct HardFilter
    {
        bool show_hidden = true;
        TextualFilter text = TextualFilter::NoFilter();
        bool IsValidItem(const VFSListingItem& _item, TextualFilter::FoundRange *_found_range = nullptr) const;
        bool IsFiltering() const noexcept;
        bool operator==(const HardFilter& _r) const noexcept;
        bool operator!=(const HardFilter& _r) const noexcept;
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
    const VFSListing&       Listing() const;
    const VFSListingPtr&    ListingPtr() const;
    PanelType                        Type() const noexcept;
    
    int RawEntriesCount() const noexcept;
    int SortedEntriesCount() const noexcept;
    
    const DirSortIndT&      SortedDirectoryEntries() const;
    
    
    /**
     * EntriesBySoftFiltering return a vector of filtered indeces of sorted entries (not raw ones)
     */
    const DirSortIndT&      EntriesBySoftFiltering() const;
    
    VFSListingItem   EntryAtRawPosition(int _pos) const noexcept; // will return an "empty" item upon invalid index
    VolatileData&       VolatileDataAtRawPosition( int _pos ); // will throw an exception upon invalid index
    const VolatileData& VolatileDataAtRawPosition( int _pos ) const; // will throw an exception upon invalid index
    
    bool IsValidSortPosition(int _pos) const noexcept;
    VFSListingItem   EntryAtSortPosition(int _pos) const noexcept; // will return an "empty" item upon invalid index
    VolatileData&       VolatileDataAtSortPosition( int _pos ); // will throw an exception upon invalid index
    const VolatileData& VolatileDataAtSortPosition( int _pos ) const; // will throw an exception upon invalid index
    
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
     * Return _item position in sorted array, -1 if not found.
     */
    int SortIndexForEntry(const VFSListingItem& _item) const noexcept;
    
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
    void SetHardFiltering(const HardFilter &_filter);
    HardFilter HardFiltering() const;
    
    void SetSoftFiltering(const TextualFilter &_filter);
    TextualFilter SoftFiltering() const;

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
    void CustomFlagsClearHighlights();
    
    /**
     * Searches for _entry using binary search with case-sensitive comparison,
     * return true if changed something, false otherwise.
     * _size should be less than uint64_t(-1).
     */
    bool SetCalculatedSizeForDirectory(const char *_entry, uint64_t _size);
    bool SetCalculatedSizeForDirectory(const char *_filename, const char *_directory, uint64_t _size);
    
    /**
     * Call it in emergency case.
     */
    void __InvariantCheck() const;
private:    
    PanelData(const PanelData&) = delete;
    void operator=(const PanelData&) = delete;
    
    void DoSortWithHardFiltering();
    void CustomFlagsSelectRaw(int _at_raw_pos, bool _is_selected);
    void ClearSelectedFlagsFromHiddenElements();
    void UpdateStatictics();
    void BuildSoftFilteringIndeces();
    static EntrySortKeys ExtractSortKeysFromEntry(const VFSListingItem& _item, const VolatileData &_item_vd);
    
    // m_Listing container will change every time directory change/reloads,
    // while the following sort-indeces(except for m_EntriesByRawName) will be permanent with it's content changing
    shared_ptr<VFSListing>      m_Listing;
    vector<VolatileData>   m_VolatileData;
    DirSortIndT                 m_EntriesByRawName;    // sorted with raw strcmp comparison
    DirSortIndT                 m_EntriesByCustomSort; // custom defined sort
    DirSortIndT                 m_EntriesBySoftFiltering; // points at m_EntriesByCustomSort indeces, not raw ones
    
    PanelSortMode               m_CustomSortMode;
    HardFilter                  m_HardFiltering;
    TextualFilter               m_SoftFiltering;
    DispatchGroup               m_SortExecGroup;
    Statistics                  m_Stats;
    PanelType                   m_Type;
};

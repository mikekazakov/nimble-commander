// Copyright (C) 2013-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>
#include "PanelDataSortMode.h"
#include "PanelDataStatistics.h"
#include "PanelDataFilter.h"

namespace nc::panel::data {

struct ItemVolatileData;
struct ExternalEntryKey;

/**
 * PanelData actually does the following things:
 * - sorting provided data
 * - handling reloading with preserving of custom entries data
 * - searching
 * - paths accessing
 * - custom information setting/getting
 * - statistics
 */
class Model
{
public:
    enum class PanelType : int8_t
    {
        Directory = 0,
        Temporary = 1
    };
    
    Model();
    ~Model();
    
    // these methods should be called by a controller, since some view's props have to be updated
    // PanelData is solely sync class - it does not know about concurrency,
    // any parallelism should be done by callers (i.e. controller)
    // just like Metallica:
    void Load  (const shared_ptr<VFSListing> &_listing, PanelType _type);
    void ReLoad(const shared_ptr<VFSListing> &_listing);

    /**
     * Tells whether Model was provided with a valid listing object.  
     */
    bool IsLoaded() const noexcept;

    /**
     * Will throw logic_error if called on listing with no common host.
     */
    const shared_ptr<VFSHost>&      Host() const;
    const VFSListing&               Listing() const;
    const shared_ptr<VFSListing>&   ListingPtr() const;
    PanelType                       Type() const noexcept;
    
    int RawEntriesCount() const noexcept;
    int SortedEntriesCount() const noexcept;
    
    const vector<unsigned>& SortedDirectoryEntries() const noexcept;
    
    
    /**
     * EntriesBySoftFiltering return a vector of filtered indeces of sorted entries (not raw ones)
     */
    const vector<unsigned>& EntriesBySoftFiltering() const noexcept;
    
    VFSListingItem   EntryAtRawPosition(int _pos) const noexcept; // will return an "empty" item upon invalid index
    ItemVolatileData&       VolatileDataAtRawPosition( int _pos ); // will throw an exception upon invalid index
    const ItemVolatileData& VolatileDataAtRawPosition( int _pos ) const; // will throw an exception upon invalid index
    
    bool IsValidSortPosition(int _pos) const noexcept;
    VFSListingItem   EntryAtSortPosition(int _pos) const noexcept; // will return an "empty" item upon invalid index
    ItemVolatileData&       VolatileDataAtSortPosition( int _pos ); // will throw an exception upon invalid index
    const ItemVolatileData& VolatileDataAtSortPosition( int _pos ) const; // will throw an exception upon invalid index
    
    vector<string>          SelectedEntriesFilenames() const;
    vector<VFSListingItem> SelectedEntries() const;
    
    /**
     * Will throw an invalid_argument on invalid _pos.
     */
    ExternalEntryKey        EntrySortKeysAtSortPosition(int _pos) const;
    
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
    int SortLowerBoundForEntrySortKeys(const ExternalEntryKey& _key) const;
    
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
    void SetSortMode(SortMode _mode);
    SortMode SortMode() const;
    
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
    
    const Statistics &Stats() const noexcept;
    
    // manupulation with user flags for directory entries
    
    // TODO: bool results?????
    
    void CustomFlagsSelectSorted(int _at_sorted_pos, bool _is_selected);
    bool CustomFlagsSelectSorted(const vector<bool>& _is_selected);
    
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
    Model(const Model&) = delete;
    void operator=(const Model&) = delete;
    
    void DoSortWithHardFiltering();
    void CustomFlagsSelectRaw(int _at_raw_pos, bool _is_selected);
    void ClearSelectedFlagsFromHiddenElements();
    void UpdateStatictics();
    void BuildSoftFilteringIndeces();
    
    // m_Listing container will change every time directory change/reloads,
    // while the following sort-indeces(except for m_EntriesByRawName) will be permanent with it's content changing
    shared_ptr<VFSListing>      m_Listing;
    vector<ItemVolatileData>    m_VolatileData;
    vector<unsigned>            m_EntriesByRawName;    // sorted with raw strcmp comparison
    vector<unsigned>            m_EntriesByCustomSort; // custom defined sort
    vector<unsigned>            m_EntriesBySoftFiltering; // points at m_EntriesByCustomSort indeces, not raw ones
    struct SortMode             m_CustomSortMode;
    HardFilter                  m_HardFiltering;
    TextualFilter               m_SoftFiltering;
    Statistics                  m_Stats;
    PanelType                   m_Type;
};

}

#pragma once
#include <sys/dirent.h>
#include <vector>


#include "DirRead.h"

@class PanelController;
struct FlexChainedStringsChunk;

struct PanelSortMode
{
    // TODO: add sensivity flags, numerical flags

    
    enum Mode
    {
        SortNoSort = 0,
        SortByName,
        SortByNameRev,
        SortByExt,
        SortByExtRev,
        SortBySize,
        SortBySizeRev,
        SortByMTime,
        SortByMTimeRev,
        SortByBTime,
        SortByBTimeRev,
        SortByRawCName     // for internal usage, seems to be meaningless for human reading (sort by internal UTF8 representation)
    };
    
    Mode sort;
    bool sepdir;    // separate directories from files, like win-like
    bool show_hidden;
    
    inline PanelSortMode():
        sort(SortByRawCName),
        sepdir(false),
        show_hidden(true)
    {}
    inline PanelSortMode(Mode _mode, bool _sepdir):
        sort(_mode),
        sepdir(_sepdir),
        show_hidden(true)
    {}
    
    inline bool operator ==(const PanelSortMode& _r) const
    {
        return sort == _r.sort && sepdir == _r.sepdir && show_hidden == _r.show_hidden;
    }
    inline bool operator !=(const PanelSortMode& _r) const
    {
        return !(*this == _r);
    }
};
    
class PanelData
{
public:
    typedef std::deque<DirectoryEntryInformation> DirEntryInfoT;
    typedef std::vector<unsigned>                 DirSortIndT; // value in this array is an index for DirEntryInfoT
  
    struct DirectoryChangeContext // allocated with malloc, should be freed upon receiving
    {
        DirEntryInfoT *entries;
        char path[MAXPATHLEN];
    };
    
    
    PanelData();
    ~PanelData();
    
    // these methods should be called by a controller, since some view's props have to be updated
    bool GoToDirectory(const char *_path); // sync version
    void GoToDirectoryWithContext(DirectoryChangeContext *_context); // _context will be removed with free()
    bool ReloadDirectory(); // sync version
    void ReloadDirectoryWithContext(DirectoryChangeContext *_context); // _context will be removed with free()
    
    // asynchronous directory changing and reloading support
    // the following routies should run in background mode
    // callback are fired from background thread
    // controller's properties are watched from background thread
    static void LoadFSDirectoryAsync(const char *_path, // _path is allocated with malloc, should be freed upon receiving
                                     void (^_on_completion) (DirectoryChangeContext*),
                                     void (^_on_fail) (const char*, int),
                                     FetchDirectoryListing_CancelChecker _checker // can not be nil, put {return false;} as dummy
                                     );
    
    const DirEntryInfoT&    DirectoryEntries() const;
    const DirSortIndT&      SortedDirectoryEntries() const;
    FlexChainedStringsChunk* StringsFromSelectedEntries() const;
    
    int SortPosToRawPos(int _pos) const; // does SortedDirectoryEntries()[_pos]
    const DirectoryEntryInformation& EntryAtRawPosition(int _pos) const; // does DirectoryEntries()[_pos]
    
    void ComposeFullPathForEntry(int _entry_no, char _buf[__DARWIN_MAXPATHLEN]);
    
    int FindEntryIndex(const char *_filename) const;
        // TODO: improve this by using a name-sorted list
        // performs a bruteforce case-sensivitive search
        // return -1 if didn't found
        // returning value is in raw land, that is DirectoryEntries[N], not sorted ones
    
    int FindSortedEntryIndex(unsigned _desired_value) const;
        // return -1 if didn't found
        // _desired_value - raw item index
    
    void GetDirectoryPath(char _buf[__DARWIN_MAXPATHLEN]) const;
        // return current directory in long variant starting from /
    void GetDirectoryPathWithTrailingSlash(char _buf[__DARWIN_MAXPATHLEN]) const;
        // same as above but path will ends with slash
    void GetDirectoryPathShort(char _buf[__DARWIN_MAXPATHLEN]) const;
        // return name of a current directory in a parent directory
        // returns a zero string for a root dir
    
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
    void CustomFlagsSelect(int _at_pos, bool _is_selected);

    bool SetCalculatedSizeForDirectory(const char *_entry, unsigned long _size); // return true if changed something
private:
    void GoToDirectoryInternal(DirEntryInfoT *_entries, const char *_path); // passing ownership of _entries
    void ReloadDirectoryInternal(DirEntryInfoT *_entries); // passing ownership of _entries
    
    void DestroyCurrentData();
    PanelData(const PanelData&);
    void operator=(const PanelData&);
    
    // this function will erase data from _to, make it size of _form->size(), and fill it with indeces according to _mode
    static void DoSort(const DirEntryInfoT* _from, DirSortIndT *_to, PanelSortMode _mode);
    
    char                                    m_DirectoryPath[__DARWIN_MAXPATHLEN]; // path with trailing slash
    // m_Entries container will change every time directory change/reloads,
    // while the following sort-indeces(except for m_EntriesByRawName) will be permanent with it's content changing
    DirEntryInfoT                           *m_Entries;
    DirSortIndT                             *m_EntriesByRawName;   // sorted with raw strcmp comparison
    DirSortIndT                             *m_EntriesByHumanName; // sorted with human-reasonable literal sort
    DirSortIndT                             *m_EntriesByCustomSort; // custom defined sort
    PanelSortMode                           m_CustomSortMode;
    dispatch_group_t                        m_SortExecGroup;
    dispatch_queue_t                        m_SortExecQueue;
    
    // statistics
    unsigned long                           m_TotalBytesInDirectory; // assuming regular files ONLY!
    unsigned                                m_TotalFilesInDirectory; // NOT DIRECTORIES! only regular files, maybe + symlinks and other stuff
    unsigned long                           m_SelectedItemsSizeBytes;
    unsigned                                m_SelectedItemsCount;
    unsigned                                m_SelectedItemsFilesCount;
    unsigned                                m_SelectedItemsDirectoriesCount;
};

#pragma once
#include <sys/dirent.h>
#include <vector>


#include "DirRead.h"

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
    PanelSortMode(){}
    PanelSortMode(Mode _mode, bool _sepdir):sort(_mode),sepdir(_sepdir){}
};


class PanelData
{
public:
    typedef std::deque<DirectoryEntryInformation> DirEntryInfoT;
    typedef std::vector<unsigned>                 DirSortIndT; // value in this array is an index for DirEntryInfoT
    
    PanelData();
    ~PanelData();
    
    // these methods should be called by a controller, since some view's props have to be updated
    bool GoToDirectory(const char *_path);
    bool ReloadDirectory();
    
    
    const DirEntryInfoT&    DirectoryEntries() const;
    const DirSortIndT&      SortedDirectoryEntries() const;
    FlexChainedStringsChunk* StringsFromSelectedEntries();
    
    int SortPosToRawPos(int _pos) const; // does SortedDirectoryEntries()[_pos]
    const DirectoryEntryInformation& EntryAtRawPosition(int _pos) const; // does DirectoryEntries()[_pos]
    
    void ComposeFullPathForEntry(int _entry_no, char _buf[__DARWIN_MAXPATHLEN]);
    
    int FindEntryIndex(const char *_filename);
        // TODO: improve this by using a name-sorted list
        // performs a bruteforce case-sensivitive search
        // return -1 if didn't found
        // returning value is in raw land, that is DirectoryEntries[N], not sorted ones
    
    int FindSortedEntryIndex(unsigned _desired_value);
        // return -1 if didn't found
    
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
    
    
private:
    void DestroyCurrentData();
    PanelData(const PanelData&);
    void operator=(const PanelData&);
    
    // this function will erase data from _to, make it size of _form->size(), and fill it with indeces according to _mode
    static void DoSort(const DirEntryInfoT* _from, DirSortIndT *_to, PanelSortMode _mode);
    
    
    char                                    m_DirectoryPath[__DARWIN_MAXPATHLEN]; // path without trailing slash
    DirEntryInfoT                           *m_Entries;
    DirSortIndT                             *m_EntriesByRawName;
    DirSortIndT                             *m_EntriesByCustomSort;
    PanelSortMode                           m_CustomSortMode;
    
    // statistics
    unsigned long                           m_TotalBytesInDirectory; // assuming regular files ONLY!
    unsigned                                m_TotalFilesInDirectory; // NOT DIRECTORIES! only regular files, maybe + symlinks and other stuff
    unsigned long                           m_SelectedItemsSizeBytes;
    unsigned                                m_SelectedItemsCount;
    unsigned                                m_SelectedItemsFilesCount;
    unsigned                                m_SelectedItemsDirectoriesCount;
};

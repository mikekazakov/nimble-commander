// Copyright (C) 2014-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Habanero/SerialQueue.h>
#include <Utility/Encodings.h>
#include <Utility/FileMask.h>
#include <VFS/VFS.h>

#include <functional>
#include <string>
#include <queue>
#include <stdint.h>

namespace nc::vfs {

class SearchForFiles
{
public:
    struct Options {
        enum {
            GoIntoSubDirs   = 0x0001,
            SearchForDirs   = 0x0002,
            SearchForFiles  = 0x0004,
            LookInArchives  = 0x0008,
        };
    };
    
    struct FilterName {
        std::string mask;
    };
    
    struct FilterContent {
        std::string text; //utf8-encoded
        int encoding        = encodings::ENCODING_UTF8;
        bool whole_phrase   = false; // search for a phrase, not a part of something
        bool case_sensitive = false;
        bool not_containing = false;
    };
    
    struct FilterSize {
        uint64_t min = 0;
        uint64_t max = std::numeric_limits<uint64_t>::max();
    };

    // _content_found used to pass info where requested content was found, or {-1,0} if not used
    using FoundCallback = std::function<void(const char *_filename,
                                             const char *_in_path,
                                             VFSHost &_in_host,
                                             CFRange _content_found)>;
    
    using SpawnArchiveCallback = std::function<VFSHostPtr(const char*_for_path, VFSHost& _in_host)>;
    
    using LookingInCallback = std::function<void(const char*, VFSHost&)>;
    
    SearchForFiles();
    ~SearchForFiles();
    
    /**
     * Sets filename filtering. Should not be called with background search going on.
     */
    void SetFilterName(const FilterName &_filter);
    
    /**
     * Sets file content filtering. Should not be called with background search going on.
     */
    void SetFilterContent(const FilterContent &_filter);

    /**
     * Sets file size filtering. Should not be called with background search going on.
     * Will ignore default filter.
     */
    void SetFilterSize(const FilterSize &_filter);
    
    /**
     * Removes all previously set filters, supposing following SetFilerXXX calls.
     * Should not be called with background search going on.
     */
    void ClearFilters();
    
    /**
     * Returns immediately, run in background thread. Options is a bitfield with bits from Options:: enum.
     */
    bool Go(const std::string &_from_path,
            const VFSHostPtr &_in_host,
            int _options,
            FoundCallback _found_callback,
            std::function<void()> _finish_callback,
            LookingInCallback _looking_in_callback = nullptr,
            SpawnArchiveCallback _spawn_archive_callback = nullptr
            );
    
    /**
     * Singals to a working thread that it should stop. Returns immediately.
     */
    void Stop();
    
    /**
     * Returns true if search is running but was signaled to be stopped.
     */
    bool IsStopped();
    
    /**
     * Synchronously wait until job finishes.
     */
    void Wait();
    
    /**
     * Shows if search for files is currently performing by this object.
     */
    bool IsRunning() const noexcept;
    
private:
    void AsyncProc(const char* _from_path, VFSHost &_in_host);
    void ProcessDirent(const char* _full_path,
                       const char* _dir_path,
                       const VFSDirEnt &_dirent,
                       VFSHost &_in_host
                       );
    void ProcessValidEntry(const char* _full_path,
                           const char* _dir_path,
                           const VFSDirEnt &_dirent,
                           VFSHost &_in_host,
                           CFRange _cont_range);
    
    void NotifyLookingIn(const char* _path, VFSHost &_in_host) const;
    bool FilterByContent(const char* _full_path, VFSHost &_in_host, CFRange &_r);
    bool FilterByFilename(const char* _filename) const;
    
    SerialQueue                 m_Queue;
    std::optional<FilterName>   m_FilterName;
    std::optional<nc::utility::FileMask> m_FilterNameMask;
    std::optional<FilterContent>m_FilterContent;
    std::optional<FilterSize>   m_FilterSize;
    
    FoundCallback               m_Callback;
    SpawnArchiveCallback        m_SpawnArchiveCallback;
    std::function<void()>       m_FinishCallback;
    LookingInCallback           m_LookingInCallback;
    int                         m_SearchOptions;
    std::queue<VFSPath>         m_DirsFIFO;
};

}

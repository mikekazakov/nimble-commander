//
//  FileSearch.h
//  Files
//
//  Created by Michael G. Kazakov on 11.02.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include "vfs/VFS.h"
#include "DispatchQueue.h"
#include "FileMask.h"
#include "Encodings.h"

class FileSearch
{
public:
    struct Options {
        enum {
            GoIntoSubDirs = 0x0001,
            SearchForDirs = 0x0002  
        };
    };
    
    struct FilterName {
        NSString *mask;
    };
    
    struct FilterContent {
        NSString *text;
        int encoding        = encodings::ENCODING_UTF8;
        bool whole_phrase   = false; // search for a phrase, not a part of something
        bool case_sensitive = false;
    };
    
    struct FilterSize {
        uint64_t min = 0;
        uint64_t max = numeric_limits<uint64_t>::max();
    };

    // _content_found used to pass info where requested content was found, or {-1,0} if not used
    using FoundCallBack = function<void(const char *_filename,
                                        const char *_in_path,
                                        CFRange _content_found)>;
    
    FileSearch();
    ~FileSearch();
    
    /**
     * Can be nullptr, so just reset current if any.
     */
    void SetFilterName(FilterName *_filter);
    
    /**
     * Can be nullptr, so just reset current if any.
     */
    void SetFilterContent(FilterContent *_filter);

    /**
     * Can be nullptr, so just reset current if any.
     */
    void SetFilterSize(FilterSize *_filter);
    
    /**
     * Returns immediately, run in background thread. Options is a bitfield with bits from Options:: enum.
     */
    bool Go(const string &_from_path,
            const VFSHostPtr &_in_host,
            int _options,
            FoundCallBack _found_callback,
            function<void()> _finish_callback,
            function<void(const char*)> _looking_in_callback = nullptr
            );
    
    /**
     * Singals to a working thread that it should stop. Returns immediately.
     */
    void Stop();
    
    /**
     *
     */
    void Wait();
    
    /**
     * Shows if search for files is currently performing by this object.
     */
    bool IsRunning() const;
    
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
    
    void NotifyLookingIn(const char* _path) const;
    bool FilterByContent(const char* _full_path, VFSHost &_in_host, CFRange &_r);
    bool FilterByFilename(const char* _filename);
    
    SerialQueue                 m_Queue = SerialQueueT::Make();
    unique_ptr<FilterName>      m_FilterName;
    unique_ptr<FileMask>        m_FilterNameMask;
    unique_ptr<FilterContent>   m_FilterContent;
    unique_ptr<FilterSize>      m_FilterSize;
    
    FoundCallBack               m_Callback;
    function<void()>            m_FinishCallback;
    function<void(const char*)> m_LookingInCallback;
    int                         m_SearchOptions;
    queue<string>               m_DirsFIFO;
};

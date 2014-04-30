//
//  FileSearch.h
//  Files
//
//  Created by Michael G. Kazakov on 11.02.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include "VFS.h"
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
        int encoding        = ENCODING_UTF8;
        bool whole_phrase   = false; // search for a phrase, not a part of something
        bool case_sensitive = false;
    };
    
    struct FilterSize {
        uint64_t min = 0;
        uint64_t max = numeric_limits<uint64_t>::max();
    };
    
    typedef void (^FoundCallBack)(const char *_filename, const char *_in_path);
    typedef void (^FinishCallBack)();
    
    FileSearch();
    
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
    bool Go(string _from_path,
            shared_ptr<VFSHost> _in_host,
            int _options,
            FoundCallBack _found_callback,
            FinishCallBack _finish_callback
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
    void AsyncProcPrologue(string _from_path, shared_ptr<VFSHost> _in_host);
    void AsyncProc(const char* _from_path, VFSHost *_in_host);
    void ProcessDirent(const char* _full_path,
                       const char* _dir_path,
                       const VFSDirEnt &_dirent,
                       VFSHost *_in_host
                       );
    void ProcessValidEntry(const char* _full_path,
                           const char* _dir_path,
                           const VFSDirEnt &_dirent,
                           VFSHost *_in_host);
    
    
    bool FilterByContent(const char* _full_path, VFSHost *_in_host);
    bool FilterByFilename(const char* _filename);
    
    SerialQueue             m_Queue;
    unique_ptr<FilterName>  m_FilterName;
    unique_ptr<FileMask>    m_FilterNameMask;
    unique_ptr<FilterContent> m_FilterContent;
    unique_ptr<FilterSize>  m_FilterSize;
    
    
    FoundCallBack           m_Callback;
    FinishCallBack          m_FinishCallback;
    int                     m_SearchOptions;
    list<string>            m_DirsFIFO;
};

//
//  VFSNetFTPCache.h
//  Files
//
//  Created by Michael G. Kazakov on 07.05.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once

#import "3rd_party/built/include/curl/curl.h"
#import "Common.h"
#import "VFSHost.h"
#import "VFSListing.h"

namespace VFSNetFTP
{
    static const uint64_t g_ListingOutdateLimit = 1000lu * 1000lu * 1000lu * 30lu; // 30 sec
    
    
    struct Entry
    {
        Entry();
        Entry(const string &_name);
        Entry(const Entry&_r);
        ~Entry();
        Entry(const Entry&&) = delete;
        void operator=(const Entry&) = delete;
        
        string      name;
        CFStringRef cfname = 0; // no allocations, pointing at name
        uint64_t    size   = 0;
        time_t      time   = 0;
        mode_t      mode   = 0;
        mutable bool dirty = false; // true when this entry was explicitly set as outdated
        
        // links support in the future
        
        void ToStat(VFSStat &_stat) const;
    };
    
    struct Directory
    {
        deque<Entry>            entries;
//        shared_ptr<Directory>   parent_dir;
        string                  path; // with trailing slash
        uint64_t                snapshot_time = 0;
//        mutable bool dirty = false; // true when this directory was explicitly set as outdated, regardless of snapshot time

        bool                    dirty_structure = false; // true when there're mismatching between this cache and ftp server
        bool                    has_dirty_items = false;
        
        inline bool IsOutdated() const
        {
            return dirty_structure; // || (GetTimeInNanoseconds() > snapshot_time + g_ListingOutdateLimit);
        }
        
        const Entry* EntryByName(const string &_name) const;
    };
    
    class Cache
    {
    public:
        /**
         * Return nullptr if was not able to find directory.
         */
        shared_ptr<Directory> FindDirectory(const char *_path) const;

        /**
         * Return nullptr if was not able to find directory.
         */
        shared_ptr<Directory> FindDirectory(const string &_path) const;
        
        /**
         * Commits new freshly downloaded ftp listing.
         * If directory at _path is already in cache - it will be overritten.
         */
        void InsertLISTDirectory(const char *_path, shared_ptr<Directory> _dir);
        
        
        // incremental and atomic cache update methods:
        
        /**
         * Will mark entry as dirty and containing directory as has_dirty_items.
         */
        void MakeEntryDirty(const string &_path);
        
        /**
         * Creates a new dirty file.
         * If this file already exist in cache - mark it as dirty.
         */
        void CommitNewFile(const string &_path);
        
        /**
         * Erases a dir at _path.
         */
        void CommitRMD(const string &_path);
        
        /**
         * Create a new directory entry.
         */
        void CommitMKD(const string &_path);

        /**
         * Erases a entry at _path.
         */
        void CommitUnlink(const string &_path);
        
    private:
        shared_ptr<Directory> FindDirectoryInt(const string &_path) const;
        void EraseEntryInt(const string &_path);
        
        map<string, shared_ptr<Directory>>  m_Directories; // "/Abra/Cadabra/" -> Directory
        mutable mutex             m_CacheLock;
    };
    
    

}
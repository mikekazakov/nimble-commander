// Copyright (C) 2014-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <curl/curl.h>
#include <VFS/Host.h>

namespace nc::vfs::ftp {

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
    string                  path; // with trailing slash
    
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
    void SetChangesCallback(void (^_handler)(const string& _at_dir));
    
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
    
    void MarkDirectoryDirty( const string &_path );
    
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
    
    /**
     * Removes old entry path and places it as a new entry.
     */
    void CommitRename(const string &_old_path, const string &_new_path);
    
private:
    shared_ptr<Directory> FindDirectoryInt(const string &_path) const;
    void EraseEntryInt(const string &_path);
    
    map<string, shared_ptr<Directory>>  m_Directories; // "/Abra/Cadabra/" -> Directory
    mutable mutex             m_CacheLock;
    void                    (^m_Callback)(const string&);
};

}

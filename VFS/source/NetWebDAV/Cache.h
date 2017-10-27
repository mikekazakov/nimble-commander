// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

namespace nc::vfs::webdav {

struct PropFindResponse;

class Cache
{
public:
    Cache();
    ~Cache();
    
    enum class E {
        Ok = 0,
        Unknown = 1,
        NonExist = 2
    };

    optional<vector<PropFindResponse>> Listing( const string &_at_path ) const;
    pair<optional<PropFindResponse>, E> Item(const string &_at_path) const;

    void CommitListing( const string &_at_path, vector<PropFindResponse> _items );
    void DiscardListing( const string &_at_path );
    void CommitMkDir( const string &_at_path );
    void CommitRmDir( const string &_at_path );
    void CommitMkFile( const string &_at_path );
    void CommitUnlink( const string &_at_path );
    void CommitMove( const string &_old_path, const string &_new_path );

    unsigned long Observe(const string &_path, function<void()> _handler);
    void StopObserving(unsigned long _ticket);

private:
    struct Directory
    {
        nanoseconds fetch_time = 0ns;
        bool has_dirty_items = false;
        
        vector<PropFindResponse> items; // sorted by .path
        vector<bool> dirty_marks;
    };
    struct Observer
    {
        function<void()> callback;
        unsigned long ticket;
    };

    void Notify( const string &_changed_dir_path );
    static bool IsOutdated(const Directory &);
    
    unordered_map<string, Directory> m_Dirs;
    mutable mutex m_Lock;
    
    atomic_ulong m_LastTicket{1};
    unordered_multimap<string, Observer> m_Observers;
    mutable mutex m_ObserversLock;
};

}

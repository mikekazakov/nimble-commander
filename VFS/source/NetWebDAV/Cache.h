// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <chrono>
#include <string>
#include <unordered_map>
#include <mutex>
#include <optional>
#include <vector>

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

    std::optional<std::vector<PropFindResponse>> Listing( const std::string &_at_path ) const;
    std::pair<std::optional<PropFindResponse>, E> Item(const std::string &_at_path) const;

    void CommitListing( const std::string &_at_path, std::vector<PropFindResponse> _items );
    void DiscardListing( const std::string &_at_path );
    void CommitMkDir( const std::string &_at_path );
    void CommitRmDir( const std::string &_at_path );
    void CommitMkFile( const std::string &_at_path );
    void CommitUnlink( const std::string &_at_path );
    void CommitMove( const std::string &_old_path, const std::string &_new_path );

    unsigned long Observe(const std::string &_path, std::function<void()> _handler);
    void StopObserving(unsigned long _ticket);

private:
    struct Directory
    {
        std::chrono::nanoseconds fetch_time = std::chrono::nanoseconds{0};
        bool has_dirty_items = false;
        
        std::vector<PropFindResponse> items; // sorted by .path
        std::vector<bool> dirty_marks;
    };
    struct Observer
    {
        std::function<void()> callback;
        unsigned long ticket;
    };

    void Notify( const std::string &_changed_dir_path );
    static bool IsOutdated(const Directory &);
    
    std::unordered_map<std::string, Directory> m_Dirs;
    mutable std::mutex m_Lock;
    
    std::atomic_ulong m_LastTicket{1};
    std::unordered_multimap<std::string, Observer> m_Observers;
    mutable std::mutex m_ObserversLock;
};

}

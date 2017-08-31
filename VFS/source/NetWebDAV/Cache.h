#pragma once

namespace nc::vfs::webdav {

struct PropFindResponse;

class Cache
{
public:
    Cache();
    ~Cache();

    void CommitListing( string _at_path, vector<PropFindResponse> _items );
    void DiscardListing( string _at_path );    

    optional<vector<PropFindResponse>> Listing( string _at_path ) const;
    optional<PropFindResponse> Item(const string &_at_path) const;

private:
    struct Directory
    {
        string path; // direcotry path with trailing slash
        nanoseconds fetch_time = 0ns;
        bool has_dirty_items = false;
        
        vector<PropFindResponse> items; // sorted by .path
        vector<bool> dirty_marks;
    };

    static bool IsOutdated(const Directory &);
    
    unordered_map<string, Directory> m_Dirs;
    mutable mutex m_Lock;
};

}

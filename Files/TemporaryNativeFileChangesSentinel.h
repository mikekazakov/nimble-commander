#pragma once


class TemporaryNativeFileChangesSentinel
{
public:
    static TemporaryNativeFileChangesSentinel &Instance();
    
    
    /**
     * callback function will be called in main thread.
     */
    bool WatchFile( const string& _path, function<void()> _on_file_changed );
    
private:
    struct Meta {
        string                  path;
        function<void()>        callback;
        uint64_t                fswatch_ticket = 0;
        vector<uint8_t>         md5_hash;
        milliseconds            drop_time;
//        atomic_b
    };
    
    void FSEventCallback( shared_ptr<Meta> _meta );
    

    spinlock                    m_WatchesLock;
    vector<shared_ptr<Meta>>    m_Watches;
    const milliseconds          m_DropTimeDelta = 1h;
};

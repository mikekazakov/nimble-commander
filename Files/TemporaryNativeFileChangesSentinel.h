#pragma once


class TemporaryNativeFileChangesSentinel
{
public:
    static TemporaryNativeFileChangesSentinel &Instance();
    
    
    /**
     * Callback function will be called in main thread.
     * This method is thread-safe.
     * @param _path filepath to watch for content changes
     * @param _on_file_changed callback on change event
     */
    bool WatchFile( const string& _path, function<void()> _on_file_changed );
    
private:
    struct Meta {
        string                          path;
        shared_ptr<function<void()>>    callback;
        uint64_t                        fswatch_ticket = 0;
        vector<uint8_t>                 last_md5_hash;
        milliseconds                    drop_time;
        atomic_bool                     checking_now;
    };
    
    void FSEventCallback( shared_ptr<Meta> _meta );

    void BackgroundItemCheck( shared_ptr<Meta> _meta );

    spinlock                    m_WatchesLock;
    vector<shared_ptr<Meta>>    m_Watches;
    const milliseconds          m_DropTimeDelta = 1h;
};

#include <Habanero/algo.h>
#include <Habanero/Hash.h>
#include <Utility/FSEventsDirUpdate.h>
#include "vfs/vfs_native.h"
#include "TemporaryNativeFileChangesSentinel.h"

static const auto g_FileCheckDelay = 5s;

static optional<vector<uint8_t>> CalculateFileHash(const string &_path)
{
    const int chunk_sz = 1*1024*1024;
    VFSFilePtr file;
    int rc = VFSNativeHost::SharedHost()->CreateFile(_path.c_str(), file, nullptr );
    if( rc != 0 )
        return nullopt;
    
    rc = file->Open( VFSFlags::OF_Read | VFSFlags::OF_ShLock, nullptr );
    if(rc != 0)
        return nullopt;
    
    auto buf = make_unique<uint8_t[]>(chunk_sz);
    Hash h(Hash::MD5);
    
    ssize_t rn = 0;
    while( (rn = file->Read(buf.get(), chunk_sz)) > 0 )
        h.Feed(buf.get(), rn);
    
    if( rn < 0 )
        return nullopt;
    
    return h.Final();
}

TemporaryNativeFileChangesSentinel &TemporaryNativeFileChangesSentinel::Instance()
{
    static auto inst = new TemporaryNativeFileChangesSentinel;
    return *inst;
}

bool TemporaryNativeFileChangesSentinel::WatchFile( const string& _path, function<void()> _on_file_changed )
{
    // 1st - read current file and it's MD5 hash
    auto file_hash = CalculateFileHash( _path );
    if( !file_hash )
        return false;

    auto current = make_shared<Meta>();
    uint64_t watch_ticket = FSEventsDirUpdate::Instance().AddWatchPath( path(_path).parent_path().c_str(), [current]{
        TemporaryNativeFileChangesSentinel::Instance().FSEventCallback(current);
    });
    if( !watch_ticket )
        return false;

    current->fswatch_ticket = watch_ticket;
    current->path = _path;
    current->callback = to_shared_ptr( move(_on_file_changed) );
    current->last_md5_hash = move(*file_hash);
    current->drop_time =  duration_cast<milliseconds>(machtime() + m_DropTimeDelta);
    
    LOCK_GUARD(m_WatchesLock) {
        m_Watches.emplace_back( move(current) );
    }
    
    return true;
}

void TemporaryNativeFileChangesSentinel::FSEventCallback( shared_ptr<Meta> _meta )
{
    dispatch_assert_main_queue();
    
    if( _meta->checking_now )
        return;

    _meta->checking_now = true;
    
    dispatch_to_background_after( g_FileCheckDelay, [=]{ BackgroundItemCheck(_meta); } );
    
    cout << "fsevent on " << _meta->path << endl;
}

void TemporaryNativeFileChangesSentinel::BackgroundItemCheck( shared_ptr<Meta> _meta )
{
    dispatch_assert_background_queue();
    auto clear_flag = at_scope_end([&]{ _meta->checking_now = false; });

    auto current_hash = CalculateFileHash( _meta->path );
    if( !current_hash )
        return; // this file is not ok - just abort
    
    if( *current_hash != _meta->last_md5_hash ) {
        _meta->last_md5_hash = move(*current_hash);
        
        auto client_callback = _meta->callback;
        dispatch_to_main_queue([=]{ (*client_callback)(); });
        
    }
}

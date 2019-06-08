// Copyright (C) 2017-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "File.h"
#include "Aux.h"
#include "FileUploadStream.h"
#include "FileUploadDelegate.h"
#include "FileDownloadDelegate.h"
#include <Habanero/spinlock.h>
#include <iostream>

namespace nc::vfs::dropbox {

using namespace std::literals;
    
File::File(const char* _relative_path,
           const std::shared_ptr<class DropboxHost> &_host):
    VFSFile(_relative_path, _host)
{
}

File::~File()
{
    Close();
}

int File::Close()
{
    if( m_Upload ) {
        if( m_State == Uploading ) {
            if( m_Upload->upload_size == m_FilePos )
                [m_Upload->stream notifyAboutDataEnd];
            else {
                // client hasn't provided enough data and is closing a file.
                // this is an invalid behaviour, need to cancel a transfer task
                [m_Upload->task cancel];
                SetLastError(VFSError::FromErrno(EIO));
                SwitchToState(Canceled);
            }
            
            // need to wait for response from server before returning from Close();
            std::unique_lock<std::mutex> lk(m_SignalLock);
            m_Signal.wait(lk, [&]{ return m_State == Completed || m_State == Canceled; } );
        }
    }

    LOCK_GUARD(m_DataLock) {
        if( m_Download ) {
            [m_Download->task cancel];
            m_Download->delegate.handleResponse = nullptr;
            m_Download->delegate.handleData = nullptr;
            m_Download->delegate.handleError = nullptr;
            m_Download.reset();
        }
        
        if( m_Upload ) {
            m_Upload->stream.feedData = nullptr;
            m_Upload->stream.hasDataToFeed = nullptr;
            m_Upload->delegate.handleFinished = nullptr;
            m_Upload.reset();
        }       
    }
    
    const int rc = LastError();
    
    SetLastError(VFSError::Ok);
    m_OpenFlags = 0;
    m_FilePos   = 0;
    m_FileSize  = -1;
    m_State     = Cold;

    return rc;
}

NSURLRequest *File::BuildDownloadRequest() const
{
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:api::Download];
    request.HTTPMethod = @"POST";
    DropboxHost().FillAuth(request);
    InsetHTTPHeaderPathspec(request, Path());
    return request;
}

int File::Open(unsigned long _open_flags,
               [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    if( m_State != Cold )
        return VFSError::InvalidCall;
        
    assert( !m_Upload && !m_Download );

    if( (_open_flags & VFSFlags::OF_Read) == VFSFlags::OF_Read ) {
        auto delegate = [[NCVFSDropboxFileDownloadDelegate alloc] init];
        delegate.handleResponse = [this](ssize_t _size) { HandleDownloadResponseAsync(_size); };
        delegate.handleData = [this](NSData *_data) { AppendDownloadedDataAsync(_data); };
        delegate.handleError = [this](int _error) { HandleDownloadError(_error); };
        
        auto request = BuildDownloadRequest();
        auto session = [NSURLSession sessionWithConfiguration:DropboxHost().GenericConfiguration()
                                                     delegate:delegate
                                                delegateQueue:nil];
        auto task = [session dataTaskWithRequest:request];
        
        m_Download = std::make_unique<Download>();
        m_Download->delegate = delegate;
        m_Download->task = task;
        m_OpenFlags = _open_flags;
        SwitchToState(Initiated);
        
        [task resume];
        
        WaitForDownloadResponse();
    
        return m_State == Downloading ? VFSError::Ok : LastError();
    }
    if( (_open_flags & VFSFlags::OF_Write) == VFSFlags::OF_Write ) {
        m_OpenFlags = _open_flags;
        SwitchToState(Initiated);
        m_Upload = std::make_unique<Upload>();
        // at this point we need to wait for SetUploadSize() call to build of a request
        // and to actually start it
        return VFSError::Ok;
    }
    
    return VFSError::InvalidCall;
}

void File::WaitForDownloadResponse() const
{
    std::unique_lock<std::mutex> lk(m_SignalLock);
    m_Signal.wait(lk, [=]{
        return m_State != Initiated;
    } );
}

void File::HandleDownloadResponseAsync( ssize_t _download_size )
{
    if( m_State != Initiated )
        return;
    
    m_FileSize = _download_size; // <- this write is not formally-synchronized
    SwitchToState(Downloading);
}

void File::HandleDownloadError( int _error )
{
    if( m_State == Initiated  || m_State == Downloading ) {
        SetLastError(_error);
        SwitchToState(Canceled);
    }
}

File::ReadParadigm File::GetReadParadigm() const
{
    return ReadParadigm::Sequential;
}

File::WriteParadigm File::GetWriteParadigm() const
{
    return WriteParadigm::Upload;
}

void File::AppendDownloadedDataAsync( NSData *_data )
{
    if( !_data || _data.length == 0 || m_State != Downloading || !m_Download || m_FileSize < 0 )
        return;

    std::lock_guard<std::mutex> lock{m_DataLock};
    [_data enumerateByteRangesUsingBlock:[this](const void *bytes,
                                                NSRange byteRange,
                                                [[maybe_unused]] BOOL *stop) {
        m_Download->fifo.insert(end(m_Download->fifo),
                                (const uint8_t*)bytes,
                                (const uint8_t*)bytes + byteRange.length);
    }];
    m_Signal.notify_all();
}

ssize_t File::Pos() const
{
    return 0;
}

ssize_t File::Size() const
{
    return m_FileSize >= 0 ? m_FileSize : VFSError::InvalidCall;
}

bool File::Eof() const
{
    return m_FilePos == m_FileSize;
}

ssize_t File::Read(void *_buf, size_t _size)
{
    if( m_State != Downloading && m_State != Completed )
        return VFSError::InvalidCall;
    if( !m_Download )
        return VFSError::InvalidCall;
    if( _size == 0 || Eof() )
        return 0;
    
    do {
        LOCK_GUARD(m_DataLock) {
            if( !m_Download->fifo.empty() ) {
                const ssize_t sz = std::min( _size, m_Download->fifo.size() );
                copy_n( begin(m_Download->fifo), sz, (uint8_t*)_buf );
                m_Download->fifo.erase( begin(m_Download->fifo), begin(m_Download->fifo) + sz );
                m_Download->fifo_offset += sz;
                m_FilePos += sz;
                if( m_FilePos == m_FileSize )
                    SwitchToState(Completed);
                return sz;
            }
        }
    
        std::unique_lock<std::mutex> lk(m_SignalLock);
        m_Signal.wait(lk);
    } while( m_State == Downloading );
    return LastError();
}

bool File::IsOpened() const
{
    return m_State == Initiated ||
            m_State == Downloading ||
            m_State == Uploading ||
            m_State == Completed;
}

int File::PreferredIOSize() const
{
    return 32768; // packets are usually 16384 bytes long, use IO twice as long
}

std::string File::BuildUploadPathspec() const
{
    std::string spec =
        "{ \"path\": \"" + EscapeStringForJSONInHTTPHeader(Path()) + "\" ";
    if( m_OpenFlags & VFSFlags::OF_Truncate )
        spec += ", \"mode\": { \".tag\": \"overwrite\" } ";
    spec += "}";
    return spec;
}

NSURLRequest *File::BuildRequestForSinglePartUpload() const
{
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:api::Upload];
    request.HTTPMethod = @"POST";
    DropboxHost().FillAuth(request);
    [request setValue:@"application/octet-stream" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithUTF8String:BuildUploadPathspec().c_str()]
             forHTTPHeaderField:@"Dropbox-API-Arg"];
    [request setValue:[NSString stringWithUTF8String:std::to_string(m_Upload->upload_size).c_str()]
             forHTTPHeaderField:@"Content-Length"];
    return request;
}

void File::StartSmallUpload()
{
    assert( m_Upload != nullptr );
    assert( m_Upload->upload_size >= 0 && m_Upload->upload_size <= m_ChunkSize );
    assert( m_Upload->delegate == nil );
    assert( m_Upload->stream == nil );
    assert( m_Upload->task == nil );

    auto stream = [[NCVFSDropboxFileUploadStream alloc] init];
    stream.hasDataToFeed = [this]() -> bool {
        return HasDataToFeedUploadTaskAsync();
    };
    stream.feedData = [this](uint8_t *_buffer, size_t _sz) -> ssize_t {
        return FeedUploadTaskAsync(_buffer, _sz);
    };
    
    auto delegate = [[NCVFSDropboxFileUploadDelegate alloc] initWithStream:stream];
    delegate.handleFinished = [this](int _vfs_error){
        if( m_State == Initiated || m_State == Uploading ) {
            if( _vfs_error == VFSError::Ok ) {
                SwitchToState(Completed);
            }
            else {
                SetLastError(_vfs_error);
                SwitchToState(Canceled);
            }
        }
    };
    
    auto request = BuildRequestForSinglePartUpload();
    auto session = [NSURLSession sessionWithConfiguration:DropboxHost().GenericConfiguration()
                                                 delegate:delegate
                                            delegateQueue:nil];
    auto task = [session uploadTaskWithStreamedRequest:request];

    m_Upload->delegate = delegate;
    m_Upload->stream = stream;
    m_Upload->task = task;
    SwitchToState(Uploading);

    [task resume];
}

NSURLRequest *File::BuildRequestForUploadSessionInit() const
{
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc]initWithURL:api::UploadSessionStart];
    request.HTTPMethod = @"POST";
    DropboxHost().FillAuth(request);
    [request setValue:@"application/octet-stream" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"{}" forHTTPHeaderField:@"Dropbox-API-Arg"];
    [request setValue:[NSString stringWithUTF8String:std::to_string(m_ChunkSize).c_str()]
             forHTTPHeaderField:@"Content-Length"];
    return request;
}

void File::StartSession()
{
    assert( m_Upload != nullptr );
    assert( m_Upload->upload_size > m_ChunkSize );
    assert( m_Upload->delegate == nil );
    assert( m_Upload->stream == nil );
    assert( m_Upload->task == nil );

    auto stream = [[NCVFSDropboxFileUploadStream alloc] init];
    stream.hasDataToFeed = [this]() -> bool {
        return HasDataToFeedUploadTaskAsync();
    };
    stream.feedData = [this](uint8_t *_buffer, size_t _sz) -> ssize_t {
        return FeedUploadTaskAsync(_buffer, _sz);
    };
    
    auto delegate = [[NCVFSDropboxFileUploadDelegate alloc] initWithStream:stream];
    delegate.handleFinished = [this](int _vfs_error){
        if( m_State == Uploading && _vfs_error != VFSError::Ok ) {
            SetLastError(_vfs_error);
            SwitchToState(Canceled);
        }
    };
    
    auto request = BuildRequestForUploadSessionInit();
    auto session = [NSURLSession sessionWithConfiguration:DropboxHost().GenericConfiguration()
                                                 delegate:delegate
                                            delegateQueue:nil];
    auto task = [session uploadTaskWithStreamedRequest:request];

    m_Upload->delegate = delegate;
    m_Upload->stream = stream;
    m_Upload->task = task;
    m_Upload->partitioned = true;
    m_Upload->part_no = 0;
    m_Upload->parts_count = (int)(m_Upload->upload_size / m_ChunkSize) +
                                 (m_Upload->upload_size % m_ChunkSize ? 1 : 0);
    SwitchToState(Uploading);
    
    [task resume];
}

NSURLRequest *File::BuildRequestForUploadSessionAppend() const
{
    NSMutableURLRequest *request =[[NSMutableURLRequest alloc]initWithURL:api::UploadSessionAppend];
    request.HTTPMethod = @"POST";
    DropboxHost().FillAuth(request);
    
    const std::string header =
        "{\"cursor\": {"s +
            "\"session_id\": \"" + m_Upload->session_id + "\", " +
            "\"offset\": " + std::to_string(m_FilePos) +
        "}}";
    [request setValue:[NSString stringWithUTF8String:header.c_str()]
             forHTTPHeaderField:@"Dropbox-API-Arg"];
    
    [request setValue:@"application/octet-stream" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithUTF8String:std::to_string(m_ChunkSize).c_str()]
             forHTTPHeaderField:@"Content-Length"];

    return request;
}

void File::StartSessionAppend()
{
    assert( m_State == Uploading );
    assert( m_Upload != nullptr );
    assert( m_FilePos >= m_ChunkSize );
    assert( m_Upload->upload_size > m_ChunkSize );
    assert( m_Upload->delegate != nil );
    assert( m_Upload->stream != nil );
    assert( m_Upload->task != nil );
    assert( m_Upload->part_no < m_Upload->parts_count - 1 );
    assert( !m_Upload->session_id.empty() );
    m_Upload->part_no++;

   auto stream = [[NCVFSDropboxFileUploadStream alloc] init];
    stream.hasDataToFeed = [this]() -> bool {
        return HasDataToFeedUploadTaskAsync();
    };
    stream.feedData = [this](uint8_t *_buffer, size_t _sz) -> ssize_t {
        return FeedUploadTaskAsync(_buffer, _sz);
    };
    
    auto delegate = [[NCVFSDropboxFileUploadDelegate alloc] initWithStream:stream];
    delegate.handleFinished = [this](int _vfs_error){
        if( m_State == Uploading && _vfs_error != VFSError::Ok ) {
            SetLastError(_vfs_error);
            SwitchToState(Canceled);
        }
    };
    
    auto request = BuildRequestForUploadSessionAppend();
    auto session = [NSURLSession sessionWithConfiguration:DropboxHost().GenericConfiguration()
                                                 delegate:delegate
                                            delegateQueue:nil];
    auto task = [session uploadTaskWithStreamedRequest:request];

    m_Upload->delegate = delegate;
    m_Upload->stream = stream;
    m_Upload->task = task;
    m_Upload->append_accepted = false;
    
    [task resume];
}

NSURLRequest *File::BuildRequestForUploadSessionFinish() const
{
    NSMutableURLRequest *request =[[NSMutableURLRequest alloc]initWithURL:api::UploadSessionFinish];
    request.HTTPMethod = @"POST";
    DropboxHost().FillAuth(request);
    
    const std::string header =
        "{\"cursor\": {"s +
            "\"session_id\": \"" + m_Upload->session_id + "\", " +
            "\"offset\": " + std::to_string(m_FilePos) +
        "}, " +
        "\"commit\": " + BuildUploadPathspec() +
        " }";
    
    [request setValue:[NSString stringWithUTF8String:header.c_str()]
             forHTTPHeaderField:@"Dropbox-API-Arg"];
    [request setValue:@"application/octet-stream" forHTTPHeaderField:@"Content-Type"];
    const long content_length = m_Upload->upload_size - m_FilePos;
    [request setValue:[NSString stringWithUTF8String:std::to_string(content_length).c_str()]
             forHTTPHeaderField:@"Content-Length"];

    return request;
}

void File::StartSessionFinish()
{
    assert( m_State == Uploading );
    assert( m_Upload != nullptr );
    assert( m_FilePos >= m_ChunkSize );
    assert( m_Upload->upload_size > m_ChunkSize );
    assert( m_Upload->delegate != nil );
    assert( m_Upload->stream != nil );
    assert( m_Upload->task != nil );
    assert( m_Upload->part_no <= m_Upload->parts_count - 1 );
    assert( !m_Upload->session_id.empty() );
    m_Upload->part_no++;

    auto stream = [[NCVFSDropboxFileUploadStream alloc] init];
    stream.hasDataToFeed = [this]() -> bool {
        return HasDataToFeedUploadTaskAsync();
    };
    stream.feedData = [this](uint8_t *_buffer, size_t _sz) -> ssize_t {
        return FeedUploadTaskAsync(_buffer, _sz);
    };
    
    auto delegate = [[NCVFSDropboxFileUploadDelegate alloc] initWithStream:stream];
    delegate.handleFinished = [this](int _vfs_error){
        if( m_State == Uploading ) {
            if( _vfs_error == VFSError::Ok ) {
                SwitchToState(Completed);
            }
            else {
                SetLastError(_vfs_error);
                SwitchToState(Canceled);
            }
        }
    };
    
    auto request = BuildRequestForUploadSessionFinish();
    auto session = [NSURLSession sessionWithConfiguration:DropboxHost().GenericConfiguration()
                                                 delegate:delegate
                                            delegateQueue:nil];
    auto task = [session uploadTaskWithStreamedRequest:request];

    m_Upload->delegate = delegate;
    m_Upload->stream = stream;
    m_Upload->task = task;
    
    [task resume];
}

int File::SetUploadSize(size_t _size)
{
    if( !m_Upload ||
        m_State != Initiated )
        return VFSError::InvalidCall;
    if( m_Upload->upload_size >= 0 )
        return VFSError::InvalidCall;
    
    m_Upload->upload_size = _size;
    
    if( _size <= (size_t)m_ChunkSize )
        StartSmallUpload();
    else
        StartSession();
    return VFSError::Ok;
}

ssize_t File::WaitForUploadBufferConsumption() const
{
    const ssize_t to_eat = m_Upload->fifo.size();
    ssize_t eaten = 0;
    while ( eaten < to_eat && m_State != Canceled ) {
        std::unique_lock<std::mutex> signal_lock(m_SignalLock);
        m_Signal.wait(signal_lock);
        
        std::lock_guard<std::mutex> lock{m_DataLock};
        eaten = to_eat - m_Upload->fifo.size();
    }
    return eaten;
}

void File::PushUploadDataIntoFIFOAndNotifyStream( const void *_buf, size_t _size )
{
    std::lock_guard<std::mutex> lock{m_DataLock};
    m_Upload->fifo.insert(end(m_Upload->fifo),
                          (const uint8_t*)_buf,
                          (const uint8_t*)_buf + _size);
    [m_Upload->stream notifyAboutNewData];
}

void File::ExtractSessionIdOrCancelUploadAsync( NSData *_data )
{
    if( m_State != Uploading )
        return;
    
    if( auto doc = ParseJSON(_data) )
        if( auto session_id = GetString(*doc, "session_id") ) {
            LOCK_GUARD(m_DataLock) {
                m_Upload->session_id = session_id;
            }
            m_Signal.notify_all();
            return;
        }
    
    SetLastError( VFSError::FromErrno(EIO) );
    SwitchToState(Canceled);
}

void File::WaitForSessionIdOrError() const
{
    std::unique_lock<std::mutex> lock(m_SignalLock);
    m_Signal.wait(lock, [this]{
        if( m_State != Uploading )
            return true;
        std::lock_guard<std::mutex> lock{m_DataLock};
        return !m_Upload->session_id.empty();
    });
}

void File::WaitForAppendToComplete() const
{
    std::unique_lock<std::mutex> lock(m_SignalLock);
    m_Signal.wait(lock, [this]{
        if( m_State != Uploading )
            return true;
        std::lock_guard<std::mutex> lock{m_DataLock};
        return bool(m_Upload->append_accepted);
    });
}

ssize_t File::Write(const void *_buf, size_t _size)
{
    if( !m_Upload ||
        m_State != Uploading ||
        m_Upload->upload_size < 0 ||
        m_FilePos + (long)_size > m_Upload->upload_size )
        return VFSError::InvalidCall;
    
    assert( m_Upload->fifo.empty() );
    
    // figure out amount of information we can consume this call
    const size_t left_of_this_chunk = m_ChunkSize - m_Upload->fifo_offset;
    const size_t to_write = std::min(_size, left_of_this_chunk);
    
    PushUploadDataIntoFIFOAndNotifyStream(_buf, to_write);
    const auto eaten = WaitForUploadBufferConsumption();

    if( m_State != Uploading )
        return LastError();

    m_FilePos += eaten;
    
    if( m_FilePos == m_Upload->upload_size ) {
        [m_Upload->stream notifyAboutDataEnd];
    }
    else if( m_Upload->partitioned && m_Upload->fifo_offset == m_ChunkSize ) {
        // finish current upload request
        [m_Upload->stream notifyAboutDataEnd];
        m_Upload->stream.feedData = nullptr;
        m_Upload->stream.hasDataToFeed = nullptr;
        m_Upload->fifo_offset = 0;
        
        if( m_Upload->part_no == 0 ) {
            m_Upload->delegate.handleReceivedData = [this](NSData *_data){
                ExtractSessionIdOrCancelUploadAsync(_data);
            };
            WaitForSessionIdOrError();

            m_Upload->delegate.handleReceivedData = nullptr;
            m_Upload->delegate.handleFinished = nullptr;
            
            if( m_State != Uploading )
                return LastError();
        }
        
        if( m_Upload->part_no >= 1 && m_Upload->part_no < m_Upload->parts_count - 1 ) {
            m_Upload->delegate.handleReceivedData = [this]([[maybe_unused]] NSData *_data){
                if( m_State != Uploading )
                    return;
                m_Upload->append_accepted = true;
                m_Signal.notify_all();
            };
            WaitForAppendToComplete();
            
            if( m_State != Uploading )
                return LastError();
        }
        
        if( m_Upload->part_no + 1 < m_Upload->parts_count - 1  )
            StartSessionAppend();
        else if( m_Upload->part_no + 1 == m_Upload->parts_count - 1  )
            StartSessionFinish();
    }
    return eaten;
}

ssize_t File::FeedUploadTaskAsync( uint8_t *_buffer, size_t _sz )
{
    if( _sz == 0 )
        return 0;
    
    ssize_t sz = 0;
    
    LOCK_GUARD(m_DataLock) {
        sz = std::min( _sz, m_Upload->fifo.size() );
        copy_n( begin(m_Upload->fifo), sz, _buffer );
        m_Upload->fifo.erase( begin(m_Upload->fifo), begin(m_Upload->fifo) + sz );
        m_Upload->fifo_offset += sz;
    }
    
    if( sz != 0 )
        m_Signal.notify_all();
    return sz;
}

bool File::HasDataToFeedUploadTaskAsync() const
{
    if( m_State != Uploading )
        return false;
    std::lock_guard<std::mutex> lock{m_DataLock};
    return !m_Upload->fifo.empty();
}

int File::SetChunkSize( size_t _size )
{
    if( m_State != Cold )
        return VFSError::InvalidCall;
    if( _size >= 1 * 1000 * 1000 && _size <= 150 * 1000 * 1000 ) {
        m_ChunkSize = _size;
        return VFSError::Ok;
    }
    return VFSError::FromErrno(EINVAL);
}

void File::CheckStateTransition( State _new_state ) const
{
    static const bool valid_flow[StatesAmount][StatesAmount] = {
/* Valid transitions from index1 to index2                              */
/*               Cold Initiated Downloading Uploading Canceled Completed*/
/*Cold*/        { 0,      1,         0,        0,         0,       0    },
/*Initiated*/   { 0,      0,         1,        1,         1,       0    },
/*Downloading*/ { 0,      0,         0,        0,         1,       1    },
/*Uploading*/   { 0,      0,         0,        0,         1,       1    },
/*Canceled*/    { 1,      0,         0,        0,         0,       0    },
/*Completed*/   { 1,      0,         0,        0,         0,       0   }};
    if( !valid_flow[m_State][_new_state] )
        std::cerr << "suspicious state change: " << m_State << " to " << _new_state << std::endl;
}

void File::SwitchToState( State _new_state )
{
    CheckStateTransition( _new_state );
    m_State = _new_state;
    m_Signal.notify_all();
}

const DropboxHost &File::DropboxHost() const
{
    return *((class DropboxHost*)Host().get());
}

}

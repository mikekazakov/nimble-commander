#include "VFSNetDropboxFile.h"
#include "Aux.h"

using namespace VFSNetDropbox;

static const auto g_Download = [NSURL URLWithString:@"https://content.dropboxapi.com/2/files/download"];
static const auto g_Upload = [NSURL URLWithString:@"https://content.dropboxapi.com/2/files/upload"];
static const NSInteger kOperationFailedReturnCode = -1;

@interface VFSNetDropboxFileDownloadDelegate : NSObject<NSURLSessionDelegate>

- (instancetype)initWithFile:(shared_ptr<VFSNetDropboxFile>)_file;

@end

@implementation VFSNetDropboxFileDownloadDelegate
{
    weak_ptr<VFSNetDropboxFile> m_File;
}

- (instancetype)initWithFile:(shared_ptr<VFSNetDropboxFile>)_file
{
    if( self = [super init] ) {
        m_File = _file;
    }
    return self;
}

- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(nullable NSError *)error
{
    cout << "didBecomeInvalidWithError" << endl;
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
                           didCompleteWithError:(nullable NSError *)error
{
    cout << "didCompleteWithError" << endl;
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
                                     didReceiveData:(NSData *)data
{
//    cout << "didReceiveData" << endl;
    if( auto file = m_File.lock() )
        file->AppendDownloadedData(data);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
                                 didReceiveResponse:(NSURLResponse *)response
                                  completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler
{
    cout << "didReceiveResponse" << endl;
    bool permit = false;
    if( auto file = m_File.lock() )
        permit = file->ProcessDownloadResponse(response);

    completionHandler( permit ?  NSURLSessionResponseAllow : NSURLSessionResponseCancel );
}
                                
@end

@interface VFSNetDropboxFileUploadDelegate : NSInputStream<NSURLSessionDelegate>

- (instancetype)initWithFile:(shared_ptr<VFSNetDropboxFile>)_file;

- (void)notifyAboutNewData;
- (void)notifyAboutDataEnd;

@end

@implementation VFSNetDropboxFileUploadDelegate
{
    weak_ptr<VFSNetDropboxFile> m_File;
    NSStreamStatus m_Status;
    __weak id<NSStreamDelegate> m_Delegate;
    NSMutableDictionary *m_Properties;
}

- (instancetype)initWithFile:(shared_ptr<VFSNetDropboxFile>)_file
{
    if( self = [super init] ) {
        m_File = _file;
        m_Status = NSStreamStatusNotOpen;
        m_Properties = [[NSMutableDictionary alloc] init];
    }
    return self;
}
//typedef NS_ENUM(NSUInteger, NSStreamStatus) {
//    NSStreamStatusNotOpen = 0,
//    NSStreamStatusOpening = 1,
//    NSStreamStatusOpen = 2,
//    NSStreamStatusReading = 3,
//    NSStreamStatusWriting = 4,
//    NSStreamStatusAtEnd = 5,
//    NSStreamStatusClosed = 6,
//    NSStreamStatusError = 7
//};

- (nullable id)propertyForKey:(NSStreamPropertyKey)key
{
    return [m_Properties objectForKey:key];
}

- (BOOL)setProperty:(nullable id)property forKey:(NSStreamPropertyKey)key
{
    [m_Properties setObject:property forKey:key];
    return true;
}


- (NSStreamStatus) streamStatus
{
    cout << "told stream status" << endl;
    return m_Status;
}

- (void)open
{
    m_Status = NSStreamStatusOpen;
}

- (void)close
{
    m_Status = NSStreamStatusClosed;
}


//@property (nullable, assign) id <NSStreamDelegate> delegate;

- (void) setDelegate:(id<NSStreamDelegate>)delegate
{
    m_Delegate = delegate;
}

- (void)scheduleInRunLoop:(NSRunLoop *)aRunLoop forMode:(NSRunLoopMode)mode {}
- (void)removeFromRunLoop:(NSRunLoop *)aRunLoop forMode:(NSRunLoopMode)mode {}

//[VFSNetDropboxFileUploadDelegate streamStatus]
// reads up to length bytes into the supplied buffer, which must be at least of size len. Returns the actual number of bytes read.
- (NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)len
{
    if( auto file = m_File.lock() ) {
        auto rc = file->FeedUploadTask(buffer, len);
        if( rc >= 0)
            return rc;
        return kOperationFailedReturnCode;
    }
    
    return kOperationFailedReturnCode;
}

- (BOOL)getBuffer:(uint8_t * _Nullable * _Nonnull)buffer length:(NSUInteger *)len { return false; }

//@property (readonly) BOOL hasBytesAvailable;
- (BOOL) hasBytesAvailable
{
    if( auto file = m_File.lock() )
        return file->HasDataToFeedUploadTask();
    return false;
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
                              needNewBodyStream:(void (^)(NSInputStream * _Nullable bodyStream))completionHandler
{
    completionHandler(self);
}

- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(nullable NSError *)error
{
    cout << "didBecomeInvalidWithError" << endl;
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
                           didCompleteWithError:(nullable NSError *)error
{
    cout << "didCompleteWithError" << endl;
    if( error )
        NSLog(@"%@", error);
    auto r = task.response;
    NSLog(@"%@", r);
//    int a = 10;

}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
                                     didReceiveData:(NSData *)data
{
    if( auto s = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] )
        NSLog(@"%@", s);
//    cout << "didReceiveData" << endl;
//    if( auto file = m_File.lock() )
//        file->AppendDownloadedData(data);
}

- (void)notifyAboutNewData
{
//- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode;
    if( [m_Delegate respondsToSelector:@selector(stream:handleEvent:)] )
        [m_Delegate stream:self handleEvent:NSStreamEventHasBytesAvailable];
}

- (void)notifyAboutDataEnd
{
    m_Status =  NSStreamStatusAtEnd;
    if( [m_Delegate respondsToSelector:@selector(stream:handleEvent:)] )
        [m_Delegate stream:self handleEvent:NSStreamEventEndEncountered];
}

@end


VFSNetDropboxFile::VFSNetDropboxFile(const char* _relative_path, const shared_ptr<VFSNetDropboxHost> &_host):
    VFSFile(_relative_path, _host)
{
}

VFSNetDropboxFile::~VFSNetDropboxFile()
{
    Close();
}

int VFSNetDropboxFile::Close()
{
    m_FilePos = 0;
    m_FileSize = -1;

    m_State = Cold;

    LOCK_GUARD(m_DataLock) {
        m_DownloadFIFO.clear();
        m_DownloadFIFOOffset = 0; // is it always equal to m_FilePos???
        [m_DownloadTask cancel];
        m_DownloadTask = nil;
    }

    return 0;
}

int VFSNetDropboxFile::Open(int _open_flags, VFSCancelChecker _cancel_checker)
{
    auto &host = *((VFSNetDropboxHost*)Host().get());
    if( (_open_flags & VFSFlags::OF_Read) == VFSFlags::OF_Read ) {
        auto delegate = [[VFSNetDropboxFileDownloadDelegate alloc] initWithFile:
                         static_pointer_cast<VFSNetDropboxFile>(shared_from_this())];
        auto session = [NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.defaultSessionConfiguration
                                                     delegate:delegate
                                                delegateQueue:nil];
        
        NSMutableURLRequest *req = [[NSMutableURLRequest alloc] initWithURL:g_Download];
        req.HTTPMethod = @"POST";
        host.FillAuth(req);
        InsetHTTPHeaderPathspec(req, RelativePath());
        
        m_State = Initiated;
        
        m_DownloadTask = [session dataTaskWithRequest:req];
        [m_DownloadTask resume];
        
        // wait for initial responce from dropbox
        unique_lock<mutex> lk(m_SignalLock);
        m_Signal.wait(lk, [=]{ return m_State != Initiated; } );
        
        return m_State == Downloading ? VFSError::Ok : VFSError::GenericError;
        
    }
    if( (_open_flags & VFSFlags::OF_Write) == VFSFlags::OF_Write ) {
        auto &host = *((VFSNetDropboxHost*)Host().get());
        auto delegate = [[VFSNetDropboxFileUploadDelegate alloc] initWithFile:
                         static_pointer_cast<VFSNetDropboxFile>(shared_from_this())];
        
        auto session = [NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.defaultSessionConfiguration
                                                     delegate:delegate
                                                delegateQueue:nil];

        NSMutableURLRequest *req = [[NSMutableURLRequest alloc] initWithURL:g_Upload];
        req.HTTPMethod = @"POST";
        host.FillAuth(req);
        [req setValue:@"application/octet-stream" forHTTPHeaderField:@"Content-Type"];
        InsetHTTPHeaderPathspec(req, RelativePath());
        

//{
//    "path": "/Homework/math/Matrices.txt",
//    "mode": "add",
//    "autorename": true,
//    "mute": false
//}

//{
//    "path": "/Homework/math/Matrices.txt",
//    "mode": {
//        ".tag": "update",
//        "update": "a1c10ce0dd78"
//    },
//    "autorename": false,
//    "mute": false
//}

        m_UploadTask = [session uploadTaskWithStreamedRequest:req];
        m_UploadTaskDelegate = delegate;
        [m_UploadTask resume];
    
        this_thread::sleep_for(5s);

        return VFSError::Ok;
    }
    
    return VFSError::InvalidCall;
}

VFSNetDropboxFile::ReadParadigm VFSNetDropboxFile::GetReadParadigm() const
{
    return ReadParadigm::Sequential;
}

VFSNetDropboxFile::WriteParadigm VFSNetDropboxFile::GetWriteParadigm() const
{
    return WriteParadigm::Upload;
}

void VFSNetDropboxFile::AppendDownloadedData( NSData *_data )
{
    if(!_data ||
        _data.length == 0 ||
        m_State != Downloading ||
        m_FileSize < 0)
        return;
    
    LOCK_GUARD(m_DataLock) {
        [_data enumerateByteRangesUsingBlock:[=](const void *bytes, NSRange byteRange, BOOL *stop){
//            cout << "accepted bytes: " << byteRange.length << endl;
            m_DownloadFIFO.insert(end(m_DownloadFIFO),
                                  (const uint8_t*)bytes,
                                  (const uint8_t*)bytes + byteRange.length);
        }];
        
        if( m_DownloadFIFOOffset + m_DownloadFIFO.size() == m_FileSize )
            m_State = Completed;
    }
    
    LOCK_GUARD(m_SignalLock) {
        m_Signal.notify_all();
    }
}

bool VFSNetDropboxFile::ProcessDownloadResponse( NSURLResponse *_response )
{
    assert( m_State == Initiated );

    if( auto http_resp = objc_cast<NSHTTPURLResponse>(_response) ) {
        if( http_resp.statusCode == 200 ) {
            if( auto cl = objc_cast<NSString>(http_resp.allHeaderFields[@"Content-Length"]) ) {
                auto file_size = atol( cl.UTF8String );
                m_FileSize = file_size;
                
                m_State = Downloading;
                LOCK_GUARD(m_SignalLock) {
                    m_Signal.notify_all();
                }
                return true;
            }
        }
        else {
            NSLog(@"%@", _response);
        }
    }
    
    m_State = Canceled;
    LOCK_GUARD(m_SignalLock) {
        m_Signal.notify_all();
    }
    return false;
}

ssize_t VFSNetDropboxFile::Pos() const
{
    return 0;
}

ssize_t VFSNetDropboxFile::Size() const
{
    return m_FileSize >= 0 ? m_FileSize : VFSError::InvalidCall;
}

bool VFSNetDropboxFile::Eof() const
{
    return m_FilePos == m_FileSize;
}

ssize_t VFSNetDropboxFile::Read(void *_buf, size_t _size)
{
    if( m_State != Downloading && m_State != Completed )
        return VFSError::InvalidCall;

    if( _size == 0 )
        return 0;
    
    if( Eof() )
        return 0;
    
    do {
        LOCK_GUARD(m_DataLock) {
            if( !m_DownloadFIFO.empty() ) {
                ssize_t sz = min( _size, m_DownloadFIFO.size() );
                copy_n( begin(m_DownloadFIFO), sz, (uint8_t*)_buf );
                m_DownloadFIFO.erase( begin(m_DownloadFIFO), begin(m_DownloadFIFO) + sz );
                m_DownloadFIFOOffset += sz;
                m_FilePos += sz;
                return sz;
            }
        }
    
        unique_lock<mutex> lk(m_SignalLock);
        m_Signal.wait(lk);
    } while( m_State == Downloading || m_State == Completed );
    return VFSError::GenericError;
}

bool VFSNetDropboxFile::IsOpened() const
{
    return m_State == Downloading || m_State == Completed;
}

int VFSNetDropboxFile::PreferredIOSize() const
{
    return 32768; // packets are usually 16384 bytes long, use IO twice as long
}

int VFSNetDropboxFile::SetUploadSize(size_t _size)
{
    if( m_UploadSize >= 0 )
        return VFSError::FromErrno( EINVAL ); // already reported before
    m_UploadSize = _size;
    return VFSError::Ok;
}

ssize_t VFSNetDropboxFile::Write(const void *_buf, size_t _size)
{
    LOCK_GUARD(m_DataLock) {
        m_UploadFIFO.insert(end(m_UploadFIFO),
                            (const uint8_t*)_buf,
                            (const uint8_t*)_buf + _size);
        cout << "received " << _size << " bytes from caller" << endl;
        [m_UploadTaskDelegate notifyAboutNewData];
    }
    
    // + signal upload task about new data
    
    while( true ) {
        lock_guard<mutex> lock{m_DataLock};
        if(m_UploadFIFO.empty())
            break;
    }
    
    if( m_UploadFIFOOffset == m_UploadSize ) {
        [m_UploadTaskDelegate notifyAboutDataEnd];
    }
    
//    notifyAboutDataEnd

    return 0;
}

ssize_t VFSNetDropboxFile::FeedUploadTask( uint8_t *_buffer, size_t _sz )
{
    LOCK_GUARD(m_DataLock) {
        ssize_t sz = min( _sz, m_UploadFIFO.size() );
        copy_n( begin(m_UploadFIFO), sz, _buffer );
        m_UploadFIFO.erase( begin(m_UploadFIFO), begin(m_UploadFIFO) + sz );
        m_UploadFIFOOffset += sz;
        cout << "fed " << sz << " bytes into stream" << endl;
        return sz;
    }
    return 0;
}

bool VFSNetDropboxFile::HasDataToFeedUploadTask()
{
    bool has_data = false;
    LOCK_GUARD(m_DataLock) {
        has_data = !m_UploadFIFO.empty();
    }
    cout << "has data for stream: " << has_data << endl;
    return has_data;
}

//  if( !IsOpenedForWriting() ||
//        !m_FileBuf )
//        return VFSError::FromErrno(EIO);
//    
//    if( m_Position < m_UploadSize ) {
//        ssize_t to_write = min( m_UploadSize - m_Position, (ssize_t)_size );
//        memcpy( m_FileBuf.get() + m_Position, _buf, to_write );
//        m_Position += to_write;
//        
//        if( m_Position == m_UploadSize ) {
//            // time to flush
//
//            if( fsetxattr(m_FD, XAttrName(), m_FileBuf.get(), m_UploadSize, 0, 0) != 0 )
//                return VFSError::FromErrno();
//            
//            dynamic_pointer_cast<VFSXAttrHost>(Host())->ReportChange();
//        }
//        return to_write;
//    }
//    return 0;


//    if (context == &POSBlobInputStreamObservingContext) {
//        id newValue = [change objectForKey:NSKeyValueChangeNewKey];
//        if ([keyPath isEqualToString:POSBlobInputStreamDataSourceOpenCompletedKeyPath] && [newValue boolValue]) {
//            [self setStatus:NSStreamStatusOpen];
//            [self enqueueEvent:NSStreamEventOpenCompleted];
//        } else if ([keyPath isEqualToString:POSBlobInputStreamDataSourceHasBytesAvailableKeyPath] && [newValue boolValue]) {
//            [self enqueueEvent:NSStreamEventHasBytesAvailable];
//        } else if ([keyPath isEqualToString:POSBlobInputStreamDataSourceAtEndKeyPath] && [newValue boolValue]) {
//            [self setStatus:NSStreamStatusAtEnd];
//            [self enqueueEvent:NSStreamEventEndEncountered];
//        } else if ([keyPath isEqualToString:POSBlobInputStreamDataSourceErrorKeyPath] && newValue != nil) {
//            [self setError:newValue];
//        }

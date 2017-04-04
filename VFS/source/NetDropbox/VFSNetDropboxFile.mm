#include "VFSNetDropboxFile.h"
#include "Aux.h"

using namespace VFSNetDropbox;

static const auto g_Download = [NSURL URLWithString:@"https://content.dropboxapi.com/2/files/download"];


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

//As with content-upload endpoints, arguments are passed in the Dropbox-API-Arg request header or arg URL parameter.
//The response body contains file content, so the result will appear as JSON in the Dropbox-API-Result response header.
//These endpoints are also on the content.dropboxapi.com domain.

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
    }

    return 0;
}

int VFSNetDropboxFile::Open(int _open_flags, VFSCancelChecker _cancel_checker)
{
    if( (_open_flags & VFSFlags::OF_Read) != VFSFlags::OF_Read )
        return VFSError::InvalidCall;
    auto &host = *((VFSNetDropboxHost*)Host().get());

    auto delegate = [[VFSNetDropboxFileDownloadDelegate alloc] initWithFile:
        static_pointer_cast<VFSNetDropboxFile>(shared_from_this())];
    auto session = [NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.defaultSessionConfiguration
                                                 delegate:delegate
                                            delegateQueue:nil];

    NSMutableURLRequest *req = [[NSMutableURLRequest alloc] initWithURL:g_Download];
    req.HTTPMethod = @"POST";
    [req setValue:[NSString stringWithFormat:@"Bearer %s", host.Token().c_str()]
        forHTTPHeaderField:@"Authorization"];
    
    const string path_spec = "{ \"path\": \"" + EscapeStringForJSONInHTTPHeader(RelativePath()) + "\" }";
    [req setValue:[NSString stringWithUTF8String:path_spec.c_str()]
        forHTTPHeaderField:@"Dropbox-API-Arg"];
    
    
    m_State = Initiated;
    
    m_DownloadTask = [session dataTaskWithRequest:req];
    [m_DownloadTask resume];

    // wait for initial responce from dropbox
    unique_lock<mutex> lk(m_SignalLock);
    m_Signal.wait(lk, [=]{ return m_State != Initiated; } );
    
    return m_State == Downloading ? VFSError::Ok : VFSError::GenericError;
}

VFSNetDropboxFile::ReadParadigm VFSNetDropboxFile::GetReadParadigm() const
{
    return ReadParadigm::Sequential;
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
                                  ((const uint8_t*)bytes) + byteRange.length);
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
            if( auto cl =  objc_cast<NSString>(http_resp.allHeaderFields[@"Content-Length"]) ) {
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
    return 32768; // packets are usually 16384 bytes long, use IO twice long
}

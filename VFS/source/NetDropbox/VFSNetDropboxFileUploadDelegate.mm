#include <VFS/VFSError.h>
#include "VFSNetDropboxFileUploadDelegate.h"
#include "VFSNetDropboxFileUploadStream.h"


@implementation VFSNetDropboxFileUploadDelegate
{
    VFSNetDropboxFileUploadStream *m_Stream;
    mutex m_CallbacksLock;
    function<void(int _vfs_error)> m_HandleFinished;
}

- (instancetype)initWithStream:(VFSNetDropboxFileUploadStream*)_stream
{
    if( self = [super init] ) {
        m_Stream = _stream;
    }
    return self;
}

- (void) setHandleFinished:(function<void(int)>)handleFinished
{
    lock_guard<mutex> lock{m_CallbacksLock};
    m_HandleFinished = handleFinished;
}

- (function<void(int)>)handleFinished
{
    lock_guard<mutex> lock{m_CallbacksLock};
    return m_HandleFinished;
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
                              needNewBodyStream:(void (^)(NSInputStream * _Nullable bodyStream))completionHandler
{
    completionHandler(m_Stream);
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
                                didSendBodyData:(int64_t)bytesSent
                                 totalBytesSent:(int64_t)totalBytesSent
                       totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend
{
    cout << "didSendBodyData: " << bytesSent
         << ", totalBytesSent: " << totalBytesSent
         << ", totalBytesExpectedToSend: " << totalBytesExpectedToSend << endl;
}

- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(nullable NSError *)error
{
    cout << "didBecomeInvalidWithError" << endl;
    
    // TODO: proper error handling
    LOCK_GUARD(m_CallbacksLock) {
        if( m_HandleFinished )
            m_HandleFinished(VFSError::FromErrno(EIO));
    }
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

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
                                 didReceiveResponse:(NSURLResponse *)response
                                  completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler
{
    int vfs_errc = [&]()->int{
        if( auto http_resp = objc_cast<NSHTTPURLResponse>(response) )
            if( http_resp.statusCode == 200 )
                return VFSError::Ok;
        
        // TODO: proper error handling
        return VFSError::FromErrno(EIO);
    }();

    LOCK_GUARD(m_CallbacksLock) {
        if( m_HandleFinished )
            m_HandleFinished(vfs_errc);
    }
    
    completionHandler( vfs_errc == VFSError::Ok ?
        NSURLSessionResponseAllow :
        NSURLSessionResponseCancel );
}

@end


#include "VFSNetDropboxFileDownloadDelegate.h"
#include <VFS/VFSError.h>

@implementation VFSNetDropboxFileDownloadDelegate
{
    mutex                                   m_CallbacksLock;
    function<bool(ssize_t _size_or_error)>  m_ResponseHandler;
    function<void(NSData*)>                 m_DataHandler;
}

- (void)setHandleResponse:(function<bool (ssize_t)>)handleResponse
{
    lock_guard<mutex> lock{m_CallbacksLock};
    m_ResponseHandler = handleResponse;
}

- (function<bool (ssize_t)>)handleResponse
{
    lock_guard<mutex> lock{m_CallbacksLock};
    return m_ResponseHandler;
}

- (void) setHandleData:(function<void (NSData *)>)handleData
{
    lock_guard<mutex> lock{m_CallbacksLock};
    m_DataHandler = handleData;
}

- (function<void (NSData *)>)handleData
{
    lock_guard<mutex> lock{m_CallbacksLock};
    return m_DataHandler;
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
//    if( auto file = m_File.lock() )
//        file->AppendDownloadedData(data);
    LOCK_GUARD(m_CallbacksLock) {
        if( m_DataHandler )
            m_DataHandler(data);
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
                                 didReceiveResponse:(NSURLResponse *)response
                                  completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler
{
    ssize_t size = VFSError::FromErrno(EIO);
    if( auto http_resp = objc_cast<NSHTTPURLResponse>(response) )
        if( http_resp.statusCode == 200 )
            if( auto length_string = objc_cast<NSString>(http_resp.allHeaderFields[@"Content-Length"]) )
                if( auto length = atol( length_string.UTF8String ); length >= 0 )
                    size = length;

    // TODO: proper errors handling
    
    cout << "didReceiveResponse" << endl;
    
    bool permit = false;
    LOCK_GUARD(m_CallbacksLock) {
        if( m_ResponseHandler )
            permit = m_ResponseHandler(size);
    }
    
    completionHandler( permit ?  NSURLSessionResponseAllow : NSURLSessionResponseCancel );
}
                                
@end


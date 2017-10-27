// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "FileDownloadDelegate.h"
#include <VFS/VFSError.h>
#include "Aux.h"

using namespace nc::vfs;
using namespace nc::vfs::dropbox;

@implementation NCVFSDropboxFileDownloadDelegate
{
    mutex                                   m_CallbacksLock;
    function<void(ssize_t _size_or_error)>  m_ResponseHandler;
    function<void(NSData*)>                 m_DataHandler;
    function<void(int)>                     m_ErrorHandler;
}

- (void)setHandleError:(function<void (int)>)handleError
{
    lock_guard<mutex> lock{m_CallbacksLock};
    m_ErrorHandler = handleError;
}

- (function<void (int)>)handleError
{
    lock_guard<mutex> lock{m_CallbacksLock};
    return m_ErrorHandler;
}

- (void)setHandleResponse:(function<void(ssize_t)>)handleResponse
{
    lock_guard<mutex> lock{m_CallbacksLock};
    m_ResponseHandler = handleResponse;
}

- (function<void(ssize_t)>)handleResponse
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

- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(nullable NSError *)_error
{
    auto error = VFSErrorFromErrorAndReponseAndData(_error, nil, nil);
    lock_guard<mutex> lock{m_CallbacksLock};
    if( m_ErrorHandler )
        m_ErrorHandler(error);
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
                           didCompleteWithError:(nullable NSError *)_error
{
    if( _error ) {
        auto error = VFSErrorFromErrorAndReponseAndData(_error, nil, nil);
        lock_guard<mutex> lock{m_CallbacksLock};
        if( m_ErrorHandler )
            m_ErrorHandler(error);
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task
                                     didReceiveData:(NSData *)data
{
    if( auto response = objc_cast<NSHTTPURLResponse>(task.response) )
        if( response.statusCode == 200 ) {
            lock_guard<mutex> lock{m_CallbacksLock};
            if( m_DataHandler )
                m_DataHandler(data);
            return;
        }
    
    auto error = VFSErrorFromErrorAndReponseAndData(nil, task.response, data);
    lock_guard<mutex> lock{m_CallbacksLock};
    if( m_ErrorHandler )
        m_ErrorHandler(error);
}

static long ExtractContentLengthFromResponse(NSURLResponse *_response)
{
    auto response = objc_cast<NSHTTPURLResponse>(_response);
    if( !response )
        return -1;
    
    if( response.statusCode != 200 )
        return -1;
    
    auto length_string = objc_cast<NSString>(response.allHeaderFields[@"Content-Length"]);
    if( !length_string )
        return -1;
    
    auto length = atol( length_string.UTF8String );
    return length >= 0 ? length : -1;
}

- (void)URLSession:(NSURLSession *)session
    dataTask:(NSURLSessionDataTask *)task
    didReceiveResponse:(NSURLResponse *)response
    completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler
{
    if( auto l = ExtractContentLengthFromResponse(response); l >= 0 ) {
        lock_guard<mutex> lock{m_CallbacksLock};
        if( m_ResponseHandler )
            m_ResponseHandler(l);
    }
    completionHandler( NSURLSessionResponseAllow );
}
                                
@end


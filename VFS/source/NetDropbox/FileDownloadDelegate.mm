// Copyright (C) 2017-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "FileDownloadDelegate.h"
#include <VFS/VFSError.h>
#include "Aux.h"
#include <mutex>
#include <Utility/ObjCpp.h>

using namespace nc::vfs;
using namespace nc::vfs::dropbox;

@implementation NCVFSDropboxFileDownloadDelegate
{
    std::mutex                                   m_CallbacksLock;
    std::function<void(ssize_t _size_or_error)>  m_ResponseHandler;
    std::function<void(NSData*)>                 m_DataHandler;
    std::function<void(int)>                     m_ErrorHandler;
}

- (void)setHandleError:(std::function<void (int)>)handleError
{
    std::lock_guard<std::mutex> lock{m_CallbacksLock};
    m_ErrorHandler = handleError;
}

- (std::function<void (int)>)handleError
{
    std::lock_guard<std::mutex> lock{m_CallbacksLock};
    return m_ErrorHandler;
}

- (void)setHandleResponse:(std::function<void(ssize_t)>)handleResponse
{
    std::lock_guard<std::mutex> lock{m_CallbacksLock};
    m_ResponseHandler = handleResponse;
}

- (std::function<void(ssize_t)>)handleResponse
{
    std::lock_guard<std::mutex> lock{m_CallbacksLock};
    return m_ResponseHandler;
}

- (void) setHandleData:(std::function<void (NSData *)>)handleData
{
    std::lock_guard<std::mutex> lock{m_CallbacksLock};
    m_DataHandler = handleData;
}

- (std::function<void (NSData *)>)handleData
{
    std::lock_guard<std::mutex> lock{m_CallbacksLock};
    return m_DataHandler;
}

- (void)URLSession:(NSURLSession *)[[maybe_unused]]session
didBecomeInvalidWithError:(nullable NSError *)_error
{
    auto error = VFSErrorFromErrorAndReponseAndData(_error, nil, nil);
    std::lock_guard<std::mutex> lock{m_CallbacksLock};
    if( m_ErrorHandler )
        m_ErrorHandler(error);
}

- (void)URLSession:(NSURLSession *)[[maybe_unused]]session
task:(NSURLSessionTask *)[[maybe_unused]]task
didCompleteWithError:(nullable NSError *)_error
{
    if( _error ) {
        auto error = VFSErrorFromErrorAndReponseAndData(_error, nil, nil);
        std::lock_guard<std::mutex> lock{m_CallbacksLock};
        if( m_ErrorHandler )
            m_ErrorHandler(error);
    }
}

- (void)URLSession:(NSURLSession *)[[maybe_unused]]session
dataTask:(NSURLSessionDataTask *)task
didReceiveData:(NSData *)data
{
    if( auto response = objc_cast<NSHTTPURLResponse>(task.response) )
        if( response.statusCode == 200 ) {
            std::lock_guard<std::mutex> lock{m_CallbacksLock};
            if( m_DataHandler )
                m_DataHandler(data);
            return;
        }
    
    auto error = VFSErrorFromErrorAndReponseAndData(nil, task.response, data);
    std::lock_guard<std::mutex> lock{m_CallbacksLock};
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

- (void)URLSession:(NSURLSession *)[[maybe_unused]]session
    dataTask:(NSURLSessionDataTask *)[[maybe_unused]]task
    didReceiveResponse:(NSURLResponse *)response
    completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler
{
    if( auto l = ExtractContentLengthFromResponse(response); l >= 0 ) {
        std::lock_guard<std::mutex> lock{m_CallbacksLock};
        if( m_ResponseHandler )
            m_ResponseHandler(l);
    }
    completionHandler( NSURLSessionResponseAllow );
}
                                
@end


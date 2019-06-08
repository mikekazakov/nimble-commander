// Copyright (C) 2017-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include <VFS/VFSError.h>
#include "FileUploadDelegate.h"
#include "Aux.h"
#include <mutex>
#include <Utility/ObjCpp.h>

using namespace nc::vfs;
using namespace nc::vfs::dropbox;

@implementation NCVFSDropboxFileUploadDelegate
{
    NSInputStream  *m_Stream;
    std::mutex                           m_CallbacksLock;
    std::function<void(int _vfs_error)>  m_HandleFinished;
    std::function<void(NSData *_data)>   m_HandleReceivedData;
}

- (instancetype)initWithStream:(NSInputStream*)_stream
{
    if( self = [super init] ) {
        assert(_stream);
        m_Stream = _stream;
    }
    return self;
}

- (void)setHandleReceivedData:(std::function<void (NSData *)>)handleReceivedData
{
    std::lock_guard<std::mutex> lock{m_CallbacksLock};
    m_HandleReceivedData = handleReceivedData;
}

- (std::function<void (NSData *)>)handleReceivedData
{
   std::lock_guard<std::mutex> lock{m_CallbacksLock};
   return m_HandleReceivedData;
}

- (void) setHandleFinished:(std::function<void(int)>)handleFinished
{
    std::lock_guard<std::mutex> lock{m_CallbacksLock};
    m_HandleFinished = handleFinished;
}

- (std::function<void(int)>)handleFinished
{
    std::lock_guard<std::mutex> lock{m_CallbacksLock};
    return m_HandleFinished;
}

- (void)URLSession:(NSURLSession *)[[maybe_unused]]_session
              task:(NSURLSessionTask *)[[maybe_unused]]_task
 needNewBodyStream:(void (^)(NSInputStream * _Nullable bodyStream))_handler
{
    _handler(m_Stream);
}

- (void)URLSession:(NSURLSession *)[[maybe_unused]]session
didBecomeInvalidWithError:(nullable NSError *)_error
{
    auto error = VFSErrorFromErrorAndReponseAndData(_error, nil, nil);
    std::lock_guard<std::mutex> lock{m_CallbacksLock};
    if( m_HandleFinished )
        m_HandleFinished(error);
}

static bool HasNoError(NSURLResponse *_response)
{
    if( auto http_resp = objc_cast<NSHTTPURLResponse>(_response) )
        if( http_resp.statusCode == 200 )
            return true;
    return false;
}

- (void)URLSession:(NSURLSession *)[[maybe_unused]]session
    task:(NSURLSessionTask *)_task
    didCompleteWithError:(nullable NSError *)_error
{
    if( !_error && HasNoError(_task.response) ) {
        std::lock_guard<std::mutex> lock{m_CallbacksLock};
        if( m_HandleFinished )
            m_HandleFinished(VFSError::Ok);
    }
    else {
        auto error = VFSErrorFromErrorAndReponseAndData(_error, _task.response, nil);
        std::lock_guard<std::mutex> lock{m_CallbacksLock};
        if( m_HandleFinished )
            m_HandleFinished(error);
    }
}

- (void)URLSession:(NSURLSession *)[[maybe_unused]]_session
          dataTask:(NSURLSessionDataTask *)_task
    didReceiveData:(NSData *)_data
{
    if( HasNoError(_task.response) ) {
        std::lock_guard<std::mutex> lock{m_CallbacksLock};
        if( m_HandleReceivedData )
            m_HandleReceivedData(_data);
    }
    else {
        auto error = VFSErrorFromErrorAndReponseAndData(nil, _task.response, _data);
        std::lock_guard<std::mutex> lock{m_CallbacksLock};
        if( m_HandleFinished )
            m_HandleFinished(error);
    }
}

@end


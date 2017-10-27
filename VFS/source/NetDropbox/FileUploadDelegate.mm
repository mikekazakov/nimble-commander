// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include <VFS/VFSError.h>
#include "FileUploadDelegate.h"
#include "Aux.h"

using namespace nc::vfs;
using namespace nc::vfs::dropbox;

@implementation NCVFSDropboxFileUploadDelegate
{
    NSInputStream  *m_Stream;
    mutex                           m_CallbacksLock;
    function<void(int _vfs_error)>  m_HandleFinished;
    function<void(NSData *_data)>   m_HandleReceivedData;
}

- (instancetype)initWithStream:(NSInputStream*)_stream
{
    if( self = [super init] ) {
        assert(_stream);
        m_Stream = _stream;
    }
    return self;
}

- (void)setHandleReceivedData:(function<void (NSData *)>)handleReceivedData
{
    lock_guard<mutex> lock{m_CallbacksLock};
    m_HandleReceivedData = handleReceivedData;
}

- (function<void (NSData *)>)handleReceivedData
{
   lock_guard<mutex> lock{m_CallbacksLock};
   return m_HandleReceivedData;
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

- (void)URLSession:(NSURLSession *)_session
              task:(NSURLSessionTask *)_task
 needNewBodyStream:(void (^)(NSInputStream * _Nullable bodyStream))_handler
{
    _handler(m_Stream);
}

- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(nullable NSError *)_error
{
    auto error = VFSErrorFromErrorAndReponseAndData(_error, nil, nil);
    lock_guard<mutex> lock{m_CallbacksLock};
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

- (void)URLSession:(NSURLSession *)session
    task:(NSURLSessionTask *)_task
    didCompleteWithError:(nullable NSError *)_error
{
    if( !_error && HasNoError(_task.response) ) {
        lock_guard<mutex> lock{m_CallbacksLock};
        if( m_HandleFinished )
            m_HandleFinished(VFSError::Ok);
    }
    else {
        auto error = VFSErrorFromErrorAndReponseAndData(_error, _task.response, nil);
        lock_guard<mutex> lock{m_CallbacksLock};
        if( m_HandleFinished )
            m_HandleFinished(error);
    }
}

- (void)URLSession:(NSURLSession *)_session
          dataTask:(NSURLSessionDataTask *)_task
    didReceiveData:(NSData *)_data
{
    if( HasNoError(_task.response) ) {
        lock_guard<mutex> lock{m_CallbacksLock};
        if( m_HandleReceivedData )
            m_HandleReceivedData(_data);
    }
    else {
        auto error = VFSErrorFromErrorAndReponseAndData(nil, _task.response, _data);
        lock_guard<mutex> lock{m_CallbacksLock};
        if( m_HandleFinished )
            m_HandleFinished(error);
    }
}

@end


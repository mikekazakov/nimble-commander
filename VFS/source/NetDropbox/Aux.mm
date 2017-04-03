#include <Cocoa/Cocoa.h>
#include "Aux.h"

namespace VFSNetDropbox {

NSData *SendSynchonousRequest(NSURLSession *_session,
                              NSURLRequest *_request,
                              __autoreleasing NSURLResponse **_response_ptr,
                              __autoreleasing NSError **_error_ptr)
{
    dispatch_semaphore_t    sem;
    __block NSData *        result;
    
    result = nil;
    
    sem = dispatch_semaphore_create(0);
    
    NSURLSessionDataTask *task =
    [_session dataTaskWithRequest:_request
                completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                    if( _error_ptr != nullptr ) {
                        *_error_ptr = error;
                    }
                    if( _response_ptr != nullptr ) {
                        *_response_ptr = response;
                    }
                    if( error == nil ) {
                        result = data;
                    }
                    dispatch_semaphore_signal(sem);
                }];
    
    [task resume];
    
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    
    return result;
}


}


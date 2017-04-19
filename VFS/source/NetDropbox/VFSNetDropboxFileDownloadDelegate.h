#pragma once

@interface VFSNetDropboxFileDownloadDelegate : NSObject<NSURLSessionDelegate>

// non-reentrant callbacks, don't change them when upon execution
@property (nonatomic) function<bool(ssize_t _size_or_error)>    handleResponse;
@property (nonatomic) function<void(NSData*)>                   handleData;

@end

#pragma once

@class VFSNetDropboxFileUploadStream;

@interface VFSNetDropboxFileUploadDelegate : NSObject<NSURLSessionDelegate>

- (instancetype)initWithStream:(VFSNetDropboxFileUploadStream*)_stream;

// non-reentrant callbacks, don't change them when upon execution
@property (nonatomic) function<void(int _vfs_error)> handleFinished;
@property (nonatomic) function<void(NSData *_data)> handleReceivedData;

@end

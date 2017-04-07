#pragma once

@class VFSNetDropboxFileUploadStream;

@interface VFSNetDropboxFileUploadDelegate : NSObject<NSURLSessionDelegate>

- (instancetype)initWithStream:(VFSNetDropboxFileUploadStream*)_stream;

// non reentrant callback, don't change it when upon execution
@property (nonatomic) function<void(int _vfs_error)> handleFinished;

@end

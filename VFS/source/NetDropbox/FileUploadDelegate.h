// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

@interface NCVFSDropboxFileUploadDelegate : NSObject<NSURLSessionDelegate>

- (instancetype)initWithStream:(NSInputStream*)_stream;

// non-reentrant callbacks, don't change them when upon execution
@property (nonatomic) function<void(int _vfs_error)> handleFinished;
@property (nonatomic) function<void(NSData *_data)> handleReceivedData;

@end

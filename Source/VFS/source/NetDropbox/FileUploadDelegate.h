// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Foundation/Foundation.h>
#include <functional>

@interface NCVFSDropboxFileUploadDelegate : NSObject<NSURLSessionDelegate>

- (instancetype)initWithStream:(NSInputStream*)_stream;

// non-reentrant callbacks, don't change them when upon execution
@property (nonatomic) std::function<void(int _vfs_error)> handleFinished;
@property (nonatomic) std::function<void(NSData *_data)> handleReceivedData;

@end

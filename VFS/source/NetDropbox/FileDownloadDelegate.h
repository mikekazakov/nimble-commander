// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Foundation/Foundation.h>
#include <functional>

@interface NCVFSDropboxFileDownloadDelegate : NSObject<NSURLSessionDelegate>

// non-reentrant callbacks, don't change them when upon execution
@property (nonatomic) std::function<void(ssize_t _size_or_error)>    handleResponse;
@property (nonatomic) std::function<void(int)>                       handleError;
@property (nonatomic) std::function<void(NSData*)>                   handleData;

@end

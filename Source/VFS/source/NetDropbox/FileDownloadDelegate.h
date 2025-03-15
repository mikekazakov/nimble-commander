// Copyright (C) 2017-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Foundation/Foundation.h>
#include <Base/Error.h>
#include <functional>

@interface NCVFSDropboxFileDownloadDelegate : NSObject <NSURLSessionDelegate>

// non-reentrant callbacks, don't change them when upon execution
@property(nonatomic) std::function<void(size_t _size)> handleResponse;
@property(nonatomic) std::function<void(nc::Error)> handleError;
@property(nonatomic) std::function<void(NSData *)> handleData;

@end

// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

@interface NCVFSDropboxFileDownloadDelegate : NSObject<NSURLSessionDelegate>

// non-reentrant callbacks, don't change them when upon execution
@property (nonatomic) function<void(ssize_t _size_or_error)>    handleResponse;
@property (nonatomic) function<void(int)>                       handleError;
@property (nonatomic) function<void(NSData*)>                   handleData;

@end

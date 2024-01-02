// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Foundation/Foundation.h>
#include <functional>

@interface NCVFSDropboxFileUploadStream : NSInputStream

// stream -> client connection, called from some background thread.
// NOT REENTRANT!
// client musn't change callbacks while they are being called, this will deadlock.
@property (nonatomic) std::function<ssize_t(uint8_t *_buffer, size_t _sz)> feedData;
@property (nonatomic) std::function<bool()> hasDataToFeed;

// client -> stream connection, called from client's thread.
- (void)notifyAboutNewData;
- (void)notifyAboutDataEnd;

@end

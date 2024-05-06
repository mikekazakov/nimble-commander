// Copyright (C) 2021 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>
#include <memory>

namespace nc::vfs::dropbox {

class URLSessionCreator
{
public:
    virtual ~URLSessionCreator() = default;
    virtual NSURLSession *CreateSession(NSURLSessionConfiguration *configuration) = 0;
    virtual NSURLSession *CreateSession(NSURLSessionConfiguration *_configuration,
                                        id<NSURLSessionDelegate> _delegate,
                                        NSOperationQueue *_queue) = 0;
};

class URLSessionFactory : public URLSessionCreator
{
public:
    static URLSessionFactory &DefaultFactory();
    NSURLSession *CreateSession(NSURLSessionConfiguration *configuration) override;
    NSURLSession *CreateSession(NSURLSessionConfiguration *_configuration,
                                id<NSURLSessionDelegate> _delegate,
                                NSOperationQueue *_queue) override;
};

} // namespace nc::vfs::dropbox

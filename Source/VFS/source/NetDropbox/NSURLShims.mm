// Copyright (C) 2021 Michael Kazakov. Subject to GNU General Public License version 3.
#include "NSURLShims.h"

namespace nc::vfs::dropbox {

URLSessionFactory &URLSessionFactory::DefaultFactory()
{
    [[clang::no_destroy]] static URLSessionFactory factory;
    return factory;
}

NSURLSession *URLSessionFactory::CreateSession(NSURLSessionConfiguration *_configuration)
{
    return [NSURLSession sessionWithConfiguration:_configuration];
}

NSURLSession *URLSessionFactory::CreateSession(NSURLSessionConfiguration *_configuration,
                                               id<NSURLSessionDelegate> _delegate,
                                               NSOperationQueue *_queue)
{
    return [NSURLSession sessionWithConfiguration:_configuration delegate:_delegate delegateQueue:_queue];
}

} // namespace nc::vfs::dropbox

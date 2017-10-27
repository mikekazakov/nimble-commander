// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#import <AppAuth.h>

@interface OIDRedirectHTTPHandler(FixedPort)

- (NSURL *)startHTTPListenerForPort:(uint16_t)port error:(NSError **)returnError;

@end

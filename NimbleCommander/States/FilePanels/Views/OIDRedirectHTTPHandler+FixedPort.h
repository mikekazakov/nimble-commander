#pragma once

#import <AppAuth.h>

@interface OIDRedirectHTTPHandler(FixedPort)

- (NSURL *)startHTTPListenerForPort:(uint16_t)port error:(NSError **)returnError;

@end

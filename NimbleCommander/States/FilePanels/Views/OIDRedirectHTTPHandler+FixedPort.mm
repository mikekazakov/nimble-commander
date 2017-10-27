// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "OIDRedirectHTTPHandler+FixedPort.h"
#import <macOS/OIDRedirectHTTPHandler.h>
#import "OIDAuthorizationService.h"
#import "OIDErrorUtilities.h"
#import <macOS/LoopbackHTTPServer/OIDLoopbackHTTPServer.h>

@implementation OIDRedirectHTTPHandler(FixedPort)

- (NSURL *)startHTTPListenerForPort:(uint16_t)port error:(NSError **)returnError
{
  // Cancels any pending requests.
  [self cancelHTTPListener];

  // Starts a HTTP server on the loopback interface.
  // By not specifying a port, a random available one will be assigned.
  _httpServ = [[HTTPServer alloc] init];
  [_httpServ setDelegate:self];
  if (port)
    [_httpServ setPort:port];
  NSError *error = nil;
  if (![_httpServ start:&error]) {
    if (returnError) {
      *returnError = error;
    }
    return nil;
  } else {
    NSString *serverURL = [NSString stringWithFormat:@"http://127.0.0.1:%d/", [_httpServ port]];
    return [NSURL URLWithString:serverURL];
  }
}

@end

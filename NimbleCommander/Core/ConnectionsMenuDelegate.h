#pragma once

class NetworkConnectionsManager;

@interface ConnectionsMenuDelegate : NSObject<NSMenuDelegate>

- (instancetype) initWithManager:(function<NetworkConnectionsManager&()>)_callback;

@end

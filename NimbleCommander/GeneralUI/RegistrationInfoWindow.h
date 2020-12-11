// Copyright (C) 2016-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

namespace nc::bootstrap {
class ActivationManager;
}

@interface RegistrationInfoWindow : NSWindowController

- (instancetype) init NS_UNAVAILABLE;
- (instancetype) initWithActivationManager:(nc::bootstrap::ActivationManager&)_am;

@end

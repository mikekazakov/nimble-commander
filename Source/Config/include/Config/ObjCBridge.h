// Copyright (C) 2015-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "Config.h"
#include <Foundation/Foundation.h>

/**
 * NCConfigObjCBridge provides a KVC-complaint ObjectiveC bridge to the nc::config::Confg.
 * The class is not KVO-complaint.
 */
@interface NCConfigObjCBridge : NSObject 

- (instancetype _Nonnull) init NS_UNAVAILABLE;
- (instancetype _Nonnull) initWithConfig:(nc::config::Config&)_config;

- (id _Nullable) valueForKeyPath:(nullable NSString *)_key_path;
- (void) setValue:(nullable id)_value forKeyPath:(nullable NSString *)_key_path;

@end

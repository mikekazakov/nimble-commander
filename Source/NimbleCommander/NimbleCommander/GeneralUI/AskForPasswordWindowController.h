// Copyright (C) 2016-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <string>

/**
 * Returns true if user clicked Ok, false otherwise.
 */
bool RunAskForPasswordModalWindow( const std::string& _password_for, std::string &_passwd );

#ifdef __OBJC__

#include <Cocoa/Cocoa.h>

@interface AskForPasswordWindowController : NSWindowController

- (id)initWithResourceName:(NSString *)_name;

@property (readonly) NSString *enteredPasswd;

@end

#endif

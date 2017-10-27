// Copyright (C) 2016 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

/**
 * Returns true if user clicked Ok, false otherwise.
 */
bool RunAskForPasswordModalWindow( const string& _password_for, string &_passwd );

#ifdef __OBJC__

@interface AskForPasswordWindowController : NSWindowController

- (id)initWithResourceName:(NSString *)_name;

@property (readonly) NSString *enteredPasswd;

@end

#endif

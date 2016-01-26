//
//  AskForPasswordWindowController.h
//  Files
//
//  Created by Michael G. Kazakov on 26/01/16.
//  Copyright © 2016 Michael G. Kazakov. All rights reserved.
//

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

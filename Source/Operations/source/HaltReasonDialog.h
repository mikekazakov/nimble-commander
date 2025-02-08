// Copyright (C) 2017-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#import <Cocoa/Cocoa.h>
#import <Base/Error.h>

@interface NCOpsHaltReasonDialog : NSWindowController

- (instancetype)init;

@property(nonatomic) NSString *message;
@property(nonatomic) NSString *path;

- (void)setErrorNo:(int)_errorNo;
- (void)setError:(nc::Error)_error;

@end

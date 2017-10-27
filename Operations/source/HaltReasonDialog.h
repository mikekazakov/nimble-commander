// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#import <Cocoa/Cocoa.h>

@interface NCOpsHaltReasonDialog : NSWindowController

- (instancetype)init;

@property (nonatomic) NSString* message;
@property (nonatomic) NSString* path;
@property (nonatomic) NSString* error;
@property (nonatomic) int errorNo;

@end

// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#include <Cocoa/Cocoa.h>

@interface AttachedResponder : NSResponder


- (AttachedResponder*)nextAttachedResponder;

- (void)setNextResponder:(NSResponder *)nextResponder;
- (void)setNextAttachedResponder:(AttachedResponder *)nextAttachedResponder;

@end

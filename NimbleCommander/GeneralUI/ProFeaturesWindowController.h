// Copyright (C) 2016 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

@interface ProFeaturesWindowController : NSWindowController
@property (nonatomic) bool              suppressDontShowAgain;
@property (nonatomic, readonly) bool    dontShowAgain;

@end

// Copyright (C) 2022 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>
#include <Base/SpdlogFacade.h>
#include <span>

@interface NCSpdLogWindowController : NSWindowController <NSWindowDelegate, NSTextViewDelegate>

- (instancetype)initWithLogs:(std::span<nc::base::SpdLogger *const>)_loggers;

@end

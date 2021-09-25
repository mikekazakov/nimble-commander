// Copyright (C) 2021 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#include <Utility/SheetController.h>
#import <Cocoa/Cocoa.h>
#include <string>

NS_ASSUME_NONNULL_BEGIN

@interface PreferencesWindowPanelsTabOperationsConcurrencySheet : SheetController

- (instancetype)initWithConcurrencyExclusionList:(const std::string &)_list;

@property(readonly, nonatomic) const std::string &exclusionList;

@end

NS_ASSUME_NONNULL_END

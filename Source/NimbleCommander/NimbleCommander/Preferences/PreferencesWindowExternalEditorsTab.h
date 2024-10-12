// Copyright (C) 2014-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#include <Cocoa/Cocoa.h>
#include <swiftToCxx/_SwiftCxxInteroperability.h>
#include <NimbleCommanderCommon-Swift.h>

class ExternalEditorsStorage;

@interface PreferencesWindowExternalEditorsTab
    : NSViewController <PreferencesViewControllerProtocol, NSTableViewDataSource>

- (instancetype)initWithEditorsStorage:(ExternalEditorsStorage &)_storage;

@end

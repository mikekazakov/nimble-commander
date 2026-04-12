// Copyright (C) 2016-2026 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// One visible crumb in the path bar (title + optional navigation target).
@interface NCPanelPathSegment : NSObject
@property(nonatomic, copy) NSString *title;
/// If set, segment is a link to this absolute POSIX path (starts with '/').
@property(nonatomic, copy, nullable) NSString *navigatePOSIXPath;
@property(nonatomic) BOOL isCurrentDirectory;
@end

NS_ASSUME_NONNULL_END

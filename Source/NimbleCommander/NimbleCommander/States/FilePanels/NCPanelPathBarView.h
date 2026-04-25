// Copyright (C) 2016-2026 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#import <Cocoa/Cocoa.h>

@class NCPanelBreadcrumbsView;

NS_ASSUME_NONNULL_BEGIN

@interface NCPanelPathBarView : NSView <NSTextViewDelegate>
@property(nonatomic, readonly) NCPanelBreadcrumbsView *breadcrumbsView;
@property(nonatomic, readonly) NSTextView *pathTextView;
@property(nonatomic) bool fullPathSelectionActive;

@property(nonatomic, copy, nullable) void (^onCancelFullPathSelection)(void);

- (void)enterFullPathSelectionWithString:(NSString *)path font:(NSFont *)font textColor:(NSColor *)textColor;
- (void)exitFullPathSelection;
- (void)syncPathTextViewVerticalAlignmentWithFont:(NSFont *)font;
@end

NS_ASSUME_NONNULL_END

// Copyright (C) 2016-2026 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#import <Cocoa/Cocoa.h>

@class NCPanelBreadcrumbsView;

NS_ASSUME_NONNULL_BEGIN

@interface NCPanelPathBarView : NSView <NSTextFieldDelegate>
@property(nonatomic, readonly) NCPanelBreadcrumbsView *breadcrumbsView;
@property(nonatomic, readonly) NSTextField *pathEditField;
@property(nonatomic) BOOL fullPathEditActive;

@property(nonatomic, copy, nullable) void (^onCommitEditedPath)(NSString *path);
@property(nonatomic, copy, nullable) void (^onCancelFullPathEdit)(void);

- (void)enterFullPathEditWithString:(NSString *)path font:(NSFont *)font textColor:(NSColor *)textColor;
- (void)exitFullPathEdit;
/// Keeps single-line path field aligned with drawn breadcrumbs when theme font changes during edit.
- (void)syncPathEditFieldVerticalAlignmentWithFont:(NSFont *)font;
@end

NS_ASSUME_NONNULL_END

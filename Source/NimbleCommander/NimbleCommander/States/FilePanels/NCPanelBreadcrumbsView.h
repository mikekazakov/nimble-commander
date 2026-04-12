// Copyright (C) 2016-2026 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#import <Cocoa/Cocoa.h>

@class NCPanelBreadcrumbsView;
@class NCPanelPathSegment;

/// Upward shift (points) so glyph ink aligns with tab/header labels; linear in (lineHeight − capHeight).
FOUNDATION_EXTERN CGFloat NCPanelPathBarOpticalShiftUp(NSFont *_Nullable font, CGFloat lineBoxHeight);

/// Text-container Y origin for one TextKit line (`used` height / origin.y) in a strip; geometric center minus optical
/// shift, clamped when the line is taller than the strip.
FOUNDATION_EXTERN CGFloat NCPanelPathBarContainerOriginYForLine(
    NSFont *_Nullable font, CGFloat stripH, CGFloat usedH, CGFloat usedOriginY);

NS_ASSUME_NONNULL_BEGIN

@protocol NCPanelBreadcrumbsViewDelegate <NSObject>
- (void)breadcrumbsView:(NCPanelBreadcrumbsView *)v didActivatePOSIXPath:(NSString *)path;
- (void)breadcrumbsViewDidActivateCurrentSegment:(NCPanelBreadcrumbsView *)v;
- (void)breadcrumbsViewDidRequestFullPathEdit:(NCPanelBreadcrumbsView *)v;
@end

/// Manual draw + layout: vertical centering is explicit in drawRect (same idea as TabBarStyle title rect).
@interface NCPanelBreadcrumbsView : NSView
@property(nonatomic, weak, nullable) id<NCPanelBreadcrumbsViewDelegate> crumbDelegate;
@property(nonatomic, copy, nullable) NSArray<NCPanelPathSegment *> *segments;
@property(nonatomic) NSInteger hoveredSegmentIndex; // -1 none
@property(nonatomic, strong) NSFont *crumbFont;
@property(nonatomic, strong) NSColor *textColor;
@property(nonatomic, strong) NSColor *linkColor;
@property(nonatomic, strong) NSColor *separatorColor;
@property(nonatomic, strong, nullable) NSColor *hoverFillColor;
@property(nonatomic, copy, nullable) NSMenu * (^menuForEventBlock)(NSEvent *event);

- (void)rebuildLayout;
/// Context menu: POSIX path for link under point, else fallback for empty/gap clicks.
- (nullable NSString *)posixPathAtViewPoint:(NSPoint)p fallbackPOSIXPath:(nullable NSString *)fallback plainPath:(nullable NSString *)plain;
@end

NS_ASSUME_NONNULL_END

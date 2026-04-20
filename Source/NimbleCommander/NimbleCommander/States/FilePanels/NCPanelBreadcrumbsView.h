// Copyright (C) 2016-2026 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#import <Cocoa/Cocoa.h>

#include "NCPanelPathBarTypes.h"

@class NCPanelBreadcrumbsView;

NS_ASSUME_NONNULL_BEGIN

@protocol NCPanelBreadcrumbsViewDelegate <NSObject>
- (void)breadcrumbsView:(NCPanelBreadcrumbsView *)v didActivatePOSIXPath:(NSString *)path;
- (void)breadcrumbsViewDidActivateCurrentSegment:(NCPanelBreadcrumbsView *)v;
- (void)breadcrumbsViewDidRequestFullPathEdit:(NCPanelBreadcrumbsView *)v;
@end

/// Manual draw: layout and vertical centering are precomputed in rebuildLayout (see NCBreadcrumbTextLayout);
/// drawRect: uses the cached geometry with no TextKit allocations.
@interface NCPanelBreadcrumbsView : NSView
@property(nonatomic, weak, nullable) id<NCPanelBreadcrumbsViewDelegate> crumbDelegate;
@property(nonatomic) NSInteger hoveredSegmentIndex; // -1 none
@property(nonatomic, strong) NSFont *crumbFont;
@property(nonatomic, strong) NSColor *textColor;
@property(nonatomic, strong) NSColor *linkColor;
@property(nonatomic, strong) NSColor *separatorColor;
@property(nonatomic, strong, nullable) NSColor *hoverFillColor;
@property(nonatomic) double hoverPadX;
@property(nonatomic) double hoverPadYTop;
@property(nonatomic) double hoverPadYBottom;
@property(nonatomic) unsigned hoverCornerRadius;
@property(nonatomic) double separatorVerticalNudgeCoefficient;
@property(nonatomic, copy, nullable) NSMenu * (^menuForEventBlock)(NSEvent *event);

- (void)setBreadcrumbs:(const std::vector<nc::panel::PanelHeaderBreadcrumb> &)breadcrumbs;
- (void)rebuildLayout;
/// Context menu: POSIX path for link under point, else fallback for empty/gap clicks.
- (nullable NSString *)posixPathAtViewPoint:(NSPoint)p fallbackPOSIXPath:(nullable NSString *)fallback plainPath:(nullable NSString *)plain;
@end

NS_ASSUME_NONNULL_END

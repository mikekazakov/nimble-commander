#pragma once

#import <Cocoa/Cocoa.h>

#include "NCPanelPathBarTypes.h"
#include "PanelViewHeaderTheme.h"
#import "NCPanelBreadcrumbsView.h"

NS_ASSUME_NONNULL_BEGIN

@interface NCPanelPathBarController : NSObject <NCPanelBreadcrumbsViewDelegate>

@property(nonatomic, readonly) NSView *view;
@property(nonatomic, weak, nullable) NSResponder *defaultResponder;
@property(nonatomic) std::function<std::optional<nc::panel::PanelPathContext>(void)> directoryContextProvider;
@property(nonatomic) std::function<void(const std::string &)> navigateToVFSPathCallback;
@property(nonatomic) NCPanelPathBarContextMenuAction contextMenuAction;
@property(nonatomic, readonly) bool fullPathSelectionActive;

- (instancetype)init;
- (void)applyTheme:(const nc::panel::HeaderTheme &)theme active:(bool)active;
- (void)setDisplayPath:(NSString *)displayPath;
- (bool)cancelFullPathSelectionIfActive;
- (void)invalidate;

@end

NS_ASSUME_NONNULL_END

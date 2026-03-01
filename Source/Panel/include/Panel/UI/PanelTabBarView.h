#pragma once
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@protocol NCPanelTabBarViewDelegate <NSTabViewDelegate>
@optional
// Extend with NCPanelTabBarView-specific delegate methods if needed
@end

[[clang::objc_runtime_name("_TtC5Panel17NCPanelTabBarView")]]
@interface NCPanelTabBarView : NSView<NSTabViewDelegate>

// Delegate
@property(nullable, nonatomic, weak) id<NCPanelTabBarViewDelegate> delegate;

// Tab View Reference
@property(nullable, nonatomic, strong) NSTabView *tabView;

// Initializers
- (instancetype)initWithFrame:(NSRect)frameRect NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;

// Public API
- (void)reloadTabs;
- (long)numberOfTabViewItems;
- (long)indexOfTabViewItem:(NSTabViewItem *)item;
- (nullable NSTabViewItem *)selectedTabViewItem;
- (void)selectTabViewItem:(NSTabViewItem *)item;
- (void)removeTabViewItem:(NSTabViewItem *)item;

@end

NS_ASSUME_NONNULL_END

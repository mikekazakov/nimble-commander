#pragma once
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class NCPanelTabBarView;

@protocol NCPanelTabBarViewDelegate <NSTabViewDelegate>
@optional
- (void)tabView:(NSTabView *)_view didCloseTabViewItem:(NSTabViewItem *)_item;
- (void)tabView:(NSTabView *)_view didDropTabViewItem:(NSTabViewItem *)_item inTabBarView:(NCPanelTabBarView *)_tabBarView;
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
- (long)indexOfTabViewItem:(NSTabViewItem *)_item;
- (nullable NSTabViewItem *)selectedTabViewItem;
- (void)selectTabViewItem:(NSTabViewItem *)_item;
- (void)removeTabViewItem:(NSTabViewItem *)_item;

- (NSButton *)closeButtonOfTabViewItem:(NSTabViewItem *)_item;

@end

NS_ASSUME_NONNULL_END

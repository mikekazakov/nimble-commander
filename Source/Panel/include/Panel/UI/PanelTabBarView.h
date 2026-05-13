#pragma once
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class NCPanelTabBarView;

@protocol NCPanelTabBarViewDelegate <NSTabViewDelegate>
@optional
- (void)tabView:(NSTabView *)_view didCloseTabViewItem:(NSTabViewItem *)_item;
- (void)tabView:(NSTabView *)_view
    didDropTabViewItem:(NSTabViewItem *)_item
          inTabBarView:(NCPanelTabBarView *)_tabBarView;
- (NSMenu *)tabView:(NSTabView *)_view menuForTabViewItem:(NSTabViewItem *)_item;
- (void)addNewTabToTabView:(NSTabView *)_view;
- (void)showAddTabMenuForTabView:(NSTabView *)_view;
@end

@protocol NCPanelTabBarThemeProvider <NSObject>
@required
@property(nonnull, nonatomic, readonly) NSColor *selectedKeyWndActiveBackgroundColor;
@property(nonnull, nonatomic, readonly) NSColor *selectedKeyWndInactiveBackgroundColor;
@property(nonnull, nonatomic, readonly) NSColor *selectedNotKeyWndBackgroundColor;
@property(nonnull, nonatomic, readonly) NSColor *regularKeyWndBackgroundColor;
@property(nonnull, nonatomic, readonly) NSColor *regularKeyWndHoverBackgroundColor;
@property(nonnull, nonatomic, readonly) NSColor *regularNotKeyWndBackgroundColor;
@property(nonnull, nonatomic, readonly) NSColor *separatorColor;
- (void)observeChangesWith:(void (^)(void))_callback;
@end

[[clang::objc_runtime_name("_TtC5Panel17NCPanelTabBarView")]]
@interface NCPanelTabBarView : NSView<NSTabViewDelegate>

// Delegate
@property(nullable, nonatomic, weak) id<NCPanelTabBarViewDelegate> delegate;

// Tab View Reference
@property(nullable, nonatomic, strong) NSTabView *tabView;

// Theme Provider
@property(nullable, nonatomic, strong) id<NCPanelTabBarThemeProvider> themeProvider;

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

- (NSButton *)addTabButton;

@end

NS_ASSUME_NONNULL_END

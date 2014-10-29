//
//  MMTabBarView.h
//  MMTabBarView
//
//  Created by Michael Monscheuer on 9/19/12.
//  Copyright (c) 2012 Michael Monscheuer. All rights reserved.
//

/*
   This view provides a control interface to manage a regular NSTabView.  It looks and works like the tabbed browsing interface of many popular browsers.
 */

#import <Cocoa/Cocoa.h>

#define MMTabDragDidEndNotification     @"MMTabDragDidEndNotification"
#define MMTabDragDidBeginNotification   @"MMTabDragDidBeginNotification"

#define kMMTabBarViewHeight             22
// default inset
#define MARGIN_X                        6
#define MARGIN_Y                        3
// padding between objects
#define kMMTabBarCellPadding            4
// fixed size objects
#define kMMMinimumTitleWidth            30
#define kMMTabBarIndicatorWidth         16.0
#define kMMTabBarIconWidth              16.0
#define kMMObjectCounterMinWidth        20.0
#define kMMObjectCounterRadius          7.0
#define kMMTabBarViewSourceListHeight   28

#define StaticImage(name) \
static NSImage* _static##name##Image() \
{ \
    static NSImage* image = nil; \
    if (!image) \
        image = [[NSImage alloc] initByReferencingFile:[[MMTabBarView bundle] pathForImageResource:@#name]]; \
    return image; \
}

@class MMOverflowPopUpButton;
@class MMRolloverButton;
@class MMTabBarViewler;
@class MMTabBarButton;
@class MMAttachedTabBarButton;
@class MMSlideButtonsAnimation;
@class MMTabBarController;

@protocol MMTabStyle;

typedef enum MMTabBarOrientation : NSUInteger {
    MMTabBarHorizontalOrientation = 0,
    MMTabBarVerticalOrientation
} MMTabBarOrientation;

typedef enum MMTabBarTearOffStyle : NSUInteger {
    MMTabBarTearOffAlphaWindow,
    MMTabBarTearOffMiniwindow
} MMTabBarTearOffStyle;

typedef enum MMAttachedButtonsEnumerationOptions : NSUInteger {

    MMAttachedButtonsEnumerationNone               = 0,
    MMAttachedButtonsEnumerationUpdateTabStateMask = 1 << 1,
    MMAttachedButtonsEnumerationUpdateButtonState  = 1 << 2
} MMAttachedButtonsEnumerationOptions;

@protocol MMTabBarViewDelegate;

@interface MMTabBarView : NSView <NSTabViewDelegate, NSDraggingSource, NSDraggingDestination, NSAnimationDelegate> {
                                                
    // control basics
    NSTabView                       *_tabView;                    // the tab view being navigated
    MMOverflowPopUpButton           *_overflowPopUpButton;        // for too many tabs
    MMRolloverButton                *_addTabButton;
    MMTabBarController              *_controller;

    // Spring-loading.
    NSTimer                         *_springTimer;
    NSTabViewItem                   *_tabViewItemWithSpring;

    // configuration
    id <MMTabStyle>                 _style;
    BOOL                            _onlyShowCloseOnHover;    
    BOOL                            _canCloseOnlyTab;
    BOOL                            _disableTabClose;
    BOOL                            _hideForSingleTab;
    BOOL                            _showAddTabButton;
    BOOL                            _sizeButtonsToFit;
    BOOL                            _useOverflowMenu;
    BOOL                            _alwaysShowActiveTab;
    BOOL                            _allowsScrubbing;
    NSInteger                       _resizeAreaCompensation;
    MMTabBarOrientation             _orientation;
    BOOL                            _automaticallyAnimates;
    MMTabBarTearOffStyle            _tearOffStyle;
    BOOL                            _allowsBackgroundTabClosing;
    BOOL                            _selectsTabsOnMouseDown;
    BOOL                            _resizeTabsToFitTotalWidth;

    // vertical tab resizing
    BOOL                            _allowsResizing;
    BOOL                            _isResizing;

    // button width
    NSInteger                       _buttonMinWidth;
    NSInteger                       _buttonMaxWidth;
    NSInteger                       _buttonOptimumWidth;

    // animation
    MMSlideButtonsAnimation         *_slideButtonsAnimation;
    
    // animation for hide/show
    NSViewAnimation                 *_hideShowTabBarAnimation;
    BOOL                            _isHidden;
    NSView                          *_partnerView;    // gets resized when hide/show
    NSInteger                       _tabBarWidth;   // stored width of vertical tab bar
        
    // states
    BOOL                            _isReorderingTabViewItems;
    BOOL                            _needsUpdate;

    // drag and drop
    NSUInteger                      _destinationIndexForDraggedItem;  // NSNotFound = none

    // delegate
    id <MMTabBarViewDelegate>       _delegate;
}

@property (retain) IBOutlet NSTabView *tabView;
@property (retain) IBOutlet NSView *partnerView;
@property (assign) IBOutlet id <MMTabBarViewDelegate> delegate;
@property (assign) NSUInteger destinationIndexForDraggedItem;
@property (readonly) BOOL isResizing;
@property (assign) BOOL needsUpdate;
@property (assign) BOOL resizeTabsToFitTotalWidth;

#pragma mark Control Characteristics

+ (NSBundle *)bundle;
- (CGFloat)availableWidthForButtons;
- (CGFloat)availableHeightForButtons;
- (NSRect)genericButtonRect;
- (BOOL)isWindowActive;
- (BOOL)allowsDetachedDraggingOfTabViewItem:(NSTabViewItem *)anItem;

#pragma mark Style Class Registry

+ (void)registerDefaultTabStyleClasses;
+ (void)registerTabStyleClass:(Class <MMTabStyle>)aStyleClass;
+ (void)unregisterTabStyleClass:(Class <MMTabStyle>)aStyleClass;
+ (NSArray *)registeredTabStyleClasses;
+ (Class <MMTabStyle>)registeredClassForStyleName:(NSString *)name;

#pragma mark Tab View Item Management

- (NSUInteger)numberOfTabViewItems;
- (NSUInteger)numberOfVisibleTabViewItems;
- (NSArray *)visibleTabViewItems;
- (NSUInteger)indexOfTabViewItem:(NSTabViewItem *)anItem;
- (NSTabViewItem *)selectedTabViewItem;
- (void)selectTabViewItem:(NSTabViewItem *)anItem;
- (void)moveTabViewItem:(NSTabViewItem *)anItem toIndex:(NSUInteger)index;
- (void)removeTabViewItem:(NSTabViewItem *)anItem;

- (NSTabViewItem *)tabViewItemPinnedToOverflowButton;
- (void)setTabViewItemPinnedToOverflowButton:(NSTabViewItem *)item;

#pragma mark Attached Buttons Management

- (NSUInteger)numberOfAttachedButtons;
- (NSSet *)attachedButtons;
- (NSArray *)orderedAttachedButtons;
- (NSArray *)sortedAttachedButtonsUsingComparator:(NSComparator)cmptr;
- (void)insertAttachedButtonForTabViewItem:(NSTabViewItem *)item atIndex:(NSUInteger)index;
- (void)addAttachedButtonForTabViewItem:(NSTabViewItem *)item;
- (void)removeAttachedButton:(MMAttachedTabBarButton *)aButton;
- (void)removeAttachedButton:(MMAttachedTabBarButton *)aButton synchronizeTabViewItems:(BOOL)syncTabViewItems;
- (void)insertAttachedButton:(MMAttachedTabBarButton *)aButton atTabItemIndex:(NSUInteger)anIndex;

#pragma mark Find Attached Buttons

- (NSIndexSet *)viewIndexesOfAttachedButtons;

- (NSUInteger)viewIndexOfSelectedAttachedButton;

- (MMAttachedTabBarButton *)selectedAttachedButton;
- (MMAttachedTabBarButton *)lastAttachedButton;

- (MMAttachedTabBarButton *)attachedButtonAtPoint:(NSPoint)aPoint;

- (MMAttachedTabBarButton *)attachedButtonForTabViewItem:(NSTabViewItem *)anItem;

- (NSUInteger)indexOfAttachedButton:(MMAttachedTabBarButton *)aButton;

#pragma mark Button State Management

- (void)updateTabStateMaskOfAttachedButton:(MMAttachedTabBarButton *)aButton atIndex:(NSUInteger)index withPrevious:(MMAttachedTabBarButton *)prevButton next:(MMAttachedTabBarButton *)nextButton;
- (void)updateTabStateMaskOfAttachedButton:(MMAttachedTabBarButton *)aButton atIndex:(NSUInteger)index;
- (void)updateTabStateMaskOfAttachedButtons;

#pragma mark Sending Messages to Attached Buttons

- (void)enumerateAttachedButtonsUsingBlock:(void (^)(MMAttachedTabBarButton *aButton, NSUInteger idx, BOOL *stop))block;

- (void)enumerateAttachedButtonsWithOptions:(MMAttachedButtonsEnumerationOptions)opts usingBlock:(void (^)(MMAttachedTabBarButton *aButton, NSUInteger idx, MMAttachedTabBarButton *previousButton, MMAttachedTabBarButton *nextButton, BOOL *stop))block;

- (void)enumerateAttachedButtons:(NSArray *)buttons inRange:(NSRange)range withOptions:(MMAttachedButtonsEnumerationOptions)opts usingBlock:(void (^)(MMAttachedTabBarButton *aButton, NSUInteger idx, MMAttachedTabBarButton *previousButton, MMAttachedTabBarButton *nextButton, BOOL *stop))block;

#pragma mark Find Tab Bar Buttons

- (MMTabBarButton *)tabBarButtonAtPoint:(NSPoint)point;

#pragma mark Control Configuration

- (id<MMTabStyle>)style;
- (void)setStyle:(id <MMTabStyle>)newStyle;
- (NSString *)styleName;
- (void)setStyleNamed:(NSString *)name;

- (MMTabBarOrientation)orientation;
- (void)setOrientation:(MMTabBarOrientation)value;
- (BOOL)onlyShowCloseOnHover;
- (void)setOnlyShowCloseOnHover:(BOOL)value;
- (BOOL)canCloseOnlyTab;
- (void)setCanCloseOnlyTab:(BOOL)value;
- (BOOL)disableTabClose;
- (void)setDisableTabClose:(BOOL)value;
- (BOOL)hideForSingleTab;
- (void)setHideForSingleTab:(BOOL)value;
- (BOOL)showAddTabButton;
- (void)setShowAddTabButton:(BOOL)value;
- (NSInteger)buttonMinWidth;
- (void)setButtonMinWidth:(NSInteger)value;
- (NSInteger)buttonMaxWidth;
- (void)setButtonMaxWidth:(NSInteger)value;
- (NSInteger)buttonOptimumWidth;
- (void)setButtonOptimumWidth:(NSInteger)value;
- (BOOL)sizeButtonsToFit;
- (void)setSizeButtonsToFit:(BOOL)value;
- (BOOL)useOverflowMenu;
- (void)setUseOverflowMenu:(BOOL)value;
- (BOOL)allowsBackgroundTabClosing;
- (void)setAllowsBackgroundTabClosing:(BOOL)value;
- (BOOL)allowsResizing;
- (void)setAllowsResizing:(BOOL)value;
- (BOOL)selectsTabsOnMouseDown;
- (void)setSelectsTabsOnMouseDown:(BOOL)value;
- (BOOL)automaticallyAnimates;
- (void)setAutomaticallyAnimates:(BOOL)value;
- (BOOL)alwaysShowActiveTab;
- (void)setAlwaysShowActiveTab:(BOOL)value;
- (BOOL)allowsScrubbing;
- (void)setAllowsScrubbing:(BOOL)value;
- (MMTabBarTearOffStyle)tearOffStyle;
- (void)setTearOffStyle:(MMTabBarTearOffStyle)tearOffStyle;

#pragma mark Accessors 

- (NSTabView *)tabView;
- (void)setTabView:(NSTabView *)view;
- (id<MMTabBarViewDelegate>)delegate;
- (void)setDelegate:(id<MMTabBarViewDelegate>)object;
- (CGFloat)heightOfTabBarButtons;
- (BOOL)supportsOrientation:(MMTabBarOrientation)orientation;

#pragma mark -
#pragma mark Visibility

- (BOOL)isOverflowButtonVisible;

#pragma mark -
#pragma mark Resizing

- (NSRect)dividerRect;

#pragma mark Hide/Show Tab Bar Control

- (void)hideTabBar:(BOOL)hide animate:(BOOL)animate;
- (BOOL)isTabBarHidden;
- (BOOL)isAnimating;

#pragma mark Determining Sizes

- (NSSize)addTabButtonSize;
- (NSRect)addTabButtonRect;
- (NSSize)overflowButtonSize;
- (NSRect)overflowButtonRect;

#pragma mark Determining Margins

- (CGFloat)rightMargin;
- (CGFloat)leftMargin;
- (CGFloat)topMargin;
- (CGFloat)bottomMargin;

#pragma mark Layout Buttons

- (void)layoutButtons;
- (void)update;
- (void)update:(BOOL)animate;

#pragma mark Interface to Dragging Assistant

- (BOOL)shouldStartDraggingAttachedTabBarButton:(MMAttachedTabBarButton *)aButton withMouseDownEvent:(NSEvent *)event;

- (void)startDraggingAttachedTabBarButton:(MMAttachedTabBarButton *)aButton withMouseDownEvent:(NSEvent *)theEvent;

- (MMAttachedTabBarButton *)attachedTabBarButtonForDraggedItems;

- (BOOL)isSliding;
- (BOOL)isDragging;

#pragma mark Tab Button Menu Support

- (NSMenu *)menuForTabBarButton:(MMTabBarButton *)aButton withEvent:(NSEvent *)anEvent;
- (NSMenu *)menuForTabViewItem:(NSTabViewItem *)aTabViewItem withEvent:(NSEvent *)anEvent;

#pragma mark Convenience

// internal bindings methods also used by the tab drag assistant
- (void)bindPropertiesOfAttachedButton:(MMAttachedTabBarButton *)aButton andTabViewItem:(NSTabViewItem *)item;
- (void)unbindPropertiesOfAttachedButton:(MMAttachedTabBarButton *)aButton;

#pragma mark -
#pragma mark Drawing

- (void)drawRect:(NSRect)rect;
- (void)drawBezelInRect:(NSRect)rect;
- (void)drawButtonBezelsInRect:(NSRect)rect;
- (void)drawInteriorInRect:(NSRect)rect;

@end

@protocol MMTabBarViewDelegate <NSTabViewDelegate>

@optional

    // Standard NSTabView delegate methods
- (BOOL)tabView:(NSTabView *)aTabView shouldCloseTabViewItem:(NSTabViewItem *)tabViewItem;
- (void)tabView:(NSTabView *)aTabView willCloseTabViewItem:(NSTabViewItem *)tabViewItem;
- (void)tabView:(NSTabView *)aTabView didCloseTabViewItem:(NSTabViewItem *)tabViewItem;
- (void)tabView:(NSTabView *)aTabView didDetachTabViewItem:(NSTabViewItem *)tabViewItem;
- (void)tabView:(NSTabView *)aTabView didMoveTabViewItem:(NSTabViewItem *)tabViewItem toIndex:(NSUInteger)index;

    // Informal tab bar visibility methods
- (void)tabView:(NSTabView *)aTabView tabBarViewDidHide:(MMTabBarView *)tabBarView;
- (void)tabView:(NSTabView *)aTabView tabBarViewDidUnhide:(MMTabBarView *)tabBarView;

    // Closing behavior
- (BOOL)tabView:(NSTabView *)aTabView disableTabCloseForTabViewItem:(NSTabViewItem *)tabViewItem;

    // Adding tabs
- (void)addNewTabToTabView:(NSTabView *)aTabView;

    // Contextual menu support
- (NSMenu *)tabView:(NSTabView *)aTabView menuForTabViewItem:(NSTabViewItem *)tabViewItem;

    // Drag and drop related methods
- (BOOL)tabView:(NSTabView *)aTabView shouldDragTabViewItem:(NSTabViewItem *)tabViewItem inTabBarView:(MMTabBarView *)tabBarView;
- (NSDragOperation)tabView:(NSTabView *)aTabView validateDrop:(id <NSDraggingInfo>)sender proposedItem:(NSTabViewItem *)tabViewItem proposedIndex:(NSUInteger)proposedIndex inTabBarView:(MMTabBarView *)tabBarView;
- (NSDragOperation)tabView:(NSTabView *)aTabView validateSlideOfProposedItem:(NSTabViewItem *)tabViewItem proposedIndex:(NSUInteger)proposedIndex inTabBarView:(MMTabBarView *)tabBarView;
- (BOOL)tabView:(NSTabView *)aTabView shouldAllowTabViewItem:(NSTabViewItem *)tabViewItem toLeaveTabBarView:(MMTabBarView *)tabBarView;
- (void)tabView:(NSTabView*)aTabView didDropTabViewItem:(NSTabViewItem *)tabViewItem inTabBarView:(MMTabBarView *)tabBarView;

    // "Spring-loaded" tabs methods
- (NSArray *)allowedDraggedTypesForTabView:(NSTabView *)aTabView;
- (BOOL)tabView:(NSTabView *)aTabView acceptedDraggingInfo:(id <NSDraggingInfo>) draggingInfo onTabViewItem:(NSTabViewItem *)tabViewItem;

    // Tear-off related methods
- (NSImage *)tabView:(NSTabView *)aTabView imageForTabViewItem:(NSTabViewItem *)tabViewItem offset:(NSSize *)offset styleMask:(NSUInteger *)styleMask;
- (MMTabBarView *)tabView:(NSTabView *)aTabView newTabBarViewForDraggedTabViewItem:(NSTabViewItem *)tabViewItem atPoint:(NSPoint)point;
- (void)tabView:(NSTabView *)aTabView closeWindowForLastTabViewItem:(NSTabViewItem *)tabViewItem;

    // Overflow handling validation
- (BOOL)tabView:(NSTabView *)aTabView validateOverflowMenuItem:(NSMenuItem *)menuItem forTabViewItem:(NSTabViewItem *)tabViewItem;
- (void)tabView:(NSTabView *)aTabView tabViewItem:(NSTabViewItem *)tabViewItem isInOverflowMenu:(BOOL)inOverflowMenu;

    // Tooltips
- (NSString *)tabView:(NSTabView *)aTabView toolTipForTabViewItem:(NSTabViewItem *)tabViewItem;

    // Accessibility
- (NSString *)accessibilityStringForTabView:(NSTabView *)aTabView objectCount:(NSInteger)objectCount;

    // Deprecated Methods
- (BOOL)tabView:(NSTabView *)aTabView shouldDragTabViewItem:(NSTabViewItem *)tabViewItem fromTabBar:(id)tabBarControl __attribute__((deprecated("implement -tabView:shouldDragTabViewItem:inTabBarView: instead.")));
- (BOOL)tabView:(NSTabView *)aTabView shouldDropTabViewItem:(NSTabViewItem *)tabViewItem inTabBar:(id)tabBarControl __attribute__((deprecated("implement -tabView:shouldDropTabViewItem:inTabBarView: instead.")));
- (BOOL)tabView:(NSTabView *)aTabView shouldAllowTabViewItem:(NSTabViewItem *)tabViewItem toLeaveTabBar:(id)tabBarControl __attribute__((deprecated("implement -tabView:shouldAllowTabViewItem:toLeaveTabBarView: instead.")));
- (void)tabView:(NSTabView*)aTabView didDropTabViewItem:(NSTabViewItem *)tabViewItem inTabBar:(id)tabBarControl __attribute__((deprecated("implement -tabView:didDropTabViewItem:inTabBarView: instead.")));
- (id)tabView:(NSTabView *)aTabView newTabBarForDraggedTabViewItem:(NSTabViewItem *)tabViewItem atPoint:(NSPoint)point __attribute__((deprecated("implement -tabView:newTabBarViewForDraggedTabViewItem:atPoint: instead.")));
- (void)tabView:(NSTabView *)aTabView tabBarDidHide:(id)tabBarControl __attribute__((deprecated("implement -tabView:tabBarViewDidHide: instead.")));
- (void)tabView:(NSTabView *)aTabView tabBarDidUnhide:(id)tabBarControl __attribute__((deprecated("implement -tabView:tabBarViewDidUnhide: instead.")));
- (CGFloat)desiredWidthForVerticalTabBar:(id)tabBarControl DEPRECATED_ATTRIBUTE;

- (NSDragOperation)tabView:(NSTabView *)aTabView shouldDropTabViewItem:(NSTabViewItem *)tabViewItem inTabBarView:(MMTabBarView *)tabBarView __attribute__((deprecated("implement -tabView:validateDrop:proposedIndex:inTabBarView: instead.")));

@end
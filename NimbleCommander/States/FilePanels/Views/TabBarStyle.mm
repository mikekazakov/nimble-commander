//
//  MMYosemiteTabStyle.m
//  --------------------
//
//  Based on MMUnifiedTabStyle.m by Keith Blount
//  Created by Ajin Man Tuladhar on 04/11/2014.
//  Copyright 2014 Ajin Man Tuladhar. All rights reserved.
//

#import "TabBarStyle.h"
#import <MMTabBarView/MMTabStyle.h>
#import <MMTabBarView/MMAttachedTabBarButton.h>
#import <MMTabBarView/MMTabBarView.h>
#import <MMTabBarView/NSView+MMTabBarViewExtensions.h>
#import <MMTabBarView/NSBezierPath+MMTabBarViewExtensions.h>
#import <MMTabBarView/MMOverflowPopUpButton.h>
#import <MMTabBarView/MMTabBarView.Private.h>


#include <NimbleCommander/Core/Theming/Theme.h>

NS_ASSUME_NONNULL_BEGIN

@implementation TabBarStyle

StaticImage(YosemiteTabClose_Front)
StaticImage(YosemiteTabClose_Front_Pressed)
StaticImage(YosemiteTabClose_Front_Rollover)
StaticImageWithFilename(YosemiteTabCloseDirty_Front, AquaTabCloseDirty_Front)
StaticImageWithFilename(YosemiteTabCloseDirty_Front_Pressed, AquaTabCloseDirty_Front_Pressed)
StaticImageWithFilename(YosemiteTabCloseDirty_Front_Rollover, AquaTabCloseDirty_Front_Rollover)
StaticImage(YosemiteTabNew)
StaticImage(YosemiteTabNewPressed)

+ (NSString *)name {
    return @"NC";
}

- (NSString *)name {
	return [[self class] name];
}

#pragma mark -
#pragma mark Creation/Destruction

- (id) init {
	if ((self = [super init])) {
	}
	return self;
}

#pragma mark -
#pragma mark Tab View Specific

- (BOOL)needsResizeTabsToFitTotalWidth
{
    return true;
}

- (NSSize)intrinsicContentSizeOfTabBarView:(MMTabBarView *)tabBarView
{
    return NSMakeSize(-1/* NSViewNoInstrinsicMetric */, 24);
}

- (CGFloat)leftMarginForTabBarView:(MMTabBarView *)tabBarView {
        return 0.f;
}

- (CGFloat)rightMarginForTabBarView:(MMTabBarView *)tabBarView {
        return 0.f;
}

- (CGFloat)topMarginForTabBarView:(MMTabBarView *)tabBarView {
        return 0.0f;
}

- (CGFloat)heightOfTabBarButtonsForTabBarView:(MMTabBarView *)tabBarView {
    return 24;
}

- (NSSize)overflowButtonSizeForTabBarView:(MMTabBarView *)tabBarView {
    return NSMakeSize(14, [self heightOfTabBarButtonsForTabBarView:tabBarView]);
}

- (NSRect)addTabButtonRectForTabBarView:(MMTabBarView *)tabBarView {

    NSRect rect = [tabBarView _addTabButtonRect];

    return rect;
}

- (NSSize)addTabButtonSizeForTabBarView:(MMTabBarView *)tabBarView {
    return NSMakeSize(18, [self heightOfTabBarButtonsForTabBarView:tabBarView]);
}

- (BOOL)supportsOrientation:(MMTabBarOrientation)orientation forTabBarView:(MMTabBarView *)tabBarView {

    if (orientation != MMTabBarHorizontalOrientation)
        return NO;
    
    return YES;
}

#pragma mark -
#pragma mark Drag Support

- (NSRect)draggingRectForTabButton:(MMAttachedTabBarButton *)aButton ofTabBarView:(MMTabBarView *)tabBarView {

	NSRect dragRect = [aButton stackingFrame];
	dragRect.size.width++;
	return dragRect;
    
}

#pragma mark -
#pragma mark Add Tab Button

- (void)updateAddButton:(MMRolloverButton *)aButton ofTabBarView:(MMTabBarView *)tabBarView {
    
    [aButton setImage:_staticYosemiteTabNewImage()];
    [aButton setAlternateImage:_staticYosemiteTabNewPressedImage()];
    [aButton setRolloverImage:_staticYosemiteTabNewImage()];
}

#pragma mark -
#pragma mark Providing Images

- (NSImage *)closeButtonImageOfType:(MMCloseButtonImageType)type forTabCell:(MMTabBarButtonCell *)cell
{
    switch (type) {
        case MMCloseButtonImageTypeStandard:
            return _staticYosemiteTabClose_FrontImage();
        case MMCloseButtonImageTypeRollover:
            return _staticYosemiteTabClose_Front_RolloverImage();
        case MMCloseButtonImageTypePressed:
            return _staticYosemiteTabClose_Front_PressedImage();
            
        case MMCloseButtonImageTypeDirty:
            return _staticYosemiteTabCloseDirty_FrontImage();
        case MMCloseButtonImageTypeDirtyRollover:
            return _staticYosemiteTabCloseDirty_Front_RolloverImage();
        case MMCloseButtonImageTypeDirtyPressed:
            return _staticYosemiteTabCloseDirty_Front_PressedImage();
            
        default:
            break;
    }
    
}

#pragma mark -
#pragma mark Drawing

- (NSAttributedString *)attributedStringValueForTabCell:(MMTabBarButtonCell *)cell
{
    static const auto paragraph_style = []()-> NSParagraphStyle* {
        NSMutableParagraphStyle *ps = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
		ps.lineBreakMode = NSLineBreakByTruncatingTail;
		ps.alignment = NSCenterTextAlignment;
        return ps;
    }();

    const auto attrs = @{NSFontAttributeName: Theme().FilePanelsTabsFont(),
                         NSForegroundColorAttributeName: Theme().FilePanelsTabsTextColor(),
                         NSParagraphStyleAttributeName: paragraph_style
                         };
    return [[NSAttributedString alloc] initWithString:cell.title
                                           attributes:attrs];
}

- (void)drawBezelOfTabBarView:(MMTabBarView *)tabBarView inRect:(NSRect)rect
{
    NSDrawWindowBackground(rect);
    [Theme().FilePanelsTabsSeparatorColor() set];
    NSBezierPath *bezier = [NSBezierPath bezierPath];
    [bezier moveToPoint:NSMakePoint(rect.origin.x,
                                    tabBarView.bounds.size.height - 0.5)];
    [bezier lineToPoint:NSMakePoint(rect.origin.x + rect.size.width,
                                    tabBarView.bounds.size.height - 0.5)];
    [bezier stroke];
}

-(void)drawBezelOfTabCell:(MMTabBarButtonCell *)cell
                withFrame:(NSRect)frame
                   inView:(NSView *)controlView
{
    frame.size.height -= 1; // for horizontal divider drawn by drawBezelOfTabBarView
    
    MMAttachedTabBarButton *button = (MMAttachedTabBarButton *)controlView;
    
    const NSColor *bg_color = [&]{
        const MMTabBarView *tabBarView = [controlView enclosingTabBarView];
        const bool wnd_active = [tabBarView isWindowActive];
        const bool tab_selected = [button state] == NSOnState;
        const bool button_hovered = [button mouseHovered];
        // this might not work, check!!!:
        const bool tab_isfr = tab_selected &&
            tabBarView.tabView.selectedTabViewItem.view == tabBarView.window.firstResponder;
        
        if( tab_selected ) {
            if( wnd_active ) {
                if( tab_isfr )
                    return Theme().FilePanelsTabsSelectedKeyWndActiveBackgroundColor();
                else
                    return Theme().FilePanelsTabsSelectedKeyWndInactiveBackgroundColor(); }
            else
                return Theme().FilePanelsTabsSelectedNotKeyWndBackgroundColor(); }
        else {
            if( wnd_active ) {
                if( button_hovered )
                    return Theme().FilePanelsTabsRegularKeyWndHoverBackgroundColor();
                else
                    return Theme().FilePanelsTabsRegularKeyWndRegularBackgroundColor(); }
            else
                return Theme().FilePanelsTabsRegularNotKeyWndBackgroundColor(); }
    }();
  
    if( bg_color && bg_color != NSColor.clearColor ) {
        [bg_color set];
        NSRectFill(frame);
    }
    else {
        NSDrawWindowBackground(frame);
    }
    
    [Theme().FilePanelsTabsSeparatorColor() set];
    NSBezierPath *bezier = [NSBezierPath bezierPath];
    if( button.shouldDisplayLeftDivider ) {
        [bezier moveToPoint:NSMakePoint(NSMinX(frame), NSMinY(frame))];
        [bezier lineToPoint:NSMakePoint(NSMinX(frame), NSMaxY(frame))];
    }
    if( button.shouldDisplayRightDivider ) {
        [bezier moveToPoint:NSMakePoint(NSMaxX(frame), NSMinY(frame))];
        [bezier lineToPoint:NSMakePoint(NSMaxX(frame), NSMaxY(frame))];
    }
    [bezier stroke];
}

-(void)drawBezelOfOverflowButton:(MMOverflowPopUpButton *)overflowButton
                    ofTabBarView:(MMTabBarView *)tabBarView
                          inRect:(NSRect)rect {
}

@end

NS_ASSUME_NONNULL_END

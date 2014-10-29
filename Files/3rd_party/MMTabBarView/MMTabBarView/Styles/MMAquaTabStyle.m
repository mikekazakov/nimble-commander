//
//  MMAquaTabStyle.m
//  MMTabBarView
//
//  Created by John Pannell on 2/17/06.
//  Copyright 2006 Positive Spin Media. All rights reserved.
//

#import "MMAquaTabStyle.h"
#import "MMAttachedTabBarButton.h"
#import "MMTabBarView.h"
#import "NSView+MMTabBarViewExtensions.h"

@implementation MMAquaTabStyle

+ (NSString *)name {
    return @"Aqua";
}

- (NSString *)name {
	return [[self class] name];
}

#pragma mark -
#pragma mark Creation/Destruction

- (id) init {
	if ((self = [super init])) {
		[self loadImages];
	}
	return self;
}

- (void) loadImages {
	// Aqua Tabs Images
	aquaTabBg = [[NSImage alloc] initByReferencingFile:[[MMTabBarView bundle] pathForImageResource:@"AquaTabsBackground"]];

	aquaTabBgDown = [[NSImage alloc] initByReferencingFile:[[MMTabBarView bundle] pathForImageResource:@"AquaTabsDown"]];

	aquaTabBgDownGraphite = [[NSImage alloc] initByReferencingFile:[[MMTabBarView bundle] pathForImageResource:@"AquaTabsDownGraphite"]];

	aquaTabBgDownNonKey = [[NSImage alloc] initByReferencingFile:[[MMTabBarView bundle] pathForImageResource:@"AquaTabsDownNonKey"]];

	aquaDividerDown = [[NSImage alloc] initByReferencingFile:[[MMTabBarView bundle] pathForImageResource:@"AquaTabsSeparatorDown"]];

	aquaDivider = [[NSImage alloc] initByReferencingFile:[[MMTabBarView bundle] pathForImageResource:@"AquaTabsSeparator"]];

	aquaCloseButton = [[NSImage alloc] initByReferencingFile:[[MMTabBarView bundle] pathForImageResource:@"AquaTabClose_Front"]];
	aquaCloseButtonDown = [[NSImage alloc] initByReferencingFile:[[MMTabBarView bundle] pathForImageResource:@"AquaTabClose_Front_Pressed"]];
	aquaCloseButtonOver = [[NSImage alloc] initByReferencingFile:[[MMTabBarView bundle] pathForImageResource:@"AquaTabClose_Front_Rollover"]];

	aquaCloseDirtyButton = [[NSImage alloc] initByReferencingFile:[[MMTabBarView bundle] pathForImageResource:@"AquaTabCloseDirty_Front"]];
	aquaCloseDirtyButtonDown = [[NSImage alloc] initByReferencingFile:[[MMTabBarView bundle] pathForImageResource:@"AquaTabCloseDirty_Front_Pressed"]];
	aquaCloseDirtyButtonOver = [[NSImage alloc] initByReferencingFile:[[MMTabBarView bundle] pathForImageResource:@"AquaTabCloseDirty_Front_Rollover"]];
}

- (void)dealloc {
	[aquaTabBg release], aquaTabBg = nil;
	[aquaTabBgDown release], aquaTabBgDown = nil;
	[aquaDividerDown release], aquaDividerDown = nil;
	[aquaDivider release], aquaDivider = nil;
	[aquaCloseButton release], aquaCloseButton = nil;
	[aquaCloseButtonDown release], aquaCloseButtonDown = nil;
	[aquaCloseButtonOver release], aquaCloseButtonOver = nil;
	[aquaCloseDirtyButton release], aquaCloseDirtyButton = nil;
	[aquaCloseDirtyButtonDown release], aquaCloseDirtyButtonDown = nil;
	[aquaCloseDirtyButtonOver release], aquaCloseDirtyButtonOver = nil;

	[super dealloc];
}

#pragma mark -
#pragma mark Tab View Specifics

- (CGFloat)leftMarginForTabBarView:(MMTabBarView *)tabBarView {
	return 0.0f;
}

- (CGFloat)rightMarginForTabBarView:(MMTabBarView *)tabBarView {
	return 0.0f;
}

- (CGFloat)topMarginForTabBarView:(MMTabBarView *)tabBarView {
	return 0.0f;
}

#pragma mark -
#pragma mark Providing Images

- (NSImage *)closeButtonImageOfType:(MMCloseButtonImageType)type forTabCell:(MMTabBarButtonCell *)cell
{
    switch (type) {
        case MMCloseButtonImageTypeStandard:
            return aquaCloseButton;
        case MMCloseButtonImageTypeRollover:
            return aquaCloseButtonOver;
        case MMCloseButtonImageTypePressed:
            return aquaCloseButtonDown;
            
        case MMCloseButtonImageTypeDirty:
            return aquaCloseDirtyButton;
        case MMCloseButtonImageTypeDirtyRollover:
            return aquaCloseDirtyButtonOver;
        case MMCloseButtonImageTypeDirtyPressed:
            return aquaCloseDirtyButtonDown;
            
        default:
            break;
    }
}

#pragma mark -
#pragma mark Drawing

- (void)drawBezelOfTabBarView:(MMTabBarView *)tabBarView inRect:(NSRect)rect {
	if (rect.size.height <= 22.0) {
		//Draw for our whole bounds; it'll be automatically clipped to fit the appropriate drawing area
		rect = [tabBarView bounds];

		[aquaTabBg drawInRect:rect fromRect:NSMakeRect(0.0, 0.0, 1.0, 22.0) operation:NSCompositeSourceOver fraction:1.0 respectFlipped:YES hints:nil];
	}
}

- (void)drawBezelOfTabCell:(MMTabBarButtonCell *)cell withFrame:(NSRect)frame inView:(NSView *)controlView {

    MMTabBarView *tabBarView = [controlView enclosingTabBarView];
    MMAttachedTabBarButton *button = (MMAttachedTabBarButton *)controlView;
    
	NSRect cellFrame = frame;
    
    NSImage *left = nil;
    NSImage *right = nil;
    NSImage *center = nil;
    
	// Selected Tab
	if ([cell state] == NSOnState) {
		NSRect aRect = NSMakeRect(cellFrame.origin.x, cellFrame.origin.y, cellFrame.size.width, cellFrame.size.height);
        
		// proper tint
		NSControlTint currentTint;
		if ([cell controlTint] == NSDefaultControlTint) {
			currentTint = [NSColor currentControlTint];
		} else{
			currentTint = [cell controlTint];
		}

		if (![tabBarView isWindowActive]) {
			currentTint = NSClearControlTint;
		}

		switch(currentTint) {
            case NSGraphiteControlTint:
                center = aquaTabBgDownGraphite;
                break;
            case NSClearControlTint:
                center = aquaTabBgDownNonKey;
                break;
            case NSBlueControlTint:
            default:
                center = aquaTabBgDown;
                break;
        }

        if ([button shouldDisplayRightDivider]) {
            right = aquaDivider;
        }
        
        if ([button shouldDisplayLeftDivider]) {
            left = aquaDivider;
        }

        NSDrawThreePartImage(aRect, left, center, right, NO, NSCompositeSourceOver, 1.0f,[controlView isFlipped]);

	} else { // Unselected Tab
		NSRect aRect = NSMakeRect(cellFrame.origin.x, cellFrame.origin.y, cellFrame.size.width, cellFrame.size.height);
        
		// Rollover
		if ([cell mouseHovered]) {
			[[NSColor colorWithCalibratedWhite:0.0 alpha:0.1] set];
			NSRectFillUsingOperation(aRect, NSCompositeSourceAtop);
		}
        
        if ([button shouldDisplayRightDivider])
            right = aquaDivider;
        if ([button shouldDisplayLeftDivider])
            left = aquaDivider;
        
        if (![button isOverflowButton]) {
            NSDrawThreePartImage(aRect, left, center, right, NO, NSCompositeSourceOver, 1.0f,[controlView isFlipped]);
        }
	}
}

- (void)drawBezelOfOverflowButton:(MMOverflowPopUpButton *)overflowButton ofTabBarView:(MMTabBarView *)tabBarView inRect:(NSRect)rect {

    MMAttachedTabBarButton *lastAttachedButton = [tabBarView lastAttachedButton];
    MMAttachedTabBarButtonCell *lastAttachedButtonCell = [lastAttachedButton cell];

    if ([lastAttachedButton isSliding])
        return;
    
	NSRect cellFrame = [overflowButton frame];
        
    NSImage *left = nil;
    NSImage *right = nil;
    NSImage *center = nil;
    
        // Draw selected
	if ([lastAttachedButtonCell state] == NSOnState) {
		NSRect aRect = NSMakeRect(cellFrame.origin.x, cellFrame.origin.y, cellFrame.size.width, cellFrame.size.height);
        aRect.size.width += 5.0f;
        
            // proper tint
		NSControlTint currentTint;
		if ([lastAttachedButtonCell controlTint] == NSDefaultControlTint) {
			currentTint = [NSColor currentControlTint];
		} else{
			currentTint = [lastAttachedButtonCell controlTint];
		}

		if (![tabBarView isWindowActive]) {
			currentTint = NSClearControlTint;
		}

		switch(currentTint) {
            case NSGraphiteControlTint:
                center = aquaTabBgDownGraphite;
                break;
            case NSClearControlTint:
                center = aquaTabBgDownNonKey;
                break;
            case NSBlueControlTint:
            default:
                center = aquaTabBgDown;
                break;
        }

        if ([tabBarView showAddTabButton]) {
            right = aquaDivider;
        }
        
        NSDrawThreePartImage(aRect, left, center, right, NO, NSCompositeSourceOver, 1.0f,[tabBarView isFlipped]);

        // Draw unselected
	} else {
		NSRect aRect = NSMakeRect(cellFrame.origin.x, cellFrame.origin.y, cellFrame.size.width, cellFrame.size.height);
        aRect.size.width += 5.0f;
        
            // Rollover
		if ([lastAttachedButton mouseHovered]) {
			[[NSColor colorWithCalibratedWhite:0.0 alpha:0.1] set];
			NSRectFillUsingOperation(aRect, NSCompositeSourceAtop);
		}
        
        if ([tabBarView showAddTabButton])
            right = aquaDivider;
        
        NSDrawThreePartImage(aRect, left, center, right, NO, NSCompositeSourceOver, 1.0f,[tabBarView isFlipped]);
	}
}

#pragma mark -
#pragma mark Archiving

- (void)encodeWithCoder:(NSCoder *)aCoder {
	//[super encodeWithCoder:aCoder];
	if ([aCoder allowsKeyedCoding]) {
		[aCoder encodeObject:aquaTabBg forKey:@"aquaTabBg"];
		[aCoder encodeObject:aquaTabBgDown forKey:@"aquaTabBgDown"];
		[aCoder encodeObject:aquaTabBgDownGraphite forKey:@"aquaTabBgDownGraphite"];
		[aCoder encodeObject:aquaTabBgDownNonKey forKey:@"aquaTabBgDownNonKey"];
		[aCoder encodeObject:aquaDividerDown forKey:@"aquaDividerDown"];
		[aCoder encodeObject:aquaDivider forKey:@"aquaDivider"];
		[aCoder encodeObject:aquaCloseButton forKey:@"aquaCloseButton"];
		[aCoder encodeObject:aquaCloseButtonDown forKey:@"aquaCloseButtonDown"];
		[aCoder encodeObject:aquaCloseButtonOver forKey:@"aquaCloseButtonOver"];
		[aCoder encodeObject:aquaCloseDirtyButton forKey:@"aquaCloseDirtyButton"];
		[aCoder encodeObject:aquaCloseDirtyButtonDown forKey:@"aquaCloseDirtyButtonDown"];
		[aCoder encodeObject:aquaCloseDirtyButtonOver forKey:@"aquaCloseDirtyButtonOver"];
	}
}

- (id)initWithCoder:(NSCoder *)aDecoder {
	//self = [super initWithCoder:aDecoder];
	//if (self) {
	if ([aDecoder allowsKeyedCoding]) {
		aquaTabBg = [[aDecoder decodeObjectForKey:@"aquaTabBg"] retain];
		aquaTabBgDown = [[aDecoder decodeObjectForKey:@"aquaTabBgDown"] retain];
		aquaTabBgDownGraphite = [[aDecoder decodeObjectForKey:@"aquaTabBgDownGraphite"] retain];
		aquaTabBgDownNonKey = [[aDecoder decodeObjectForKey:@"aquaTabBgDownNonKey"] retain];
		aquaDividerDown = [[aDecoder decodeObjectForKey:@"aquaDividerDown"] retain];
		aquaDivider = [[aDecoder decodeObjectForKey:@"aquaDivider"] retain];
		aquaCloseButton = [[aDecoder decodeObjectForKey:@"aquaCloseButton"] retain];
		aquaCloseButtonDown = [[aDecoder decodeObjectForKey:@"aquaCloseButtonDown"] retain];
		aquaCloseButtonOver = [[aDecoder decodeObjectForKey:@"aquaCloseButtonOver"] retain];
		aquaCloseDirtyButton = [[aDecoder decodeObjectForKey:@"aquaCloseDirtyButton"] retain];
		aquaCloseDirtyButtonDown = [[aDecoder decodeObjectForKey:@"aquaCloseDirtyButtonDown"] retain];
		aquaCloseDirtyButtonOver = [[aDecoder decodeObjectForKey:@"aquaCloseDirtyButtonOver"] retain];
	}
	//}
	return self;
}

@end

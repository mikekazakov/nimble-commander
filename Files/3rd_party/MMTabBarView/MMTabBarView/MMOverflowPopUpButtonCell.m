//
//  MMOverflowPopUpButtonCell.m
//  MMTabBarView
//
//  Created by Michael Monscheuer on 9/24/12.
//  Copyright (c) 2012 Michael Monscheuer. All rights reserved.
//

#import "MMOverflowPopUpButtonCell.h"
#import "NSCell+MMTabBarViewExtensions.h"

@interface MMOverflowPopUpButtonCell (/*Private*/)

- (NSRect)_imageRectForBounds:(NSRect)theRect forImage:(NSImage *)anImage;

@end

@implementation MMOverflowPopUpButtonCell

@dynamic image;
@synthesize secondImage = _secondImage;
@synthesize secondImageAlpha = _secondImageAlpha;
@synthesize bezelDrawingBlock = _bezelDrawingBlock;

- (id)initTextCell:(NSString *)stringValue pullsDown:(BOOL)pullDown {
    self = [super initTextCell:stringValue pullsDown:pullDown];
    if (self) {
        _bezelDrawingBlock = nil;
        _image = nil;
        _secondImage = nil;
        _secondImageAlpha = 0.0;
    }

    return self;
}

- (void)dealloc
{
    [_bezelDrawingBlock release], _bezelDrawingBlock = nil;
    [_image release], _image = nil;
    [_secondImage release], _secondImage = nil;
    
    [super dealloc];
}

#pragma mark -
#pragma mark Accessors

- (NSImage *)image {
    return _image;
}

- (void)setImage:(NSImage *)image {

        // as super class ignores setting image, we store it separately.
    if (_image) {
        [_image release], _image = nil;
    }
    
    _image = [image retain];
}

#pragma mark -
#pragma mark Drawing

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {

    [self drawBezelWithFrame:cellFrame inView:controlView];
    [self drawInteriorWithFrame:cellFrame inView:controlView];
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    [self drawImageWithFrame:cellFrame inView:controlView];
}

- (void)drawImageWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {

    if ([self isHighlighted])
        [self drawImage:[self alternateImage] withFrame:cellFrame inView:controlView];
    else {
        [self drawImage:[self image] withFrame:cellFrame inView:controlView];
        
        if (_secondImage) {
            [self drawImage:_secondImage withFrame:cellFrame inView:controlView alpha:_secondImageAlpha];
        }
    }
}

- (void)drawImage:(NSImage *)image withFrame:(NSRect)frame inView:(NSView *)controlView {
    [self drawImage:image withFrame:frame inView:controlView alpha:1.0];
}

- (void)drawImage:(NSImage *)image withFrame:(NSRect)frame inView:(NSView *)controlView alpha:(CGFloat)alpha {

    NSRect theRect = [self _imageRectForBounds:frame forImage:image];
    
    [image drawInRect:theRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:alpha respectFlipped:YES hints:nil];
}

- (void)drawBezelWithFrame:(NSRect)frame inView:(NSView *)controlView {
    if (_bezelDrawingBlock) {
        _bezelDrawingBlock(self,frame,controlView);
    }
}

#pragma mark -
#pragma mark Copying

- (id)copyWithZone:(NSZone *)zone {
    
    MMOverflowPopUpButtonCell *cellCopy = [super copyWithZone:zone];
    if (cellCopy) {
    
        cellCopy->_image = [_image copyWithZone:zone];
        cellCopy->_secondImage = [_secondImage copyWithZone:zone];
    }
    
    return cellCopy;
}

#pragma mark -
#pragma mark Archiving

- (void)encodeWithCoder:(NSCoder *)aCoder {
	[super encodeWithCoder:aCoder];

	if ([aCoder allowsKeyedCoding]) {
        [aCoder encodeObject:_image forKey:@"MMTabBarOverflowPopUpImage"];
        [aCoder encodeObject:_secondImage forKey:@"MMTabBarOverflowPopUpSecondImage"];
	}
}

- (id)initWithCoder:(NSCoder *)aDecoder {
	if ((self = [super initWithCoder:aDecoder])) {
		if ([aDecoder allowsKeyedCoding]) {
        
            _image = [[aDecoder decodeObjectForKey:@"MMTabBarOverflowPopUpImage"] retain];
            _secondImage = [[aDecoder decodeObjectForKey:@"MMTabBarOverflowPopUpSecondImage"] retain];
		}
	}
	return self;
}

#pragma mark -
#pragma mark Private Methods

-(NSRect)_imageRectForBounds:(NSRect)theRect forImage:(NSImage *)anImage {
    
    // calculate rect
    NSRect drawingRect = [self drawingRectForBounds:theRect];
        
    NSSize imageSize = [anImage size];
    
    NSSize scaledImageSize = [self mm_scaleImageWithSize:imageSize toFitInSize:NSMakeSize(imageSize.width, drawingRect.size.height) scalingType:NSImageScaleProportionallyDown];

    NSRect result = NSMakeRect(NSMaxX(drawingRect)-scaledImageSize.width, drawingRect.origin.y, scaledImageSize.width, scaledImageSize.height);

    if (scaledImageSize.height < drawingRect.size.height) {
        result.origin.y += ceil((drawingRect.size.height - scaledImageSize.height) / 2.0);
    }

    return NSIntegralRect(result);
}
@end

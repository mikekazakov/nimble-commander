//
//  FeatureNotAvailableWindowController.m
//  Files
//
//  Created by Michael G. Kazakov on 01/12/15.
//  Copyright © 2015 Michael G. Kazakov. All rights reserved.
//

#include "FeatureNotAvailableWindowController.h"

static NSMutableAttributedString* Hyperlink(NSString* _string, NSURL* _url)
{
    NSMutableAttributedString* str = [[NSMutableAttributedString alloc] initWithString: _string];
    NSRange range = NSMakeRange(0, str.length);
    
    [str beginEditing];
    [str addAttribute:NSLinkAttributeName value:_url.absoluteString range:range];
    
    // make the text appear in blue
    [str addAttribute:NSForegroundColorAttributeName value:NSColor.blueColor range:range];
    
    // next make the text appear with an underline
    [str addAttribute:NSUnderlineStyleAttributeName value:@(NSUnderlineStyleSingle) range:range];
    
    [str endEditing];
    
    return str;
}

static NSMutableAttributedString *PlaceHyperlinks(NSString *_source)
{
    NSMutableAttributedString* result = [[NSMutableAttributedString alloc] init];
    auto dollar = [NSCharacterSet characterSetWithCharactersInString:@"$"];
    unsigned long position = 0;
    const auto full_length = _source.length;
    while( position < full_length ) {
        auto r1 = [_source rangeOfCharacterFromSet:dollar
                                          options:0
                                            range:NSMakeRange(position, full_length - position)];
        
        if( r1.location == NSNotFound ) {
            auto raw = [_source substringWithRange:NSMakeRange(position, full_length - position)];
            [result appendAttributedString:[[NSMutableAttributedString alloc] initWithString:raw]];
            break;
        }
        else {
            if( r1.location != position ) {
                auto raw = [_source substringWithRange:NSMakeRange(position, r1.location - position)];
                [result appendAttributedString:[[NSMutableAttributedString alloc] initWithString:raw]];
            }
            
            auto r2 = [_source rangeOfCharacterFromSet:dollar
                                               options:0
                                                 range:NSMakeRange(r1.location + 1, full_length - r1.location - 1)];
            if( r2.location == NSNotFound )
                break;
            
            auto r3 = [_source rangeOfCharacterFromSet:dollar
                                               options:0
                                                 range:NSMakeRange(r2.location + 1, full_length - r2.location - 1)];
            
            if( r3.location == NSNotFound )
                break;
            
            auto text = [_source substringWithRange:NSMakeRange(r1.location + 1, r2.location - r1.location - 1)];
            auto url = [_source substringWithRange:NSMakeRange(r2.location + 1, r3.location - r2.location - 1)];
            auto part = Hyperlink(text, [NSURL URLWithString:url]);
            [result appendAttributedString:part];
            position = r3.location + 1;
        }
    }
    return result;
}

@interface FeatureNotAvailableWindow : NSPanel
@end
@implementation FeatureNotAvailableWindow
- (BOOL) canBecomeKeyWindow
{
    return true;
}

- (BOOL) canBecomeMainWindow
{
    return true;
}
- (void)close
{
    [super close];
    [NSApp stopModalWithCode:NSModalResponseOK];
}
@end

@interface FeatureNotAvailableTextView : NSTextView
@end
@implementation FeatureNotAvailableTextView
{
    NSTrackingArea *_trackingArea;
}

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _trackingArea = [[NSTrackingArea alloc]initWithRect:[self bounds] options: (NSTrackingMouseMoved | NSTrackingActiveInKeyWindow) owner:self userInfo:nil];
        [self addTrackingArea:_trackingArea];
    }
    return self;
}

- (void)mouseMoved:(NSEvent *)event
{
    [NSCursor.arrowCursor set];
}

- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    [self removeTrackingArea:_trackingArea];
    _trackingArea = [[NSTrackingArea alloc] initWithRect:[self bounds] options: (NSTrackingMouseMoved | NSTrackingActiveInKeyWindow) owner:self userInfo:nil];
    [self addTrackingArea:_trackingArea];
}

@end


@implementation FeatureNotAvailableWindowController

- (id)init
{
    self = [super initWithWindowNibName:NSStringFromClass(self.class)];
    if(self) {
        (void)self.window;
        self.window.movableByWindowBackground = true;
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    self.textView.frame =  self.textView.superview.superview.bounds;
    self.textView.maxSize = self.textView.superview.superview.bounds.size;
    self.textView.minSize = self.textView.superview.superview.bounds.size;
    self.textView.alignment = NSTextAlignmentCenter;
    [self.textView.textStorage setAttributedString:PlaceHyperlinks(NSLocalizedString(@"__GENERAL_FEATURE_NOT_AVAILABLE", ""))];
}

- (IBAction)OnClose:(id)sender
{
    [self.window close];
}

@end

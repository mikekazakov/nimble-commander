#import "MMTabBarStyle.h"
#import "3rd_party/MMTabBarView/MMTabBarView/MMAttachedTabBarButton.h"
#import "3rd_party/MMTabBarView/MMTabBarView/NSView+MMTabBarViewExtensions.h"

static CGColorRef DividerColor(bool _wnd_active)
{
    static CGColorRef act = CGColorCreateGenericRGB(176/255.0, 176/255.0, 176/255.0, 1.0);
    static CGColorRef inact = CGColorCreateGenericRGB(225/255.0, 225/255.0, 225/255.0, 1.0);
    return _wnd_active ? act : inact;
}

@implementation MMTabBarStyle

+ (NSString *)name {
    return @"Files";
}

- (NSString *)name {
	return self.class.name;
}

- (CGFloat)leftMarginForTabBarView:(MMTabBarView *)tabBarView
{
    return 0.0;
}

- (CGFloat)rightMarginForTabBarView:(MMTabBarView *)tabBarView
{
    return 0.0;
}

- (CGFloat)topMarginForTabBarView:(MMTabBarView *)tabBarView
{
    return 0.0;
}

- (CGFloat)bottomMarginForTabBarView:(MMTabBarView *)tabBarView
{
    return 0.0;
}

- (CGFloat)heightOfTabBarButtonsForTabBarView:(MMTabBarView *)tabBarView
{
    return kMMTabBarViewHeight;
}

- (BOOL)supportsOrientation:(MMTabBarOrientation)orientation forTabBarView:(MMTabBarView *)tabBarView
{
    return orientation == MMTabBarHorizontalOrientation;
}

- (NSRect)draggingRectForTabButton:(MMAttachedTabBarButton *)aButton ofTabBarView:(MMTabBarView *)tabBarView {

	NSRect dragRect = [aButton stackingFrame];
	dragRect.size.width++;
	return dragRect;
}

- (NSImage *)closeButtonImageOfType:(MMCloseButtonImageType)type forTabCell:(MMTabBarButtonCell *)cell
{
    static NSImage *def   = [NSImage imageNamed:@"tab_close"];
    static NSImage *hover = [NSImage imageNamed:@"tab_close_hover"];
    static NSImage *press = [NSImage imageNamed:@"tab_close_press"];
    
    switch (type) {
        case MMCloseButtonImageTypeStandard:
            return def;
        case MMCloseButtonImageTypeRollover:
            return hover;
        case MMCloseButtonImageTypePressed:
            return press;
/*
        case MMCloseButtonImageTypeDirty:
            return cardCloseDirtyButton;
        case MMCloseButtonImageTypeDirtyRollover:
            return cardCloseDirtyButtonOver;
        case MMCloseButtonImageTypeDirtyPressed:
            return cardCloseDirtyButtonDown;*/
            
        default:
            return def;
    }
}

- (void)drawBezelOfTabBarView:(MMTabBarView *)tabBarView inRect:(NSRect)rect {
    NSDrawWindowBackground(rect);
    
    CGContextRef context = (CGContextRef)NSGraphicsContext.currentContext.graphicsPort;

    // draw horizontal divider line
    CGContextSaveGState(context);
    CGContextSetStrokeColorWithColor(context, DividerColor(tabBarView.isWindowActive));
    NSPoint points[2] = { {rect.origin.x, tabBarView.bounds.size.height - 0.5},
                          {rect.origin.x + rect.size.width, tabBarView.bounds.size.height - 0.5} };
    CGContextStrokeLineSegments(context, points, 2);
    CGContextRestoreGState(context);
}

- (void)drawBezelOfTabCell:(MMTabBarButtonCell *)cell withFrame:(NSRect)frame inView:(NSView *)controlView
{
    frame.size.height -= 1; // for horizontal divider drawn by drawBezelOfTabBarView
    
    MMTabBarView *tabBarView = [controlView enclosingTabBarView];
    MMAttachedTabBarButton *button = (MMAttachedTabBarButton *)controlView;
    bool wnd_active = [tabBarView isWindowActive];
    bool tab_selected = [button state] == NSOnState;
    bool tab_isfr = tab_selected && tabBarView.tabView.selectedTabViewItem.view == tabBarView.window.firstResponder;
    bool button_hovered = [button mouseHovered];
    CGContextRef context = (CGContextRef)NSGraphicsContext.currentContext.graphicsPort;
    CGContextSaveGState(context);
    if(tab_selected) {
        if(wnd_active) {
            if(tab_isfr) {
                static CGColorRef bg = CGColorCreateGenericRGB(256./256., 256./256., 256./256., 1);
                CGContextSetFillColorWithColor(context, bg);
                CGContextFillRect(context, frame);
            }
            else
                NSDrawWindowBackground(frame);
        }
        else
            NSDrawWindowBackground(frame);
    }
    else {
        if(wnd_active) {
            if(!button_hovered) {
                static CGColorRef bg = CGColorCreateGenericRGB(185./256., 185./256., 185./256., 1);
                CGContextSetFillColorWithColor(context, bg);
                CGContextFillRect(context, frame);
            }
            else {
                static CGColorRef bg = CGColorCreateGenericRGB(165./256., 165./256., 165./256., 1);
                CGContextSetFillColorWithColor(context, bg);
                CGContextFillRect(context, frame);
            }
        }
        else
            NSDrawWindowBackground(frame);
    }

    // draw vertical divider
    CGContextSetStrokeColorWithColor(context, DividerColor(wnd_active));
    NSPoint points[2] = { {frame.origin.x + frame.size.width - 0.5, frame.origin.y} ,
        {frame.origin.x + frame.size.width - 0.5, frame.origin.y + frame.size.height} };
    CGContextStrokeLineSegments(context, points, 2);
    CGContextRestoreGState(context);
}

- (void)drawTitleOfTabCell:(MMTabBarButtonCell *)cell withFrame:(NSRect)frame inView:(NSView *)controlView
{
    CGContextRef context = (CGContextRef)NSGraphicsContext.currentContext.graphicsPort;
    CGContextSaveGState(context);
    CGContextSetShouldSmoothFonts((CGContextRef)NSGraphicsContext.currentContext.graphicsPort, false);

    // draw title
    [[cell attributedStringValue] drawInRect:[cell titleRectForBounds:frame]];
    
   CGContextRestoreGState(context);
}

- (void)updateAddButton:(MMRolloverButton *)aButton ofTabBarView:(MMTabBarView *)tabBarView
{
    static NSImage *img;
    static once_flag once;
    call_once(once, []{
        img = [NSImage imageNamed:@"tab_add"];
        [img setTemplate:true];
    });
    
    aButton.image = img;
    aButton.alternateImage = nil;
}

- (NSSize)addTabButtonSizeForTabBarView:(MMTabBarView *)tabBarView
{
    return NSMakeSize(12.0,20.0);
}

@end

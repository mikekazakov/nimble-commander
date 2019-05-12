#include "PreviewModeView.h"
#include <Quartz/Quartz.h>
#include <Utility/StringExtras.h>

@implementation NCViewerPreviewModeView
{
    std::string m_Path;
    const nc::viewer::Theme *m_Theme;
    QLPreviewView *m_Preview;
}

- (instancetype)initWithFrame:(NSRect)_frame
                         path:(const std::string&)_path
                        theme:(const nc::viewer::Theme&)_theme
{
    if( self = [super initWithFrame:_frame] ) {
        self.translatesAutoresizingMaskIntoConstraints = false;
        m_Path = _path;
        m_Theme = &_theme;
        
        m_Preview = [[QLPreviewView alloc] initWithFrame:NSMakeRect(0,
                                                                    0,
                                                                    _frame.size.width, 
                                                                    _frame.size.height)];
        m_Preview.translatesAutoresizingMaskIntoConstraints = false;
        [self addFillingSubview:m_Preview];        
        
        if( const auto url = [NSURL fileURLWithPath:[NSString stringWithUTF8StdString:m_Path]] )
            m_Preview.previewItem = url;
    }
    return self;
}

- (void) addFillingSubview:(NSView*)_view
{
    [self addSubview:_view];
    const auto views = NSDictionaryOfVariableBindings(_view);
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:
                          @"|-(==0)-[_view]-(==0)-|" options:0 metrics:nil views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:
                          @"V:|-(==0)-[_view]-(==0)-|" options:0 metrics:nil views:views]];
}

- (void)drawRect:(NSRect)_dirty_rect
{
    const auto context = NSGraphicsContext.currentContext.CGContext;
    CGContextSetFillColorWithColor(context, m_Theme->ViewerBackgroundColor().CGColor );
    CGContextFillRect(context, NSRectToCGRect(_dirty_rect));
}

- (void) themeHasChanged
{
    [self setNeedsDisplay:true];
}

@end

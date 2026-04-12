// Copyright (C) 2016-2026 Michael Kazakov. Subject to GNU General Public License version 3.
#import "NCPanelPathBarView.h"
#import "NCPanelBreadcrumbsView.h"

@implementation NCPanelPathBarView {
    NCPanelBreadcrumbsView *m_Breadcrumbs;
    NSTextField *m_PathField;
    NSLayoutConstraint *m_PathFieldCenterY;
}

@synthesize breadcrumbsView = m_Breadcrumbs;
@synthesize pathEditField = m_PathField;
@synthesize fullPathEditActive = _fullPathEditActive;
@synthesize onCommitEditedPath = _onCommitEditedPath;
@synthesize onCancelFullPathEdit = _onCancelFullPathEdit;

- (instancetype)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if( self ) {
        self.clipsToBounds = YES;
        m_Breadcrumbs = [[NCPanelBreadcrumbsView alloc] initWithFrame:NSZeroRect];
        m_Breadcrumbs.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:m_Breadcrumbs];

        m_PathField = [[NSTextField alloc] initWithFrame:NSZeroRect];
        m_PathField.translatesAutoresizingMaskIntoConstraints = NO;
        m_PathField.bezeled = NO;
        m_PathField.bordered = NO;
        m_PathField.drawsBackground = NO;
        m_PathField.focusRingType = NSFocusRingTypeNone;
        m_PathField.editable = YES;
        m_PathField.selectable = YES;
        m_PathField.alignment = NSTextAlignmentCenter;
        m_PathField.lineBreakMode = NSLineBreakByTruncatingHead;
        m_PathField.maximumNumberOfLines = 1;
        m_PathField.hidden = YES;
        m_PathField.delegate = self;
        [self addSubview:m_PathField];

        self.fullPathEditActive = NO;

        m_PathFieldCenterY = [m_PathField.centerYAnchor constraintEqualToAnchor:self.centerYAnchor];
        [NSLayoutConstraint activateConstraints:@[
            [m_Breadcrumbs.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [m_Breadcrumbs.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [m_Breadcrumbs.topAnchor constraintEqualToAnchor:self.topAnchor],
            [m_Breadcrumbs.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
            m_PathFieldCenterY,
            [m_PathField.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:8],
            [m_PathField.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-8],
        ]];
    }
    return self;
}

- (void)syncPathEditFieldVerticalAlignmentWithFont:(NSFont *)font
{
    NSFont *const f = font ?: [NSFont systemFontOfSize:13.];
    NSLayoutManager *const lm = [[NSLayoutManager alloc] init];
    const CGFloat lineH = [lm defaultLineHeightForFont:f];
    const CGFloat stripH = NSHeight(self.bounds);
    if( stripH < 2. ) {
        m_PathFieldCenterY.constant = 0.;
        return;
    }
    const CGFloat geometric = (stripH - lineH) * 0.5;
    const CGFloat y = NCPanelPathBarContainerOriginYForLine(f, stripH, lineH, 0.);
    m_PathFieldCenterY.constant = y - geometric;
}

- (void)layout
{
    [super layout];
    if( self.fullPathEditActive && m_PathField.font != nil )
        [self syncPathEditFieldVerticalAlignmentWithFont:m_PathField.font];
}

- (void)enterFullPathEditWithString:(NSString *)path font:(NSFont *)font textColor:(NSColor *)textColor
{
    m_PathField.font = font;
    m_PathField.textColor = textColor;
    m_PathField.stringValue = path ?: @"";
    [self syncPathEditFieldVerticalAlignmentWithFont:font];
    m_Breadcrumbs.hidden = YES;
    m_PathField.hidden = NO;
    self.fullPathEditActive = YES;
    [self.window makeFirstResponder:m_PathField];
    [m_PathField selectText:nil];
}

- (void)exitFullPathEdit
{
    m_PathFieldCenterY.constant = 0.;
    m_Breadcrumbs.hidden = NO;
    m_PathField.hidden = YES;
    self.fullPathEditActive = NO;
}

- (BOOL)control:(NSControl *)control
           textView:(NSTextView *)textView
    doCommandBySelector:(SEL)commandSelector
{
    (void)textView;
    if( control != m_PathField )
        return NO;
    if( commandSelector == @selector(cancelOperation:) ) {
        if( self.onCancelFullPathEdit )
            self.onCancelFullPathEdit();
        return YES;
    }
    if( commandSelector == @selector(insertNewline:) ) {
        if( self.onCommitEditedPath )
            self.onCommitEditedPath(m_PathField.stringValue ?: @"");
        return YES;
    }
    return NO;
}

@end

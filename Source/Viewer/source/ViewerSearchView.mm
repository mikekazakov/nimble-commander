// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ViewerSearchView.h"
#include "Internal.h"

using namespace nc::viewer;

@implementation NCViewerSearchView {
    NSSearchField *m_SearchField;
    NSProgressIndicator *m_SearchProgressIndicator;
    NSButton *m_CloseButton;
    NSColor *m_BorderColor;
    NSVisualEffectView *m_Background;
}

- (instancetype)initWithFrame:(NSRect)_frame
{
    self = [super initWithFrame:_frame];
    if( self ) {
        m_BorderColor = NSColor.placeholderTextColor;

        m_SearchField = [[NSSearchField alloc] initWithFrame:NSRect()];
        m_SearchField.translatesAutoresizingMaskIntoConstraints = false;
        [self addSubview:m_SearchField];

        m_SearchProgressIndicator = [[NSProgressIndicator alloc] initWithFrame:NSRect()];
        m_SearchProgressIndicator.translatesAutoresizingMaskIntoConstraints = false;
        m_SearchProgressIndicator.style = NSProgressIndicatorStyleSpinning;
        m_SearchProgressIndicator.indeterminate = true;
        m_SearchProgressIndicator.displayedWhenStopped = false;
        [self addSubview:m_SearchProgressIndicator];

        m_CloseButton = [[NSButton alloc] initWithFrame:NSRect()];
        m_CloseButton.image = [Bundle() imageForResource:@"xmark"];
        [m_CloseButton.image setTemplate:true];
        m_CloseButton.imagePosition = NSImageOnly;
        m_CloseButton.imageScaling = NSImageScaleNone;
        m_CloseButton.translatesAutoresizingMaskIntoConstraints = false;
        m_CloseButton.bordered = false;
        m_CloseButton.bezelStyle = NSBezelStyleToolbar;
        m_CloseButton.buttonType = NSButtonTypeMomentaryPushIn;
        m_CloseButton.target = self;
        m_CloseButton.action = @selector(onClose:);
        [self addSubview:m_CloseButton];

        m_Background = [[NSVisualEffectView alloc] initWithFrame:NSRect()];
        m_Background.translatesAutoresizingMaskIntoConstraints = false;
        m_Background.wantsLayer = true;
        m_Background.blendingMode = NSVisualEffectBlendingModeWithinWindow;
        m_Background.material = NSVisualEffectMaterialSheet;
        m_Background.state = NSVisualEffectStateFollowsWindowActiveState;
        m_Background.layer.cornerRadius = 8.;
        m_Background.layer.borderColor = m_BorderColor.CGColor;
        m_Background.layer.borderWidth = 1;
        [self addSubview:m_Background positioned:NSWindowBelow relativeTo:self.subviews.firstObject];

        const auto views =
            NSDictionaryOfVariableBindings(m_SearchProgressIndicator, m_SearchField, m_CloseButton, m_Background);
        const auto add = [&](NSString *_vf) {
            auto constraints = [NSLayoutConstraint constraintsWithVisualFormat:_vf options:0 metrics:nil views:views];
            [self addConstraints:constraints];
        };

        add(@"V:[m_SearchField(==22)]");
        add(@"V:[m_SearchProgressIndicator(==16)]");
        add(@"|-(==12)-[m_SearchProgressIndicator(==16)]-(==8)-[m_SearchField(>=100)]-(==8)-[m_CloseButton(==16)]-(=="
            @"12)-|");
        add(@"|-(==0)-[m_Background]-(==0)-|");
        add(@"V:|-(==0)-[m_Background]-(==0)-|");

        [NSLayoutConstraint activateConstraints:@[
            [m_SearchField.centerYAnchor constraintEqualToAnchor:self.centerYAnchor constant:0.],
            [m_CloseButton.centerYAnchor constraintEqualToAnchor:self.centerYAnchor constant:0.],
            [m_SearchProgressIndicator.centerYAnchor constraintEqualToAnchor:self.centerYAnchor constant:0.],
            [self.heightAnchor constraintEqualToConstant:40.],
        ]];

        self.wantsLayer = YES;
        [self makeBackingLayer];

        NSShadow *shadow = [[NSShadow alloc] init];
        shadow.shadowOffset = NSMakeSize(0, 0);
        shadow.shadowBlurRadius = 2;
        self.shadow = shadow;
    }
    return self;
}

- (NSSize)intrinsicContentSize
{
    return NSMakeSize(300., 40.);
}

- (void)viewDidChangeEffectiveAppearance
{
    [super viewDidChangeEffectiveAppearance];

    if( @available(macOS 11, *) ) {
        [NSApp.effectiveAppearance performAsCurrentDrawingAppearance:^{
          m_Background.layer.borderColor = m_BorderColor.CGColor;
        }];
    }
    else {
        NSAppearance *curr = NSAppearance.currentAppearance;
        NSAppearance.currentAppearance = NSApp.effectiveAppearance;
        m_Background.layer.borderColor = m_BorderColor.CGColor;
        NSAppearance.currentAppearance = curr;
    }
}

- (NSSearchField *)searchField
{
    return m_SearchField;
}

- (NSProgressIndicator *)progressIndicator
{
    return m_SearchProgressIndicator;
}

- (void)onClose:(id)_sender
{
    self.hidden = true;
}

@end

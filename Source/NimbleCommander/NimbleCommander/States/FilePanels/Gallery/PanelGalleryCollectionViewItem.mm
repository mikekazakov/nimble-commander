// Copyright (C) 2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelGalleryCollectionViewItem.h"

@implementation NCPanelGalleryCollectionViewItem {
    NSImageView *m_ImageView;
    NSTextField *m_Label;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.wantsLayer = YES; // Required for layer-backed background

    m_ImageView = [[NSImageView alloc]
        initWithFrame:NSMakeRect(0, 20, self.view.bounds.size.width, self.view.bounds.size.height - 20)];
    m_ImageView.imageScaling = NSImageScaleProportionallyUpOrDown;
    m_ImageView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

    m_Label = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, self.view.bounds.size.width, 20)];
    m_Label.editable = NO;
    m_Label.bezeled = NO;
    m_Label.drawsBackground = NO;
    m_Label.alignment = NSTextAlignmentCenter;
    m_Label.font = [NSFont systemFontOfSize:12];
    m_Label.autoresizingMask = NSViewWidthSizable;

    [self.view addSubview:m_ImageView];
    [self.view addSubview:m_Label];

    self.imageView = m_ImageView;
    self.textField = m_Label;
}

- (void)setSelected:(BOOL)selected
{
    [super setSelected:selected];

    if( selected ) {
        self.view.layer.backgroundColor = [[NSColor alternateSelectedControlColor] CGColor];
    }
    else {
        self.view.layer.backgroundColor = [[NSColor clearColor] CGColor];
    }
}

@end

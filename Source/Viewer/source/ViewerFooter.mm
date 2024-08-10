// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ViewerFooter.h"
#include "Internal.h"
#include <Utility/ObjCpp.h>
#include <Utility/ColoredSeparatorLine.h>
#include <Utility/VerticallyCenteredTextFieldCell.h>
#include <Utility/ByteCountFormatter.h>
#include <Utility/Encodings.h>
#include <utility>

using namespace nc;
using namespace nc::viewer;

@implementation NCViewerFooter {
    ViewMode m_Mode;
    utility::Encoding m_Encoding;
    uint64_t m_FileSize;
    bool m_WrapLines;

    ColoredSeparatorLine *m_SeparatorLine;
    NSPopUpButton *m_ModeButton;
    NSPopUpButton *m_EncodingButton;
    NSButton *m_LineWrapButton;
    NSTextField *m_FileSizeLabel;
}

- (instancetype)initWithFrame:(NSRect)_frame
{
    if( self = [super initWithFrame:_frame] ) {
        m_Mode = ViewMode::Text;
        m_Encoding = utility::Encoding::ENCODING_UTF8;
        m_FileSize = 0;
        m_WrapLines = false;

        [self buildControls];
        [self layoutControls];
    }
    return self;
}

- (void)buildControls
{
    m_SeparatorLine = [[ColoredSeparatorLine alloc] initWithFrame:NSRect()];
    m_SeparatorLine.translatesAutoresizingMaskIntoConstraints = false;
    m_SeparatorLine.borderColor = NSColor.systemPinkColor;
    [self addSubview:m_SeparatorLine];

    NSMenu *mode_menu = [[NSMenu alloc] init];
    [mode_menu addItemWithTitle:@"Text" action:nullptr keyEquivalent:@""].tag = static_cast<int>(ViewMode::Text);
    [mode_menu addItemWithTitle:@"Hex" action:nullptr keyEquivalent:@""].tag = static_cast<int>(ViewMode::Hex);
    [mode_menu addItemWithTitle:@"Preview" action:nullptr keyEquivalent:@""].tag = static_cast<int>(ViewMode::Preview);

    m_ModeButton = [[NSPopUpButton alloc] initWithFrame:NSRect() pullsDown:false];
    m_ModeButton.imagePosition = NSNoImage;
    m_ModeButton.bordered = false;
    m_ModeButton.menu = mode_menu;
    [m_ModeButton selectItemWithTag:std::to_underlying(m_Mode)];
    m_ModeButton.target = self;
    m_ModeButton.action = @selector(onModeChanged:);
    m_ModeButton.translatesAutoresizingMaskIntoConstraints = false;
    [self addSubview:m_ModeButton];

    NSMenu *encoding_menu = [[NSMenu alloc] init];
    for( const auto &encoding : utility::LiteralEncodingsList() ) {
        [encoding_menu addItemWithTitle:(__bridge NSString *)encoding.second action:nullptr keyEquivalent:@""].tag =
            std::to_underlying(encoding.first);
    }

    m_EncodingButton = [[NSPopUpButton alloc] initWithFrame:NSRect() pullsDown:false];
    m_EncodingButton.imagePosition = NSNoImage;
    m_EncodingButton.bordered = false;
    m_EncodingButton.menu = encoding_menu;
    [m_EncodingButton selectItemWithTag:std::to_underlying(m_Encoding)];
    m_EncodingButton.target = self;
    m_EncodingButton.action = @selector(onEncodingChanged:);
    m_EncodingButton.translatesAutoresizingMaskIntoConstraints = false;
    [self addSubview:m_EncodingButton];

    m_LineWrapButton = [[NSButton alloc] initWithFrame:NSRect()];
    m_LineWrapButton.image = [Bundle() imageForResource:@"custom.return.left"];
    [m_LineWrapButton.image setTemplate:true];
    m_LineWrapButton.imagePosition = NSImageOnly;
    m_LineWrapButton.imageScaling = NSImageScaleNone;
    m_LineWrapButton.translatesAutoresizingMaskIntoConstraints = false;
    m_LineWrapButton.bordered = false;
    m_LineWrapButton.bezelStyle = NSBezelStyleToolbar;
    m_LineWrapButton.buttonType = NSButtonTypeToggle;
    m_LineWrapButton.target = self;
    m_LineWrapButton.action = @selector(onWrappingChanged:);
    m_LineWrapButton.toolTip = NSLocalizedString(@"Wrap lines", "Tooltip for the footer element");
    [self addSubview:m_LineWrapButton];

    m_FileSizeLabel = [[NSTextField alloc] initWithFrame:NSRect()];
    m_FileSizeLabel.translatesAutoresizingMaskIntoConstraints = false;
    m_FileSizeLabel.cell = [VerticallyCenteredTextFieldCell new];
    m_FileSizeLabel.stringValue = @"";
    m_FileSizeLabel.bordered = false;
    m_FileSizeLabel.editable = false;
    m_FileSizeLabel.drawsBackground = false;
    m_FileSizeLabel.lineBreakMode = NSLineBreakByClipping;
    m_FileSizeLabel.usesSingleLineMode = true;
    m_FileSizeLabel.alignment = NSTextAlignmentRight;
    [self addSubview:m_FileSizeLabel];
}

- (void)layoutControls
{
    const auto views = NSDictionaryOfVariableBindings(
        m_SeparatorLine, m_ModeButton, m_EncodingButton, m_LineWrapButton, m_FileSizeLabel);
    const auto add = [&](NSString *_vf) {
        auto constraints = [NSLayoutConstraint constraintsWithVisualFormat:_vf options:0 metrics:nil views:views];
        [self addConstraints:constraints];
    };

    add(@"V:|-(==0)-[m_SeparatorLine(==1)]");
    add(@"V:[m_SeparatorLine]-(==0)-[m_ModeButton]-(==0)-|");
    add(@"V:[m_SeparatorLine]-(==0)-[m_FileSizeLabel]-(==0)-|");
    add(@"V:[m_SeparatorLine]-(==0)-[m_EncodingButton]-(==0)-|");
    add(@"V:[m_SeparatorLine]-(==0)-[m_LineWrapButton]-(==0)-|");

    add(@"|-(==0)-[m_SeparatorLine]-(==0)-|");
    add(@"|-(4)-[m_ModeButton]");
    add(@"[m_LineWrapButton(==24)]-(4)-[m_EncodingButton]-(4)-[m_FileSizeLabel]-(4)-|");
}

- (void)setMode:(ViewMode)_mode
{
    if( m_Mode == _mode )
        return; // nothing to do

    [self willChangeValueForKey:@"mode"];
    m_Mode = _mode;
    [self didChangeValueForKey:@"mode"];

    [m_ModeButton selectItemWithTag:std::to_underlying(m_Mode)];

    // TODO: update layouts...
}

- (ViewMode)mode
{
    return m_Mode;
}

- (nc::utility::Encoding)encoding
{
    return m_Encoding;
}

- (void)setEncoding:(nc::utility::Encoding)_encoding
{
    if( m_Encoding == _encoding )
        return; // nothing to do

    [self willChangeValueForKey:@"encoding"];
    m_Encoding = _encoding;
    [self didChangeValueForKey:@"encoding"];

    [m_EncodingButton selectItemWithTag:std::to_underlying(m_Encoding)];
}

- (uint64_t)fileSize
{
    return m_FileSize;
}

- (void)setFileSize:(uint64_t)_size
{
    if( m_FileSize == _size )
        return; // nothing to do

    m_FileSize = _size;
    m_FileSizeLabel.stringValue = ByteCountFormatter::Instance().ToNSString(m_FileSize, ByteCountFormatter::Fixed6);
}

- (bool)wrapLines
{
    return m_WrapLines;
}

- (void)setWrapLines:(bool)_wrap_lines
{
    if( m_WrapLines == _wrap_lines )
        return; // nothing to do

    [self willChangeValueForKey:@"wrapLines"];
    m_WrapLines = _wrap_lines;
    [self didChangeValueForKey:@"wrapLines"];

    m_LineWrapButton.state = m_WrapLines ? NSControlStateValueOn : NSControlStateValueOff;
}

- (IBAction)onModeChanged:(id)_sender
{
    assert(_sender == m_ModeButton);
    self.mode = static_cast<ViewMode>(m_ModeButton.selectedTag); // notifies via KVO
}

- (IBAction)onEncodingChanged:(id)_sender
{
    assert(_sender == m_EncodingButton);
    self.encoding = static_cast<nc::utility::Encoding>(m_EncodingButton.selectedTag); // notifies via KVO
}

- (IBAction)onWrappingChanged:(id)_sender
{
    assert(_sender == m_LineWrapButton);
    self.wrapLines = m_LineWrapButton.state == NSControlStateValueOn;
}

@end

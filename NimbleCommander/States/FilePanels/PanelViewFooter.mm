// Copyright (C) 2016-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelViewFooter.h"
#include <Utility/ByteCountFormatter.h>
#include <Utility/ColoredSeparatorLine.h>
#include <Utility/VerticallyCenteredTextFieldCell.h>
#include <Utility/AdaptiveDateFormatting.h>
#include <Utility/StringExtras.h>
#include "PanelViewPresentationSettings.h"
#include "PanelViewFooterVolumeInfoFetcher.h"

using namespace nc::panel;
using nc::utility::AdaptiveDateFormatting;

static NSString* FileSizeToString(const VFSListingItem &_dirent,
                                  const data::ItemVolatileData &_vd,
                                  ByteCountFormatter::Type _format,
                                  ByteCountFormatter &_fmter)
{
    if( _dirent.IsDir() ) {
        if( _vd.is_size_calculated() ) {
            return _fmter.ToNSString(_vd.size, _format);
        }
        else {
            if( _dirent.IsDotDot() ) {
                return NSLocalizedString(@"__MODERNPRESENTATION_UP_WORD",
                                         "Upper-level in directory, for English is 'Up'");
            }
            else {
                return NSLocalizedString
                (@"__MODERNPRESENTATION_FOLDER_WORD",
                 "Folders dummy string when size is not available, for English is 'Folder'");
            }
        }
    }
    else {
        return _fmter.ToNSString(_dirent.Size(), _format);
    }
}

static NSString* FormHumanReadableBytesAndFiles(uint64_t _sz,
                                                int _total_files,
                                                ByteCountFormatter::Type _format,
                                                ByteCountFormatter &_fmter)
{
    const auto bytes = _fmter.ToNSString(_sz, _format);
    if(_total_files == 1) {
        auto fmt = NSLocalizedString
        (@"Selected %@ in 1 file",
         "Informative text for a bottom information bar in panels, showing size of selection");
        return [NSString stringWithFormat:fmt, bytes];
    }
    else if(_total_files == 2) {
        auto fmt = NSLocalizedString
        (@"Selected %@ in 2 files",
         "Informative text for a bottom information bar in panels, showing size of selection");
        return [NSString stringWithFormat:fmt, bytes];
    }
    else if(_total_files == 3) {
        auto fmt = NSLocalizedString
        (@"Selected %@ in 3 files",
         "Informative text for a bottom information bar in panels, showing size of selection");
        return [NSString stringWithFormat:fmt, bytes];
    }
    else if(_total_files == 4) {
        auto fmt = NSLocalizedString
        (@"Selected %@ in 4 files",
         "Informative text for a bottom information bar in panels, showing size of selection");
        return [NSString stringWithFormat:fmt, bytes];
    }
    else if(_total_files == 5) {
        auto fmt = NSLocalizedString
        (@"Selected %@ in 5 files",
         "Informative text for a bottom information bar in panels, showing size of selection");
        return [NSString stringWithFormat:fmt, bytes];
    }
    else if(_total_files == 6) {
        auto fmt = NSLocalizedString
        (@"Selected %@ in 6 files",
         "Informative text for a bottom information bar in panels, showing size of selection");
        return [NSString stringWithFormat:fmt, bytes];
    }
    else if(_total_files == 7) {
        auto fmt = NSLocalizedString
        (@"Selected %@ in 7 files",
         "Informative text for a bottom information bar in panels, showing size of selection");
        return [NSString stringWithFormat:fmt, bytes];
    }
    else if(_total_files == 8) {
        auto fmt = NSLocalizedString
        (@"Selected %@ in 8 files",
         "Informative text for a bottom information bar in panels, showing size of selection");
        return [NSString stringWithFormat:fmt, bytes];
    }
    else if(_total_files == 9) {
        auto fmt = NSLocalizedString
        (@"Selected %@ in 9 files",
         "Informative text for a bottom information bar in panels, showing size of selection");
        return [NSString stringWithFormat:fmt, bytes];
    }
    else {
        auto fmt = NSLocalizedString
        (@"Selected %@ in %@ files",
         "Informative text for a bottom information bar in panels, showing size of selection");
        return [NSString stringWithFormat:fmt, bytes, [NSNumber numberWithInt:_total_files]];
    }
}

@implementation NCPanelViewFooter
{
    NSColor                 *m_Background;
    ColoredSeparatorLine    *m_SeparatorLine;
    ColoredSeparatorLine    *m_VSeparatorLine1;
    ColoredSeparatorLine    *m_VSeparatorLine2;
    NSTextField             *m_FilenameLabel;
    NSTextField             *m_SizeLabel;
    NSTextField             *m_ModTime;
    NSTextField             *m_ItemsLabel;
    NSTextField             *m_VolumeLabel;
    NSTextField             *m_SelectionLabel;

    data::Statistics m_Stats;
    FooterVolumeInfoFetcher m_VolumeInfoFetcher;
    std::unique_ptr<nc::panel::FooterTheme> m_Theme;    
    
    bool m_Active;
}

- (id) initWithFrame:(NSRect)frameRect
               theme:(std::unique_ptr<nc::panel::FooterTheme>)_theme
{
    self = [super initWithFrame:frameRect];
    if( self ) {
        m_Active = false;
        m_Theme = std::move(_theme);
    
        [self createControls];
        [self setupPresentation];
        
        [self addSubview:m_SeparatorLine];
        [self addSubview:m_FilenameLabel];
        [self addSubview:m_SizeLabel];
        [self addSubview:m_ModTime];
        [self addSubview:m_SelectionLabel];
        [self addSubview:m_ItemsLabel];
        [self addSubview:m_VolumeLabel];
        [self addSubview:m_VSeparatorLine1];
        [self addSubview:m_VSeparatorLine2];
        
        [self installConstraints];
        
        __weak NCPanelViewFooter *weak_self = self;
        m_VolumeInfoFetcher.SetCallback([=](const VFSStatFS &) {
            if( NCPanelViewFooter *strong_self = weak_self )
                [strong_self updateVolumeInfo];
        });
        m_Theme->ObserveChanges( [weak_self]{
            if( auto strong_self = weak_self )
                [strong_self setupPresentation];
        });        
    }

    return self;
}

- (void) createControls
{
    m_SeparatorLine = [[ColoredSeparatorLine alloc] initWithFrame:NSRect()];
    m_SeparatorLine.translatesAutoresizingMaskIntoConstraints = NO;
    
    m_FilenameLabel = [[NSTextField alloc] initWithFrame:NSRect()];
    m_FilenameLabel.translatesAutoresizingMaskIntoConstraints = false;
    m_FilenameLabel.cell = [VerticallyCenteredTextFieldCell new];
    m_FilenameLabel.stringValue = @"";
    m_FilenameLabel.bordered = false;
    m_FilenameLabel.editable = false;
    m_FilenameLabel.selectable = false;
    m_FilenameLabel.drawsBackground = false;
    m_FilenameLabel.lineBreakMode = NSLineBreakByTruncatingHead;
    m_FilenameLabel.usesSingleLineMode = true;
    m_FilenameLabel.alignment = NSTextAlignmentLeft;
    [m_FilenameLabel
     setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow
     forOrientation:NSLayoutConstraintOrientationHorizontal];
    
    m_SizeLabel = [[NSTextField alloc] initWithFrame:NSRect()];
    m_SizeLabel.translatesAutoresizingMaskIntoConstraints = false;
    m_SizeLabel.cell = [VerticallyCenteredTextFieldCell new];
    m_SizeLabel.stringValue = @"";
    m_SizeLabel.bordered = false;
    m_SizeLabel.editable = false;
    m_SizeLabel.drawsBackground = false;
    m_SizeLabel.lineBreakMode = NSLineBreakByTruncatingHead;
    m_SizeLabel.usesSingleLineMode = true;
    m_SizeLabel.alignment = NSTextAlignmentRight;
    [m_SizeLabel
     setContentCompressionResistancePriority:NSLayoutPriorityDefaultHigh
     forOrientation:NSLayoutConstraintOrientationHorizontal];
    
    m_ModTime = [[NSTextField alloc] initWithFrame:NSRect()];
    m_ModTime.translatesAutoresizingMaskIntoConstraints = false;
    m_ModTime.cell = [VerticallyCenteredTextFieldCell new];
    m_ModTime.stringValue = @"";
    m_ModTime.bordered = false;
    m_ModTime.editable = false;
    m_ModTime.drawsBackground = false;
    m_ModTime.lineBreakMode = NSLineBreakByTruncatingHead;
    m_ModTime.usesSingleLineMode = true;
    m_ModTime.alignment = NSTextAlignmentRight;
    [m_ModTime
     setContentCompressionResistancePriority:NSLayoutPriorityDefaultHigh
     forOrientation:NSLayoutConstraintOrientationHorizontal];
    
    m_SelectionLabel = [[NSTextField alloc] initWithFrame:NSRect()];
    m_SelectionLabel.translatesAutoresizingMaskIntoConstraints = false;
    m_SelectionLabel.cell = [VerticallyCenteredTextFieldCell new];
    m_SelectionLabel.stringValue = @"";
    m_SelectionLabel.bordered = false;
    m_SelectionLabel.editable = false;
    m_SelectionLabel.drawsBackground = false;
    m_SelectionLabel.lineBreakMode = NSLineBreakByTruncatingHead;
    m_SelectionLabel.usesSingleLineMode = true;
    m_SelectionLabel.alignment = NSTextAlignmentCenter;
    [m_SelectionLabel
     setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow
     forOrientation:NSLayoutConstraintOrientationHorizontal];
    [m_SelectionLabel
     setContentHuggingPriority:NSLayoutPriorityFittingSizeCompression
     forOrientation:NSLayoutConstraintOrientationHorizontal];
    
    m_ItemsLabel = [[NSTextField alloc] initWithFrame:NSRect()];
    m_ItemsLabel.translatesAutoresizingMaskIntoConstraints = false;
    m_ItemsLabel.cell = [VerticallyCenteredTextFieldCell new];
    m_ItemsLabel.stringValue = @"";
    m_ItemsLabel.bordered = false;
    m_ItemsLabel.editable = false;
    m_ItemsLabel.drawsBackground = false;
    m_ItemsLabel.lineBreakMode = NSLineBreakByClipping;
    m_ItemsLabel.usesSingleLineMode = true;
    m_ItemsLabel.alignment = NSTextAlignmentCenter;
    [m_ItemsLabel
     setContentCompressionResistancePriority:40
     forOrientation:NSLayoutConstraintOrientationHorizontal];
    
    m_VolumeLabel = [[NSTextField alloc] initWithFrame:NSRect()];
    m_VolumeLabel.translatesAutoresizingMaskIntoConstraints = false;
    m_VolumeLabel.cell = [VerticallyCenteredTextFieldCell new];
    m_VolumeLabel.stringValue = @"";
    m_VolumeLabel.bordered = false;
    m_VolumeLabel.editable = false;
    m_VolumeLabel.drawsBackground = false;
    m_VolumeLabel.lineBreakMode = NSLineBreakByTruncatingHead;
    m_VolumeLabel.usesSingleLineMode = true;
    m_VolumeLabel.alignment = NSTextAlignmentRight;
    m_VolumeLabel.lineBreakMode = NSLineBreakByClipping;
    [m_VolumeLabel
     setContentCompressionResistancePriority:40
     forOrientation:NSLayoutConstraintOrientationHorizontal];
    
    m_VSeparatorLine1 = [[ColoredSeparatorLine alloc] initWithFrame:NSRect()];
    m_VSeparatorLine1.translatesAutoresizingMaskIntoConstraints = NO;
    [m_VSeparatorLine1
     setContentCompressionResistancePriority:40
     forOrientation:NSLayoutConstraintOrientationHorizontal];
    
    m_VSeparatorLine2 = [[ColoredSeparatorLine alloc] initWithFrame:NSRect()];
    m_VSeparatorLine2.translatesAutoresizingMaskIntoConstraints = NO;
    [m_VSeparatorLine2
     setContentCompressionResistancePriority:40
     forOrientation:NSLayoutConstraintOrientationHorizontal];    
}

- (void) installConstraints
{
    const auto views = NSDictionaryOfVariableBindings(m_SeparatorLine, m_FilenameLabel,
                                                      m_SizeLabel, m_ModTime, m_ItemsLabel,
                                                      m_VolumeLabel, m_VSeparatorLine1,
                                                      m_VSeparatorLine2);
    const auto metrics = @{@"lm1":@400, @"lm2":@450};
    const auto ac = [&](NSString *_vf) {
        auto constraints = [NSLayoutConstraint constraintsWithVisualFormat:_vf
                                                                   options:0
                                                                   metrics:metrics
                                                                     views:views];
        [self addConstraints:constraints]; 
    };
    ac(@"V:|-(0)-[m_SeparatorLine(==1)]-(==0)-[m_FilenameLabel]-(==0)-|");
    ac(@"V:[m_SeparatorLine]-(==0)-[m_VSeparatorLine1]-(0)-|");
    ac(@"V:[m_SeparatorLine]-(==0)-[m_VSeparatorLine2]-(0)-|");
    ac(@"V:|-(0)-[m_SeparatorLine]-(==0)-[m_FilenameLabel]-(==0)-|");
    ac(@"V:[m_SeparatorLine]-(==0)-[m_SizeLabel]-(==0)-|");
    ac(@"V:[m_SeparatorLine]-(==0)-[m_ModTime]-(==0)-|");
    ac(@"V:[m_SeparatorLine]-(==0)-[m_ItemsLabel]-(==0)-|");
    ac(@"V:[m_SeparatorLine]-(==0)-[m_VolumeLabel]-(==0)-|");
    ac(@"|-(0)-[m_SeparatorLine]-(0)-|");
    ac(@"[m_ModTime]-(>=4@500)-|");
    ac(@"|-(7)-[m_FilenameLabel]-(>=4)-[m_SizeLabel]-(4)-[m_ModTime(>=140@500)]-(4@400)-"
       "[m_VSeparatorLine1(==1@300)]-(2@300)-[m_ItemsLabel(>=50@300)]-(4@300)-"
       "[m_VSeparatorLine2(==1@290)]-(2@300)-[m_VolumeLabel(>=120@280)]-(4@300)-|");
    ac(@"|-(>=lm1@400)-[m_VSeparatorLine1]");
    ac(@"|-(>=lm1@400)-[m_ItemsLabel]");
    ac(@"|-(>=lm2@400)-[m_VSeparatorLine2]");
    ac(@"|-(>=lm2@400)-[m_VolumeLabel]");
    
    const auto add = [&](NSLayoutConstraint *_lc) {
        [self addConstraint:_lc];        
    };    
    add([m_SelectionLabel.leadingAnchor constraintEqualToAnchor:m_FilenameLabel.leadingAnchor]);
    add([m_SelectionLabel.topAnchor constraintEqualToAnchor:m_FilenameLabel.topAnchor]);
    add([m_SelectionLabel.bottomAnchor constraintEqualToAnchor:m_FilenameLabel.bottomAnchor]);
    add([m_SelectionLabel.trailingAnchor constraintEqualToAnchor:m_ModTime.trailingAnchor]);    
}

static NSString *ComposeFooterFileNameForEntry(const VFSListingItem &_dirent)
{
    // output is a direct filename or symlink path in ->filename form
    if( !_dirent.IsSymlink() ) {
        if( _dirent.Listing()->IsUniform() ) // this looks like a hacky solution
            return _dirent.FilenameNS(); // we're on regular panel - just return filename
        
        // we're on non-uniform panel like temporary, will return full path
        return [NSString stringWithUTF8StdString:_dirent.Path()];
    }
    else if(_dirent.Symlink() != 0) {
        const auto link = [NSString stringWithUTF8String:_dirent.Symlink()];
        if( link != nil )
            return [@"->" stringByAppendingString:link];
    }
    return @""; // fallback case
}

- (void) updateFocusedItem:(const VFSListingItem&)_item
                        VD:(data::ItemVolatileData)_vd // may be empty
{
    if( _item ) {
        m_FilenameLabel.stringValue = ComposeFooterFileNameForEntry(_item);
        m_FilenameLabel.toolTip = [NSString stringWithUTF8StdString:_item.Path()];
        m_SizeLabel.stringValue = FileSizeToString(_item,
                                                   _vd,
                                                   GetFileSizeFormat(),
                                                   ByteCountFormatter::Instance());        
        const auto style = AdaptiveDateFormatting::Style::Medium;
        m_ModTime.stringValue = AdaptiveDateFormatting{}.Format(style, _item.MTime());
    }
    else {
        m_FilenameLabel.stringValue = @"";
        m_SizeLabel.stringValue = @"";
        m_ModTime.stringValue = @"";
    }
}

- (BOOL) canDrawSubviewsIntoLayer
{
    return true;
}

- (BOOL) isOpaque
{
    return true;
}

- (void)drawRect:(NSRect)dirtyRect
{
    if( m_Background && m_Background != NSColor.clearColor  ) {
        auto context = NSGraphicsContext.currentContext.CGContext;
        CGContextSetFillColorWithColor(context, m_Background.CGColor);
        CGContextFillRect(context, NSRectToCGRect(dirtyRect));
    }
   else {
        NSDrawWindowBackground(dirtyRect);
    }
}

- (void) setupPresentation
{
    const bool active = m_Active;
    m_Background = active ? m_Theme->ActiveBackgroundColor() : m_Theme->InactiveBackgroundColor();
    
    auto font = m_Theme->Font();    
    m_FilenameLabel.font = font;
    m_SizeLabel.font = font;
    m_ModTime.font = font;
    m_ItemsLabel.font = font;
    m_VolumeLabel.font = font;
    m_SelectionLabel.font = font;

    const auto text_color = active ? m_Theme->ActiveTextColor() : m_Theme->TextColor();    
    m_FilenameLabel.textColor = text_color;
    m_SizeLabel.textColor = text_color;
    m_ModTime.textColor = text_color;
    m_ItemsLabel.textColor = text_color;
    m_VolumeLabel.textColor = text_color;
    m_SelectionLabel.textColor = text_color;
    
    auto separator_color = m_Theme->SeparatorsColor();
    m_SeparatorLine.borderColor = separator_color;
    m_VSeparatorLine1.borderColor = separator_color;
    m_VSeparatorLine2.borderColor = separator_color;
    
    [self setNeedsDisplay:true];    
}

- (void) updateStatistics:(const data::Statistics&)_stats
{
    if( m_Stats == _stats )
        return;

    m_Stats = _stats;
        
    m_ItemsLabel.stringValue = [NSString stringWithFormat:@"(%d)", m_Stats.total_entries_amount];
    
    if( m_Stats.selected_entries_amount == 0 ) {
        m_SelectionLabel.stringValue = @"";
        m_SelectionLabel.hidden = true;
        m_FilenameLabel.hidden = false;
        m_SizeLabel.hidden = false;
        m_ModTime.hidden = false;
    }
    else {
        const auto sel_str = FormHumanReadableBytesAndFiles(m_Stats.bytes_in_selected_entries,
                                                            m_Stats.selected_entries_amount,
                                                            GetSelectionSizeFormat(),
                                                            ByteCountFormatter::Instance()); 
        m_SelectionLabel.stringValue = sel_str; 
        m_SelectionLabel.hidden = false;
        m_FilenameLabel.hidden = true;
        m_SizeLabel.hidden = true;
        m_ModTime.hidden = true;
    }
}

- (void) updateListing:(const VFSListingPtr&)_listing
{
    m_VolumeInfoFetcher.SetTarget(_listing);
    [self updateVolumeInfo];
}

- (void) updateVolumeInfo
{
    const auto fmt = NSLocalizedString
    (@"%@ available",
     "Panels bottom volume bar, showing amount of bytes available");
    const auto &fmter = ByteCountFormatter::Instance();
    const auto avail = fmter.ToNSString(m_VolumeInfoFetcher.Current().avail_bytes,
                                        ByteCountFormatter::Adaptive6);
    m_VolumeLabel.stringValue = [NSString stringWithFormat:fmt, avail];
    
    m_VolumeLabel.toolTip = 
        [NSString stringWithUTF8StdString:m_VolumeInfoFetcher.Current().volume_name];
}

- (void)viewDidMoveToWindow
{
    if( self.window )
        m_VolumeInfoFetcher.ResumeUpdates();
    else
        m_VolumeInfoFetcher.PauseUpdates();
}

- (void) setActive:(bool)active
{
    if( m_Active == active )
        return;
    
    m_Active = active;
    [self setupPresentation];
}

- (bool) active
{
    return m_Active;
}


@end

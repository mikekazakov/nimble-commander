// Copyright (C) 2016-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Utility/ByteCountFormatter.h>
#include <Utility/ColoredSeparatorLine.h>
#include <Utility/VerticallyCenteredTextFieldCell.h>
#include <NimbleCommander/Bootstrap/AppDelegate.h>
#include <NimbleCommander/Core/Theming/Theme.h>
#include <NimbleCommander/Core/Theming/ThemesManager.h>
#include "PanelView.h"
#include "PanelViewPresentationSettings.h"
#include "List/PanelListViewDateFormatting.h"
#include "PanelViewFooterVolumeInfoFetcher.h"
#include "PanelViewFooter.h"

using namespace nc::panel;

static NSString* FileSizeToString(const VFSListingItem &_dirent, const data::ItemVolatileData &_vd, ByteCountFormatter::Type _format)
{
    if( _dirent.IsDir() ) {
        if( _vd.is_size_calculated() ) {
            return ByteCountFormatter::Instance().ToNSString(_vd.size, _format);
        }
        else {
            if(_dirent.IsDotDot())
                return NSLocalizedString(@"__MODERNPRESENTATION_UP_WORD", "Upper-level in directory, for English is 'Up'");
            else
                return NSLocalizedString(@"__MODERNPRESENTATION_FOLDER_WORD", "Folders dummy string when size is not available, for English is 'Folder'");
        }
    }
    else {
        return ByteCountFormatter::Instance().ToNSString(_dirent.Size(), _format);
    }
}

static NSString* FormHumanReadableBytesAndFiles(uint64_t _sz, int _total_files, ByteCountFormatter::Type _format)
{
    NSString *bytes = ByteCountFormatter::Instance().ToNSString(_sz, _format);
    if(_total_files == 1)
        return [NSString stringWithFormat:NSLocalizedString(@"Selected %@ in 1 file",
                                                            "Informative text for a bottom information bar in panels, showing size of selection"),
                bytes];
    else if(_total_files == 2)
        return [NSString stringWithFormat:NSLocalizedString(@"Selected %@ in 2 files",
                                                            "Informative text for a bottom information bar in panels, showing size of selection"),
                bytes];
    else if(_total_files == 3)
        return [NSString stringWithFormat:NSLocalizedString(@"Selected %@ in 3 files",
                                                            "Informative text for a bottom information bar in panels, showing size of selection"),
                bytes];
    else if(_total_files == 4)
        return [NSString stringWithFormat:NSLocalizedString(@"Selected %@ in 4 files",
                                                            "Informative text for a bottom information bar in panels, showing size of selection"),
                bytes];
    else if(_total_files == 5)
        return [NSString stringWithFormat:NSLocalizedString(@"Selected %@ in 5 files",
                                                            "Informative text for a bottom information bar in panels, showing size of selection"),
                bytes];
    else if(_total_files == 6)
        return [NSString stringWithFormat:NSLocalizedString(@"Selected %@ in 6 files",
                                                            "Informative text for a bottom information bar in panels, showing size of selection"),
                bytes];
    else if(_total_files == 7)
        return [NSString stringWithFormat:NSLocalizedString(@"Selected %@ in 7 files",
                                                            "Informative text for a bottom information bar in panels, showing size of selection"),
                bytes];
    else if(_total_files == 8)
        return [NSString stringWithFormat:NSLocalizedString(@"Selected %@ in 8 files",
                                                            "Informative text for a bottom information bar in panels, showing size of selection"),
                bytes];
    else if(_total_files == 9)
        return [NSString stringWithFormat:NSLocalizedString(@"Selected %@ in 9 files",
                                                            "Informative text for a bottom information bar in panels, showing size of selection"),
                bytes];
    else
        return [NSString stringWithFormat:NSLocalizedString(@"Selected %@ in %@ files",
                                                            "Informative text for a bottom information bar in panels, showing size of selection"),
                bytes,
                [NSNumber numberWithInt:_total_files]];
}

@implementation PanelViewFooter
{
    NSColor             *m_Background;
    NSColor             *m_TextColor;
    ColoredSeparatorLine               *m_SeparatorLine;
    ColoredSeparatorLine               *m_VSeparatorLine1;
    ColoredSeparatorLine               *m_VSeparatorLine2;
    NSTextField         *m_FilenameLabel;
    NSTextField         *m_SizeLabel;
    NSTextField         *m_ModTime;
    NSTextField         *m_ItemsLabel;
    NSTextField         *m_VolumeLabel;
    NSTextField         *m_SelectionLabel;

    
    __weak PanelView    *m_PanelView;
    
    data::Statistics m_Stats;
    PanelViewFooterVolumeInfoFetcher m_VolumeInfoFetcher;
    ThemesManager::ObservationTicket    m_ThemeObservation;
}

- (id) initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if( self ) {
        m_SeparatorLine = [[ColoredSeparatorLine alloc] initWithFrame:NSRect()];
        m_SeparatorLine.translatesAutoresizingMaskIntoConstraints = NO;
        m_SeparatorLine.boxType = NSBoxSeparator;
        
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
        [m_FilenameLabel setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow
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
        [m_SizeLabel setContentCompressionResistancePriority:NSLayoutPriorityDefaultHigh
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
        [m_ModTime setContentCompressionResistancePriority:NSLayoutPriorityDefaultHigh
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
        [m_SelectionLabel setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow
            forOrientation:NSLayoutConstraintOrientationHorizontal];
        [m_SelectionLabel setContentHuggingPriority:NSLayoutPriorityFittingSizeCompression
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
        [m_ItemsLabel setContentCompressionResistancePriority:40
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
        [m_VolumeLabel setContentCompressionResistancePriority:40
            forOrientation:NSLayoutConstraintOrientationHorizontal];
        
        m_VSeparatorLine1 = [[ColoredSeparatorLine alloc] initWithFrame:NSRect()];
        m_VSeparatorLine1.translatesAutoresizingMaskIntoConstraints = NO;
        m_VSeparatorLine1.boxType = NSBoxSeparator;
        [m_VSeparatorLine1 setContentCompressionResistancePriority:40
            forOrientation:NSLayoutConstraintOrientationHorizontal];
        
        m_VSeparatorLine2 = [[ColoredSeparatorLine alloc] initWithFrame:NSRect()];
        m_VSeparatorLine2.translatesAutoresizingMaskIntoConstraints = NO;
        m_VSeparatorLine2.boxType = NSBoxSeparator;
        [m_VSeparatorLine2 setContentCompressionResistancePriority:40
            forOrientation:NSLayoutConstraintOrientationHorizontal];
        
        
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
        
        NSDictionary *views = NSDictionaryOfVariableBindings(m_SeparatorLine, m_FilenameLabel, m_SizeLabel, m_ModTime, m_ItemsLabel, m_VolumeLabel, m_VSeparatorLine1, m_VSeparatorLine2);
        NSDictionary *metrics = @{@"lm1":@400, @"lm2":@450};
        
        [self addConstraints:[NSLayoutConstraint
                              constraintsWithVisualFormat:@"V:|-(0)-[m_SeparatorLine(==1)]-(==0)-[m_FilenameLabel]-(==0)-|" options:0 metrics:nil views:views]];
        [self addConstraints:[NSLayoutConstraint
                              constraintsWithVisualFormat:@"V:[m_SeparatorLine]-(==0)-[m_VSeparatorLine1]-(0)-|" options:0 metrics:nil views:views]];
        [self addConstraints:[NSLayoutConstraint
                              constraintsWithVisualFormat:@"V:[m_SeparatorLine]-(==0)-[m_VSeparatorLine2]-(0)-|" options:0 metrics:nil views:views]];
        [self addConstraints:[NSLayoutConstraint
                              constraintsWithVisualFormat:@"V:|-(0)-[m_SeparatorLine]-(==0)-[m_FilenameLabel]-(==0)-|" options:0 metrics:nil views:views]];
        [self addConstraints:[NSLayoutConstraint
                              constraintsWithVisualFormat:@"V:[m_SeparatorLine]-(==0)-[m_SizeLabel]-(==0)-|" options:0 metrics:nil views:views]];
        [self addConstraints:[NSLayoutConstraint
                              constraintsWithVisualFormat:@"V:[m_SeparatorLine]-(==0)-[m_ModTime]-(==0)-|" options:0 metrics:nil views:views]];
        [self addConstraints:[NSLayoutConstraint
                              constraintsWithVisualFormat:@"V:[m_SeparatorLine]-(==0)-[m_ItemsLabel]-(==0)-|" options:0 metrics:nil views:views]];
        [self addConstraints:[NSLayoutConstraint
                              constraintsWithVisualFormat:@"V:[m_SeparatorLine]-(==0)-[m_VolumeLabel]-(==0)-|" options:0 metrics:nil views:views]];
        [self addConstraints:[NSLayoutConstraint
                              constraintsWithVisualFormat:@"|-(0)-[m_SeparatorLine]-(0)-|" options:0 metrics:nil views:views]];
        [self addConstraints:[NSLayoutConstraint
                              constraintsWithVisualFormat:@"[m_ModTime]-(>=4@500)-|" options:0 metrics:nil views:views]];
        [self addConstraints:[NSLayoutConstraint
                              constraintsWithVisualFormat:
@"|-(7)-[m_FilenameLabel]-(>=4)-[m_SizeLabel]-(4)-[m_ModTime(>=140@500)]-(4@400)-\
[m_VSeparatorLine1(<=1@300)]-(2@300)-[m_ItemsLabel(>=50@300)]-(4@300)-\
[m_VSeparatorLine2(<=1@290)]-(2@300)-[m_VolumeLabel(>=120@290)]-(4@300)-|" options:0 metrics:metrics views:views]];
        [self addConstraints:[NSLayoutConstraint
                              constraintsWithVisualFormat:@"|-(>=lm1@400)-[m_VSeparatorLine1]" options:0 metrics:metrics views:views]];
        [self addConstraints:[NSLayoutConstraint
                              constraintsWithVisualFormat:@"|-(>=lm1@400)-[m_ItemsLabel]" options:0 metrics:metrics views:views]];
        [self addConstraints:[NSLayoutConstraint
                              constraintsWithVisualFormat:@"|-(>=lm2@400)-[m_VSeparatorLine2]" options:0 metrics:metrics views:views]];
        [self addConstraints:[NSLayoutConstraint
                              constraintsWithVisualFormat:@"|-(>=lm2@400)-[m_VolumeLabel]" options:0 metrics:metrics views:views]];

        [self addConstraint:[m_SelectionLabel.leadingAnchor constraintEqualToAnchor:m_FilenameLabel.leadingAnchor]];
        [self addConstraint:[m_SelectionLabel.topAnchor constraintEqualToAnchor:m_FilenameLabel.topAnchor]];
        [self addConstraint:[m_SelectionLabel.bottomAnchor constraintEqualToAnchor:m_FilenameLabel.bottomAnchor]];
        [self addConstraint:[m_SelectionLabel.trailingAnchor constraintEqualToAnchor:m_ModTime.trailingAnchor]];
        
        __weak PanelViewFooter *weak_self = self;
        m_VolumeInfoFetcher.SetCallback([=](const VFSStatFS &_st) {
            if( PanelViewFooter *strong_self = weak_self )
                [strong_self updateVolumeInfo];
        });
        m_ThemeObservation = NCAppDelegate.me.themesManager.ObserveChanges(
            ThemesManager::Notifications::FilePanelsFooter, [weak_self]{
            if( auto strong_self = weak_self ) {
                [strong_self setupPresentation];
                [strong_self observeValueForKeyPath:@"active" ofObject:nil change:nil context:nil];
            }
        });
    }

    return self;
}

-(void) dealloc
{
}

static NSString *ComposeFooterFileNameForEntry(const VFSListingItem &_dirent)
{
    // output is a direct filename or symlink path in ->filename form
    if(!_dirent.IsSymlink()) {
        if( _dirent.Listing()->IsUniform() ) // this looks like a hacky solution
            return _dirent.FilenameNS(); // we're on regular panel - just return filename
        
        // we're on non-uniform panel like temporary, will return full path
        return [NSString stringWithUTF8StdString:_dirent.Path()];
    }
    else if(_dirent.Symlink() != 0) {
        NSString *link = [NSString stringWithUTF8String:_dirent.Symlink()];
        if(link != nil)
            return [@"->" stringByAppendingString:link];
    }
    return @""; // fallback case
}

- (void) updateFocusedItem:(VFSListingItem)_item VD:(data::ItemVolatileData)_vd // may be empty
{
    if( _item ) {
        m_FilenameLabel.stringValue = ComposeFooterFileNameForEntry(_item);
        m_FilenameLabel.toolTip = [NSString stringWithUTF8StdString:_item.Path()];
        
        m_SizeLabel.stringValue = FileSizeToString(_item,
                                                   _vd,
                                                   GetFileSizeFormat());
        
        m_ModTime.stringValue = PanelListViewDateFormatting::Format(
                                                                   PanelListViewDateFormatting::Style::Medium,
                                                                   _item.MTime());
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
    auto f = CurrentTheme().FilePanelsFooterFont();
    m_FilenameLabel.font = f;
    m_SizeLabel.font = f;
    m_ModTime.font = f;
    m_ItemsLabel.font = f;
    m_VolumeLabel.font = f;
    m_SelectionLabel.font = f;

    m_FilenameLabel.textColor = m_TextColor;
    m_SizeLabel.textColor = m_TextColor;
    m_ModTime.textColor = m_TextColor;
    m_ItemsLabel.textColor = m_TextColor;
    m_VolumeLabel.textColor = m_TextColor;
    m_SelectionLabel.textColor = m_TextColor;
    
    auto s = CurrentTheme().FilePanelsFooterSeparatorsColor();
    m_SeparatorLine.borderColor = s;
    m_VSeparatorLine1.borderColor = s;
    m_VSeparatorLine2.borderColor = s;
}

- (void)viewDidMoveToSuperview
{
    if( auto pv = objc_cast<PanelView>(self.superview) ) {
        m_PanelView = pv;
        [pv addObserver:self forKeyPath:@"active" options:0 context:NULL];
        [self observeValueForKeyPath:@"active" ofObject:pv change:nil context:nil];
    }
    else {
        [m_PanelView removeObserver:self forKeyPath:@"active"];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if( !m_PanelView )
        return;
    if( [keyPath isEqualToString:@"active"] ) {
        const bool active = m_PanelView.active;
        m_Background = active ?
            CurrentTheme().FilePanelsFooterActiveBackgroundColor() :
            CurrentTheme().FilePanelsFooterInactiveBackgroundColor();
        m_TextColor = active ?
            CurrentTheme().FilePanelsFooterActiveTextColor() :
            CurrentTheme().FilePanelsFooterTextColor();
        [self setupPresentation];
        [self setNeedsDisplay:true];
    }
}

- (void) updateStatistics:(const data::Statistics&)_stats
{
    if( m_Stats != _stats ) {
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
            m_SelectionLabel.stringValue = FormHumanReadableBytesAndFiles(m_Stats.bytes_in_selected_entries,
                                                                          m_Stats.selected_entries_amount,
                                                                          GetSelectionSizeFormat());
            m_SelectionLabel.hidden = false;
            m_FilenameLabel.hidden = true;
            m_SizeLabel.hidden = true;
            m_ModTime.hidden = true;
        }
    }
}

- (void) updateListing:(const VFSListingPtr&)_listing
{
    m_VolumeInfoFetcher.SetTarget(_listing);
    [self updateVolumeInfo];
}

- (void) updateVolumeInfo
{
    NSString *text = [NSString stringWithFormat:NSLocalizedString(@"%@ available",
                                                                  "Panels bottom volume bar, showing amount of bytes available"),
                             ByteCountFormatter::Instance().ToNSString(m_VolumeInfoFetcher.Current().avail_bytes,
                                                                       ByteCountFormatter::Adaptive6)];
    m_VolumeLabel.stringValue = text;
    m_VolumeLabel.toolTip = [NSString stringWithUTF8StdString:m_VolumeInfoFetcher.Current().volume_name];
}

- (void)viewDidMoveToWindow
{
    if( self.window )
        m_VolumeInfoFetcher.ResumeUpdates();
    else
        m_VolumeInfoFetcher.PauseUpdates();
}

@end

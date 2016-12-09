#include <Utility/ByteCountFormatter.h>
#include "../../../Files/PanelView.h"
#include "List/PanelListViewDateFormatting.h"
#include "PanelViewFooterVolumeInfoFetcher.h"
#include "PanelViewFooter.h"

static NSString* FileSizeToString(const VFSListingItem &_dirent, const PanelData::VolatileData &_vd, ByteCountFormatter::Type _format)
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
    NSBox               *m_SeparatorLine;
    NSBox               *m_VSeparatorLine1;
    NSBox               *m_VSeparatorLine2;
    NSTextField         *m_FilenameLabel;
    NSTextField         *m_SizeLabel;
    NSTextField         *m_ModTime;
    NSTextField         *m_ItemsLabel;
    NSTextField         *m_VolumeLabel;
    NSTextField         *m_SelectionLabel;

    
    __weak PanelView    *m_PanelView;
    
    PanelDataStatistics m_Stats;
    PanelViewFooterVolumeInfoFetcher m_VolumeInfoFetcher;
}

- (id) initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if( self ) {

        m_SeparatorLine = [[NSBox alloc] initWithFrame:NSRect()];
        m_SeparatorLine.translatesAutoresizingMaskIntoConstraints = NO;
        m_SeparatorLine.boxType = NSBoxSeparator;
        [self addSubview:m_SeparatorLine];
        
        m_FilenameLabel = [[NSTextField alloc] initWithFrame:NSRect()];
        m_FilenameLabel.translatesAutoresizingMaskIntoConstraints = false;
        m_FilenameLabel.bordered = false;
        m_FilenameLabel.editable = false;
        m_FilenameLabel.drawsBackground = false;
        m_FilenameLabel.lineBreakMode = NSLineBreakByTruncatingHead;
        m_FilenameLabel.usesSingleLineMode = true;
        m_FilenameLabel.alignment = NSTextAlignmentLeft;
        m_FilenameLabel.font = [NSFont systemFontOfSize:NSFont.systemFontSize];
        [m_FilenameLabel setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
        [self addSubview:m_FilenameLabel];

        m_SizeLabel = [[NSTextField alloc] initWithFrame:NSRect()];
        m_SizeLabel.translatesAutoresizingMaskIntoConstraints = false;
        m_SizeLabel.bordered = false;
        m_SizeLabel.editable = false;
        m_SizeLabel.drawsBackground = false;
        m_SizeLabel.lineBreakMode = NSLineBreakByTruncatingHead;
        m_SizeLabel.usesSingleLineMode = true;
        m_SizeLabel.alignment = NSTextAlignmentRight;
        m_SizeLabel.font = [NSFont systemFontOfSize:NSFont.systemFontSize];
        [m_SizeLabel setContentCompressionResistancePriority:NSLayoutPriorityDefaultHigh forOrientation:NSLayoutConstraintOrientationHorizontal];
        [self addSubview:m_SizeLabel];

        m_ModTime = [[NSTextField alloc] initWithFrame:NSRect()];
        m_ModTime.translatesAutoresizingMaskIntoConstraints = false;
        m_ModTime.bordered = false;
        m_ModTime.editable = false;
        m_ModTime.drawsBackground = false;
        m_ModTime.lineBreakMode = NSLineBreakByTruncatingHead;
        m_ModTime.usesSingleLineMode = true;
        m_ModTime.alignment = NSTextAlignmentRight;
        m_ModTime.font = [NSFont systemFontOfSize:NSFont.systemFontSize];
//        m_ModTime.preferredMaxLayoutWidth = 150;
        [m_ModTime setContentCompressionResistancePriority:NSLayoutPriorityDefaultHigh forOrientation:NSLayoutConstraintOrientationHorizontal];
        [self addSubview:m_ModTime];
        
        m_SelectionLabel = [[NSTextField alloc] initWithFrame:NSRect()];
        m_SelectionLabel.translatesAutoresizingMaskIntoConstraints = false;
        m_SelectionLabel.bordered = false;
        m_SelectionLabel.editable = false;
        m_SelectionLabel.drawsBackground = false;
        m_SelectionLabel.lineBreakMode = NSLineBreakByTruncatingHead;
        m_SelectionLabel.usesSingleLineMode = true;
        m_SelectionLabel.alignment = NSTextAlignmentCenter;
        m_SelectionLabel.font = [NSFont systemFontOfSize:NSFont.systemFontSize];
//        m_SelectionLabel.preferredMaxLayoutWidth = 0;
        [m_SelectionLabel setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
        [m_SelectionLabel setContentHuggingPriority:NSLayoutPriorityFittingSizeCompression forOrientation:NSLayoutConstraintOrientationHorizontal];
        [self addSubview:m_SelectionLabel];

        m_ItemsLabel = [[NSTextField alloc] initWithFrame:NSRect()];
        m_ItemsLabel.translatesAutoresizingMaskIntoConstraints = false;
        m_ItemsLabel.bordered = false;
        m_ItemsLabel.editable = false;
        m_ItemsLabel.drawsBackground = false;
        m_ItemsLabel.lineBreakMode = NSLineBreakByTruncatingHead;
        m_ItemsLabel.usesSingleLineMode = true;
        m_ItemsLabel.alignment = NSTextAlignmentCenter;
        m_ItemsLabel.font = [NSFont systemFontOfSize:NSFont.systemFontSize];
//        m_ItemsLabel.preferredMaxLayoutWidth = 50;
        [m_ItemsLabel setContentCompressionResistancePriority:40 forOrientation:NSLayoutConstraintOrientationHorizontal];
        [self addSubview:m_ItemsLabel];
        
        m_VolumeLabel = [[NSTextField alloc] initWithFrame:NSRect()];
        m_VolumeLabel.translatesAutoresizingMaskIntoConstraints = false;
        m_VolumeLabel.bordered = false;
        m_VolumeLabel.editable = false;
        m_VolumeLabel.drawsBackground = false;
        m_VolumeLabel.lineBreakMode = NSLineBreakByTruncatingHead;
        m_VolumeLabel.usesSingleLineMode = true;
        m_VolumeLabel.alignment = NSTextAlignmentCenter;
        m_VolumeLabel.font = [NSFont systemFontOfSize:NSFont.systemFontSize];
        m_VolumeLabel.stringValue = @"Abra!!!";
        //        m_ItemsLabel.preferredMaxLayoutWidth = 50;
        [m_VolumeLabel setContentCompressionResistancePriority:40 forOrientation:NSLayoutConstraintOrientationHorizontal];
        [self addSubview:m_VolumeLabel];
        
        m_VSeparatorLine1 = [[NSBox alloc] initWithFrame:NSRect()];
        m_VSeparatorLine1.translatesAutoresizingMaskIntoConstraints = NO;
        m_VSeparatorLine1.boxType = NSBoxSeparator;
        [m_VSeparatorLine1 setContentCompressionResistancePriority:40 forOrientation:NSLayoutConstraintOrientationHorizontal];
        [self addSubview:m_VSeparatorLine1];

        m_VSeparatorLine2 = [[NSBox alloc] initWithFrame:NSRect()];
        m_VSeparatorLine2.translatesAutoresizingMaskIntoConstraints = NO;
        m_VSeparatorLine2.boxType = NSBoxSeparator;
        [m_VSeparatorLine2 setContentCompressionResistancePriority:40 forOrientation:NSLayoutConstraintOrientationHorizontal];
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
@"|-(4)-[m_FilenameLabel]-(>=4)-[m_SizeLabel]-(4)-[m_ModTime(>=150@500)]-(4@400)-\
[m_VSeparatorLine1(<=1@300)]-(2@300)-[m_ItemsLabel(>=50@300)]-(4@300)-\
[m_VSeparatorLine2(<=1@200)]-(2@200)-[m_VolumeLabel(>=100@200)]-(4@200)-|" options:0 metrics:metrics views:views]];
        [self addConstraints:[NSLayoutConstraint
                              constraintsWithVisualFormat:@"|-(>=lm1@400)-[m_VSeparatorLine1]" options:0 metrics:metrics views:views]];
        [self addConstraints:[NSLayoutConstraint
                              constraintsWithVisualFormat:@"|-(>=lm1@400)-[m_ItemsLabel]" options:0 metrics:metrics views:views]];
        [self addConstraints:[NSLayoutConstraint
                              constraintsWithVisualFormat:@"|-(>=lm2@300)-[m_VSeparatorLine2]" options:0 metrics:metrics views:views]];
        [self addConstraints:[NSLayoutConstraint
                              constraintsWithVisualFormat:@"|-(>=lm2@300)-[m_VolumeLabel]" options:0 metrics:metrics views:views]];

        

        [self addConstraint:[m_SelectionLabel.leadingAnchor constraintEqualToAnchor:m_FilenameLabel.leadingAnchor]];
        [self addConstraint:[m_SelectionLabel.topAnchor constraintEqualToAnchor:m_FilenameLabel.topAnchor]];
        [self addConstraint:[m_SelectionLabel.bottomAnchor constraintEqualToAnchor:m_FilenameLabel.bottomAnchor]];
        [self addConstraint:[m_SelectionLabel.trailingAnchor constraintEqualToAnchor:m_ModTime.trailingAnchor]];
        
        __weak PanelViewFooter *weak_self = self;
        m_VolumeInfoFetcher.SetCallback([=](const VFSStatFS &_st) {
            cout << _st.avail_bytes << " " << _st.volume_name << endl;
            if( PanelViewFooter *strong_self = weak_self )
                [strong_self updateVolumeInfo];
        });
        [self updateVolumeInfo];
    }
    return self;
}

-(void) dealloc
{
}

- (void) updateFocusedItem:(VFSListingItem)_item VD:(PanelDataItemVolatileData)_vd // may be empty
{
    if( _item ) {
        m_FilenameLabel.stringValue = _item.NSName();
        m_SizeLabel.stringValue = FileSizeToString(_item,
                                                   _vd,
                                                   ByteCountFormatter::Type::Fixed6);
        
        m_ModTime.stringValue =PanelListViewDateFormatting::Format(
                                                                   PanelListViewDateFormatting::Style::Medium,
                                                                   _item.MTime());
        
//        class PanelListViewDateFormatting

    }
    else {
        m_FilenameLabel.stringValue = @"";
        m_SizeLabel.stringValue = @"";
    }

//    NSColor
}

- (void)drawRect:(NSRect)dirtyRect
{
    //    const auto bounds = self.bounds;
    if( m_Background  ) {
        CGContextRef context = (CGContextRef)NSGraphicsContext.currentContext.graphicsPort;
        CGContextSetFillColorWithColor(context, m_Background.CGColor);
        CGContextFillRect(context, NSRectToCGRect(dirtyRect));
    }
}

- (void)viewDidMoveToSuperview
{
    if( auto pv = objc_cast<PanelView>(self.superview) ) {
        m_PanelView = pv;
        [pv addObserver:self forKeyPath:@"active" options:0 context:NULL];
        [self observeValueForKeyPath:@"active" ofObject:pv change:nil context:nil];
        
//        [m_FilenameLabel bind:@"hidden" toObject:m_SelectionLabel withKeyPath:@"self.text.length" options:nil];
        
        
//        [m_SearchMatchesField bind:@"hidden" toObject:self withKeyPath:@"searchPrompt" options:@{NSValueTransformerNameBindingOption:NSIsNilTransformerName}];
//        [m_PathTextField bind:@"hidden" toObject:self withKeyPath:@"searchPrompt" options:@{NSValueTransformerNameBindingOption:NSIsNotNilTransformerName}];
//        [m_SortButton bind:@"hidden" toObject:self withKeyPath:@"searchPrompt" options:@{NSValueTransformerNameBindingOption:NSIsNotNilTransformerName}];
    }
    else {
        [m_PanelView removeObserver:self forKeyPath:@"active"];
//        [m_SearchTextField unbind:@"hidden"];
//        [m_SearchMatchesField unbind:@"hidden"];
//        [m_PathTextField unbind:@"hidden"];
//        [m_SortButton unbind:@"hidden"];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if( [keyPath isEqualToString:@"active"] ) {
        const bool active = m_PanelView.active;
        m_Background = active ? NSColor.controlAlternatingRowBackgroundColors[0] : nil;
        [self setNeedsDisplay:true];
    }
}

- (void) updateStatistics:(const PanelDataStatistics&)_stats
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
                                                                          ByteCountFormatter::Type::SpaceSeparated);
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
}

- (void)viewDidMoveToWindow
{
    if( self.window )
        m_VolumeInfoFetcher.ResumeUpdates();
    else
        m_VolumeInfoFetcher.PauseUpdates();
}

@end

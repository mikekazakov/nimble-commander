#include <Utility/ByteCountFormatter.h>
#include "../../../Files/PanelView.h"
#include "List/PanelListViewDateFormatting.h"

#include "PanelViewFooter.h"

static NSString* FileSizeToString(const VFSListingItem &_dirent, const PanelData::PanelVolatileData &_vd, ByteCountFormatter::Type _format)
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

@implementation PanelViewFooter
{
    NSColor             *m_Background;
    NSBox               *m_SeparatorLine;
    NSTextField         *m_FilenameLabel;
    NSTextField         *m_SizeLabel;
    NSTextField         *m_ModTime;
    NSTextField         *m_ItemsLabel;
    
    __weak PanelView    *m_PanelView;
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
        m_FilenameLabel.stringValue = @"ABra!";
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
        m_SizeLabel.stringValue = @"ABra!";
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
        m_ModTime.stringValue = @"ABra!";
        m_ModTime.preferredMaxLayoutWidth = 150;
        [m_ModTime setContentCompressionResistancePriority:NSLayoutPriorityDefaultHigh forOrientation:NSLayoutConstraintOrientationHorizontal];
        
        [self addSubview:m_ModTime];

        m_ItemsLabel = [[NSTextField alloc] initWithFrame:NSRect()];
        m_ItemsLabel.translatesAutoresizingMaskIntoConstraints = false;
        m_ItemsLabel.bordered = false;
        m_ItemsLabel.editable = false;
        m_ItemsLabel.drawsBackground = false;
        m_ItemsLabel.lineBreakMode = NSLineBreakByTruncatingHead;
        m_ItemsLabel.usesSingleLineMode = true;
        m_ItemsLabel.alignment = NSTextAlignmentRight;
        m_ItemsLabel.font = [NSFont systemFontOfSize:NSFont.systemFontSize];
        m_ItemsLabel.stringValue = @"ABra!";
        [m_ItemsLabel setContentCompressionResistancePriority:40 forOrientation:NSLayoutConstraintOrientationHorizontal];
        [self addSubview:m_ItemsLabel];
                
        NSDictionary *views = NSDictionaryOfVariableBindings(m_SeparatorLine, m_FilenameLabel, m_SizeLabel, m_ModTime, m_ItemsLabel);
        [self addConstraints:[NSLayoutConstraint
                              constraintsWithVisualFormat:@"V:|-(0)-[m_SeparatorLine]-(==0)-[m_FilenameLabel]-(==0)-|" options:0 metrics:nil views:views]];
        [self addConstraints:[NSLayoutConstraint
                              constraintsWithVisualFormat:@"V:[m_SeparatorLine]-(==0)-[m_SizeLabel]-(==0)-|" options:0 metrics:nil views:views]];
        [self addConstraints:[NSLayoutConstraint
                              constraintsWithVisualFormat:@"V:[m_SeparatorLine]-(==0)-[m_ModTime]-(==0)-|" options:0 metrics:nil views:views]];
        [self addConstraints:[NSLayoutConstraint
                              constraintsWithVisualFormat:@"V:[m_SeparatorLine]-(==0)-[m_ItemsLabel]-(==0)-|" options:0 metrics:nil views:views]];
        [self addConstraints:[NSLayoutConstraint
                              constraintsWithVisualFormat:@"|-(0)-[m_SeparatorLine]-(0)-|" options:0 metrics:nil views:views]];
        [self addConstraints:[NSLayoutConstraint
                              constraintsWithVisualFormat:@"|-(4)-[m_FilenameLabel]-(>=4)-[m_SizeLabel]-(4)-[m_ModTime(>=150@500)]-(4)-[m_ItemsLabel]-(4)-|" options:0 metrics:nil views:views]];
        [self addConstraints:[NSLayoutConstraint
                              constraintsWithVisualFormat:@"|-(>=400@400)-[m_ItemsLabel]" options:0 metrics:nil views:views]];
        
    }
    return self;
}

-(void) dealloc
{
    [m_PanelView removeObserver:self forKeyPath:@"active"];
}

- (void) updateFocusedItem:(VFSListingItem)_item VD:(PanelData::PanelVolatileData)_vd // may be empty
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
        
//        [m_SearchTextField bind:@"hidden" toObject:self withKeyPath:@"searchPrompt" options:@{NSValueTransformerNameBindingOption:NSIsNilTransformerName}];
//        [m_SearchMatchesField bind:@"hidden" toObject:self withKeyPath:@"searchPrompt" options:@{NSValueTransformerNameBindingOption:NSIsNilTransformerName}];
//        [m_PathTextField bind:@"hidden" toObject:self withKeyPath:@"searchPrompt" options:@{NSValueTransformerNameBindingOption:NSIsNotNilTransformerName}];
//        [m_SortButton bind:@"hidden" toObject:self withKeyPath:@"searchPrompt" options:@{NSValueTransformerNameBindingOption:NSIsNotNilTransformerName}];
    }
    else {
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


@end

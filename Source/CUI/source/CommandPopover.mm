// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "CommandPopover.h"
#include <Carbon/Carbon.h>
#include <vector>
#include <ranges>
#include <algorithm>
#include <numeric>
#include <span>
#include <optional>

@interface NCCommandPopover (Private)
- (std::span<NCCommandPopoverItem *const>)commandItems;
- (double)maximumCommandTitleWidth;

@end

@interface NCCommandPopoverViewController : NSViewController <NSTableViewDataSource, NSTableViewDelegate>
- (instancetype _Nonnull)initWithPopover:(NCCommandPopover *)_popover andTitle:(NSString *)_title;
- (void)tableView:(NSTableView *)_table didClickTableRow:(NSInteger)_row;
@end

@interface NCCommandPopoverTableView : NSTableView
@end

@interface NCCommandPopoverTableSectionRowView : NSTableRowView
@end

@implementation NCCommandPopoverItem {
    NSString *m_Title;
    __weak id m_Target;
    SEL m_Action;
    id m_RepresentedObject;
    NSImage *m_Image;
    long m_Tag;
    bool m_IsSeparator;
    bool m_IsSectionHeader;
}
@synthesize tag = m_Tag;
@synthesize representedObject = m_RepresentedObject;
@synthesize image = m_Image;

- (NCCommandPopoverItem *_Nonnull)init
{
    if( self = [super init] ) {
        m_Title = @"";
        m_Tag = 0;
        m_IsSeparator = false;
        m_IsSectionHeader = false;
    }
    return self;
}

+ (NCCommandPopoverItem *_Nonnull)sectionHeaderWithTitle:(NSString *_Nonnull)_title
{
    NCCommandPopoverItem *item = [[NCCommandPopoverItem alloc] init];
    item->m_IsSectionHeader = true;
    item->m_Title = [_title copy];
    return item;
}

+ (NCCommandPopoverItem *_Nonnull)separatorItem
{
    NCCommandPopoverItem *item = [[NCCommandPopoverItem alloc] init];
    item->m_IsSeparator = true;
    return item;
}

- (NSString *)title
{
    return m_Title;
}

- (void)setTitle:(NSString *)_title
{
    if( m_IsSeparator )
        return;
    assert(_title != nullptr);
    m_Title = [_title copy];
}

- (bool)separatorItem
{
    return m_IsSeparator;
}

- (bool)sectionHeader
{
    return m_IsSectionHeader;
}

- (void)setTarget:(id)_target
{
    assert(!m_IsSeparator && !m_IsSectionHeader);
    m_Target = _target;
}

- (__weak id)target
{
    return m_Target;
}

- (void)setAction:(SEL)_action
{
    assert(!m_IsSeparator && !m_IsSectionHeader);
    m_Action = _action;
}

- (SEL)action
{
    return m_Action;
}

@end

@implementation NCCommandPopoverViewController {
    NSString *m_Title;
    NSTextField *m_LabelTextField;
    NSTextField *m_FilterTextField;
    NCCommandPopoverTableView *m_TableView;
    NSScrollView *m_ScrollView;
    NSLayoutConstraint *m_ScrollViewHeightConstraint;
    NSFont *m_LabelFont;
    NSFont *m_SectionFont;
    __weak NCCommandPopover *m_Parent;
    std::vector<signed char> m_ItemIdxToHotKeyIdx; // negative means no mapping
    std::array<int, 12> m_HotKeyIdxToItemIdx;      // negative means no mapping
    double m_RegularRowHeight;
    double m_SeparatorRowHeight;
    double m_RowPadding;
}

- (instancetype _Nonnull)initWithPopover:(NCCommandPopover *)_popover andTitle:(NSString *)_title
{
    if( self = [super initWithNibName:nil bundle:nil] ) {
        m_Parent = _popover;
        m_Title = _title;
        m_LabelFont = [NSFont menuFontOfSize:0.0];
        m_SectionFont = [NSFont menuFontOfSize:NSFont.smallSystemFontSize];
        m_RegularRowHeight = std::round(m_LabelFont.pointSize + 7.);
        m_SeparatorRowHeight = 11.;
        m_RowPadding = 16.; // TODO: will be different on MacOS 10.15, verify and adjust
    }
    return self;
}

- (void)loadView
{
    [self setupHotKeysMapping];
    const double max_title_width = [m_Parent maximumCommandTitleWidth];
    const double title_col_margin = 20.;
    const double title_col_width = std::max(max_title_width + title_col_margin, 160.);

    NSView *v = [[NSView alloc] initWithFrame:NSMakeRect(0., 0., 200., 200.)];
    m_LabelTextField = [[NSTextField alloc] initWithFrame:NSRect()];
    m_LabelTextField.stringValue = m_Title;
    m_LabelTextField.bordered = false;
    m_LabelTextField.editable = false;
    m_LabelTextField.drawsBackground = false;
    m_LabelTextField.translatesAutoresizingMaskIntoConstraints = false;
    [v addSubview:m_LabelTextField];

    m_FilterTextField = [[NSTextField alloc] initWithFrame:NSRect()];
    m_FilterTextField.stringValue = @"Filter";
    m_FilterTextField.bordered = true;
    m_FilterTextField.editable = true;
    m_FilterTextField.drawsBackground = true;
    m_FilterTextField.translatesAutoresizingMaskIntoConstraints = false;
    [v addSubview:m_FilterTextField];

    m_ScrollView = [[NSScrollView alloc] initWithFrame:NSRect()];
    m_ScrollView.borderType = NSNoBorder;
    m_ScrollView.hasVerticalScroller = false;
    m_ScrollView.hasHorizontalScroller = false;
    m_ScrollView.verticalScrollElasticity = NSScrollElasticityNone;
    m_ScrollView.horizontalScrollElasticity = NSScrollElasticityNone;
    m_ScrollView.translatesAutoresizingMaskIntoConstraints = false;
    m_ScrollView.drawsBackground = false;

    m_TableView = [[NCCommandPopoverTableView alloc] initWithFrame:NSRect()];
    m_TableView.autoresizingMask = NSViewNotSizable;
    m_TableView.delegate = self;
    m_TableView.dataSource = self;
    m_TableView.headerView = nil;
    m_TableView.allowsColumnReordering = false;
    m_TableView.allowsColumnResizing = false;
    m_TableView.allowsMultipleSelection = false;
    m_TableView.allowsEmptySelection = true;
    m_TableView.allowsColumnSelection = false;
    m_TableView.allowsTypeSelect = false;
    m_TableView.autosaveTableColumns = false;
    m_TableView.intercellSpacing = NSMakeSize(0., 2);
    if( @available(macOS 11.0, *) ) {
        m_TableView.style = NSTableViewStyleInset;
    }
    else {
        m_TableView.selectionHighlightStyle = NSTableViewSelectionHighlightStyleRegular;
    }
    m_TableView.usesAlternatingRowBackgroundColors = false;
    m_TableView.backgroundColor = NSColor.clearColor;
    m_TableView.rowSizeStyle = NSTableViewRowSizeStyleCustom;
    m_TableView.rowHeight = m_RegularRowHeight;

    NSTableColumn *img_col = [[NSTableColumn alloc] initWithIdentifier:@"I"];
    img_col.width = 20.;
    [m_TableView addTableColumn:img_col];

    NSTableColumn *label_col = [[NSTableColumn alloc] initWithIdentifier:@"L"];
    label_col.width = title_col_width;
    [m_TableView addTableColumn:label_col];

    NSTableColumn *hk_col = [[NSTableColumn alloc] initWithIdentifier:@"K"];
    hk_col.width = [@"3" sizeWithAttributes:@{NSFontAttributeName: m_LabelFont}].width + 2.;
    [m_TableView addTableColumn:hk_col];

    double total_columns_width = 0;
    for( NSTableColumn *column in m_TableView.tableColumns ) {
        total_columns_width += column.width;
    }

    m_ScrollView.documentView = m_TableView;
    [v addSubview:m_ScrollView];

    auto views = NSDictionaryOfVariableBindings(m_LabelTextField, m_FilterTextField, m_ScrollView);
    [v addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-(4)-[m_LabelTextField(>=40)]-(4)-|"
                                                              options:0
                                                              metrics:nil
                                                                views:views]];
    [v addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-(4)-[m_FilterTextField(>=40)]-(4)-|"
                                                              options:0
                                                              metrics:nil
                                                                views:views]];

    //    [v addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-(==0)-[m_ScrollView]-(==0)-|"
    // TODO: for MacOS < 11 remove this VVVV hack ^^^
    [v addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-(==-5)-[m_ScrollView]-(==-5)-|"
                                                              options:0
                                                              metrics:nil
                                                                views:views]];
    [v addConstraints:[NSLayoutConstraint
                          constraintsWithVisualFormat:
                              @"V:|-(4)-[m_LabelTextField]-(4)-[m_FilterTextField]-(4)-[m_ScrollView(>=20)]-(4)-|"
                                              options:0
                                              metrics:nil
                                                views:views]];

    [v addConstraint:[NSLayoutConstraint constraintWithItem:m_ScrollView
                                                  attribute:NSLayoutAttributeWidth
                                                  relatedBy:NSLayoutRelationGreaterThanOrEqual
                                                     toItem:nil
                                                  attribute:NSLayoutAttributeNotAnAttribute
                                                 multiplier:1.
                                                   constant:total_columns_width + 32.]];

    m_ScrollViewHeightConstraint = [NSLayoutConstraint constraintWithItem:m_ScrollView
                                                                attribute:NSLayoutAttributeHeight
                                                                relatedBy:NSLayoutRelationGreaterThanOrEqual
                                                                   toItem:nil
                                                                attribute:NSLayoutAttributeNotAnAttribute
                                                               multiplier:1.
                                                                 constant:0.];
    m_ScrollViewHeightConstraint.priority = NSLayoutPriorityWindowSizeStayPut;
    [v addConstraint:m_ScrollViewHeightConstraint];

    self.view = v;
}

- (void)setupHotKeysMapping
{
    const auto items = m_Parent.commandItems;
    m_HotKeyIdxToItemIdx.fill(-1);
    m_ItemIdxToHotKeyIdx.resize(items.size(), -1);
    for( size_t it_idx = 0, hk_idx = 0; it_idx < items.size() && hk_idx < m_HotKeyIdxToItemIdx.size(); ++it_idx ) {
        if( items[it_idx].separatorItem || items[it_idx].sectionHeader )
            continue;
        m_ItemIdxToHotKeyIdx[it_idx] = static_cast<signed char>(hk_idx);
        m_HotKeyIdxToItemIdx[hk_idx] = static_cast<int>(it_idx);
        ++hk_idx;
    }
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return m_Parent.commandItems.size();
}

- (NSString *)hotkeyLabelForItemAtIndex:(size_t)_index
{
    if( _index >= m_ItemIdxToHotKeyIdx.size() )
        return @"";
    switch( m_ItemIdxToHotKeyIdx[_index] ) {
        case 0:
            return @"1";
        case 1:
            return @"2";
        case 2:
            return @"3";
        case 3:
            return @"4";
        case 4:
            return @"5";
        case 5:
            return @"6";
        case 6:
            return @"7";
        case 7:
            return @"8";
        case 8:
            return @"9";
        case 9:
            return @"0";
        case 10:
            return @"-";
        case 11:
            return @"=";
        default:
            return @"";
    }
}

- (std::optional<size_t>)itemIndexFromKeyDown:(NSEvent *)_event
{
    // Use only clear keypresses, no modifiers
    if( _event.modifierFlags & (NSEventModifierFlagShift | NSEventModifierFlagControl | NSEventModifierFlagOption |
                                NSEventModifierFlagCommand) )
        return {};

    NSString *chars = _event.characters;
    if( chars == nil || chars.length != 1 )
        return {};
    const unsigned short ch = [chars characterAtIndex:0];
    auto to_idx = [&](size_t _idx) -> std::optional<size_t> {
        assert(_idx < m_HotKeyIdxToItemIdx.size());
        if( m_HotKeyIdxToItemIdx[_idx] >= 0 )
            return m_HotKeyIdxToItemIdx[_idx];
        return {};
    };

    switch( ch ) {
        case '1':
            return to_idx(0);
        case '2':
            return to_idx(1);
        case '3':
            return to_idx(2);
        case '4':
            return to_idx(3);
        case '5':
            return to_idx(4);
        case '6':
            return to_idx(5);
        case '7':
            return to_idx(6);
        case '8':
            return to_idx(7);
        case '9':
            return to_idx(8);
        case '0':
            return to_idx(9);
        case '-':
            return to_idx(10);
        case '=':
            return to_idx(11);
        default:
            return {};
    }
}

- (NSView *)tableView:(NSTableView *)_table viewForTableColumn:(NSTableColumn *)_column row:(NSInteger)_row
{
    const auto items = m_Parent.commandItems;
    if( _row < 0 || _row >= static_cast<long>(items.size()) ) {
        return nil;
    }
    NCCommandPopoverItem *item = items[_row];
    if( item.separatorItem ) {
        NSBox *box = [[NSBox alloc] initWithFrame:NSRect()];
        box.boxType = NSBoxSeparator;
        box.translatesAutoresizingMaskIntoConstraints = false;
        NSTableCellView *cv = [[NSTableCellView alloc] initWithFrame:NSRect()];
        [cv addSubview:box];
        [cv addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-(==0)-[box]-(==0)-|"
                                                                   options:0
                                                                   metrics:nil
                                                                     views:NSDictionaryOfVariableBindings(box)]];
        [cv addConstraint:[NSLayoutConstraint constraintWithItem:box
                                                       attribute:NSLayoutAttributeCenterY
                                                       relatedBy:NSLayoutRelationEqual
                                                          toItem:cv
                                                       attribute:NSLayoutAttributeCenterY
                                                      multiplier:1.
                                                        constant:0.]];
        [cv addConstraint:[NSLayoutConstraint constraintWithItem:box
                                                       attribute:NSLayoutAttributeHeight
                                                       relatedBy:NSLayoutRelationEqual
                                                          toItem:nil
                                                       attribute:NSLayoutAttributeNotAnAttribute
                                                      multiplier:0.
                                                        constant:1.]];
        return cv;
    }
    else if( item.sectionHeader ) {
        return nil; // handled in rowViewForRow
    }
    else {
        
        if( [_column.identifier isEqualToString:@"I"] ) {
            if( item.image == nil )
                return nil;
            NSImageView *iv = [[NSImageView alloc] initWithFrame:NSRect()];
            iv.image = item.image;
            iv.imageFrameStyle = NSImageFrameNone;
            iv.imageAlignment = NSImageAlignCenter;
            iv.imageScaling = NSImageScaleProportionallyDown;
            iv.translatesAutoresizingMaskIntoConstraints = false;
            NSTableCellView *cv = [[NSTableCellView alloc] initWithFrame:NSRect()];
            [cv addSubview:iv];
            cv.imageView = iv;
            [cv addConstraints:@[
                [NSLayoutConstraint constraintWithItem:iv
                                             attribute:NSLayoutAttributeWidth
                                             relatedBy:NSLayoutRelationEqual
                                                toItem:nil
                                             attribute:NSLayoutAttributeNotAnAttribute
                                            multiplier:1.
                                              constant:16.],
                [NSLayoutConstraint constraintWithItem:iv
                                             attribute:NSLayoutAttributeHeight
                                             relatedBy:NSLayoutRelationEqual
                                                toItem:nil
                                             attribute:NSLayoutAttributeNotAnAttribute
                                            multiplier:1.
                                              constant:16.],
                [NSLayoutConstraint constraintWithItem:iv
                                             attribute:NSLayoutAttributeLeft
                                             relatedBy:NSLayoutRelationEqual
                                                toItem:cv
                                             attribute:NSLayoutAttributeLeft
                                            multiplier:1.
                                              constant:0.],
                [NSLayoutConstraint constraintWithItem:iv
                                             attribute:NSLayoutAttributeCenterY
                                             relatedBy:NSLayoutRelationEqual
                                                toItem:cv
                                             attribute:NSLayoutAttributeCenterY
                                            multiplier:1.
                                              constant:0.]
            ]];
            return cv;
        }
        
        if( [_column.identifier isEqualToString:@"L"] ) {
            NSTextField *tf = [[NSTextField alloc] initWithFrame:NSRect()];
            tf.translatesAutoresizingMaskIntoConstraints = false;
            tf.stringValue = item.title;
            tf.bordered = false;
            tf.editable = false;
            tf.usesSingleLineMode = true;
            tf.drawsBackground = false;
            tf.font = m_LabelFont;
            tf.textColor = NSColor.labelColor;
            
            NSTableCellView *cv = [[NSTableCellView alloc] initWithFrame:NSRect()];
            [cv addSubview:tf];
            cv.textField = tf;
            [cv addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-(==0)-[tf]-(==0)-|"
                                                                       options:0
                                                                       metrics:nil
                                                                         views:NSDictionaryOfVariableBindings(tf)]];
            [cv addConstraint:[NSLayoutConstraint constraintWithItem:tf
                                                           attribute:NSLayoutAttributeCenterY
                                                           relatedBy:NSLayoutRelationEqual
                                                              toItem:cv
                                                           attribute:NSLayoutAttributeCenterY
                                                          multiplier:1.
                                                            constant:0.]];
            return cv;
        }
        
        if( [_column.identifier isEqualToString:@"K"] ) {
            NSString *hk = [self hotkeyLabelForItemAtIndex:_row];
            if( hk.length == 0 )
                return nil;
            NSTextField *tf = [[NSTextField alloc] initWithFrame:NSRect()];
            tf.translatesAutoresizingMaskIntoConstraints = false;
            tf.stringValue = hk;
            tf.bordered = false;
            tf.editable = false;
            tf.drawsBackground = false;
            tf.usesSingleLineMode = true;
            tf.alignment = NSTextAlignmentCenter;
            tf.font = m_LabelFont;
            tf.textColor = NSColor.disabledControlTextColor;
            
            NSTableCellView *cv = [[NSTableCellView alloc] initWithFrame:NSRect()];
            [cv addSubview:tf];
            cv.textField = tf;
            [cv addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-(==0)-[tf]-(==0)-|"
                                                                       options:0
                                                                       metrics:nil
                                                                         views:NSDictionaryOfVariableBindings(tf)]];
            [cv addConstraint:[NSLayoutConstraint constraintWithItem:tf
                                                           attribute:NSLayoutAttributeCenterY
                                                           relatedBy:NSLayoutRelationEqual
                                                              toItem:cv
                                                           attribute:NSLayoutAttributeCenterY
                                                          multiplier:1.
                                                            constant:0.]];
            return cv;
        }
    }
    return nil;
}

- (nullable NSTableRowView *)tableView:(NSTableView *)_table rowViewForRow:(NSInteger)_row
{
    const auto items = m_Parent.commandItems;
    if( _row < 0 || _row >= static_cast<long>(items.size()) ) {
        return nil;
    }
    NCCommandPopoverItem *item = items[_row];
    if( !item.sectionHeader )
        return nil;

    NCCommandPopoverTableSectionRowView *rv = [[NCCommandPopoverTableSectionRowView alloc] initWithFrame:NSRect()];

    NSTextField *tf = [[NSTextField alloc] initWithFrame:NSRect()];
    tf.translatesAutoresizingMaskIntoConstraints = false;
    tf.stringValue = item.title;
    tf.bordered = false;
    tf.editable = false;
    tf.usesSingleLineMode = true;
    tf.drawsBackground = false;
    tf.font = m_SectionFont;
    tf.textColor = NSColor.disabledControlTextColor;

    [rv addSubview:tf];

    [rv addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[tf]-(==0)-|"
                                                               options:0
                                                               metrics:nil
                                                                 views:NSDictionaryOfVariableBindings(tf)]];
    [rv addConstraint:[NSLayoutConstraint constraintWithItem:tf
                                                   attribute:NSLayoutAttributeLeading
                                                   relatedBy:NSLayoutRelationEqual
                                                      toItem:rv
                                                   attribute:NSLayoutAttributeLeading
                                                  multiplier:1.
                                                    constant:m_RowPadding]];

    [rv addConstraint:[NSLayoutConstraint constraintWithItem:tf
                                                   attribute:NSLayoutAttributeCenterY
                                                   relatedBy:NSLayoutRelationEqual
                                                      toItem:rv
                                                   attribute:NSLayoutAttributeCenterY
                                                  multiplier:1.
                                                    constant:0.]];
    return rv;
}

- (void)viewDidAppear
{
    [super viewDidAppear];
    [self.view.window makeFirstResponder:m_TableView];

    if( !m_Parent.commandItems.empty() && [self tableView:m_TableView shouldSelectRow:0] ) {
        [m_TableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:false];
    }

    const auto items = m_Parent.commandItems;
    double height = 18.; // why???
    for( size_t idx = 0; idx < std::min(items.size(), 30ul); ++idx ) {
        height += items[idx].separatorItem ? m_SeparatorRowHeight : m_RegularRowHeight;
        if( idx > 0 )
            height += m_TableView.intercellSpacing.height;
    }
    m_ScrollViewHeightConstraint.constant = height;

    //    [m_TableView tile]; // no idea why this is not triggered automatically?
    [self.view layout];

    [m_Parent setContentSize:self.view.fittingSize];
}

- (void)tableView:(NSTableView *)_table didClickTableRow:(NSInteger)_row
{
    const auto items = m_Parent.commandItems;
    if( _row >= 0 || _row < static_cast<long>(items.size()) ) {
        NCCommandPopoverItem *item = items[_row];
        [m_Parent close]; // should we close BEFORE or AFTER triggering the action??
        if( ![NSApplication.sharedApplication sendAction:item.action to:item.target from:item] ) {
            NSBeep();
        }
    }
}

- (double)tableView:(NSTableView *)_table heightOfRow:(long)_row
{
    const auto items = m_Parent.commandItems;
    if( _row >= 0 && _row < static_cast<long>(items.size()) && items[_row].separatorItem )
        return m_SeparatorRowHeight;
    return m_RegularRowHeight;
}

- (BOOL)tableView:(NSTableView *)_table shouldSelectRow:(NSInteger)_row
{
    const auto items = m_Parent.commandItems;
    if( _row >= 0 && _row < static_cast<long>(items.size()) )
        return !(items[_row].separatorItem || items[_row].sectionHeader);
    return false;
}

@end

static constexpr NSTrackingAreaOptions g_TrackingOptions =
    NSTrackingMouseEnteredAndExited | NSTrackingMouseMoved | NSTrackingActiveInActiveApp;

@implementation NCCommandPopoverTableView {
    NSTrackingArea *m_TrackingArea;
}

- (instancetype)initWithFrame:(NSRect)_frame
{
    if( self = [super initWithFrame:_frame] ) {
        m_TrackingArea = [[NSTrackingArea alloc] initWithRect:self.bounds
                                                      options:g_TrackingOptions
                                                        owner:self
                                                     userInfo:nil];
        [self addTrackingArea:m_TrackingArea];
    }
    return self;
}

- (void)keyDown:(NSEvent *)_event
{
    const unsigned short keycode = _event.keyCode;
    if( keycode == kVK_Return || keycode == kVK_ANSI_KeypadEnter || keycode == kVK_Space ) {
        const long selected = self.selectedRow;
        if( selected != -1 ) {
            [static_cast<NCCommandPopoverViewController *>(self.delegate) tableView:self didClickTableRow:selected];
        }
        else {
            NSBeep();
        }
    }
    else if( auto idx = [static_cast<NCCommandPopoverViewController *>(self.delegate) itemIndexFromKeyDown:_event] ) {
        if( static_cast<long>(*idx) < self.numberOfRows ) {
            [static_cast<NCCommandPopoverViewController *>(self.delegate) tableView:self didClickTableRow:*idx];
        }
        else {
            NSBeep();
        }
    }
    else {
        [super keyDown:_event];
    }
}

- (void)updateTrackingAreas
{
    [super updateTrackingAreas];
    [self removeTrackingArea:m_TrackingArea];
    m_TrackingArea = [[NSTrackingArea alloc] initWithRect:self.bounds
                                                  options:g_TrackingOptions
                                                    owner:self
                                                 userInfo:nil];
    [self addTrackingArea:m_TrackingArea];
}

- (void)mouseMoved:(NSEvent *)_event
{
    const NSPoint global = _event.locationInWindow;
    const NSPoint local = [self convertPoint:global fromView:nil];
    const long row = [self rowAtPoint:local];
    if( row == self.selectedRow )
        return;
    if( row >= 0 && row < self.numberOfRows && [self.delegate tableView:self shouldSelectRow:row] )
        [self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:false];
    else
        [self selectRowIndexes:[NSIndexSet indexSet] byExtendingSelection:false];
}

- (void)mouseEntered:(NSEvent *)_event
{
    [self mouseMoved:_event];
}

- (void)mouseExited:(NSEvent *)_event
{
    [self selectRowIndexes:[NSIndexSet indexSet] byExtendingSelection:false];
}

- (void)mouseDown:(NSEvent *)_event
{
    [super mouseDown:_event];
    const NSPoint global = _event.locationInWindow;
    const NSPoint local = [self convertPoint:global fromView:nil];
    if( const long row = [self rowAtPoint:local]; row != -1 && [self.delegate tableView:self shouldSelectRow:row] ) {
        [static_cast<NCCommandPopoverViewController *>(self.delegate) tableView:self didClickTableRow:row];
    }
}

@end

@implementation NCCommandPopoverTableSectionRowView
@end

@implementation NCCommandPopover {
    std::vector<NCCommandPopoverItem *> m_Items;
    NCCommandPopoverViewController *m_Controller;
}

- (instancetype _Nonnull)initWithTitle:(NSString *_Nonnull)_title
{
    if( self = [super init] ) {
        self.behavior = NSPopoverBehaviorTransient;
        self.animates = false;
        m_Controller = [[NCCommandPopoverViewController alloc] initWithPopover:self andTitle:_title];
        self.contentViewController = m_Controller;
    }
    return self;
}

- (void)addItem:(NCCommandPopoverItem *_Nonnull)_new_item
{
    assert(std::ranges::find(m_Items, _new_item) == m_Items.end());
    m_Items.push_back(_new_item);
}

//- (void)showRelativeToRect:(NSRect)_positioning_rect
//                    ofView:(NSView *)_positioning_view
//             preferredEdge:(NSRectEdge)_preferred_edge
//{
//    if( [self respondsToSelector:NSSelectorFromString(@"shouldHideAnchor")] ) {
//
//        [self setValue:@true forKeyPath:@"shouldHideAnchor"];
//        const bool flipped = _positioning_view.flipped;
//        // TODO: clarify!
//        if( _preferred_edge == NSMaxYEdge ) {
//            const double arror_height = 19.;
//            _positioning_rect = NSOffsetRect(_positioning_rect, 0., flipped ? -arror_height : arror_height);
//        }
//        if( _preferred_edge == NSMinYEdge ) {
//            const double arror_height = 17.;
//            _positioning_rect = NSOffsetRect(_positioning_rect, 0., flipped ? arror_height : -arror_height);
//        }
//    }
//    [super showRelativeToRect:_positioning_rect ofView:_positioning_view preferredEdge:_preferred_edge];
//}

- (std::span<NCCommandPopoverItem *const>)commandItems
{
    return m_Items;
}

- (double)maximumCommandTitleWidth
{
    if( m_Items.empty() ) {
        return 0.;
    }
    auto attributes = @{NSFontAttributeName: [NSFont menuFontOfSize:0.0]};
    auto widths = m_Items | std::views::transform([attributes](NCCommandPopoverItem *_item) -> double {
                      return [_item.title sizeWithAttributes:attributes].width;
                  });
    return *std::ranges::max_element(widths);
}

@end

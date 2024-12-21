// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "CommandPopover.h"
#include <Carbon/Carbon.h>
#include <vector>
#include <ranges>
#include <algorithm>
#include <numeric>
#include <span>
#include <optional>

static constexpr double g_ContentViewCornerRadius = 10.;

@interface NCCommandPopover (Private)
- (std::span<NCCommandPopoverItem *const>)commandItems;

@property(nonatomic, readwrite) NSSize contentSize;

@end

@interface NCCommandPopoverWindow : NSWindow
@end

@interface NCCommandPopoverContentView : NSView
@end

@interface NCCommandPopoverViewController : NSViewController <NSTableViewDataSource, //
                                                              NSTableViewDelegate,   //
                                                              NSTextFieldDelegate>
- (instancetype _Nonnull)initWithPopover:(NCCommandPopover *)_popover andTitle:(NSString *)_title;
- (void)tableView:(NSTableView *)_table didClickTableRow:(NSInteger)_row;
- (bool)processKeyDown:(NSEvent *)_event;
@property(readonly, nonatomic) bool numericHotkeysEnabled;
@end

@interface NCCommandPopoverTableView : NSTableView
- (void)processMouseMoved:(NSPoint)_local_coords;
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
@synthesize toolTip;

- (NCCommandPopoverItem *_Nonnull)init
{
    self = [super init];
    if( self ) {
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
    NSImageView *m_SearchIcon;
    NCCommandPopoverTableView *m_TableView;
    NSScrollView *m_ScrollView;
    NSLayoutConstraint *m_ScrollViewHeightConstraint;
    NSFont *m_LabelFont;
    NSFont *m_SectionFont;
    __weak NCCommandPopover *m_Parent;
    std::vector<NCCommandPopoverItem *> m_AllItems;
    std::vector<NCCommandPopoverItem *> m_FilteredItems;
    std::vector<signed char> m_ItemIdxToHotKeyIdx; // negative means no mapping
    std::array<int, 12> m_HotKeyIdxToItemIdx;      // negative means no mapping
    double m_RegularRowHeight;
    double m_SeparatorRowHeight;
}

- (instancetype _Nonnull)initWithPopover:(NCCommandPopover *)_popover andTitle:(NSString *)_title
{
    self = [super initWithNibName:nil bundle:nil];
    if( self ) {
        m_Parent = _popover;
        m_Title = _title;
        m_LabelFont = [NSFont menuFontOfSize:0.0];
        m_SectionFont = [NSFont menuFontOfSize:NSFont.smallSystemFontSize];
        m_RegularRowHeight = std::round(m_LabelFont.pointSize + 7.);
        m_SeparatorRowHeight = 11.;
    }
    return self;
}

- (void)loadView
{
    m_AllItems.assign(m_Parent.commandItems.begin(), m_Parent.commandItems.end());
    m_FilteredItems = m_AllItems;

    [self setupHotKeysMapping];
    const double max_title_width = [self maximumCommandTitleWidth];
    const double title_col_margin = 20.;
    const double title_col_width = std::max(max_title_width + title_col_margin, 160.);

    NCCommandPopoverContentView *v = [[NCCommandPopoverContentView alloc] initWithFrame:NSMakeRect(0., 0., 200., 200.)];

    m_SearchIcon = [[NSImageView alloc] initWithFrame:NSRect()];
    m_SearchIcon.translatesAutoresizingMaskIntoConstraints = false;
    m_SearchIcon.image = [NSImage imageNamed:NSImageNameTouchBarSearchTemplate];
    m_SearchIcon.imageAlignment = NSImageAlignCenter;
    m_SearchIcon.imageScaling = NSImageScaleProportionallyDown;
    m_SearchIcon.imageFrameStyle = NSImageFrameNone;
    [v addSubview:m_SearchIcon];

    m_LabelTextField = [[NSTextField alloc] initWithFrame:NSRect()];
    m_LabelTextField.stringValue = @"";
    m_LabelTextField.placeholderString = m_Title;
    m_LabelTextField.bordered = false;
    m_LabelTextField.editable = true;
    m_LabelTextField.drawsBackground = false;
    m_LabelTextField.translatesAutoresizingMaskIntoConstraints = false;
    m_LabelTextField.font = m_LabelFont;
    m_LabelTextField.focusRingType = NSFocusRingTypeNone;
    m_LabelTextField.usesSingleLineMode = true;
    m_LabelTextField.lineBreakMode = NSLineBreakByClipping;
    m_LabelTextField.delegate = self;
    [v addSubview:m_LabelTextField];

    m_ScrollView = [[NSScrollView alloc] initWithFrame:NSRect()];
    m_ScrollView.borderType = NSNoBorder;
    m_ScrollView.hasVerticalScroller = false;
    m_ScrollView.hasHorizontalScroller = false;
    m_ScrollView.verticalScrollElasticity = NSScrollElasticityNone;
    m_ScrollView.horizontalScrollElasticity = NSScrollElasticityNone;
    m_ScrollView.translatesAutoresizingMaskIntoConstraints = false;
    m_ScrollView.drawsBackground = false;
    m_ScrollView.contentInsets = NSEdgeInsets{0., 0., 0., 0.};

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
        m_TableView.style = NSTableViewStyleFullWidth;
    }
    else {
        m_TableView.selectionHighlightStyle = NSTableViewSelectionHighlightStyleRegular;
    }
    m_TableView.usesAlternatingRowBackgroundColors = false;
    m_TableView.backgroundColor = NSColor.clearColor;
    m_TableView.rowSizeStyle = NSTableViewRowSizeStyleCustom;
    m_TableView.rowHeight = m_RegularRowHeight;

    NSTableColumn *img_col = [[NSTableColumn alloc] initWithIdentifier:@"I"];
    if( @available(macOS 11.0, *) )
        img_col.width = 20.;
    else
        img_col.width = 26.;
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

    auto views = NSDictionaryOfVariableBindings(m_LabelTextField, m_SearchIcon, m_ScrollView);
    [v addConstraints:[NSLayoutConstraint
                          constraintsWithVisualFormat:@"H:|-(6)-[m_SearchIcon(==16)]-(4)-[m_LabelTextField(>=40)]-(4)-|"
                                              options:0
                                              metrics:nil
                                                views:views]];

    [v addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-(==0)-[m_ScrollView]-(==0)-|"
                                                              options:0
                                                              metrics:nil
                                                                views:views]];
    [v addConstraints:[NSLayoutConstraint
                          constraintsWithVisualFormat:@"V:|-(6)-[m_LabelTextField]-(4)-[m_ScrollView(>=20)]-(4)-|"
                                              options:0
                                              metrics:nil
                                                views:views]];
    [v addConstraint:[NSLayoutConstraint constraintWithItem:m_SearchIcon
                                                  attribute:NSLayoutAttributeCenterY
                                                  relatedBy:NSLayoutRelationEqual
                                                     toItem:m_LabelTextField
                                                  attribute:NSLayoutAttributeCenterY
                                                 multiplier:1.
                                                   constant:0.]];
    [v addConstraint:[NSLayoutConstraint constraintWithItem:m_SearchIcon
                                                  attribute:NSLayoutAttributeHeight
                                                  relatedBy:NSLayoutRelationGreaterThanOrEqual
                                                     toItem:nil
                                                  attribute:NSLayoutAttributeNotAnAttribute
                                                 multiplier:1.
                                                   constant:16.]];

    [v addConstraint:[NSLayoutConstraint constraintWithItem:m_ScrollView
                                                  attribute:NSLayoutAttributeWidth
                                                  relatedBy:NSLayoutRelationGreaterThanOrEqual
                                                     toItem:nil
                                                  attribute:NSLayoutAttributeNotAnAttribute
                                                 multiplier:1.
                                                   constant:total_columns_width + 16.]];

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
    [self updateScrollViewHeighConstraint];
    [self.view layout];
}

- (void)updateScrollViewHeighConstraint
{
    const auto &items = m_FilteredItems;
    double height = 2.; // why???
    const size_t max_visible_rows = 30;
    for( size_t idx = 0; idx < std::min(items.size(), max_visible_rows); ++idx ) {
        height += items[idx].separatorItem ? m_SeparatorRowHeight : m_RegularRowHeight;
        if( idx > 0 )
            height += m_TableView.intercellSpacing.height;
    }
    m_ScrollViewHeightConstraint.constant = height;
}

- (void)viewDidAppear
{
    [super viewDidAppear];
    [self.view.window makeFirstResponder:m_TableView];
    [self updateScrollViewHeighConstraint];
    [self.view layout];
    m_Parent.contentSize = self.view.fittingSize;

    // First try place the selection where the mouse cursor currently is to avoid flicker
    // (mouse-tracking events are processed later and there's a visual delay between the appearance of the view and
    // setting the selection via mouse-tracking)
    const NSPoint global_mouse_location = NSEvent.mouseLocation;
    const NSPoint window_mouse_location = [self.view.window convertPointFromScreen:global_mouse_location];
    const NSPoint table_mouse_location = [m_TableView convertPoint:window_mouse_location fromView:nil];
    if( [m_TableView mouse:table_mouse_location inRect:m_TableView.bounds] ) {
        [m_TableView processMouseMoved:table_mouse_location];
    }

    // And only afterwards set to the first row if there's no selection
    if( m_TableView.selectedRow == -1 ) {
        [self selectFirstSelectableRow];
    }
}

- (double)maximumCommandTitleWidth
{
    if( m_AllItems.empty() ) {
        return 0.;
    }
    auto attributes = @{NSFontAttributeName: m_LabelFont};
    auto widths = m_AllItems | std::views::transform([attributes](NCCommandPopoverItem *_item) -> double {
                      return [_item.title sizeWithAttributes:attributes].width;
                  });
    return *std::ranges::max_element(widths);
}

- (void)setupHotKeysMapping
{
    const auto &items = m_FilteredItems;
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
    return m_FilteredItems.size();
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
    if( !self.numericHotkeysEnabled )
        return {};

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
    const auto &items = m_FilteredItems;
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
                                             attribute:NSLayoutAttributeRight
                                             relatedBy:NSLayoutRelationEqual
                                                toItem:cv
                                             attribute:NSLayoutAttributeRight
                                            multiplier:1.
                                              constant:-4.],
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
            tf.toolTip = item.toolTip;

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

        if( [_column.identifier isEqualToString:@"K"] && self.numericHotkeysEnabled ) {
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
    const auto &items = m_FilteredItems;
    if( _row < 0 || _row >= static_cast<long>(items.size()) ) {
        return nil;
    }
    NCCommandPopoverItem *item = items[_row];
    if( !item.sectionHeader )
        return nil;

    NSTextField *tf = [[NSTextField alloc] initWithFrame:NSRect()];
    tf.translatesAutoresizingMaskIntoConstraints = false;
    tf.stringValue = item.title;
    tf.bordered = false;
    tf.editable = false;
    tf.usesSingleLineMode = true;
    tf.drawsBackground = false;
    tf.font = m_SectionFont;
    tf.textColor = NSColor.disabledControlTextColor;

    NSTableRowView *rv = [[NSTableRowView alloc] initWithFrame:NSRect()];
    [rv addSubview:tf];
    [rv addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-(==6)-[tf]-(==0)-|"
                                                               options:0
                                                               metrics:nil
                                                                 views:NSDictionaryOfVariableBindings(tf)]];
    [rv addConstraint:[NSLayoutConstraint constraintWithItem:tf
                                                   attribute:NSLayoutAttributeCenterY
                                                   relatedBy:NSLayoutRelationEqual
                                                      toItem:rv
                                                   attribute:NSLayoutAttributeCenterY
                                                  multiplier:1.
                                                    constant:0.]];
    return rv;
}

- (void)tableView:(NSTableView *)_table didClickTableRow:(NSInteger)_row
{
    const auto &items = m_FilteredItems;
    if( _row >= 0 || _row < static_cast<long>(items.size()) ) {
        NCCommandPopoverItem *item = items[_row];
        SEL action = item.action;
        id target = item.target;

        [m_Parent close]; // should we close BEFORE or AFTER triggering the action??

        if( ![NSApplication.sharedApplication sendAction:action to:target from:item] ) {
            NSBeep();
        }
    }
}

- (double)tableView:(NSTableView *)_table heightOfRow:(long)_row
{
    const auto &items = m_FilteredItems;
    if( _row >= 0 && _row < static_cast<long>(items.size()) && items[_row].separatorItem )
        return m_SeparatorRowHeight;
    return m_RegularRowHeight;
}

- (BOOL)tableView:(NSTableView *)_table shouldSelectRow:(NSInteger)_row
{
    const auto &items = m_FilteredItems;
    if( _row >= 0 && _row < static_cast<long>(items.size()) )
        return !(items[_row].separatorItem || items[_row].sectionHeader);
    return false;
}

- (bool)processKeyDown:(NSEvent *)_event
{
    // Use only clear keypresses, no modifiers
    if( _event.modifierFlags & (NSEventModifierFlagControl | NSEventModifierFlagCommand) )
        return false;

    const auto keycode = _event.keyCode;
    if( keycode == kVK_Delete ) {
        NSString *str = m_LabelTextField.stringValue ? m_LabelTextField.stringValue : @"";
        if( str.length > 0 ) {
            str = [str substringToIndex:str.length - 1];
            m_LabelTextField.stringValue = str;
            [self updateFiltering];
            return true;
        }
        else {
            return false;
        }
    }

    static NSCharacterSet *const allowed = [] {
        NSMutableCharacterSet *const set = [[NSMutableCharacterSet alloc] init];
        [set formUnionWithCharacterSet:NSCharacterSet.alphanumericCharacterSet];
        [set formUnionWithCharacterSet:NSCharacterSet.punctuationCharacterSet];
        [set formUnionWithCharacterSet:NSCharacterSet.symbolCharacterSet];
        return set.invertedSet;
    }();
    NSString *chars = _event.characters;
    if( chars.length == 0 || [chars rangeOfCharacterFromSet:allowed].location != NSNotFound ) {
        return false;
    }

    NSString *str = m_LabelTextField.stringValue ? m_LabelTextField.stringValue : @"";
    str = [str stringByAppendingString:chars];
    m_LabelTextField.stringValue = str;

    [self updateFiltering];
    return true;
}

- (void)controlTextDidChange:(NSNotification *) [[maybe_unused]] _obj
{
    [self updateFiltering];
}

- (BOOL)control:(NSControl *)_control textView:(NSTextView *)_text_biew doCommandBySelector:(SEL)_sel
{
    if( _control == m_LabelTextField && _sel == @selector(cancelOperation:) ) {
        [m_Parent close];
        return true;
    }
    return false;
}

- (void)updateFiltering
{
    NSString *str = m_LabelTextField.stringValue ? m_LabelTextField.stringValue : @"";
    auto validate = [str](NCCommandPopoverItem *_item) -> bool {
        if( str.length == 0 )
            return true; // no filtering
        if( _item.separatorItem || _item.sectionHeader )
            return false;
        return [_item.title rangeOfString:str options:NSCaseInsensitiveSearch].location != NSNotFound;
    };

    std::vector<NCCommandPopoverItem *> new_filtered;
    std::ranges::copy_if(m_AllItems, std::back_inserter(new_filtered), validate);
    if( new_filtered == m_FilteredItems )
        return; // nothing to do

    m_FilteredItems = new_filtered;
    [self setupHotKeysMapping];
    [m_TableView reloadData];
    [self selectFirstSelectableRow];

    [self updateScrollViewHeighConstraint];
    [self.view layout];
    m_Parent.contentSize = self.view.fittingSize;
}

- (void)selectFirstSelectableRow
{
    const auto &items = m_FilteredItems;
    for( size_t idx = 0; idx < items.size(); ++idx ) {
        if( [self tableView:m_TableView shouldSelectRow:idx] ) {
            [m_TableView selectRowIndexes:[NSIndexSet indexSetWithIndex:idx] byExtendingSelection:false];
            break;
        }
    }
}

- (bool)numericHotkeysEnabled
{
    return m_LabelTextField.stringValue == nil || m_LabelTextField.stringValue.length == 0;
}

@end

static constexpr NSTrackingAreaOptions g_TrackingOptions =
    NSTrackingMouseEnteredAndExited | NSTrackingMouseMoved | NSTrackingActiveInActiveApp;

@implementation NCCommandPopoverTableView {
    NSTrackingArea *m_TrackingArea;
}

- (instancetype)initWithFrame:(NSRect)_frame
{
    self = [super initWithFrame:_frame];
    if( self ) {
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
    NCCommandPopoverViewController *ctrl = static_cast<NCCommandPopoverViewController *>(self.delegate);
    assert(ctrl != nil);
    const unsigned short keycode = _event.keyCode;
    if( keycode == kVK_Return || keycode == kVK_ANSI_KeypadEnter || keycode == kVK_Space ) {
        const long selected = self.selectedRow;
        if( selected != -1 ) {
            [ctrl tableView:self didClickTableRow:selected];
        }
        else {
            NSBeep();
        }
    }
    else if( keycode == kVK_Home ) {
        const long rows = self.numberOfRows;
        for( long row = 0; row < rows; ++row )
            if( [ctrl tableView:self shouldSelectRow:row] ) {
                [self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:false];
                [self scrollRowToVisible:row];
                break;
            }
    }
    else if( keycode == kVK_End ) {
        const long rows = self.numberOfRows;
        for( long row = rows - 1; row >= 0; --row )
            if( [ctrl tableView:self shouldSelectRow:row] ) {
                [self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:false];
                [self scrollRowToVisible:row];
                break;
            }
    }
    else if( auto idx = [ctrl itemIndexFromKeyDown:_event] ) {
        if( static_cast<long>(*idx) < self.numberOfRows ) {
            [ctrl tableView:self didClickTableRow:*idx];
        }
        else {
            NSBeep();
        }
    }
    else if( [ctrl processKeyDown:_event] ) {
        /*nothing - already processed*/
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

- (void)processMouseMoved:(NSPoint)_local_coords
{
    const long row = [self rowAtPoint:_local_coords];
    if( row == self.selectedRow )
        return;
    if( row >= 0 && row < self.numberOfRows && [self.delegate tableView:self shouldSelectRow:row] )
        [self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:false];
    else
        [self selectRowIndexes:[NSIndexSet indexSet] byExtendingSelection:false];
}

- (void)mouseMoved:(NSEvent *)_event
{
    const NSPoint global = _event.locationInWindow;
    const NSPoint local = [self convertPoint:global fromView:nil];
    [self processMouseMoved:local];
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

@implementation NCCommandPopoverWindow {
    id m_GlobalEventMonitor;
    id m_LocalEventMonitor;
}

- (instancetype)initWithContentRect:(NSRect)contentRect
{
    self = [super initWithContentRect:contentRect
                            styleMask:NSWindowStyleMaskBorderless
                              backing:NSBackingStoreBuffered
                                defer:true];
    if( self ) {
        self.opaque = false;
        self.backgroundColor = NSColor.clearColor;
        self.level = NSPopUpMenuWindowLevel;
        self.ignoresMouseEvents = false;
        self.hasShadow = true;
        self.releasedWhenClosed = false;
    }
    return self;
}

- (BOOL)canBecomeKeyWindow
{
    return true;
}

- (void)makeKeyAndOrderFront:(nullable id)_sender
{
    [super makeKeyAndOrderFront:_sender];

    __weak NCCommandPopoverWindow *weak_self = self;
    const NSEventMask mask = NSEventMaskLeftMouseDown | NSEventMaskRightMouseDown | NSEventMaskOtherMouseDown;
    m_GlobalEventMonitor = [NSEvent addGlobalMonitorForEventsMatchingMask:mask
                                                                  handler:^(NSEvent *_Nonnull _event) {
                                                                    if( NCCommandPopoverWindow *me = weak_self )
                                                                        [me closeIfNeededWithMouseEvent:_event];
                                                                  }];
    m_LocalEventMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:mask
                                                                handler:^(NSEvent *_Nonnull _event) {
                                                                  if( NCCommandPopoverWindow *me = weak_self )
                                                                      [me closeIfNeededWithMouseEvent:_event];
                                                                  return _event;
                                                                }];
}

- (void)closeIfNeededWithMouseEvent:(NSEvent *)_event
{
    const NSPoint global = [_event locationInWindow];
    const NSPoint local = [self.contentView convertPoint:global fromView:nil];
    if( !NSPointInRect(local, self.contentView.bounds) )
        [self close];
}

- (void)keyDown:(NSEvent *)_event
{
    if( _event.keyCode == kVK_Escape )
        [self close];
    else
        [super keyDown:_event];
}

- (void)close
{
    if( m_GlobalEventMonitor ) {
        [NSEvent removeMonitor:m_GlobalEventMonitor];
        m_GlobalEventMonitor = nil;
    }
    if( m_LocalEventMonitor ) {
        [NSEvent removeMonitor:m_LocalEventMonitor];
        m_LocalEventMonitor = nil;
    }

    [super close];
}

@end
@implementation NCCommandPopoverContentView

- (instancetype)initWithFrame:(NSRect)_rect
{
    self = [super initWithFrame:_rect];
    if( self ) {
        self.wantsLayer = true;
        self.layer.cornerRadius = g_ContentViewCornerRadius;
        self.layer.masksToBounds = true;
    }
    return self;
}

- (void)drawRect:(NSRect)_rc
{
    [super drawRect:_rc];
    [NSColor.clearColor setFill];
    NSRectFill(self.bounds);

    [NSColor.windowBackgroundColor setFill];
    [[NSBezierPath bezierPathWithRoundedRect:self.bounds
                                     xRadius:g_ContentViewCornerRadius
                                     yRadius:g_ContentViewCornerRadius] fill];
}

@end

@implementation NCCommandPopover {
    std::vector<NCCommandPopoverItem *> m_Items;
    NCCommandPopoverViewController *m_Controller;
    NCCommandPopoverWindow *m_Window;
    NSSize m_ContentSize;
    __weak id<NCCommandPopoverDelegate> m_Delegate;
}

@synthesize delegate = m_Delegate;

- (instancetype _Nonnull)initWithTitle:(NSString *_Nonnull)_title
{
    self = [super init];
    if( self ) {
        m_Controller = [[NCCommandPopoverViewController alloc] initWithPopover:self andTitle:_title];
    }
    return self;
}

- (void)dealloc
{
    if( m_Window ) {
        m_Window.delegate = nil;
        [m_Window close];
    }
}

- (void)addItem:(NCCommandPopoverItem *_Nonnull)_new_item
{
    assert(std::ranges::find(m_Items, _new_item) == m_Items.end());
    m_Items.push_back(_new_item);
}

- (void)showRelativeToRect:(NSRect)_positioning_rect
                    ofView:(NSView *_Nonnull)_positioning_view
                 alignment:(NCCommandPopoverAlignment)_alignment
{
    NSView *view = m_Controller.view;
    m_ContentSize = view.fittingSize;

    const NSRect rect_in_window = [_positioning_view convertRect:_positioning_rect toView:nil];
    const NSRect rect_on_screen = [_positioning_view.window convertRectToScreen:rect_in_window];
    const double sx = m_ContentSize.width;
    const double sy = m_ContentSize.height;
    const double initial_x = [&] {
        if( _alignment == NCCommandPopoverAlignment::Left )
            return NSMinX(rect_on_screen);
        else if( _alignment == NCCommandPopoverAlignment::Right )
            return NSMaxX(rect_on_screen) - sx;
        else
            return NSMinX(rect_on_screen) + ((rect_on_screen.size.width - sx) / 2.);
    }();
    const double y = NSMinY(rect_on_screen) - m_ContentSize.height;
    NSScreen *screen = _positioning_view.window.screen;
    const NSRect screen_rect = screen.visibleFrame;
    const double x = [&] {
        if( initial_x < screen_rect.origin.x )
            return screen_rect.origin.x;
        else if( initial_x + sx > NSMaxX(screen_rect) )
            return NSMaxX(screen_rect) - sx;
        else
            return initial_x;
    }();
    m_Window = [[NCCommandPopoverWindow alloc] initWithContentRect:NSMakeRect(x, y, sx, sy)];
    m_Window.contentView = view;
    m_Window.delegate = self;
    [m_Window makeKeyAndOrderFront:nil];
}

- (std::span<NCCommandPopoverItem *const>)commandItems
{
    return m_Items;
}

- (void)close
{
    [m_Window close];
}

- (void)windowDidResignKey:(NSNotification *)_notification
{
    [self close];
}

- (void)windowWillClose:(NSNotification *)_notification
{
    if( id<NCCommandPopoverDelegate> delegate = m_Delegate;
        delegate != nil && [delegate respondsToSelector:@selector(commandPopoverDidClose:)] ) {
        [delegate commandPopoverDidClose:self];
    }

    m_Window = nil;
    m_Controller = nil;
    m_Items.clear();
}

- (NSSize)contentSize
{
    return m_ContentSize;
}

- (void)setContentSize:(NSSize)contentSize
{
    if( !NSEqualSizes(m_ContentSize, contentSize) ) {
        m_ContentSize = contentSize;
        const NSRect frame = m_Window.frame;
        NSRect new_frame = NSMakeRect(frame.origin.x,
                                      frame.origin.y - (m_ContentSize.height - frame.size.height),
                                      m_ContentSize.width,
                                      m_ContentSize.height);
        [m_Window setFrame:new_frame display:true animate:false];
    }
}

@end

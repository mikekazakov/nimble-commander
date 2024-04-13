// Copyright (C) 2014-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Panel/UI/SelectionWithMaskPopupViewController.h>
#include <Panel/Internal.h>
#include <Utility/StringExtras.h>
#include <Utility/ObjCpp.h>

using namespace nc::panel;

@interface SelectionWithMaskPopupViewController ()

@property(nonatomic) IBOutlet NSSearchField *searchField;
@property(nonatomic) IBOutlet NSTextField *titleLabel;

@end

@implementation SelectionWithMaskPopupViewController {
    std::vector<FindFilesMask> m_History;
    FindFilesMask m_Initial;
    std::function<void(const nc::panel::FindFilesMask &_mask)> m_OnSelect;
    std::function<void()> m_OnClearHistory;
    bool m_DoesSelect;
    bool m_RegexSearch;
}

@synthesize onSelect = m_OnSelect;
@synthesize onClearHistory = m_OnClearHistory;
@synthesize searchField;
@synthesize titleLabel;

- (instancetype)initInitialQuery:(const nc::panel::FindFilesMask &)_initial_mask
                         history:(std::span<const nc::panel::FindFilesMask>)_masks
                      doesSelect:(bool)_select
{
    self = [super initWithNibName:@"SelectionWithMaskPopupViewController" bundle:Bundle()];
    if( self ) {
        m_DoesSelect = _select;
        m_History.assign(_masks.begin(), _masks.end());
        m_Initial = _initial_mask;
        m_RegexSearch = _initial_mask.type == nc::panel::FindFilesMask::RegEx;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.titleLabel.stringValue =
        m_DoesSelect ? NSLocalizedString(@"Select files by mask:", "Title for selection by mask popup")
                     : NSLocalizedString(@"Deselect files by mask:", "Title for deselection by mask popup");

    [self updateMasksMenu];
    [self updateSearchPrompt];
    self.searchField.stringValue = [NSString stringWithUTF8StdString:m_Initial.string];
    nc::objc_cast<NSSearchFieldCell>(self.searchField.cell).cancelButtonCell = nil;
}

- (NSMenu *)buildMasksMenu
{
    const auto menu = [[NSMenu alloc] initWithTitle:@""];

    [menu addItemWithTitle:NSLocalizedString(@"Options", "") action:nil keyEquivalent:@""];

    const auto regex = [menu addItemWithTitle:NSLocalizedString(@"Regular Expression", "")
                                       action:@selector(onMaskMenuRegExOptionClicked:)
                                keyEquivalent:@""];
    regex.state = m_RegexSearch ? NSControlStateValueOn : NSControlStateValueOff;
    regex.indentationLevel = 1;

    if( !m_History.empty() ) {
        [menu addItem:NSMenuItem.separatorItem];
        [menu addItemWithTitle:NSLocalizedString(@"Recent Searches", "") action:nil keyEquivalent:@""];
        long query_index = 0;
        for( const auto &query : m_History ) {
            NSString *title = @"";
            if( query.type == FindFilesMask::Classic ) {
                title = [NSString
                    stringWithFormat:NSLocalizedString(@"Mask \u201c%@\u201d", "Find file masks history - plain mask"),
                                     [NSString stringWithUTF8StdString:query.string]];
            }
            else if( query.type == FindFilesMask::RegEx ) {
                title = [NSString
                    stringWithFormat:NSLocalizedString(@"RegEx \u201c%@\u201d", "Find file masks history - regex"),
                                     [NSString stringWithUTF8StdString:query.string]];
            }
            auto item = [menu addItemWithTitle:title
                                        action:@selector(onMaskMenuHistoryEntryClicked:)
                                 keyEquivalent:@""];
            item.indentationLevel = 1;
            item.tag = query_index;
            ++query_index;
        }
        [menu addItem:NSMenuItem.separatorItem];
        [menu addItemWithTitle:NSLocalizedString(@"Clear Recents", "")
                        action:@selector(onMaskMenuClearRecentsClicked:)
                 keyEquivalent:@""];
    }

    return menu;
}

- (void)updateMasksMenu
{
    self.searchField.searchMenuTemplate = [self buildMasksMenu];
}

- (void)updateSearchPrompt
{
    NSString *tt = @"";
    NSString *ps = @"";
    if( m_RegexSearch ) {
        tt = NSLocalizedString(@"Specify a regular expression to match filenames with.",
                               "Tooltip for a regex filename match");
        ps = NSLocalizedString(@"Regular expression", "Placeholder prompt for a regex");
    }
    else {
        tt = NSLocalizedString(@"Use \"*\" for multiple-character wildcard, \"?\" for single-character wildcard and "
                               @"\",\" to specify more than one mask.",
                               "Tooltip for mask filename match");
        ps = NSLocalizedString(@"Mask: *, or *.t?t, or *.txt,*.jpg", "Placeholder prompt for a filemask");
    }
    self.searchField.toolTip = tt;
    self.searchField.placeholderString = ps;
}

- (IBAction)onMaskMenuRegExOptionClicked:(id)sender
{
    m_RegexSearch = !m_RegexSearch;
    [self updateMasksMenu];
    [self updateSearchPrompt];
}

- (IBAction)onMaskMenuHistoryEntryClicked:(id)_sender
{

    const auto item = nc::objc_cast<NSMenuItem>(_sender);
    if( !item )
        return;
    const auto tag = item.tag;
    if( tag < 0 || static_cast<size_t>(tag) >= m_History.size() )
        return;
    const auto history_entry = m_History[tag];
    m_RegexSearch = history_entry.type == nc::panel::FindFilesMask::RegEx;
    [self.searchField setStringValue:[NSString stringWithUTF8StdString:history_entry.string]];

    [self updateMasksMenu];
}

- (IBAction)onMaskMenuClearRecentsClicked:(id)sender
{
    m_History.clear();
    [self updateMasksMenu];
    assert(m_OnClearHistory);
    m_OnClearHistory();
}

- (IBAction)onSearch:(id)sender
{
    const std::string mask_str =
        self.searchField.stringValue ? self.searchField.stringValue.fileSystemRepresentationSafe : "";
    if( mask_str.empty() )
        return; // don't allow empty masks
    nc::panel::FindFilesMask mask;
    mask.string = mask_str;
    mask.type = m_RegexSearch ? nc::panel::FindFilesMask::RegEx : nc::panel::FindFilesMask::Classic;

    [self.view.window performClose:nil];

    assert(m_OnSelect);
    m_OnSelect(mask);
}

- (void)popoverDidClose:(NSNotification *)notification
{
    // delete ourselves
    static_cast<NSPopover *>(notification.object).contentViewController = nil;
}

- (BOOL)control:(NSControl *)_control textView:(NSTextView *) [[maybe_unused]] _text_view doCommandBySelector:(SEL)_sel
{
    if( _control == self.searchField && _sel == @selector(moveDown:) ) {
        // show the mask field's combo box when the Down key is pressed
        const auto menu_offset = 6.;
        const auto menu = self.searchField.searchMenuTemplate;
        const auto bounds = self.searchField.bounds;
        [menu popUpMenuPositioningItem:nil
                            atLocation:NSMakePoint(NSMinX(bounds), NSMaxY(bounds) + menu_offset)
                                inView:self.searchField];
        return true;
    }
    if( _control == self.searchField && _sel == @selector(cancelOperation:) ) {
        // Don't allow the search field to swallow the Esc button, close the popup when it's pressed
        [self.view.window performClose:nil];
        return true;
    }
    return false;
}

@end

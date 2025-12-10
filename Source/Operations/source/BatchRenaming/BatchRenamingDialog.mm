// Copyright (C) 2015-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Carbon/Carbon.h>
#include <Utility/SheetWithHotkeys.h>
#include "BatchRenamingDialog.h"
#include "BatchRenamingRangeSelectionPopover.h"
#include "BatchRenamingScheme.h"
#include <Operations/Localizable.h>
#include <Base/dispatch_cpp.h>
#include <Utility/ObjCpp.h>
#include <Utility/StringExtras.h>
#include "../Internal.h"
#include <Base/UnorderedUtil.h>

#include <algorithm>

static NSString *_Nonnull const g_BatchRenamingDialogTableViewDataType =
    @"com.magnumbytes.nc.ops.BatchRenameSheetControllerPrivateTableViewDataType";

[[clang::no_destroy]] static const ankerl::unordered_dense::map<long, NSString *> g_BatchRenamingDialogInsertSnippets =
    {
        {101, @"[N]"},        //
        {102, @"[N1]"},       //
        {103, @"[N2-5]"},     //
        {104, @"[N2,5]"},     //
        {105, @"[N2-]"},      //
        {106, @"[N02-9]"},    //
        {107, @"[N 2-9]"},    //
        {108, @"[N-8,5]"},    //
        {109, @"[N-8-5]"},    //
        {110, @"[N2--5]"},    //
        {111, @"[N-5-]"},     //
        {201, @"[E]"},        //
        {202, @"[E1]"},       //
        {203, @"[E2-5]"},     //
        {204, @"[E2,5]"},     //
        {205, @"[E2-]"},      //
        {206, @"[E02-9]"},    //
        {207, @"[E 2-9]"},    //
        {208, @"[E-8,5]"},    //
        {209, @"[E-8-5]"},    //
        {210, @"[E2--5]"},    //
        {211, @"[E-5-]"},     //
        {301, @"[d]"},        //
        {302, @"[Y]"},        //
        {303, @"[y]"},        //
        {304, @"[M]"},        //
        {305, @"[D]"},        //
        {306, @"[t]"},        //
        {307, @"[h]"},        //
        {308, @"[m]"},        //
        {309, @"[s]"},        //
        {401, @"[U]"},        //
        {402, @"[L]"},        //
        {403, @"[F]"},        //
        {404, @"[n]"},        //
        {501, @"[C]"},        //
        {502, @"[C10]"},      //
        {503, @"[C10+2]"},    //
        {504, @"[C10+2/1]"},  //
        {505, @"[C10+2/1:5"}, //
        {601, @"[A]"},        //
        {602, @"[["},         //
        {603, @"]]"},         //
        {701, @"[A]"},        //
        {702, @"[A1]"},       //
        {703, @"[A2-5]"},     //
        {704, @"[A2,5]"},     //
        {705, @"[A2-]"},      //
        {706, @"[A02-9]"},    //
        {707, @"[A 2-9]"},    //
        {708, @"[A-8,5]"},    //
        {709, @"[A-8-5]"},    //
        {710, @"[A2--5]"},    //
        {711, @"[A-5-]"},     //
        {801, @"[P]"},        //
        {802, @"[P1]"},       //
        {803, @"[P2-5]"},     //
        {804, @"[P2,5]"},     //
        {805, @"[P2-]"},      //
        {806, @"[P02-9]"},    //
        {807, @"[P 2-9]"},    //
        {808, @"[P-8,5]"},    //
        {809, @"[P-8-5]"},    //
        {810, @"[P2--5]"},    //
        {811, @"[P-5-]"},     //
        {901, @"[G]"},        //
        {902, @"[G1]"},       //
        {903, @"[G2-5]"},     //
        {904, @"[G2,5]"},     //
        {905, @"[G2-]"},      //
        {906, @"[G02-9]"},    //
        {907, @"[G 2-9]"},    //
        {908, @"[G-8,5]"},    //
        {909, @"[G-8-5]"},    //
        {910, @"[G2--5]"},    //
        {911, @"[G-5-]"},     //
};

@interface BatchRenameSheetControllerNilNumberValueTransformer : NSValueTransformer
@end

@implementation BatchRenameSheetControllerNilNumberValueTransformer
+ (Class _Nonnull)transformedValueClass
{
    return [NSNumber class];
}
- (id _Nullable)transformedValue:(id _Nullable)value
{
    if( value == nil )
        return @0;
    else
        return value;
}
@end

@interface NCOpsBatchRenamingDialog ()

@property(strong, nonatomic) IBOutlet NSTableView *_Nonnull FilenamesTable;
@property(strong, nonatomic) IBOutlet NSComboBox *_Nonnull FilenameMask;
@property(strong, nonatomic) IBOutlet NSComboBox *_Nonnull SearchForComboBox;
@property(strong, nonatomic) IBOutlet NSComboBox *_Nonnull ReplaceWithComboBox;
@property(strong, nonatomic) IBOutlet NSButton *_Nonnull SearchCaseSensitive;
@property(strong, nonatomic) IBOutlet NSButton *_Nonnull SearchOnlyOnce;
@property(strong, nonatomic) IBOutlet NSButton *_Nonnull SearchInExtension;
@property(strong, nonatomic) IBOutlet NSButton *_Nonnull SearchWithRegExp;
@property(strong, nonatomic) IBOutlet NSPopUpButton *_Nonnull CaseProcessing;
@property(strong, nonatomic) IBOutlet NSButton *_Nonnull CaseProcessingWithExtension;
@property(strong, nonatomic) IBOutlet NSPopUpButton *_Nonnull CounterDigits;
@property(strong, nonatomic) IBOutlet NSButton *_Nonnull InsertNameRangePlaceholderButton;
@property(strong, nonatomic) IBOutlet NSButton *_Nonnull InsertPlaceholderMenuButton;
@property(strong, nonatomic) IBOutlet NSMenu *_Nonnull InsertPlaceholderMenu;
@property(strong, nonatomic) IBOutlet NSButton *_Nonnull OkButton;
@property(nonatomic, readwrite) int CounterStartsAt;
@property(nonatomic, readwrite) int CounterStepsBy;

- (IBAction)OnFilenameMaskChanged:(id _Nullable)_sender;
- (IBAction)OnInsertNamePlaceholder:(id _Nullable)_sender;
- (IBAction)OnInsertNameRangePlaceholder:(id _Nullable)_sender;
- (IBAction)OnInsertCounterPlaceholder:(id _Nullable)_sender;
- (IBAction)OnInsertExtensionPlaceholder:(id _Nullable)_sender;
- (IBAction)OnInsertDatePlaceholder:(id _Nullable)_sender;
- (IBAction)OnInsertTimePlaceholder:(id _Nullable)_sender;
- (IBAction)OnInsertMenu:(id _Nullable)_sender;
- (IBAction)OnInsertPlaceholderFromMenu:(id _Nullable)_sender;

- (IBAction)OnSearchForChanged:(id _Nullable)_sender;
- (IBAction)OnReplaceWithChanged:(id _Nullable)_sender;
- (IBAction)OnSearchReplaceOptionsChanged:(id _Nullable)_sender;
- (IBAction)OnCaseProcessingChanged:(id _Nullable)_sender;
- (IBAction)OnCounterSettingsChanged:(id _Nullable)_sender;

- (IBAction)OnOK:(id _Nullable)_sender;
- (IBAction)OnCancel:(id _Nullable)_sender;

@end

using SourceReverseMappingStorage =
    ankerl::unordered_dense::map<std::string, size_t, nc::UnorderedStringHashEqual, nc::UnorderedStringHashEqual>;

@implementation NCOpsBatchRenamingDialog {
    std::vector<nc::ops::BatchRenamingScheme::FileInfo> m_FileInfos;
    SourceReverseMappingStorage m_SourceReverseMapping;

    std::vector<NSTextField *> m_LabelsBefore;
    std::vector<NSTextField *> m_LabelsAfter;

    NSPopover *m_Popover;
    int m_CounterStartsAt;
    int m_CounterStepsBy;

    std::vector<std::string> m_ResultSource;
    std::vector<std::string> m_ResultDestination;

    NCUtilSimpleComboBoxPersistentDataSource *m_RenamePatternDataSource;
    NCUtilSimpleComboBoxPersistentDataSource *m_SearchForDataSource;
    NCUtilSimpleComboBoxPersistentDataSource *m_ReplaceWithDataSource;
}

@synthesize CounterStartsAt = m_CounterStartsAt;
@synthesize CounterStepsBy = m_CounterStepsBy;
@synthesize filenamesSource = m_ResultSource;
@synthesize filenamesDestination = m_ResultDestination;
@synthesize renamePatternDataSource = m_RenamePatternDataSource;
@synthesize searchForDataSource = m_SearchForDataSource;
@synthesize replaceWithDataSource = m_ReplaceWithDataSource;
@synthesize isValidRenaming;
@synthesize FilenamesTable;
@synthesize FilenameMask;
@synthesize SearchForComboBox;
@synthesize ReplaceWithComboBox;
@synthesize SearchCaseSensitive;
@synthesize SearchOnlyOnce;
@synthesize SearchInExtension;
@synthesize SearchWithRegExp;
@synthesize CaseProcessing;
@synthesize CaseProcessingWithExtension;
@synthesize CounterDigits;
@synthesize InsertNameRangePlaceholderButton;
@synthesize InsertPlaceholderMenuButton;
@synthesize InsertPlaceholderMenu;
@synthesize OkButton;

- (instancetype _Nonnull)initWithItems:(std::vector<VFSListingItem>)_items
{
    using namespace nc::ops;
    const auto nib_path = [Bundle() pathForResource:@"BatchRenamingDialog" ofType:@"nib"];
    self = [super initWithWindowNibPath:nib_path owner:self];
    if( self ) {
        if( _items.empty() )
            throw std::logic_error("empty files list");

        for( auto &entry : _items ) {
            m_FileInfos.emplace_back(entry);
            m_ResultSource.emplace_back(entry.Directory() + entry.Filename());
        }

        for( size_t i = 0; i != m_FileInfos.size(); ++i )
            m_SourceReverseMapping.emplace(m_FileInfos[i].filename.UTF8String, i);

        for( auto &e : _items ) {

            {
                NSTextField *tf = [[NSTextField alloc] initWithFrame:NSRect()];
                tf.stringValue = e.FilenameNS();
                tf.bordered = false;
                tf.editable = false;
                tf.drawsBackground = false;
                static_cast<NSTextFieldCell *>(tf.cell).lineBreakMode = NSLineBreakByTruncatingTail;
                m_LabelsBefore.emplace_back(tf);
            }

            {
                NSTextField *tf = [[NSTextField alloc] initWithFrame:NSRect()];
                tf.stringValue = e.FilenameNS();
                tf.bordered = false;
                tf.editable = false;
                tf.drawsBackground = false;
                static_cast<NSTextFieldCell *>(tf.cell).lineBreakMode = NSLineBreakByTruncatingTail;
                m_LabelsAfter.emplace_back(tf);
            }
        }

        m_CounterStartsAt = 1;
        m_CounterStepsBy = 1;
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];

    // Implement this method to handle any initialization after your window controller's window has
    // been loaded from its nib file.
    [self InsertStringIntoMask:@"[N].[E]"];
    self.isValidRenaming = true;

    [self.FilenamesTable registerForDraggedTypes:@[g_BatchRenamingDialogTableViewDataType]];

    // set up data sources for comboboxes
    if( !m_RenamePatternDataSource )
        m_RenamePatternDataSource = [NCUtilSimpleComboBoxPersistentDataSource new];
    self.FilenameMask.usesDataSource = true;
    self.FilenameMask.dataSource = m_RenamePatternDataSource;

    if( !m_SearchForDataSource )
        m_SearchForDataSource = [NCUtilSimpleComboBoxPersistentDataSource new];
    self.SearchForComboBox.usesDataSource = true;
    self.SearchForComboBox.dataSource = m_SearchForDataSource;

    if( !m_ReplaceWithDataSource )
        m_ReplaceWithDataSource = [NCUtilSimpleComboBoxPersistentDataSource new];
    self.ReplaceWithComboBox.usesDataSource = true;
    self.ReplaceWithComboBox.dataSource = m_ReplaceWithDataSource;

    NCSheetWithHotkeys *sheet = static_cast<NCSheetWithHotkeys *>(self.window);
    sheet.onCtrlA = [sheet makeActionHotkey:@selector(OnInsertMenu:)];
    sheet.onCtrlC = [sheet makeActionHotkey:@selector(OnInsertCounterPlaceholder:)];
    sheet.onCtrlD = [sheet makeActionHotkey:@selector(OnInsertDatePlaceholder:)];
    sheet.onCtrlE = [sheet makeActionHotkey:@selector(OnInsertExtensionPlaceholder:)];
    sheet.onCtrlG = [sheet makeClickHotkey:self.CounterDigits];
    sheet.onCtrlI = [sheet makeFocusHotkey:self.FilenamesTable];
    sheet.onCtrlL = [sheet makeClickHotkey:self.SearchCaseSensitive];
    sheet.onCtrlN = [sheet makeActionHotkey:@selector(OnInsertNamePlaceholder:)];
    sheet.onCtrlO = [sheet makeClickHotkey:self.SearchOnlyOnce];
    sheet.onCtrlP = [sheet makeFocusHotkey:self.FilenameMask];
    sheet.onCtrlR = [sheet makeActionHotkey:@selector(OnInsertNameRangePlaceholder:)];
    sheet.onCtrlS = [sheet makeFocusHotkey:self.SearchForComboBox];
    sheet.onCtrlT = [sheet makeActionHotkey:@selector(OnInsertTimePlaceholder:)];
    sheet.onCtrlU = [sheet makeClickHotkey:self.CaseProcessing];
    sheet.onCtrlW = [sheet makeFocusHotkey:self.ReplaceWithComboBox];
}

- (IBAction)OnCancel:(id _Nullable) [[maybe_unused]] _sender
{
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseStop];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *_Nonnull)tableView
{
    if( tableView == self.FilenamesTable )
        return m_LabelsBefore.size();
    return 0;
}

- (NSView *_Nullable)tableView:(NSTableView *_Nonnull)tableView
            viewForTableColumn:(NSTableColumn *_Nullable)tableColumn
                           row:(NSInteger)row
{
    if( tableView == self.FilenamesTable ) {
        if( [tableColumn.identifier isEqualToString:@"original"] ) {
            assert(row >= 0 && row < static_cast<int>(m_LabelsBefore.size()));
            return m_LabelsBefore[row];
        }
        if( [tableColumn.identifier isEqualToString:@"renamed"] ) {
            assert(row >= 0 && row < static_cast<int>(m_LabelsAfter.size()));
            return m_LabelsAfter[row];
        }
    }

    return nil;
}

- (IBAction)OnFilenameMaskChanged:(id _Nullable) [[maybe_unused]] _sender
{
    [self updateRenamedFilenames];
}

- (void)updateRenamedFilenames
{
    using namespace nc::ops;
    NSString *filename_mask = self.FilenameMask.stringValue ? self.FilenameMask.stringValue : @"";

    NSString *search_for = self.SearchForComboBox.stringValue ? self.SearchForComboBox.stringValue : @"";
    NSString *replace_with = self.ReplaceWithComboBox.stringValue ? self.ReplaceWithComboBox.stringValue : @"";
    bool search_case_sens = self.SearchCaseSensitive.state == NSControlStateValueOn;
    bool search_once = self.SearchOnlyOnce.state == NSControlStateValueOn;
    bool search_in_ext = self.SearchInExtension.state == NSControlStateValueOn;
    bool search_regexp = self.SearchWithRegExp.state == NSControlStateValueOn;
    BatchRenamingScheme::CaseTransform ct =
        static_cast<BatchRenamingScheme::CaseTransform>(self.CaseProcessing.selectedTag);
    bool ct_with_ext = self.CaseProcessingWithExtension.state == NSControlStateValueOn;

    BatchRenamingScheme br;
    br.SetReplacingOptions(search_for, replace_with, search_case_sens, search_once, search_in_ext, search_regexp);
    br.SetCaseTransform(ct, ct_with_ext);
    br.SetDefaultCounter(m_CounterStartsAt, m_CounterStepsBy, 1, static_cast<unsigned>(self.CounterDigits.selectedTag));

    if( !br.BuildActionsScript(filename_mask) ) {
        for( auto &l : m_LabelsAfter )
            l.stringValue = @"<Error!>";
        self.isValidRenaming = false;
        return;
    }

    // apply the renaming scheme to the source filenames
    std::vector<NSString *> renamed_names;
    renamed_names.reserve(m_FileInfos.size());
    for( size_t index = 0, e = m_FileInfos.size(); index != e; ++index ) {
        NSString *renamed_name = br.Rename(m_FileInfos[index], static_cast<int>(index));
        renamed_names.emplace_back(renamed_name);
    }

    // build the reverse mapping to check for duplicates later
    SourceReverseMappingStorage dest_reverse_mapping;
    dest_reverse_mapping.reserve(m_FileInfos.size());
    for( size_t index = 0, e = renamed_names.size(); index != e; ++index )
        dest_reverse_mapping.emplace(renamed_names[index].UTF8String, index);

    // transfer the results to the labels
    for( size_t index = 0, e = renamed_names.size(); index != e; ++index )
        m_LabelsAfter[index].stringValue = renamed_names[index];

    self.isValidRenaming = true;

    // validate the resulting filenames
    for( size_t index = 0, e = m_FileInfos.size(); index != e; ++index ) {
        bool is_valid = true;
        NSString *renamed_into = renamed_names[index];
        if( renamed_into.length == 0 ) {
            // don't allow empty filenames
            is_valid = false;
        }
        else {
            // now check for duplicates
            const char *utf8 = renamed_into.UTF8String;
            const auto source_reverse_it = m_SourceReverseMapping.find(utf8);
            if( source_reverse_it != m_SourceReverseMapping.end() && source_reverse_it->second != index ) {
                // prohibit renaming into filenames which might already exist initially.
                is_valid = false;
            }

            const auto dest_reverse_it = dest_reverse_mapping.find(utf8);
            assert(dest_reverse_it != dest_reverse_mapping.end());
            if( dest_reverse_it->second != index ) {
                // prohibit the renamed set from having duplicates
                is_valid = false;
            }
        }

        if( !is_valid ) {
            m_LabelsAfter[index].textColor = NSColor.redColor;
            self.isValidRenaming = false;
        }
        else {
            m_LabelsAfter[index].textColor = NSColor.labelColor;
        }
    }
}

- (IBAction)OnInsertNamePlaceholder:(id _Nullable) [[maybe_unused]] _sender
{
    [self InsertStringIntoMask:@"[N]"];
}

- (IBAction)OnInsertNameRangePlaceholder:(id _Nullable) [[maybe_unused]] _sender
{
    using namespace nc::ops;
    auto *pc = [NCOpsBatchRenamingRangeSelectionPopover new];
    auto curr_sel = self.currentMaskSelection;
    pc.handler = ^(NSRange _range) {
      if( _range.length == 0 )
          return;
      NSString *ph = [NSString stringWithFormat:@"[N%lu-%lu]", _range.location + 1, _range.location + _range.length];
      dispatch_to_main_queue([=] { [self InsertStringIntoMask:ph withSelection:curr_sel]; });
    };
    if( self.FilenamesTable.selectedRow >= 0 ) {
        // pick the filename of the select item
        const auto index = self.FilenamesTable.selectedRow;
        pc.string = m_FileInfos[index].name;
    }
    else {
        // pick the longest filename
        const auto longest_it = std::ranges::max_element(
            m_FileInfos, [](const BatchRenamingScheme::FileInfo &lhs, const BatchRenamingScheme::FileInfo &rhs) {
                return lhs.name.length < rhs.name.length;
            });
        pc.string = longest_it->name;
    }

    m_Popover = [NSPopover new];
    m_Popover.contentViewController = pc;
    m_Popover.delegate = pc;
    m_Popover.behavior = NSPopoverBehaviorTransient;
    pc.enclosingPopover = m_Popover;
    [m_Popover showRelativeToRect:self.InsertNameRangePlaceholderButton.bounds
                           ofView:self.InsertNameRangePlaceholderButton
                    preferredEdge:NSMaxXEdge];
}

- (IBAction)OnInsertCounterPlaceholder:(id _Nullable) [[maybe_unused]] _sender
{
    [self InsertStringIntoMask:@"[C]"];
}

- (IBAction)OnInsertExtensionPlaceholder:(id _Nullable) [[maybe_unused]] _sender
{
    [self InsertStringIntoMask:@"[E]"];
}

- (IBAction)OnInsertDatePlaceholder:(id _Nullable) [[maybe_unused]] _sender
{
    [self InsertStringIntoMask:@"[YMD]"];
}

- (IBAction)OnInsertTimePlaceholder:(id _Nullable) [[maybe_unused]] _sender
{
    [self InsertStringIntoMask:@"[hms]"];
}

- (IBAction)OnInsertMenu:(id _Nullable) [[maybe_unused]] _sender
{
    const auto r = self.InsertPlaceholderMenuButton.bounds;
    [self.InsertPlaceholderMenu popUpMenuPositioningItem:nil
                                              atLocation:NSMakePoint(NSMaxX(r), NSMinY(r))
                                                  inView:self.InsertPlaceholderMenuButton];
}

- (IBAction)OnInsertPlaceholderFromMenu:(id _Nullable)sender
{
    if( auto item = nc::objc_cast<NSMenuItem>(sender) ) {
        if( g_BatchRenamingDialogInsertSnippets.contains(item.tag) )
            [self InsertStringIntoMask:g_BatchRenamingDialogInsertSnippets.at(item.tag)];
    }
}

- (IBAction)OnSearchForChanged:(id _Nullable) [[maybe_unused]] _sender
{
    [self updateRenamedFilenames];
}

- (IBAction)OnReplaceWithChanged:(id _Nullable) [[maybe_unused]] _sender
{
    [self updateRenamedFilenames];
}

- (IBAction)OnSearchReplaceOptionsChanged:(id _Nullable) [[maybe_unused]] _sender
{
    [self updateRenamedFilenames];
}

- (IBAction)OnCaseProcessingChanged:(id _Nullable) [[maybe_unused]] _sender
{
    [self updateRenamedFilenames];
}

- (IBAction)OnCounterSettingsChanged:(id _Nullable) [[maybe_unused]] _sender
{
    [self updateRenamedFilenames];
}

- (NSRange)currentMaskSelection
{
    if( self.FilenameMask.currentEditor )
        return self.FilenameMask.currentEditor.selectedRange;
    else
        return NSMakeRange(NSNotFound, 0);
}

- (void)InsertStringIntoMask:(NSString *_Nonnull)_str
{
    NSString *current_mask = self.FilenameMask.stringValue ? self.FilenameMask.stringValue : @"";
    if( self.FilenameMask.currentEditor ) {
        NSRange range = self.FilenameMask.currentEditor.selectedRange;
        current_mask = [current_mask stringByReplacingCharactersInRange:range withString:_str];
    }
    else
        current_mask = [current_mask stringByAppendingString:_str];

    [self SetNewMask:current_mask];
}

- (void)InsertStringIntoMask:(NSString *_Nonnull)_str withSelection:(NSRange)_r
{
    NSString *current_mask = self.FilenameMask.stringValue ? self.FilenameMask.stringValue : @"";
    if( _r.location != NSNotFound )
        current_mask = [current_mask stringByReplacingCharactersInRange:_r withString:_str];
    else
        current_mask = [current_mask stringByAppendingString:_str];

    [self SetNewMask:current_mask];
}

- (void)SetNewMask:(NSString *_Nonnull)_str
{
    [self.FilenameMask.undoManager registerUndoWithTarget:self
                                                 selector:@selector(SetNewMask:)
                                                   object:self.FilenameMask.stringValue];

    self.FilenameMask.stringValue = _str;
    [self OnFilenameMaskChanged:self.FilenameMask];
}

- (void)controlTextDidChange:(NSNotification *_Nonnull)notification
{
    if( nc::objc_cast<NSTextField>(notification.object) == self.FilenameMask )
        [self OnFilenameMaskChanged:self.FilenameMask];
    else if( nc::objc_cast<NSTextField>(notification.object) == self.ReplaceWithComboBox )
        [self OnReplaceWithChanged:self.ReplaceWithComboBox];
    else if( nc::objc_cast<NSTextField>(notification.object) == self.SearchForComboBox )
        [self OnSearchForChanged:self.SearchForComboBox];
    else
        [self updateRenamedFilenames];
}

- (NSDragOperation)tableView:(NSTableView *_Nonnull) [[maybe_unused]] aTableView
                validateDrop:(id<NSDraggingInfo> _Nonnull) [[maybe_unused]] info
                 proposedRow:(NSInteger) [[maybe_unused]] row
       proposedDropOperation:(NSTableViewDropOperation)operation
{
    return operation == NSTableViewDropOn ? NSDragOperationNone : NSDragOperationMove;
}

- (nullable id<NSPasteboardWriting>)tableView:(NSTableView *_Nonnull)_table_view pasteboardWriterForRow:(NSInteger)_row
{
    auto data = [NSKeyedArchiver archivedDataWithRootObject:[NSNumber numberWithInteger:_row]
                                      requiringSecureCoding:false
                                                      error:nil];
    NSPasteboardItem *pbitem = [[NSPasteboardItem alloc] init];
    [pbitem setData:data forType:g_BatchRenamingDialogTableViewDataType];
    return pbitem;
}

- (BOOL)tableView:(NSTableView *_Nonnull) [[maybe_unused]] aTableView
       acceptDrop:(id<NSDraggingInfo> _Nonnull)info
              row:(NSInteger)drag_to
    dropOperation:(NSTableViewDropOperation) [[maybe_unused]] operation
{
    NSData *data = [info.draggingPasteboard dataForType:g_BatchRenamingDialogTableViewDataType];
    NSNumber *ind = [NSKeyedUnarchiver unarchivedObjectOfClass:NSNumber.class fromData:data error:nil];
    NSInteger drag_from = ind.integerValue;

    if( drag_to == drag_from ||    // same index, above
        drag_to == drag_from + 1 ) // same index, below
        return false;

    if( drag_from < drag_to )
        drag_to--;
    if( drag_to >= static_cast<int>(m_LabelsBefore.size()) || drag_from >= static_cast<int>(m_LabelsBefore.size()) )
        return false;

    // don't forget to swap items in ALL containers!
    std::swap(m_FileInfos[drag_to], m_FileInfos[drag_from]);
    std::swap(m_LabelsBefore[drag_to], m_LabelsBefore[drag_from]);
    std::swap(m_LabelsAfter[drag_to], m_LabelsAfter[drag_from]);
    std::swap(m_ResultSource[drag_to], m_ResultSource[drag_from]);

    [self.FilenamesTable reloadData];

    dispatch_to_main_queue([=] { [self updateRenamedFilenames]; });

    return true;
}

- (void)buildResultDestinations
{
    m_ResultDestination.clear();
    for( size_t i = 0, e = m_FileInfos.size(); i != e; ++i )
        m_ResultDestination.emplace_back(m_FileInfos[i].item.Directory() +
                                         m_LabelsAfter[i].stringValue.fileSystemRepresentationSafe);
}

- (IBAction)OnOK:(id _Nullable) [[maybe_unused]] _sender
{
    [self updateRenamedFilenames];
    [self buildResultDestinations];

    [m_RenamePatternDataSource reportEnteredItem:self.FilenameMask.stringValue];
    [m_SearchForDataSource reportEnteredItem:self.SearchForComboBox.stringValue];
    [m_ReplaceWithDataSource reportEnteredItem:self.ReplaceWithComboBox.stringValue];

    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
}

- (void)keyDown:(NSEvent *_Nonnull)event
{
    if( event.type == NSEventTypeKeyDown && event.keyCode == kVK_Delete &&
        self.window.firstResponder == self.FilenamesTable && self.FilenamesTable.selectedRow != -1 ) {
        [self removeItemAtIndex:static_cast<int>(self.FilenamesTable.selectedRow)];
        return;
    }

    [super keyDown:event];
    return;
}

- (BOOL)validateMenuItem:(NSMenuItem *_Nonnull)item
{
    if( item.menu == self.FilenamesTable.menu ) {
        auto clicked_row = self.FilenamesTable.clickedRow;
        return clicked_row >= 0 && clicked_row < self.FilenamesTable.numberOfRows;
    }

    return true;
}

- (void)removeItemAtIndex:(size_t)_index
{
    using namespace nc::ops;
    assert(_index < m_FileInfos.size());
    if( _index == 0 && m_FileInfos.size() == 1 ) {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:localizable::BatchRenamingCantRemoveLastItemMessage()];
        [alert runModal];
        return;
    }

    // don't forget to erase items in ALL containers!
    m_FileInfos.erase(std::next(m_FileInfos.begin(), _index));
    m_LabelsBefore.erase(std::next(m_LabelsBefore.begin(), _index));
    m_LabelsAfter.erase(std::next(m_LabelsAfter.begin(), _index));
    m_ResultSource.erase(std::next(m_ResultSource.begin(), _index));

    [self.FilenamesTable reloadData];

    if( _index < static_cast<size_t>(self.FilenamesTable.numberOfRows) )
        [self.FilenamesTable selectRowIndexes:[NSIndexSet indexSetWithIndex:_index] byExtendingSelection:false];
    else if( self.FilenamesTable.numberOfRows > 0 )
        [self.FilenamesTable selectRowIndexes:[NSIndexSet indexSetWithIndex:self.FilenamesTable.numberOfRows - 1]
                         byExtendingSelection:false];

    dispatch_to_main_queue([=] { [self updateRenamedFilenames]; });
}

- (IBAction)onContextMenuRemoveItem:(id _Nullable) [[maybe_unused]] _sender
{
    auto clicked_row = self.FilenamesTable.clickedRow;
    if( clicked_row < 0 && clicked_row >= self.FilenamesTable.numberOfRows )
        return;

    [self removeItemAtIndex:static_cast<int>(clicked_row)];
}

@end

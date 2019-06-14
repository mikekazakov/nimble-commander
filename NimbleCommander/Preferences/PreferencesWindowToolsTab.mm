// Copyright (C) 2016-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PreferencesWindowToolsTab.h"
#include "../Bootstrap/ActivationManager.h"
#include "../States/FilePanels/ExternalToolsSupport.h"
#include <Habanero/dispatch_cpp.h>
#include <Utility/StringExtras.h>
#include <Utility/ObjCpp.h>

using namespace std::literals;

@interface PreferencesWindowToolsTab ()

@property (nonatomic) IBOutlet NSTableView                            *toolsTable;
@property (nonatomic) IBOutlet NSTextField                            *toolTitle;
@property (nonatomic) IBOutlet NSTextField                            *toolPath;
@property (nonatomic) IBOutlet NSTextField                            *toolParameters;
@property (nonatomic) IBOutlet NSPopUpButton                          *toolStartupMode;
@property (nonatomic) IBOutlet NSSegmentedControl                     *toolsAddRemove;
@property (nonatomic) IBOutlet NSMenu                                 *parametersMenu;
@property (nonatomic) IBOutlet NSButton                               *addParameterButton;
@property (nonatomic) bool                                             anySelected;
@property (readonly, nonatomic) bool                                haveCommandLineTools;
@property (readonly, nonatomic) std::shared_ptr<const ExternalTool>    selectedTool;

@end

static auto g_MyPrivateTableViewDataType = @"PreferencesWindowToolsTabPrivateTableViewDataType";

static bool AskUserToDeleteTool()
{
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = NSLocalizedString(@"Are you sure you want to remove this tool?", "Asking the user for confirmation on deleting the external tool - message");
    alert.informativeText = NSLocalizedString(@"This operation is not reversible.", "Asking the user for confirmation on deleting the external tool - message");
    [alert addButtonWithTitle:NSLocalizedString(@"OK", "")];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", "")];
    [alert.buttons objectAtIndex:0].keyEquivalent = @"";
    if( [alert runModal] == NSAlertFirstButtonReturn )
        return true;
    return false;
}

@implementation PreferencesWindowToolsTab
{
    std::function<ExternalToolsStorage&()>              m_ToolsStorage;
    std::vector<std::shared_ptr<const ExternalTool>>    m_Tools;
    ExternalToolsStorage::ObservationTicket             m_ToolsObserver;
}

- (id) initWithToolsStorage:(std::function<ExternalToolsStorage&()>)_tool_storage
{
    assert(_tool_storage);
    self = [super init];
    if( self ) {
        self.anySelected = false;
        m_ToolsStorage = _tool_storage;
    }
    return self;
}

- (NSToolbarItem *)toolbarItem
{
    NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:self.identifier];
    item.image = self.toolbarItemImage;
    item.label = self.toolbarItemLabel;
    item.enabled = nc::bootstrap::ActivationManager::Instance().HasExternalTools();
    return item;
}

-(NSString*)identifier{
    return NSStringFromClass(self.class);
}

-(NSImage*)toolbarItemImage{
    return [NSImage imageNamed:NSImageNameAdvanced];
}

-(NSString*)toolbarItemLabel{
    return NSLocalizedStringFromTable(@"Tools",
                                      @"Preferences",
                                      "Tools preferences tab title");
}

- (void)loadView
{
    [super loadView];
    m_Tools = m_ToolsStorage().GetAllTools();
    m_ToolsObserver = m_ToolsStorage().ObserveChanges([=]{
        dispatch_to_main_queue([=]{
            m_Tools = m_ToolsStorage().GetAllTools();
  
            if( (long)m_Tools.size() != self.toolsTable.numberOfRows )
                [self.toolsTable noteNumberOfRowsChanged];
            [self.toolsTable reloadDataForRowIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, m_Tools.size())]
                                       columnIndexes:[NSIndexSet indexSetWithIndex:0]];
            
            [self tableViewSelectionDidChange:[NSNotification notificationWithName:@""
                                                                            object:nil]];
        });
    });
    
    [self.toolsTable registerForDraggedTypes:@[g_MyPrivateTableViewDataType]];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)[[maybe_unused]]tableView
{
    return m_Tools.size();
}

- (NSView *)tableView:(NSTableView *)[[maybe_unused]]tableView
   viewForTableColumn:(NSTableColumn *)[[maybe_unused]]tableColumn
                  row:(NSInteger)row
{
    if( row >= (long)m_Tools.size() )
        return nil;

    auto &tool = m_Tools[row];
    
    NSTextField *tf = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
    tf.stringValue = tool->m_Title.empty() ?
        [NSString stringWithFormat:@"Tool #%ld", row] :
        [NSString stringWithUTF8StdString:tool->m_Title];
    tf.bordered = false;
    tf.editable = false;
    tf.drawsBackground = false;
    return tf;
}

- (void)tableViewSelectionDidChange:(NSNotification *)[[maybe_unused]]notification
{
    NSInteger row = self.toolsTable.selectedRow;
    self.anySelected = row >= 0;
    if( row >= 0 )
        [self fillFields];
    else
        [self clearFields];
}

- (void) fillFields
{
    auto t = self.selectedTool;
    assert(t);
    self.toolTitle.stringValue = [NSString stringWithUTF8StdString:t->m_Title];
    self.toolPath.stringValue = [NSString stringWithUTF8StdString:t->m_ExecutablePath];
    self.toolParameters.stringValue = [NSString stringWithUTF8StdString:t->m_Parameters];
    [self.toolStartupMode selectItemWithTag:(int)t->m_StartupMode];
}

- (void) clearFields
{
    self.toolTitle.stringValue = @"";
    self.toolPath.stringValue = @"";
    self.toolParameters.stringValue = @"";
    [self.toolStartupMode selectItemWithTag:(int)ExternalTool::StartupMode::Automatic];
}

- (std::shared_ptr<const ExternalTool>) selectedTool
{
    NSInteger row = self.toolsTable.selectedRow;
    return row < (long)m_Tools.size() ? m_Tools[row] : nullptr;
}

- (void) commitToolChanges:(const ExternalTool&)_et
{
    NSInteger row = self.toolsTable.selectedRow;
    assert( row >= 0 );
    
    m_ToolsStorage().ReplaceTool(_et, row);
}

- (IBAction)onToolTitleChanged:(id)[[maybe_unused]]sender
{
    if( auto t = self.selectedTool ) {
        if( t->m_Title != self.toolTitle.stringValue.UTF8String ) {
            ExternalTool changed_tool = *t;
            changed_tool.m_Title = self.toolTitle.stringValue.UTF8String;
            [self commitToolChanges:changed_tool];
        }
    }
}

- (IBAction)onToolPathChanged:(id)[[maybe_unused]]sender
{
    if( auto t = self.selectedTool ) {
        if( t->m_ExecutablePath != self.toolPath.stringValue.UTF8String ) {
            ExternalTool changed_tool = *t;
            changed_tool.m_ExecutablePath = self.toolPath.stringValue.UTF8String;
            [self commitToolChanges:changed_tool];
        }
    }
}

- (IBAction)onToolParametersChanged:(id)[[maybe_unused]]sender
{
    if( auto t = self.selectedTool ) {
        if( t->m_Parameters != self.toolParameters.stringValue.UTF8String ) {
            ExternalTool changed_tool = *t;
            changed_tool.m_Parameters = self.toolParameters.stringValue.UTF8String;
            [self commitToolChanges:changed_tool];
            
            std::string error;
            ExternalToolsParametersParser().Parse(changed_tool.m_Parameters,
                                                  [&](std::string _err){ error = _err; });
            if( !error.empty() ) {
                NSHelpManager *helpManager = [NSHelpManager sharedHelpManager];
                [helpManager setContextHelp:[[NSAttributedString alloc] initWithString:[NSString stringWithUTF8StdString:error]]
                                  forObject:self.toolParameters];
                [helpManager showContextHelpForObject:self.toolParameters
                                         locationHint:NSEvent.mouseLocation];
                [helpManager removeContextHelpForObject:self.toolParameters];
            }
        }
    }
}

- (IBAction)onPlusMinusButton:(id)[[maybe_unused]]sender
{
    const auto segment = self.toolsAddRemove.selectedSegment;
    if( segment == 0 ) {
        m_ToolsStorage().InsertTool( ExternalTool() );
        dispatch_to_main_queue_after(10ms, [=]{
            if( self.toolsTable.numberOfRows > 0 ) {
                [self.toolsTable selectRowIndexes:[NSIndexSet indexSetWithIndex:self.toolsTable.numberOfRows-1]
                             byExtendingSelection:false];
                [self.view.window makeFirstResponder:self.toolTitle];
            }
        });
    }
    else if( segment == 1 ) {
        const auto row = self.toolsTable.selectedRow;
        if( row < 0 )
            return;
        if( AskUserToDeleteTool() )
            m_ToolsStorage().RemoveTool(row);
    }
}

- (IBAction)onAddParameter:(id)[[maybe_unused]]sender
{
    const auto rect = self.addParameterButton.bounds;
    [self.parametersMenu popUpMenuPositioningItem:nil
                                       atLocation:NSMakePoint(NSMinX(rect), NSMaxY(rect) + 4.0)
                                           inView:self.addParameterButton];

}

- (IBAction)onAddParametersMenuItemClicked:(id)sender
{
    if( auto t = objc_cast<NSMenuItem>(sender) )
        if( auto s = objc_cast<NSString>(t.representedObject) )
            [self insertStringIntoParameters:s];
}

- (IBAction)onStartupModeChanged:(id)[[maybe_unused]]sender
{
    if( auto t = self.selectedTool ) {
        if( t->m_StartupMode != (ExternalTool::StartupMode)self.toolStartupMode.selectedTag ) {
            ExternalTool changed_tool = *t;
            changed_tool.m_StartupMode = (ExternalTool::StartupMode)self.toolStartupMode.selectedTag;
            [self commitToolChanges:changed_tool];
        }
    }
}

- (void)insertStringIntoParameters:(NSString*)_str
{
    NSString *current_parameters = self.toolParameters.stringValue ? self.toolParameters.stringValue : @"";
    if( self.toolParameters.currentEditor ) {
        NSRange range = self.toolParameters.currentEditor.selectedRange;
        current_parameters = [current_parameters stringByReplacingCharactersInRange:range withString:_str];
    }
    else
        current_parameters = [current_parameters stringByAppendingString:_str];
    
    [self setNewParametersString:current_parameters];
}

- (void)setNewParametersString:(NSString*)_str
{
    [self.toolParameters.undoManager registerUndoWithTarget:self
                                                   selector:@selector(setNewParametersString:)
                                                     object:self.toolParameters.stringValue];
    
    self.toolParameters.stringValue = _str;
    [self onToolParametersChanged:self.toolParameters];
}

- (void)setNewPathString:(NSString*)_str
{
    [self.toolPath.undoManager registerUndoWithTarget:self
                                             selector:@selector(setNewPathString:)
                                               object:self.toolPath.stringValue];
    self.toolPath.stringValue = _str;
    [self onToolPathChanged:self.toolPath];
}

- (void)setNewTitleString:(NSString*)_str
{
    [self.toolTitle.undoManager registerUndoWithTarget:self
                                              selector:@selector(setNewPathString:)
                                                object:self.toolTitle.stringValue];
    self.toolTitle.stringValue = _str;
    [self onToolTitleChanged:self.toolTitle];
}

- (IBAction)onSetApplicationPathButtonClicked:(id)[[maybe_unused]]sender
{
    if( !self.selectedTool )
        return;
    
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.resolvesAliases = false;
    panel.canChooseDirectories = true;
    panel.canChooseFiles = true;
    panel.allowsMultipleSelection = false;
    panel.showsHiddenFiles = true;
    panel.treatsFilePackagesAsDirectories = true;
    
    if( !self.selectedTool->m_ExecutablePath.empty() )
        if( auto u = [NSURL fileURLWithPath:[NSString stringWithUTF8StdString:self.selectedTool->m_ExecutablePath]] )
            panel.directoryURL = u;
    
    if( [panel runModal] == NSFileHandlingPanelOKButton )
        if( panel.URL ) {
            [self setNewPathString:panel.URL.path];
            
            dispatch_to_main_queue_after(1ms, [=] {
                if( auto t = self.selectedTool )
                    if( t->m_Title.empty() )
                        if( NSString *name = [NSFileManager.defaultManager displayNameAtPath:panel.URL.path] )
                            [self setNewTitleString:name];
            });
        }
}

- (NSDragOperation)tableView:(NSTableView *)[[maybe_unused]]aTableView
validateDrop:(id < NSDraggingInfo >)[[maybe_unused]]info
proposedRow:(NSInteger)[[maybe_unused]]row 
proposedDropOperation:(NSTableViewDropOperation)operation
{
    return operation == NSTableViewDropOn ? NSDragOperationNone : NSDragOperationMove;
}

- (BOOL)tableView:(NSTableView *)[[maybe_unused]]aTableView 
writeRowsWithIndexes:(NSIndexSet *)rowIndexes 
toPasteboard:(NSPasteboard *)pboard
{
    [pboard declareTypes:@[g_MyPrivateTableViewDataType]
                   owner:self];
    [pboard setData:[NSKeyedArchiver archivedDataWithRootObject:rowIndexes]
            forType:g_MyPrivateTableViewDataType];
    return true;
}

- (BOOL)tableView:(NSTableView *)[[maybe_unused]]aTableView
       acceptDrop:(id<NSDraggingInfo>)info
              row:(NSInteger)drag_to
    dropOperation:(NSTableViewDropOperation)[[maybe_unused]]operation
{
    NSData* data = [info.draggingPasteboard dataForType:g_MyPrivateTableViewDataType];
    NSIndexSet* inds = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    NSInteger drag_from = inds.firstIndex;


    if( drag_to == drag_from ||    // same index, above
        drag_to == drag_from + 1 ) // same index, below
        return false;

    if( drag_from < drag_to )
        drag_to--;
    
    m_ToolsStorage().MoveTool( drag_from, drag_to );
    
    return true;
}

- (bool) haveCommandLineTools
{
    return nc::bootstrap::ActivationManager::Instance().HasTerminal();
}

@end

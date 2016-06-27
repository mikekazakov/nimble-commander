//
//  PreferencesWindowToolsTab.m
//  NimbleCommander
//
//  Created by Michael G. Kazakov on 6/24/16.
//  Copyright © 2016 Michael G. Kazakov. All rights reserved.
//

#include "PreferencesWindowToolsTab.h"
#include "../States/FilePanels/ExternalToolsSupport.h"

@interface PreferencesWindowToolsTab ()

@property (strong) IBOutlet NSTableView                            *toolsTable;
@property (strong) IBOutlet NSTextField                            *toolTitle;
@property (strong) IBOutlet NSTextField                            *toolPath;
@property (strong) IBOutlet NSTextField                            *toolParameters;
@property (strong) IBOutlet NSSegmentedControl                     *toolsAddRemove;
@property (strong) IBOutlet NSMenu                                 *parametersMenu;
@property (strong) IBOutlet NSButton                               *addParameterButton;
@property bool                                                      anySelected;
@property (readonly, nonatomic) shared_ptr<const ExternalTool>      selectedTool;

@end

@implementation PreferencesWindowToolsTab
{
    function<ExternalToolsStorage&()>                   m_ToolsStorage;
    vector<shared_ptr<const ExternalTool>>              m_Tools;
    shared_ptr<ExternalToolsStorage::ChangesObserver>   m_ToolsObserver;
}

- (id) initWithToolsStorage:(function<ExternalToolsStorage&()>)_tool_storage
{
    assert(_tool_storage);
    self = [super init];
    if( self ) {
        self.anySelected = false;
        m_ToolsStorage = _tool_storage;
    }
    return self;
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
  
            
            if( m_Tools.size() != self.toolsTable.numberOfRows )
                [self.toolsTable noteNumberOfRowsChanged];
            [self.toolsTable reloadDataForRowIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, m_Tools.size())]
                                       columnIndexes:[NSIndexSet indexSetWithIndex:0]];
            
            [self tableViewSelectionDidChange:[NSNotification notificationWithName:@""
                                                                            object:nil]];
        });
    });
    
    
    
    
    
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return m_Tools.size();
}

- (NSView *)tableView:(NSTableView *)tableView
   viewForTableColumn:(NSTableColumn *)tableColumn
                  row:(NSInteger)row
{
    if( row >= m_Tools.size() )
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

- (void)tableViewSelectionDidChange:(NSNotification *)notification
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
//    self.toolParametersParseError.stringValue = @"";
}

- (void) clearFields
{
    self.toolTitle.stringValue = @"";
    self.toolPath.stringValue = @"";
    self.toolParameters.stringValue = @"";
//    self.toolParametersParseError.stringValue = @"";
}

- (shared_ptr<const ExternalTool>) selectedTool
{
    NSInteger row = self.toolsTable.selectedRow;
    return row < m_Tools.size() ? m_Tools[row] : nullptr;
}

- (void) commitToolChanges:(const ExternalTool&)_et
{
    NSInteger row = self.toolsTable.selectedRow;
    assert( row >= 0 );
    
    m_ToolsStorage().ReplaceTool(_et, row);
}

- (IBAction)onToolTitleChanged:(id)sender
{
    if( auto t = self.selectedTool ) {
        if( t->m_Title != self.toolTitle.stringValue.UTF8String ) {
            ExternalTool changed_tool = *t;
            changed_tool.m_Title = self.toolTitle.stringValue.UTF8String;
            [self commitToolChanges:changed_tool];
        }
    }
}

- (IBAction)onToolPathChanged:(id)sender
{
    if( auto t = self.selectedTool ) {
        if( t->m_ExecutablePath != self.toolPath.stringValue.UTF8String ) {
            ExternalTool changed_tool = *t;
            changed_tool.m_ExecutablePath = self.toolPath.stringValue.UTF8String;
            [self commitToolChanges:changed_tool];
        }
    }
}

- (IBAction)onToolParametersChanged:(id)sender
{
    if( auto t = self.selectedTool ) {
        if( t->m_Parameters != self.toolParameters.stringValue.UTF8String ) {
            ExternalTool changed_tool = *t;
            changed_tool.m_Parameters = self.toolParameters.stringValue.UTF8String;
            [self commitToolChanges:changed_tool];
            
            string error;
            ExternalToolsParametersParser().Parse(changed_tool.m_Parameters, [&](string _err){ error = _err; });
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

- (IBAction)onPlusMinusButton:(id)sender
{
    NSInteger segment = self.toolsAddRemove.selectedSegment;
    if( segment == 0 )
        m_ToolsStorage().InsertTool( ExternalTool() );
}

- (IBAction)onAddParameter:(id)sender
{
    NSRect r = [self.view.window convertRectToScreen:self.addParameterButton.frame];
    [self.parametersMenu popUpMenuPositioningItem:nil
                                       atLocation:NSMakePoint(NSMinX(r), NSMinY(r))
                                           inView:nil];
}

- (IBAction)onAddParametersMenuItemClicked:(id)sender
{
    if( auto t = objc_cast<NSMenuItem>(sender) )
        if( auto s = objc_cast<NSString>(t.representedObject) )
            [self insertStringIntoParameters:s];
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

@end

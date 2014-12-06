//
//  FileDeletionSheetWindowController.m
//  Directories
//
//  Created by Pavel Dogurevich on 15.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "FileDeletionSheetController.h"
#import "Common.h"

@implementation FileDeletionSheetController
{
    FileDeletionSheetCompletionHandler m_Handler;
    FileDeletionOperationType m_DefaultType;
    FileDeletionOperationType m_ResultType;
    
    NSString *m_Title;
}

- (id)init
{
    self = [super initWithWindowNibName:@"FileDeletionSheetController"];
    if (self) {
        m_Title = @"";
    }
    
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    self.Label.stringValue = m_Title;
    
    int index;
    if (m_DefaultType == FileDeletionOperationType::MoveToTrash)
        index = 0;
    else if (m_DefaultType == FileDeletionOperationType::Delete)
        index = 1;
    else if (m_DefaultType == FileDeletionOperationType::SecureDelete)
        index = 2;
    else
        assert(0);
    
    NSMenuItem *item = self.DeleteButtonMenu.itemArray[index];
    [self.DeleteButton setLabel:item.title forSegment:0];
    [self.DeleteButtonMenu removeItemAtIndex:index];
    
    [self.DeleteButton MakeDefault];
}

- (void)didEndSheet:(NSWindow *)_sheet returnCode:(NSInteger)_code contextInfo:(void *)_context
{
    [[self window] orderOut:self];
    
    if(m_Handler)
        m_Handler((int)_code);
    m_Handler = nil;
}

- (IBAction)OnDeleteAction:(id)sender
{
    m_ResultType = m_DefaultType;
    [NSApp endSheet:self.window returnCode:DialogResult::Delete];
}

- (void)OnCancelAction:(id)sender
{
    [NSApp endSheet:self.window returnCode:DialogResult::Cancel];
}

- (IBAction)OnMenuItem:(NSMenuItem *)sender
{
    NSInteger tag = sender.tag;
    if (tag == 0)
        m_ResultType = FileDeletionOperationType::MoveToTrash;
    else if (tag == 1)
        m_ResultType = FileDeletionOperationType::Delete;
    else if (tag == 2)
        m_ResultType = FileDeletionOperationType::SecureDelete;
    [NSApp endSheet:self.window returnCode:DialogResult::Delete];
}

- (void) buildTitle:(const vector<string>&)_files
{
    if(_files.size() == 1)
        m_Title = [NSString stringWithFormat:@"Do you wish to delete %@?",
                   [NSString stringWithUTF8String:_files.front().c_str()]];
    else
        m_Title = [NSString stringWithFormat:@"Do you wish to delete %lu items?",
                   _files.size()];
    
}

- (void)ShowSheet:(NSWindow *)_window Files:(const vector<string>&)_files
             Type:(FileDeletionOperationType)_type
          Handler:(FileDeletionSheetCompletionHandler)_handler
{
    assert(!_files.empty());
    assert(_handler);
    
    
    m_Handler = _handler;
    m_DefaultType = _type;
    
    [self buildTitle:_files];
    
    [NSApp beginSheet: [self window]
       modalForWindow: _window
        modalDelegate: self
       didEndSelector: @selector(didEndSheet:returnCode:contextInfo:)
          contextInfo: nil];
}

- (void)ShowSheetForVFS:(NSWindow *)_window
                  Files:(const vector<string>&)_files
                Handler:(FileDeletionSheetCompletionHandler)_handler
{
    assert(!_files.empty());
    assert(_handler);
    m_Handler = _handler;
    [self buildTitle:_files];
    
    [self window]; // load
    [self.DeleteButton setLabel:@"Delete Permanently" forSegment:0];
    [self.DeleteButton setSegmentCount:1];
    
    [NSApp beginSheet: [self window]
       modalForWindow: _window
        modalDelegate: self
       didEndSelector: @selector(didEndSheet:returnCode:contextInfo:)
          contextInfo: nil];
}

- (FileDeletionOperationType)GetType
{
    return m_ResultType;
}

@end

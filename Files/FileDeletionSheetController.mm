//
//  FileDeletionSheetWindowController.m
//  Directories
//
//  Created by Pavel Dogurevich on 15.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "FileDeletionSheetController.h"

#import "chained_strings.h"
#import "Common.h"

@interface FileDeletionSheetController ()
- (void)windowDidLoad;
- (void)didEndSheet:(NSWindow *)_sheet returnCode:(NSInteger)_code
        contextInfo:(void *)_context;
@end

@implementation FileDeletionSheetController
{
    chained_strings *m_Files;
    FileDeletionSheetCompletionHandler m_Handler;
    FileDeletionOperationType m_DefaultType;
    FileDeletionOperationType m_ResultType;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    NSString *label;
    if (m_Files->size() == 1)
    {
        label = [NSString stringWithFormat:@"Do you wish to delete %@?",
                 [NSString stringWithUTF8String:m_Files->front().str()]];
    }
    else
    {
        label = [NSString stringWithFormat:@"Do you wish to delete %i items?",
                 m_Files->size()];
    }
    [self.Label setStringValue:label];
    
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

- (id)init
{
    self = [super initWithWindowNibName:@"FileDeletionSheetController"];
    if (self)
    {
    }
    
    return self;
}

- (void)ShowSheet:(NSWindow *)_window Files:(chained_strings *)_files
             Type:(FileDeletionOperationType)_type
          Handler:(FileDeletionSheetCompletionHandler)_handler
{
    assert(!_files->empty());
    assert(_handler);
    
    m_Files = _files;
    m_Handler = _handler;
    m_DefaultType = _type;
    
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

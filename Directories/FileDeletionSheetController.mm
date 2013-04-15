//
//  FileDeletionSheetWindowController.m
//  Directories
//
//  Created by Pavel Dogurevich on 15.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "FileDeletionSheetController.h"

#import "FlexChainedStringsChunk.h"
#import "Common.h"

@interface FileDeletionSheetController ()
- (void)windowDidLoad;
- (void)didEndSheet:(NSWindow *)_sheet returnCode:(NSInteger)_code
        contextInfo:(void *)_context;
@end

@implementation FileDeletionSheetController
{
    FlexChainedStringsChunk *m_Files;
    FileDeletionSheetCompletionHandler m_Handler;
    FileDeletionOperationType m_Type;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    [self.window setDefaultButtonCell:self.DeleteButton.cell];
    
    NSString *label;
    if (m_Files->amount == 1)
    {
        label = [NSString stringWithFormat:@"Do you wish to delete %@?",
                 [NSString stringWithUTF8String:m_Files->strings[0].str()]];
    }
    else
    {
        label = [NSString stringWithFormat:@"Do you wish to delete %i items?",
                 m_Files->amount];
    }
    [self.Label setStringValue:label];
    
    if (m_Type == FileDeletionOperationType::MoveToTrash)
        [self.DeleteTypeButton selectItemAtIndex:0];
    else if (m_Type == FileDeletionOperationType::Delete)
        [self.DeleteTypeButton selectItemAtIndex:1];
    else if (m_Type == FileDeletionOperationType::SecureDelete)
        [self.DeleteTypeButton selectItemAtIndex:2];
}

- (void)didEndSheet:(NSWindow *)_sheet returnCode:(NSInteger)_code contextInfo:(void *)_context
{
    [[self window] orderOut:self];
    
    if(m_Handler)
        m_Handler((int)_code);
}

- (IBAction)OnDeleteAction:(id)sender
{
    [NSApp endSheet:self.window returnCode:DialogResult::Delete];
}

- (void)OnCancelAction:(id)sender
{
    [NSApp endSheet:self.window returnCode:DialogResult::Cancel];
}

- (id)init
{
    self = [super initWithWindowNibName:@"FileDeletionSheetController"];
    if (self)
    {
    }
    
    return self;
}

- (void)ShowSheet:(NSWindow *)_window Files:(FlexChainedStringsChunk *)_files
             Type:(FileDeletionOperationType)_type
          Handler:(FileDeletionSheetCompletionHandler)_handler
{
    assert(_files->amount > 0);
    assert(_handler);
    
    m_Files = _files;
    m_Handler = _handler;
    m_Type = _type;
    
    [NSApp beginSheet: [self window]
       modalForWindow: _window
        modalDelegate: self
       didEndSelector: @selector(didEndSheet:returnCode:contextInfo:)
          contextInfo: nil];
}

- (void)SetType:(FileDeletionOperation *)_type
{
    
}

- (FileDeletionOperationType)GetType
{
    switch ([self.DeleteTypeButton indexOfSelectedItem])
    {
        case 0: return FileDeletionOperationType::MoveToTrash;
        case 1: return FileDeletionOperationType::Delete;
        case 2: return FileDeletionOperationType::SecureDelete;
    }
    
    return FileDeletionOperationType::Invalid;
}

@end

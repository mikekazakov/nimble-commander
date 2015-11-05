//
//  FileDeletionSheetWindowController.m
//  Directories
//
//  Created by Pavel Dogurevich on 15.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include "FileDeletionSheetController.h"
#include "../../Common.h"

@implementation FileDeletionSheetController
{
    FileDeletionSheetCompletionHandler m_Handler;
    FileDeletionOperationType m_DefaultType;
    FileDeletionOperationType m_ResultType;

    bool                        m_AllowMoveToTrash;
    bool                        m_AllowSecureDelete;
    NSString *m_Title;
}

@synthesize allowMoveToTrash = m_AllowMoveToTrash;
@synthesize allowSecureDelete = m_AllowSecureDelete;
@synthesize resultType = m_ResultType;

- (id)init
{
    self = [super initWithWindowNibName:@"FileDeletionSheetController"];
    if (self) {
        m_AllowMoveToTrash = true;
        m_AllowSecureDelete = true;
        m_DefaultType = FileDeletionOperationType::Delete;
        m_ResultType = FileDeletionOperationType::Delete;
        m_Title = @"";
    }
    
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    self.Label.stringValue = m_Title;
    
    [self.DeleteButtonMenu removeAllItems];
    if( m_AllowMoveToTrash ) {
        NSMenuItem *it = [[NSMenuItem alloc] init];
        it.title = NSLocalizedString(@"Move to Trash", "Menu item title in file deletion sheet");
        it.tag = int(FileDeletionOperationType::MoveToTrash);
        it.action = @selector(OnMenuItem:);
        it.target = self;
        [self.DeleteButtonMenu addItem:it];
    }
    if( true ) {
        NSMenuItem *it = [[NSMenuItem alloc] init];
        it.title = NSLocalizedString(@"Delete Permanently", "Menu item title in file deletion sheet");
        it.tag = int(FileDeletionOperationType::Delete);
        it.action = @selector(OnMenuItem:);
        it.target = self;
        [self.DeleteButtonMenu addItem:it];        
    }
    if( m_AllowSecureDelete ) {
        NSMenuItem *it = [[NSMenuItem alloc] init];
        it.title = NSLocalizedString(@"Delete Securely", "Menu item title in file deletion sheet");
        it.tag = int(FileDeletionOperationType::SecureDelete);
        it.action = @selector(OnMenuItem:);
        it.target = self;        
        [self.DeleteButtonMenu addItem:it];        
    }

    NSMenuItem *item = [self.DeleteButtonMenu itemWithTag:int(m_DefaultType)];
    if(!item) {
        item = [self.DeleteButtonMenu itemWithTag:int(FileDeletionOperationType::Delete)];
        m_DefaultType = FileDeletionOperationType::Delete;
    }
    
    [self.DeleteButton setLabel:item.title forSegment:0];
    [self.DeleteButtonMenu removeItem:item];
    
    [self.DeleteButton MakeDefault];
  
    if( self.DeleteButtonMenu.itemArray.count == 0 )
        [self.DeleteButton setSegmentCount:1];
}

- (void)didEndSheet:(NSWindow *)_sheet returnCode:(NSInteger)_code contextInfo:(void *)_context
{
    [self.window orderOut:self];
    
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
    m_ResultType = FileDeletionOperationType(tag);
    [NSApp endSheet:self.window returnCode:DialogResult::Delete];
}

- (void) buildTitle:(const vector<string>&)_files
{
    if(_files.size() == 1)
        m_Title = [NSString stringWithFormat:NSLocalizedString(@"Do you wish to delete \u201c%@\u201d?", "Asking user to delete a file"),
                   [NSString stringWithUTF8String:_files.front().c_str()]];
    else
        m_Title = [NSString stringWithFormat:NSLocalizedString(@"Do you wish to delete %@ items?", "Asking user to delete multiple files"),
                   [NSNumber numberWithUnsignedLong:_files.size()]];
    
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

@end

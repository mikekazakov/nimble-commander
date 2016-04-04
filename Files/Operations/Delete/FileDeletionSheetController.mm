//
//  FileDeletionSheetWindowController.m
//  Directories
//
//  Created by Pavel Dogurevich on 15.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include "../../GoogleAnalytics.h"
#include "../../ButtonWithOptions.h"
#include "FileDeletionSheetController.h"

@interface FileDeletionSheetController()

@property (strong) IBOutlet NSTextField *Label;
@property (strong) IBOutlet ButtonWithOptions *DeleteButton;
@property (strong) IBOutlet NSMenu *DeleteButtonMenu;

- (IBAction)OnDeleteAction:(id)sender;
- (IBAction)OnCancelAction:(id)sender;
- (IBAction)OnMenuItem:(NSMenuItem *)sender;

@end

@implementation FileDeletionSheetController
{
    FileDeletionOperationType m_DefaultType;
    FileDeletionOperationType m_ResultType;

    shared_ptr<vector<VFSListingItem>> m_Items;
    bool                        m_AllowMoveToTrash;
}

@synthesize allowMoveToTrash = m_AllowMoveToTrash;
@synthesize resultType = m_ResultType;
@synthesize defaultType = m_DefaultType;

- (id)initWithItems:(shared_ptr<vector<VFSListingItem>>)_items
{
    self = [super initWithWindowNibName:@"FileDeletionSheetController"];
    if (self) {
        m_AllowMoveToTrash = true;
        m_DefaultType = FileDeletionOperationType::Delete;
        m_ResultType = FileDeletionOperationType::Delete;
        m_Items = _items;
    }
    
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
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
    
    [self buildTitle];
    
    GoogleAnalytics::Instance().PostScreenView("Delete Files");
}

- (IBAction)OnDeleteAction:(id)sender
{
    m_ResultType = m_DefaultType;
    [self endSheet:NSModalResponseOK];
}

- (void)OnCancelAction:(id)sender
{
    [self endSheet:NSModalResponseCancel];
}

- (IBAction)OnMenuItem:(NSMenuItem *)sender
{
    NSInteger tag = sender.tag;
    m_ResultType = FileDeletionOperationType(tag);
    [self endSheet:NSModalResponseOK];
}

- (void) buildTitle
{
    if(m_Items->size() == 1)
        self.Label.stringValue = [NSString stringWithFormat:NSLocalizedString(@"Do you wish to delete \u201c%@\u201d?", "Asking user to delete a file"),
                                  [NSString stringWithUTF8String:m_Items->front().Name()]];
    else
        self.Label.stringValue = [NSString stringWithFormat:NSLocalizedString(@"Do you wish to delete %@ items?", "Asking user to delete multiple files"),
                                  [NSNumber numberWithUnsignedLong:m_Items->size()]];
}

@end

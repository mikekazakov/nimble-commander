// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "DeletionDialog.h"
#include "../Internal.h"
#include <VFS/VFS.h>

using namespace nc::ops;

@interface NCOpsDeletionDialog()

@property (strong) IBOutlet NSTextField *Label;
@property (strong) IBOutlet NSButton *primaryActionButton;
@property (strong) IBOutlet NSPopUpButton *auxiliaryActionPopup;

@end

@implementation NCOpsDeletionDialog
{
    DeletionType m_DefaultType;
    DeletionType m_ResultType;

    shared_ptr<vector<VFSListingItem>> m_Items;
    bool                        m_AllowMoveToTrash;
}

@synthesize allowMoveToTrash = m_AllowMoveToTrash;
@synthesize resultType = m_ResultType;
@synthesize defaultType = m_DefaultType;

- (id)initWithItems:(const shared_ptr<vector<VFSListingItem>>&)_items
{
   self = [super initWithWindowNibName:@"DeletionDialog"];
    if (self) {
        m_AllowMoveToTrash = true;
        m_DefaultType = DeletionType::Permanent;
        m_ResultType = DeletionType::Permanent;
        m_Items = _items;
    }
    
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    if( m_DefaultType == DeletionType::Trash ) {
        self.primaryActionButton.title = NSLocalizedString(@"Move to Trash", "Menu item title in file deletion sheet");
    
        [self.auxiliaryActionPopup addItemWithTitle:NSLocalizedString(@"Delete Permanently", "Menu item title in file deletion sheet")];
        self.auxiliaryActionPopup.lastItem.target = self;
        self.auxiliaryActionPopup.lastItem.action = @selector(onAuxActionPermDelete:);
    }
    else if( m_DefaultType == DeletionType::Permanent ) {
        self.primaryActionButton.title = NSLocalizedString(@"Delete Permanently", "Menu item title in file deletion sheet");
        
        if( m_AllowMoveToTrash ) {
            [self.auxiliaryActionPopup addItemWithTitle:NSLocalizedString(@"Move to Trash", "Menu item title in file deletion sheet")];
            self.auxiliaryActionPopup.lastItem.target = self;
            self.auxiliaryActionPopup.lastItem.action = @selector(onAuxActionTrash:);
        }
        else {
            self.auxiliaryActionPopup.enabled = false;
        }
    }
    
    [self buildTitle];
}

- (IBAction)onPrimaryAction:(id)sender
{
    m_ResultType = m_DefaultType;
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
}

- (IBAction)onAuxActionTrash:(id)sender
{
    m_ResultType = DeletionType::Trash;
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
}

- (IBAction)onAuxActionPermDelete:(id)sender
{
    m_ResultType = DeletionType::Permanent;
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
}

- (IBAction)OnCancelAction:(id)sender
{
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
}

- (void)moveRight:(id)sender
{
    [self.window selectNextKeyView:sender];
}

- (void)moveLeft:(id)sender
{
    [self.window selectPreviousKeyView:sender];
}

- (void) buildTitle
{
    if(m_Items->size() == 1)
        self.Label.stringValue = [NSString stringWithFormat:NSLocalizedString(@"Do you want to delete “%@”?", "Asking user to delete a file"),
                                  [NSString stringWithUTF8String:m_Items->front().FilenameC()]];
    else
        self.Label.stringValue = [NSString stringWithFormat:NSLocalizedString(@"Do you want to delete %@ items?", "Asking user to delete multiple files"),
                                  [NSNumber numberWithUnsignedLong:m_Items->size()]];
}

@end

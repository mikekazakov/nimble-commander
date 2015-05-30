//
//  BatchRenameSheetRangeSelectionPopoverController.m
//  Files
//
//  Created by Michael G. Kazakov on 17/05/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#import "BatchRenameSheetRangeSelectionPopoverController.h"

@implementation BatchRenameSheetRangeSelectionPopoverController
{
    NSRange m_Selection;
}

- (id) init
{
    self = [super initWithNibName:NSStringFromClass(self.class) bundle:nil];
    if(self) {
        self.string = @"";
        m_Selection = NSMakeRange(0, 0);
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.textField.stringValue = self.string;
}

- (IBAction)OnOK:(id)sender
{
    if( self.textField.currentEditor )
        m_Selection = self.textField.currentEditor.selectedRange;
    
    if(self.handler)
        self.handler(m_Selection);
    
    if(auto v = (NSPopover*)self.enclosingPopover)
        [v close];
}

- (IBAction)OnCancel:(id)sender
{
    if(auto v = (NSPopover*)self.enclosingPopover)
        [v close];
}

- (void)popoverDidClose:(NSNotification *)notification
{
    ((NSPopover*)notification.object).contentViewController = nil; // here we are
}

- (void)controlTextDidEndEditing:(NSNotification *)obj
{
    if( self.textField.currentEditor )
        m_Selection = self.textField.currentEditor.selectedRange;
}

- (void)controlTextDidChange:(NSNotification *)obj
{
    self.textField.stringValue = self.string;
    
}

@end

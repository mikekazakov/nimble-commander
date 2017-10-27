// Copyright (C) 2015-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "BatchRenamingRangeSelectionPopover.h"
#include "../Internal.h"

using namespace nc::ops;

@implementation NCOpsBatchRenamingRangeSelectionPopover
{
    NSRange m_Selection;
}

- (id) init
{
    self = [super initWithNibName:@"BatchRenamingRangeSelectionPopover" bundle:Bundle()];
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

- (void)popoverWillShow:(NSNotification *)notification
{
    self.view.window.initialFirstResponder = self.textField;
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

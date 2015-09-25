//
//  MassCopySheetController.m
//  Directories
//
//  Created by Michael G. Kazakov on 12.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "MassCopySheetController.h"
#import "Common.h"
#import "FileCopyOperation.h"

@implementation MassCopySheetController
{
    MassCopySheetCompletionHandler m_Handler;
    shared_ptr<vector<string>> m_Items;
    NSString *m_InitialPath;
    bool m_IsCopying;
}

- (id)init {
    self = [super initWithWindowNibName:@"MassCopySheetController"];
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
 
    [self.window makeFirstResponder:self.TextField];
    self.TextField.stringValue = m_InitialPath;
    if(m_InitialPath.length > 0 && [m_InitialPath characterAtIndex:0] != u'/')
    {
        // short path, find if there's an extension, if so - select only filename without .ext
        NSRange r = [m_InitialPath rangeOfString:@"." options:NSBackwardsSearch];
        if(r.location != NSNotFound)
            self.TextField.currentEditor.selectedRange = NSMakeRange(0, r.location);
    }
    
    
    int amount = (int)m_Items->size();
    if(m_IsCopying) {
        if(amount > 1)
            self.DescriptionText.stringValue = [NSString stringWithFormat:NSLocalizedString(@"Copy %@ items to:", "Copy files sheet prompt, copying many files"),
                                                [NSNumber numberWithInt:amount]];
        else
            self.DescriptionText.stringValue = [NSString stringWithFormat:NSLocalizedString(@"Copy \u201c%@\u201d to:", "Copy files sheet prompt, copying single file"),
                                                [NSString stringWithUTF8String:m_Items->front().c_str()]];
        self.CopyButton.title = self.CopyButtonStringStub.title;
    }
    else {
        if(amount > 1)
            self.DescriptionText.stringValue = [NSString stringWithFormat:NSLocalizedString(@"Rename/move %@ items to:", "Move files sheet prompt, moving many files"),
                                                [NSNumber numberWithInt:amount]];
        else
            self.DescriptionText.stringValue = [NSString stringWithFormat:NSLocalizedString(@"Rename/move \u201c%@\u201d to:", "Move files sheet prompt, moving single file"),
                                                [NSString stringWithUTF8String:m_Items->front().c_str()]];
        self.CopyButton.title = self.RenameButtonStringStub.title;
    }
    
    [self OnDisclosureTriangle:self];
}

- (IBAction)OnCopy:(id)sender
{
    [NSApp endSheet:[self window] returnCode:DialogResult::Copy];
}

- (IBAction)OnCancel:(id)sender
{
    [NSApp endSheet:[self window] returnCode:DialogResult::Cancel];    
}

- (IBAction)OnDisclosureTriangle:(id)sender
{
    NSSize new_size;
    if(self.DisclosureTriangle.state == NSOnState) {
        new_size = NSMakeSize(370, 270);
        self.DisclosureLabel.stringValue = NSLocalizedString(@"Hide advanced settings", "");
    }
    else {
        new_size = NSMakeSize(370, 140);
        self.DisclosureLabel.stringValue = NSLocalizedString(@"Show advanced settings", "");
        self.DisclosureGroup.hidden = true;
    }
    
    NSWindow *window = [self window];
    NSRect frame = [window contentRectForFrameRect:[window frame]];
    NSRect newFrame = [window frameRectForContentRect:
                       NSMakeRect(frame.origin.x, NSMaxY(frame) - new_size.height,
                                  frame.size.width, new_size.height)];

    if(sender != self)
    {
        double hDifference = fabs(new_size.height - ((NSView*)[window contentView]).bounds.size.height);
        double duration = MAX(0.0005 * hDifference, 0.10); // we always want a slight animation
        nanoseconds nduration(uint64_t(duration * NSEC_PER_SEC));
        
        [NSAnimationContext beginGrouping];
        [[NSAnimationContext currentContext] setDuration:duration];
        [[window animator] setFrame:newFrame display:YES];
        [NSAnimationContext endGrouping];
        if([self.DisclosureTriangle state] == NSOnState)
            dispatch_to_main_queue_after(nduration, [=]{
                               [self.DisclosureGroup setHidden:false];
                           });
    }
    else
    {
        [window setFrame:newFrame display:YES];
    }
    [window setMinSize:NSMakeSize(370, newFrame.size.height-10)];
    [window setMaxSize:NSMakeSize(800, newFrame.size.height+10)];
}

- (void)ShowSheet:(NSWindow *)_window initpath:(NSString*)_path iscopying:(bool)_iscopying items:(shared_ptr<vector<string>>)_items handler:(MassCopySheetCompletionHandler)_handler
{
    if( _items->empty() )
        throw invalid_argument("MassCopySheetController.ShowSheet: _items can't be empty");
    
    m_Handler = _handler;
    m_InitialPath = _path;
    m_IsCopying = _iscopying;
    m_Items = _items;

    [NSApp beginSheet: self.window
       modalForWindow: _window
        modalDelegate: self
       didEndSelector: @selector(didEndSheet:returnCode:contextInfo:)
          contextInfo: nil];
}

- (void)didEndSheet:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    [self.window orderOut:self];
    
    if(m_Handler)
        m_Handler((int)returnCode);
    m_Handler = nil;
}

- (void)FillOptions:(FileCopyOperationOptions*) _opts
{
    _opts->preserve_symlinks    = [self.PreserveSymlinksCheckbox    state] == NSOnState;
    _opts->copy_xattrs          = [self.CopyXattrsCheckbox          state] == NSOnState;
    _opts->copy_file_times      = [self.CopyFileTimesCheckbox       state] == NSOnState;
    _opts->copy_unix_flags      = [self.CopyUNIXFlagsCheckbox       state] == NSOnState;
    _opts->copy_unix_owners     = [self.CopyUnixOwnersCheckbox      state] == NSOnState;
}

@end

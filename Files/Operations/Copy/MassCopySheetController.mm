//
//  MassCopySheetController.m
//  Directories
//
//  Created by Michael G. Kazakov on 12.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include <Habanero/CommonPaths.h>
#include <Habanero/algo.h>
#import "MassCopySheetController.h"
#import "Common.h"
#import "FileCopyOperation.h"

// removes entries of ".." and "."
// quite a bad implementation with O(n^2) complexity and possibly some allocations
static string MakeCanonicPath(string _input)
{
    static const auto dotdot = "/../"s;
    auto pos = _input.find(dotdot);
    if( pos != _input.npos && pos > 0 ) {
        auto sl = _input.rfind('/', pos-1);
        if( sl != _input.npos ) {
            _input.erase( sl+1, pos - sl + dotdot.size() - 1 );
            return MakeCanonicPath( move(_input) );
        }
    }
    
    static const auto dot = "/./"s;
    pos = _input.find(dot);
    if( pos != _input.npos ) {
        _input.erase( pos, 2 );
        return MakeCanonicPath( move(_input) );
    }
    
    return _input;
}

@implementation MassCopySheetController
{
    vector<VFSFlexibleListingItem>  m_SourceItems;
    VFSHostPtr                      m_SourceHost; // can be nullptr in case of non-uniform listing
    string                          m_SourceDirectory; // may be "" if SourceHost is nullptr
    string                          m_InitialDestination;
    VFSHostPtr                      m_DestinationHost; // can be nullptr in case of non-uniform listing
    FileCopyOperationOptions        m_Options;
    
    string                          m_ResultDestination;
    VFSHostPtr                      m_ResultHost;
}

@synthesize resultDestination = m_ResultDestination;
@synthesize resultHost = m_ResultHost;
@synthesize resultOptions = m_Options;

- (instancetype) initWithItems:(vector<VFSFlexibleListingItem>)_source_items
                     sourceVFS:(const VFSHostPtr&)_source_host
               sourceDirectory:(const string&)_source_directory
            initialDestination:(const string&)_initial_destination
                destinationVFS:(const VFSHostPtr&)_destination_host
              operationOptions:(const FileCopyOperationOptions&)_options
{
    self = [super initWithWindowNibName:@"MassCopySheetController"];
    if( self ) {
        m_SourceItems = move( _source_items );
        m_SourceDirectory = _source_directory;
        m_SourceHost = _source_host;
        m_InitialDestination = _initial_destination;
        m_DestinationHost = _destination_host;
        m_Options = _options;
        self.isValidInput = [self validateInput:_initial_destination];
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    [self.window makeFirstResponder:self.TextField];
    
    auto initial_path = [NSString stringWithUTF8StdString:m_InitialDestination];
    
    self.TextField.stringValue = initial_path;
    if( initial_path.length > 0 && [initial_path characterAtIndex:0] != u'/' ) {
        // short path, find if there's an extension, if so - select only filename without .ext
        NSRange r = [initial_path rangeOfString:@"." options:NSBackwardsSearch];
        if( r.location != NSNotFound )
            self.TextField.currentEditor.selectedRange = NSMakeRange(0, r.location);
    }
    
    int amount = (int)m_SourceItems.size();
    if( m_Options.docopy ) {
        if(amount > 1)
            self.DescriptionText.stringValue = [NSString stringWithFormat:NSLocalizedString(@"Copy %@ items to:", "Copy files sheet prompt, copying many files"),
                                                [NSNumber numberWithInt:amount]];
        else
            self.DescriptionText.stringValue = [NSString stringWithFormat:NSLocalizedString(@"Copy \u201c%@\u201d to:", "Copy files sheet prompt, copying single file"),
                                                [NSString stringWithUTF8String:m_SourceItems.front().Name()]];
        self.CopyButton.title = self.CopyButtonStringStub.title;
    }
    else {
        if(amount > 1)
            self.DescriptionText.stringValue = [NSString stringWithFormat:NSLocalizedString(@"Rename/move %@ items to:", "Move files sheet prompt, moving many files"),
                                                [NSNumber numberWithInt:amount]];
        else
            self.DescriptionText.stringValue = [NSString stringWithFormat:NSLocalizedString(@"Rename/move \u201c%@\u201d to:", "Move files sheet prompt, moving single file"),
                                                [NSString stringWithUTF8String:m_SourceItems.front().Name()]];
        self.CopyButton.title = self.RenameButtonStringStub.title;
    }
    
    [self OnDisclosureTriangle:self];
}

- (IBAction)OnCopy:(id)sender
{
    [self validate];
    [self fillOptions];
    [self endSheet:NSModalResponseOK];
}

- (IBAction)OnCancel:(id)sender
{
    [self endSheet:NSModalResponseCancel];
}

- (bool)validateInput:(const string&)_input
{
    auto not_valid = [self]{
        m_ResultDestination = "";
        m_ResultHost = nullptr;
        return false;
    };
    
    if( _input.empty() )
        return not_valid();
    
    
    string input = _input;
    
    if( input.front() == '/' ) {
        if( !m_DestinationHost )
            return not_valid();

        // do '..'/'.' stuff
        input = MakeCanonicPath(input);
        
        m_ResultDestination = input;
        m_ResultHost = m_DestinationHost;
    }
    else {
        if( !m_SourceHost )
            return not_valid();
        
        if( m_SourceHost->IsNativeFS() && has_prefix(input, "~/") ) // input is relative to home dir
            input.replace(0, 2, CommonPaths::Home());
        else if( m_SourceHost->IsNativeFS() && has_prefix(input, "~") ) // input is relative to home dir
            input.replace(0, 1, CommonPaths::Home());
        else // input is relative to source base dir
            input = m_SourceDirectory + input;

        // do '..'/'.' stuff
        input = MakeCanonicPath(input);
        
//        cout << input << endl;

        m_ResultDestination = input;
        m_ResultHost = m_SourceHost;   
    }
    
    return true;
}

- (IBAction)OnDisclosureTriangle:(id)sender
{
    // TODO: remove this shit and make it again with auto-layout
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

- (void)fillOptions
{
    m_Options.preserve_symlinks    = self.PreserveSymlinksCheckbox.state == NSOnState;
    m_Options.copy_xattrs          = self.CopyXattrsCheckbox.state == NSOnState;
    m_Options.copy_file_times      = self.CopyFileTimesCheckbox.state == NSOnState;
    m_Options.copy_unix_flags      = self.CopyUNIXFlagsCheckbox.state == NSOnState;
    m_Options.copy_unix_owners     = self.CopyUnixOwnersCheckbox.state == NSOnState;
    // TODO: verification options
}

- (void)validate
{
    NSString *val = self.TextField.stringValue;
    self.isValidInput = [self validateInput:(val ? val.fileSystemRepresentationSafe : "")];
}

- (void)controlTextDidChange:(NSNotification *)notification
{
    if( objc_cast<NSTextField>(notification.object) == self.TextField )
        [self validate];
}


@end

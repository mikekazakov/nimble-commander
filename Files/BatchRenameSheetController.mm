//
//  BatchRenameSheetController.m
//  Files
//
//  Created by Michael G. Kazakov on 16/05/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#import "BatchRenameSheetController.h"
#import "BatchRename.h"
#import "Common.h"
#import "BatchRenameSheetRangeSelectionPopoverController.h"

@implementation BatchRenameSheetController
{
    vector<NSView*>                 m_ActionViews;
    vector<unsigned>                m_Indeces;
    vector<BatchRename::FileInfo>   m_FileInfos;
    
    
    
    vector<NSTextField*>            m_LabelsBefore;
    vector<NSTextField*>            m_LabelsAfter;
    
    NSPopover                      *m_Popover;
}


- (instancetype) initWithListing:(const VFSListing&)_listing
                      andIndeces:(vector<unsigned>)_inds
{
    self = [[BatchRenameSheetController alloc] init];
    if(self) {
        assert(!_inds.empty());
        m_Indeces = _inds;
        
        for( auto i: m_Indeces ) {
            auto &e = _listing.At(i);
            
            BatchRename::FileInfo fi;
            fi.mod_time = e.MTime();
            localtime_r(&fi.mod_time, &fi.mod_time_tm);
            fi.filename = e.NSName().copy;
            
            static auto cs = [NSCharacterSet characterSetWithCharactersInString:@"."];
            auto r = [fi.filename rangeOfCharacterFromSet:cs options:NSBackwardsSearch];
            bool has_ext = (r.location != NSNotFound && r.location != 0 && r.location != fi.filename.length - 1);
            if(has_ext) {
                fi.name = [fi.filename substringWithRange:NSMakeRange(0, r.location)];
                fi.extension = [fi.filename substringWithRange:NSMakeRange( r.location + 1, fi.filename.length - r.location - 1)];
            }
            else {
                fi.name = fi.filename;
                fi.extension = @"";
            }
            
            m_FileInfos.emplace_back(fi);
        }
        
        
        for(auto i: m_Indeces) {
            auto &e = _listing.At(i);
            
            {
                NSTextField *tf = [[NSTextField alloc] initWithFrame:NSRect()];
                tf.stringValue = e.NSName().copy;
                tf.bordered = false;
                tf.editable = false;
                tf.drawsBackground = false;
                m_LabelsBefore.emplace_back(tf);
            }
            
            {
                NSTextField *tf = [[NSTextField alloc] initWithFrame:NSRect()];
                tf.stringValue = e.NSName().copy;
                tf.bordered = false;
                tf.editable = false;
                tf.drawsBackground = false;
                m_LabelsAfter.emplace_back(tf);
            }
            
            
        }
    }
    return self;
    
}
- (void)windowDidLoad {
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    
    [self InsertStringIntoMask:@"[N].[E]"];
}

- (IBAction)OnCancel:(id)sender
{
    [self endSheet:NSModalResponseStop];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    if( tableView == self.FilenamesTable )
        return m_Indeces.size();
    return 0;
}

- (NSView *)tableView:(NSTableView *)tableView
   viewForTableColumn:(NSTableColumn *)tableColumn
                  row:(NSInteger)row
{
    if( tableView == self.FilenamesTable ) {
        if( [tableColumn.identifier isEqualToString:@"original"] ) {
            assert( row >= 0 && row < m_LabelsBefore.size() );
            return m_LabelsBefore[row];
        }
        if( [tableColumn.identifier isEqualToString:@"renamed"] ) {
            assert( row >= 0 && row < m_LabelsAfter.size() );
            return m_LabelsAfter[row];
        }
        
    }
    
    return nil;
}

- (IBAction)OnFilenameMaskChanged:(id)sender
{
    NSString *filename_mask = self.FilenameMask.stringValue ? self.FilenameMask.stringValue : @"";
    
    BatchRename br;
    if(!br.BuildActionsScript(filename_mask))
    {
        for(auto &l:m_LabelsAfter)
            l.stringValue = @"<Error!>";
        return;
    }
    else {
        vector<NSString*> newnames;

        MachTimeBenchmark mtb;
//        for(auto &i: fis)
        for(size_t i = 0, e = m_FileInfos.size(); i!=e; ++i)
            newnames.emplace_back(br.Rename(m_FileInfos[i], (int)i));
        mtb.ResetMicro();
        
        for(size_t i = 0, e = newnames.size(); i!=e; ++i)
            m_LabelsAfter[i].stringValue = newnames[i];
    }
    
}

- (IBAction)OnInsertNamePlaceholder:(id)sender
{
    [self InsertStringIntoMask:@"[N]"];
}

- (IBAction)OnInsertNameRangePlaceholder:(id)sender
{
    auto *pc = [BatchRenameSheetRangeSelectionPopoverController new];
    auto curr_sel = self.currentMaskSelection;
    pc.handler = ^(NSRange _range){
        if(_range.length == 0)
            return;
        NSString *ph = [NSString stringWithFormat:@"[N%lu-%lu]", _range.location + 1, _range.location + _range.length];
        dispatch_to_main_queue([=]{
            [self InsertStringIntoMask:ph withSelection:curr_sel];
        });
    };
    if( self.FilenamesTable.selectedRow >= 0  )
        pc.string = m_FileInfos[self.FilenamesTable.selectedRow].name;
    else
        pc.string = m_FileInfos[0].name;
    
    m_Popover = [NSPopover new];
    m_Popover.contentViewController = pc;
    m_Popover.delegate = pc;
    m_Popover.behavior = NSPopoverBehaviorTransient;
    pc.enclosingPopover = m_Popover;
    [m_Popover showRelativeToRect:self.InsertNameRangePlaceholderButton.bounds
                           ofView:self.InsertNameRangePlaceholderButton
                    preferredEdge:NSMaxXEdge];
}

- (IBAction)OnInsertCounterPlaceholder:(id)sender
{
    [self InsertStringIntoMask:@"[C]"];
}

- (IBAction)OnInsertExtensionPlaceholder:(id)sender
{
    [self InsertStringIntoMask:@"[E]"];
}

- (IBAction)OnInsertDatePlaceholder:(id)sender
{
    [self InsertStringIntoMask:@"[YMD]"];
}

- (IBAction)OnInsertTimePlaceholder:(id)sender
{
    [self InsertStringIntoMask:@"[hms]"];
}

- (IBAction)OnInsertMenu:(id)sender
{
    NSRect r = [self.window convertRectToScreen:self.InsertPlaceholderMenuButton.frame];
    [self.InsertPlaceholderMenu popUpMenuPositioningItem:nil atLocation:NSMakePoint(NSMaxX(r), NSMaxY(r)) inView:nil];
}

- (IBAction)OnInsertUppercasePlaceholder:(id)sender
{
    [self InsertStringIntoMask:@"[U]"];
}

- (IBAction)OnInsertLowercasePlaceholder:(id)sender
{
    [self InsertStringIntoMask:@"[L]"];    
}

- (IBAction)OnInsertCapitalizePlaceholder:(id)sender
{
    [self InsertStringIntoMask:@"[F]"];
}

- (IBAction)OnInsertOriginalCasePlaceholder:(id)sender
{
    [self InsertStringIntoMask:@"[n]"];
}

- (NSRange)currentMaskSelection
{
    if( self.FilenameMask.currentEditor )
        return self.FilenameMask.currentEditor.selectedRange;
    else
        return NSMakeRange(NSNotFound, 0);
}

- (void)InsertStringIntoMask:(NSString*)_str
{
    NSString *current_mask = self.FilenameMask.stringValue ? self.FilenameMask.stringValue : @"";
    if( self.FilenameMask.currentEditor ) {
        NSRange range = self.FilenameMask.currentEditor.selectedRange;
        current_mask = [current_mask stringByReplacingCharactersInRange:range withString:_str];
    }
    else
        current_mask = [current_mask stringByAppendingString:_str];
    
    [self SetNewMask:current_mask];
}

- (void)InsertStringIntoMask:(NSString*)_str withSelection:(NSRange)_r
{
    NSString *current_mask = self.FilenameMask.stringValue ? self.FilenameMask.stringValue : @"";
    if( _r.location != NSNotFound)
        current_mask = [current_mask stringByReplacingCharactersInRange:_r withString:_str];
    else
        current_mask = [current_mask stringByAppendingString:_str];
    
    [self SetNewMask:current_mask];
}

- (void)SetNewMask:(NSString*)_str
{
    [self.FilenameMask.undoManager registerUndoWithTarget:self
                                                 selector:@selector(SetNewMask:)
                                                   object:self.FilenameMask.stringValue];

    self.FilenameMask.stringValue = _str;
    [self OnFilenameMaskChanged:self.FilenameMask];
}

- (void)controlTextDidChange:(NSNotification *)notification
{
    if( objc_cast<NSTextField>(notification.object) == self.FilenameMask )
        [self OnFilenameMaskChanged:self.FilenameMask];
}

@end

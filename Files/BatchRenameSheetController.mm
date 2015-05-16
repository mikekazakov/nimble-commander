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

@implementation BatchRenameSheetController
{
    vector<NSView*>                 m_ActionViews;
    shared_ptr<const VFSListing>    m_Listing;
    vector<unsigned>                m_Indeces;
    
    
    vector<NSTextField*>            m_LabelsBefore;
    vector<NSTextField*>            m_LabelsAfter;
}


- (instancetype) initWithListing:(shared_ptr<const VFSListing>)_listing
                      andIndeces:(vector<unsigned>)_inds
{
    self = [[BatchRenameSheetController alloc] init];
    if(self) {
        m_Listing = _listing;
        m_Indeces = _inds;
        
        for(auto i: m_Indeces) {
            auto &e = m_Listing->At(i);
            
            {
                NSTextField *tf = [[NSTextField alloc] initWithFrame:NSRect()];
                tf.stringValue = e.NSName().copy;
                tf.bordered = false;
                tf.editable = true;
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
    
    vector<BatchRename::FileInfo> fis;
    for( auto i: m_Indeces ) {
        auto &e = m_Listing->At(i);
        
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
        
        fis.emplace_back(fi);
    }
    
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
        for(size_t i = 0, e = fis.size(); i!=e; ++i)
            newnames.emplace_back(br.Rename(fis[i], (int)i));
        mtb.ResetMicro();
        
        for(size_t i = 0, e = newnames.size(); i!=e; ++i)
            m_LabelsAfter[i].stringValue = newnames[i];
    }
    
}

- (void)controlTextDidChange:(NSNotification *)notification
{
    if( objc_cast<NSTextField>(notification.object) == self.FilenameMask )
        [self OnFilenameMaskChanged:self.FilenameMask];
}

@end

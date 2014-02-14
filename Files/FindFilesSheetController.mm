//
//  FindFileSheetController.m
//  Files
//
//  Created by Michael G. Kazakov on 12.02.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import <deque>
#import <sys/stat.h>
#import "FindFilesSheetController.h"
#import "Encodings.h"
#import "FileSearch.h"
#import "Common.h"

struct FoundItem
{
    string filename;
    string dir_path;
    struct stat st;
};

@implementation FindFilesSheetController
{
    NSWindow *m_ParentWindow;
    FindFilesSheetController *m_Self;
    shared_ptr<VFSHost>     m_Host;
    string                  m_Path;
    
    shared_ptr<FileSearch>  m_FileSearch;
    
    deque<FoundItem>        m_FoundItems;
    
    NSDateFormatter         *m_DateFormatter;
}

- (id) init
{
    self = [super initWithWindowNibName:NSStringFromClass(self.class)];
    if(self){
        m_FileSearch = make_shared<FileSearch>();
        
        m_DateFormatter = [NSDateFormatter new];
        [m_DateFormatter setLocale:[NSLocale currentLocale]];
        [m_DateFormatter setDateStyle:NSDateFormatterShortStyle];	// short date
        
    }
    return self;
}


- (void)windowDidLoad
{
    [super windowDidLoad];
    
    self.TableView.delegate = self;
    self.TableView.dataSource = self;
}

- (void)ShowSheet:(NSWindow *)_window
          withVFS:(shared_ptr<VFSHost>) _host
         fromPath:(string) _path;
{
    m_ParentWindow = _window;
    m_Host = _host;
    m_Path = _path;
    
    m_Self = self;
    [NSApp beginSheet: [self window]
       modalForWindow: _window
        modalDelegate: self
       didEndSelector: @selector(didEndSheet:returnCode:contextInfo:)
          contextInfo: nil];
    
}

- (void)didEndSheet:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    [[self window] orderOut:self];
    m_ParentWindow = nil;
    m_Self = nil;
}

- (IBAction)OnClose:(id)sender
{
    // TODO: stop searching here and wait until search actually flushes it's backgroun thread
    m_FileSearch->Stop();
    m_FileSearch->Wait();
    [NSApp endSheet:[self window] returnCode:0];
}

- (IBAction)OnSearch:(id)sender
{    
    if([self.MaskTextField.stringValue isEqualToString:@""] == false &&
       [self.MaskTextField.stringValue isEqualToString:@"*"] == false)
    {
        FileSearch::FilterName filter_name;
        filter_name.mask = self.MaskTextField.stringValue;
        m_FileSearch->SetFilterName(&filter_name);
    }
    else
        m_FileSearch->SetFilterName(nullptr);
    
    if([self.ContainingTextField.stringValue isEqualToString:@""] == false)
    {
        FileSearch::FilterContent filter_content;
        filter_content.text = self.ContainingTextField.stringValue;
        filter_content.encoding = ENCODING_UTF8;
        m_FileSearch->SetFilterContent(&filter_content);
    }
    else
        m_FileSearch->SetFilterContent(nullptr);
        
    
    m_FileSearch->Go(m_Path.c_str(),
                     m_Host,
                     FileSearch::Options::GoIntoSubDirs,
                     ^bool(const char *_filename, const char *_in_path){
                         FoundItem it;
                         it.filename = _filename;
                         it.dir_path = _in_path;
                         memset(&it.st, 0, sizeof(it.st));
                         
                         // sync op - bad. better move it off the searching thread
                         m_Host->Stat((it.dir_path + "/" + it.filename).c_str(),
                                      it.st, 0, 0);
                         
                         m_FoundItems.emplace_back(it);
                         

                         NSIndexSet *rows = [NSIndexSet indexSetWithIndex:m_FoundItems.size()-1];
                         
                         dispatch_to_main_queue(^{
                            [self.TableView insertRowsAtIndexes:rows
                                                  withAnimation:NSTableViewAnimationEffectNone];
                            });
                         return true;
                     },
                     ^{}
                     );
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return m_FoundItems.size();
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    if([tableColumn.identifier isEqualToString:@"ColName"]) {
        NSTableCellView *result = [tableView makeViewWithIdentifier:@"ColName" owner:self];
        result.textField.stringValue = [NSString stringWithUTF8String:m_FoundItems[row].filename.c_str()];
        return result;
    }
    else if([tableColumn.identifier isEqualToString:@"ColPath"]) {
        NSTableCellView *result = [tableView makeViewWithIdentifier:@"ColPath" owner:self];
        result.textField.stringValue = [NSString stringWithUTF8String:m_FoundItems[row].dir_path.c_str()];
        return result;
    }
    else if([tableColumn.identifier isEqualToString:@"ColSize"]) {
        NSTableCellView *result = [tableView makeViewWithIdentifier:@"ColSize" owner:self];
        result.textField.stringValue = FormHumanReadableSizeRepresentation6(m_FoundItems[row].st.st_size);
        result.textField.alignment = NSRightTextAlignment;
        return result;
    }
    else if([tableColumn.identifier isEqualToString:@"ColModif"]) {
        NSTableCellView *result = [tableView makeViewWithIdentifier:@"ColModif" owner:self];
        NSDate *date = [NSDate dateWithTimeIntervalSince1970:m_FoundItems[row].st.st_mtimespec.tv_sec];
        result.textField.stringValue = [m_DateFormatter stringFromDate:date];
        result.textField.alignment = NSCenterTextAlignment;
        return result;
    }
    
    return nil;
}


- (IBAction)OnStop:(id)sender
{
    m_FileSearch->Stop();    
}
@end

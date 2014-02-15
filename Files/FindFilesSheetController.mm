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

static const int g_MaximumSearchResults = 16384;

namespace {
    
struct FoundItem
{
    string filename = "!";
    string dir_path = "!!";
    string full_filename;
    struct stat st;
};
    
}

@interface FindFilesSheetFoundItem : NSObject

- (id) initWithFoundItem:(const FoundItem&)_item;
@property NSString *location;
@property NSString *filename;
@property (readonly) uint64_t size;
@property (readonly) uint64_t mdate;
@end

@implementation FindFilesSheetFoundItem
{
    FoundItem m_Data;
    NSString *m_Location;
    NSString *m_Filename;
}

@synthesize location = m_Location;
@synthesize filename = m_Filename;

- (id) initWithFoundItem:(const FoundItem&)_item
{
    self = [super init];
    if(self) {
        m_Data = _item;
        m_Location = [NSString stringWithUTF8StdStringNoCopy:m_Data.dir_path];
        m_Filename = [NSString stringWithUTF8StdStringNoCopy:m_Data.filename];
    }
    return self;
}

- (uint64_t) size {
    return m_Data.st.st_size;
}

- (uint64_t) mdate {
    return m_Data.st.st_mtimespec.tv_sec;
}

@end

@interface FindFilesSheetSizeToStringTransformer : NSValueTransformer
@end
@implementation FindFilesSheetSizeToStringTransformer
+ (void) initialize
{
    [NSValueTransformer setValueTransformer:[[self alloc] init]
                                    forName:NSStringFromClass(self.class)];
}
+ (Class)transformedValueClass
{
	return [NSString class];
}
- (id)transformedValue:(id)value
{
    return (value == nil) ? nil : FormHumanReadableSizeRepresentation6([value unsignedLongLongValue]);
}
@end

@interface FindFilesSheetTimeToStringTransformer : NSValueTransformer
@end
@implementation FindFilesSheetTimeToStringTransformer
+ (void) initialize
{
    [NSValueTransformer setValueTransformer:[[self alloc] init]
                                    forName:NSStringFromClass(self.class)];
}
+ (Class)transformedValueClass
{
	return [NSString class];
}
- (id)transformedValue:(id)value
{
    static NSDateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [NSDateFormatter new];
        [formatter setLocale:[NSLocale currentLocale]];
        [formatter setDateStyle:NSDateFormatterShortStyle];	// short date
    });
    
    if(value == nil)
        return nil;
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:[value unsignedLongLongValue]];
    return [formatter stringFromDate:date];
}
@end


@implementation FindFilesSheetController
{
    NSWindow                   *m_ParentWindow;
    FindFilesSheetController   *m_Self;
    shared_ptr<VFSHost>         m_Host;
    string                      m_Path;
    unique_ptr<FileSearch>      m_FileSearch;
    NSDateFormatter            *m_DateFormatter;
    
    NSMutableArray             *m_FoundItems;
    
    NSMutableArray             *m_FoundItemsBatch;
    NSTimer                    *m_BatchDrainTimer;
    SerialQueue                 m_BatchQueue;
}

@synthesize FoundItems = m_FoundItems;

- (id) init
{
    self = [super initWithWindowNibName:NSStringFromClass(self.class)];
    if(self){
        m_FileSearch.reset(new FileSearch);
        m_FoundItems = [NSMutableArray new];
        m_FoundItemsBatch = [NSMutableArray new];
        m_BatchQueue = SerialQueueT::Make();
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    self.TableView.ColumnAutoresizingStyle = NSTableViewUniformColumnAutoresizingStyle;
    [self.TableView sizeToFit];
    
    self.ArrayController.SortDescriptors = @[
                                             [[NSSortDescriptor alloc] initWithKey:@"location" ascending:YES],
                                             [[NSSortDescriptor alloc] initWithKey:@"filename" ascending:YES],
                                             [[NSSortDescriptor alloc] initWithKey:@"size" ascending:YES],
                                             [[NSSortDescriptor alloc] initWithKey:@"mdate" ascending:YES]
                                             ];
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
    m_FileSearch->Stop();
    m_FileSearch->Wait();
    [NSApp endSheet:[self window] returnCode:0];
}

- (void) OnFinishedSearch
{
    dispatch_to_main_queue(^{
        self.SearchButton.state = NSOffState;

        [self UpdateByTimer:m_BatchDrainTimer];
        [m_BatchDrainTimer invalidate];
        m_BatchDrainTimer = nil;
    });
}

- (IBAction)OnSearch:(id)sender
{
    if(m_FileSearch->IsRunning()) {
        m_FileSearch->Stop();
        return;
    }

    NSRange range_all = NSMakeRange(0, [self.ArrayController.arrangedObjects count]);
    [self.ArrayController removeObjectsAtArrangedObjectIndexes:[NSIndexSet indexSetWithIndexesInRange:range_all]];
    
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
        filter_content.case_sensitive = self.CaseSensitiveButton.intValue;
        filter_content.whole_phrase = self.WholePhraseButton.intValue;
        m_FileSearch->SetFilterContent(&filter_content);
    }
    else
        m_FileSearch->SetFilterContent(nullptr);
    
    if([self.SizeTextField.stringValue isEqualToString:@""] == false)
    {
        uint64_t value = self.SizeTextField.integerValue;
        switch (self.SizeMetricPopUp.selectedTag) {
            case 1: value *= 1024; break;
            case 2: value *= 1024*1024; break;
            case 3: value *= 1024*1024*1024; break;
            default: break;
        }
        FileSearch::FilterSize filter_size;
        if(self.SizeRelationPopUp.selectedTag == 0) // "≥"
            filter_size.min = value;
        else if(self.SizeRelationPopUp.selectedTag == 2) // "≤"
            filter_size.max = value;
        else if(self.SizeRelationPopUp.selectedTag == 1) // "="
            filter_size.min = filter_size.max = value;
        
        m_FileSearch->SetFilterSize(&filter_size);        
    }
        else m_FileSearch->SetFilterSize(nullptr);
    
        
    
    bool r = m_FileSearch->Go(m_Path.c_str(),
                              m_Host,
                              FileSearch::Options::GoIntoSubDirs,
                              ^(const char *_filename, const char *_in_path){
                                  FoundItem it;
                                  it.filename = _filename;
                                  it.dir_path = _in_path;
                                  it.full_filename = it.dir_path;
                                  if(it.full_filename.back() != '/') it.full_filename += '/';
                                  it.full_filename += it.filename;
                                  if(it.dir_path != "/" && it.dir_path.back() == '/') it.dir_path.pop_back();
                                  
                                  memset(&it.st, 0, sizeof(it.st));
                         
                                  // sync op - bad. better move it off the searching thread
                                  m_Host->Stat(it.full_filename.c_str(), it.st, 0, 0);
                                  
                                  FindFilesSheetFoundItem *item = [[FindFilesSheetFoundItem alloc] initWithFoundItem:it];
                                  
                                  m_BatchQueue->Run(^{
                                      [m_FoundItemsBatch addObject:item];
                                    });
                                  
                                  if(m_FoundItems.count + m_FoundItemsBatch.count >= g_MaximumSearchResults)
                                      m_FileSearch->Stop(); // gorshochek, ne vari!!!
                              },
                              ^{
                                  [self OnFinishedSearch];
                              }
                              );
    if(r) {
        self.SearchButton.state = NSOnState;
        m_BatchDrainTimer = [NSTimer scheduledTimerWithTimeInterval:0.2 // 0.2 sec update
                                                             target:self
                                                           selector:@selector(UpdateByTimer:)
                                                           userInfo:nil
                                                            repeats:YES];
        [m_BatchDrainTimer SetSafeTolerance];
    }
    else {
        self.SearchButton.state = NSOffState;
    }
}

- (void) UpdateByTimer:(NSTimer*)theTimer
{
    m_BatchQueue->Run(^{
        if(m_FoundItemsBatch.count == 0)
            return;
        
        NSArray *temp = m_FoundItemsBatch;
        m_FoundItemsBatch = [NSMutableArray new];
        
        dispatch_to_main_queue(^{
            [self.ArrayController addObjects:temp];
        });
    });
}

@end

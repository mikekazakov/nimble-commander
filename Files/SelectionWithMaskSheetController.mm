//
//  SelectionWithMaskSheetController.m
//  Files
//
//  Created by Michael G. Kazakov on 30.07.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <map>
#import "3rd_party/NSFileManager+DirectoryLocations.h"
#import "SelectionWithMaskSheetController.h"
#import "Common.h"


static NSString *g_FileName = @"/selectionwithmasksheet.bplist"; // bplist file name
static SelectionWithMaskSheetHistory *g_SharedHistory = nil;

@implementation SelectionWithMaskSheetHistoryEntry
- (id)initWithCoder:(NSCoder *)decoder {
    self = [super init];
    if (self) {
        mask = [decoder decodeObjectForKey:@"mask"];
        last_used = [decoder decodeObjectForKey:@"last_used"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:mask forKey:@"mask"];
    [encoder encodeObject:last_used forKey:@"last_used"];
}
@end

@implementation SelectionWithMaskSheetHistory
{
    NSMutableArray *m_History;
    bool            m_IsDirty;
    map<void*, NSString*> m_SelectedMask;
}

+ (NSString*) StorageFileName
{
    return [[[NSFileManager defaultManager] applicationSupportDirectory] stringByAppendingString:g_FileName];
}

- (id) init
{
    self = [super init];
    if(self == nil)
        return self;
    
    m_History = [NSKeyedUnarchiver unarchiveObjectWithFile:[SelectionWithMaskSheetHistory StorageFileName]];
    if(!m_History)
        m_History = [NSMutableArray new];
    m_IsDirty = false;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(OnTerminate:)
                                                 name:NSApplicationWillTerminateNotification
                                               object:[NSApplication sharedApplication]];
    
    return self;
}

- (void)OnTerminate:(NSNotification *)note
{
    [NSKeyedArchiver archiveRootObject:m_History toFile:[SelectionWithMaskSheetHistory StorageFileName]];
}

+ (SelectionWithMaskSheetHistory*) sharedHistory
{
    static dispatch_once_t once;
    
    dispatch_once(&once, ^{
        g_SharedHistory = [SelectionWithMaskSheetHistory new];
    });
    
    return g_SharedHistory;
}

- (NSArray*) History
{
    return m_History;
}

- (NSString*) SelectedMaskForWindow:(NSWindow*)_window
{
    // every window should have "*.*" selection mask initially.
    // next times it should have previous mask by default
    void *key = (__bridge void*)_window;
    auto i = m_SelectedMask.find(key);
    return i != m_SelectedMask.end() ? (*i).second : @"*.*";
}

- (void) ReportUsedMask:(NSString*)_mask ForWindow:(NSWindow*)_window
{
    void *key = (__bridge void*)_window;
    NSString *mask = [_mask copy];
    m_SelectedMask[key] = mask;

    // exclude meaningless masks - don't store them
    if([mask isEqualToString:@""]    ||
       [mask isEqualToString:@"."]   ||
       [mask isEqualToString:@".."]  ||
       [mask isEqualToString:@"*"]   ||
       [mask isEqualToString:@"*.*"] )
        return;
    
    for(SelectionWithMaskSheetHistoryEntry *entry: m_History)
        if([entry->mask isEqualToString:mask])
        {
            [m_History removeObject:entry];
            break;
        }
        
    SelectionWithMaskSheetHistoryEntry *new_entry = [SelectionWithMaskSheetHistoryEntry new];
    new_entry->mask = mask;
    new_entry->last_used = [NSDate date];
    [m_History insertObject:new_entry atIndex:0];
    m_IsDirty = true;
}

@end

@implementation SelectionWithMaskSheetController
{
    NSString *m_Mask;
    NSWindow       *m_ParentWindow;
    bool    m_IsDeselect;
    SelectionWithMaskCompletionHandler m_Handler;
}

- (id)init
{
    self = [super initWithWindowNibName:NSStringFromClass(self.class)];
    if(self){
        m_IsDeselect = false;
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];

    for(SelectionWithMaskSheetHistoryEntry *entry: [[SelectionWithMaskSheetHistory sharedHistory] History])
        [self.ComboBox addItemWithObjectValue:entry->mask];

    NSString *mask = [[SelectionWithMaskSheetHistory sharedHistory] SelectedMaskForWindow:m_ParentWindow];
    [self.ComboBox setStringValue:mask];
    [self.ComboBox selectItemWithObjectValue:mask];
    [self.ComboBox becomeFirstResponder];
    
    [self.TitleLabel setStringValue:m_IsDeselect ? @"Deselect using mask:" : @"Select using mask:" ];
}

- (NSString *) Mask
{
    return m_Mask;
}

- (IBAction)OnOK:(id)sender
{
    m_Mask = self.ComboBox.stringValue;
    [[SelectionWithMaskSheetHistory sharedHistory] ReportUsedMask:m_Mask ForWindow:m_ParentWindow];
    
    [NSApp endSheet:[self window] returnCode:DialogResult::OK];    
}

- (IBAction)OnCancel:(id)sender
{
    m_Mask = @"";
    [NSApp endSheet:[self window] returnCode:DialogResult::Cancel];    
}

- (void)didEndSheet:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    [[self window] orderOut:self];
    m_ParentWindow = nil;
    m_Handler((int)returnCode);
    m_Handler = nil;
}

- (void)ShowSheet:(NSWindow *)_window handler:(SelectionWithMaskCompletionHandler)_handler
{
    m_Handler = _handler;
    m_ParentWindow = _window;
    [NSApp beginSheet: [self window]
       modalForWindow: _window
        modalDelegate: self
       didEndSelector: @selector(didEndSheet:returnCode:contextInfo:)
          contextInfo: nil];
}

- (void)SetIsDeselect:(bool) _value
{
    m_IsDeselect = _value;
}

@end

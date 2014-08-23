//
//  SelectionWithMaskPopupViewController.m
//  Files
//
//  Created by Michael G. Kazakov on 23/08/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import "3rd_party/NSFileManager+DirectoryLocations.h"
#import "SelectionWithMaskPopupViewController.h"
#import "Common.h"

@interface SelectionWithMaskSheetHistoryEntry : NSObject<NSCoding>
{
@public
    NSString    *mask;
    NSDate      *last_used;
}
@end

@interface SelectionWithMaskSheetHistory : NSObject
+ (SelectionWithMaskSheetHistory*) sharedHistory;
- (NSArray*) History;
- (NSString*) SelectedMaskForWindow:(NSWindow*)_window;
- (void) ReportUsedMask:(NSString*)_mask ForWindow:(NSWindow*)_window;
@end

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


@implementation SelectionWithMaskPopupViewController
{
    __unsafe_unretained NSWindow *m_TargetWnd;
}

- (id) init
{
    self = [super initWithNibName:NSStringFromClass(self.class) bundle:nil];
    if(self) {
        [self loadView];
    }
    return self;
}

- (void) setupForWindow:(NSWindow*)_window
{
    for(SelectionWithMaskSheetHistoryEntry *entry: [SelectionWithMaskSheetHistory.sharedHistory History])
        [self.comboBox addItemWithObjectValue:entry->mask];
    
    NSString *mask = [[SelectionWithMaskSheetHistory sharedHistory]
                      SelectedMaskForWindow:_window];
    self.comboBox.stringValue = mask;
    [self.comboBox selectItemWithObjectValue:mask];
    m_TargetWnd = _window;
}

- (IBAction)OnComboBox:(id)sender
{
    if(self.handler == nil)
        return;
    
    if(self.comboBox.stringValue == nil ||
       self.comboBox.stringValue.length == 0)
        return;
    
    [SelectionWithMaskSheetHistory.sharedHistory ReportUsedMask:self.comboBox.stringValue
                                                      ForWindow:m_TargetWnd];
    self.handler( self.comboBox.stringValue );
    self.handler = nil;
    m_TargetWnd = nil;
}

- (void)popoverDidClose:(NSNotification *)notification
{
    ((NSPopover*)notification.object).contentViewController = nil; // here we are
}

@end

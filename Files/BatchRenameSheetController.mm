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
#import "SheetWithHotkeys.h"

@interface BatchRenameSheetControllerNilNumberValueTransformer : NSValueTransformer
@end

@implementation BatchRenameSheetControllerNilNumberValueTransformer
+(Class)transformedValueClass {
    return [NSNumber class];
}
-(id)transformedValue:(id)value {
    if (value == nil)
        return @0;
    else
        return value;
}
@end

@implementation BatchRenameSheetController
{
    vector<NSView*>                 m_ActionViews;
    vector<unsigned>                m_Indeces;
    vector<BatchRename::FileInfo>   m_FileInfos;
    
    
    
    vector<NSTextField*>            m_LabelsBefore;
    vector<NSTextField*>            m_LabelsAfter;
    
    NSPopover                      *m_Popover;
    int                             m_CounterStartsAt;
    int                             m_CounterStepsBy;
}


@synthesize CounterStartsAt = m_CounterStartsAt;
@synthesize CounterStepsBy = m_CounterStepsBy;

- (instancetype) initWithListing:(const VFSListing&)_listing
                      andIndeces:(vector<unsigned>)_inds
{
    self = [[BatchRenameSheetController alloc] init];
    if(self) {
//        assert(!_inds.empty());
        if(_inds.empty())
            throw logic_error("empty files list");
            
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
        
        m_CounterStartsAt = 1;
        m_CounterStepsBy = 1;
    }
    return self;
    
}
- (void)windowDidLoad {
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    
    [self InsertStringIntoMask:@"[N].[E]"];
    
    // wire up hotkeys
    SheetWithHotkeys *sheet = (SheetWithHotkeys *)self.window;
    sheet.onCtrlA = [sheet makeActionHotkey:@selector(OnInsertMenu:)];
    sheet.onCtrlC = [sheet makeActionHotkey:@selector(OnInsertCounterPlaceholder:)];
    sheet.onCtrlD = [sheet makeActionHotkey:@selector(OnInsertDatePlaceholder:)];
    sheet.onCtrlE = [sheet makeActionHotkey:@selector(OnInsertExtensionPlaceholder:)];
    sheet.onCtrlG = [sheet makeClickHotkey:self.CounterDigits];
    sheet.onCtrlL = [sheet makeClickHotkey:self.SearchCaseSensitive];
    sheet.onCtrlN = [sheet makeActionHotkey:@selector(OnInsertNamePlaceholder:)];
    sheet.onCtrlO = [sheet makeClickHotkey:self.SearchOnlyOnce];
    sheet.onCtrlP = [sheet makeFocusHotkey:self.FilenameMask];
    sheet.onCtrlR = [sheet makeActionHotkey:@selector(OnInsertNameRangePlaceholder:)];
    sheet.onCtrlS = [sheet makeFocusHotkey:self.SearchForComboBox];
    sheet.onCtrlT = [sheet makeActionHotkey:@selector(OnInsertTimePlaceholder:)];
    sheet.onCtrlU = [sheet makeClickHotkey:self.CaseProcessing];
    sheet.onCtrlW = [sheet makeFocusHotkey:self.ReplaceWithComboBox];
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
    [self UpdateRename];
}

- (void) UpdateRename
{
    NSString *filename_mask = self.FilenameMask.stringValue ? self.FilenameMask.stringValue : @"";

    NSString *search_for = self.SearchForComboBox.stringValue ? self.SearchForComboBox.stringValue : @"";
    NSString *replace_with = self.ReplaceWithComboBox.stringValue ? self.ReplaceWithComboBox.stringValue : @"";
    bool search_case_sens = self.SearchCaseSensitive.state == NSOnState;
    bool search_once = self.SearchOnlyOnce.state == NSOnState;
    bool search_in_ext = self.SearchInExtension.state == NSOnState;
    bool search_regexp = self.SearchWithRegExp.state == NSOnState;
    BatchRename::CaseTransform ct = (BatchRename::CaseTransform)self.CaseProcessing.selectedTag;
    
    BatchRename br;
    br.SetReplacingOptions(search_for, replace_with, search_case_sens, search_once, search_in_ext, search_regexp);
    br.SetCaseTransform(ct);
    br.SetDefaultCounter(m_CounterStartsAt, m_CounterStepsBy, 1, (unsigned)self.CounterDigits.selectedTag);
    
    if(!br.BuildActionsScript(filename_mask))
    {
        for(auto &l:m_LabelsAfter)
            l.stringValue = @"<Error!>";
        return;
    }
    else {
        vector<NSString*> newnames;
        
        MachTimeBenchmark mtb;
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

- (IBAction)OnInsertPlaceholderFromMenu:(id)sender
{
    if(auto item = objc_cast<NSMenuItem>(sender))
        switch (item.tag) {
            case 101: [self InsertStringIntoMask:@"[N]"];       break;
            case 102: [self InsertStringIntoMask:@"[N1]"];      break;
            case 103: [self InsertStringIntoMask:@"[N2-5]"];    break;
            case 104: [self InsertStringIntoMask:@"[N2,5]"];    break;
            case 105: [self InsertStringIntoMask:@"[N2-]"];     break;
            case 106: [self InsertStringIntoMask:@"[N02-9]"];   break;
            case 107: [self InsertStringIntoMask:@"[N 2-9]"];   break;
            case 108: [self InsertStringIntoMask:@"[N-8,5]"];   break;
            case 109: [self InsertStringIntoMask:@"[N-8-5]"];   break;
            case 110: [self InsertStringIntoMask:@"[N2--5]"];   break;
            case 111: [self InsertStringIntoMask:@"[N-5-]"];    break;
            // ----
            case 201: [self InsertStringIntoMask:@"[E]"];       break;
            case 202: [self InsertStringIntoMask:@"[E1]"];      break;
            case 203: [self InsertStringIntoMask:@"[E2-5]"];    break;
            case 204: [self InsertStringIntoMask:@"[E2,5]"];    break;
            case 205: [self InsertStringIntoMask:@"[E2-]"];     break;
            case 206: [self InsertStringIntoMask:@"[E02-9]"];   break;
            case 207: [self InsertStringIntoMask:@"[E 2-9]"];   break;
            case 208: [self InsertStringIntoMask:@"[E-8,5]"];   break;
            case 209: [self InsertStringIntoMask:@"[E-8-5]"];   break;
            case 210: [self InsertStringIntoMask:@"[E2--5]"];   break;
            case 211: [self InsertStringIntoMask:@"[E-5-]"];    break;
            // ----
            case 301: [self InsertStringIntoMask:@"[d]"];       break;
            case 302: [self InsertStringIntoMask:@"[Y]"];       break;
            case 303: [self InsertStringIntoMask:@"[y]"];       break;
            case 304: [self InsertStringIntoMask:@"[M]"];       break;
            case 305: [self InsertStringIntoMask:@"[D]"];       break;
            case 306: [self InsertStringIntoMask:@"[t]"];       break;
            case 307: [self InsertStringIntoMask:@"[h]"];       break;
            case 308: [self InsertStringIntoMask:@"[m]"];       break;
            case 309: [self InsertStringIntoMask:@"[s]"];       break;
            // ----
            case 401: [self InsertStringIntoMask:@"[U]"];       break;
            case 402: [self InsertStringIntoMask:@"[L]"];       break;
            case 403: [self InsertStringIntoMask:@"[F]"];       break;
            case 404: [self InsertStringIntoMask:@"[n]"];       break;
            // ----
            case 501: [self InsertStringIntoMask:@"[C]"];       break;
            case 502: [self InsertStringIntoMask:@"[C10]"];     break;
            case 503: [self InsertStringIntoMask:@"[C10+2]"];   break;
            case 504: [self InsertStringIntoMask:@"[C10+2/1]"]; break;
            case 505:[self InsertStringIntoMask:@"[C10+2/1:5]"];break;
            // ----
            case 601: [self InsertStringIntoMask:@"[A]"];       break;
            case 602: [self InsertStringIntoMask:@"[[]"];       break;
            case 603: [self InsertStringIntoMask:@"[]]"];       break;
        }
}

- (IBAction)OnSearchForChanged:(id)sender
{
    [self UpdateRename];
}

- (IBAction)OnReplaceWithChanged:(id)sender
{
    [self UpdateRename];
}

- (IBAction)OnSearchReplaceOptionsChanged:(id)sender
{
    [self UpdateRename];
}

- (IBAction)OnCaseProcessingChanged:(id)sender
{
    [self UpdateRename];
}

- (IBAction)OnCounterSettingsChanged:(id)sender
{
    [self UpdateRename];
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
    else if( objc_cast<NSTextField>(notification.object) == self.ReplaceWithComboBox )
        [self OnReplaceWithChanged:self.ReplaceWithComboBox];
    else if( objc_cast<NSTextField>(notification.object) == self.SearchForComboBox )
        [self OnSearchForChanged:self.SearchForComboBox];
    else
        [self UpdateRename];        
}

@end

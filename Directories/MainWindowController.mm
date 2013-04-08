//
//  MainWindowController.m
//  Directories
//
//  Created by Michael G. Kazakov on 09.02.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include "MainWindowController.h"
#include "PanelController.h"
#include "AppDelegate.h"

#include "CopyAsSheetController.h"
#include "CreateDirectorySheetController.h"
#include "MassCopySheetController.h"
#include "DetailedVolumeInformationSheetController.h"
#include "FileSysEntryAttrSheetController.h"
#include "FlexChainedStringsChunk.h"
#include "JobData.h"
#include "FileOp.h"
#include "FileOpMassCopy.h"
#import "OperationsController.h"
#import "OperationsSummaryViewController.h"
#include "FileSysAttrChangeOperation.h"
#include "FileDeletionOperation.h"
#include "MessageBox.h"
#include "KQueueDirUpdate.h"
#include "FSEventsDirUpdate.h"
#include <pwd.h>

// TODO: remove
#import "TimedDummyOperation.h"


@interface MainWindowController ()

@end

@implementation MainWindowController
{
    ActiveState m_ActiveState;                  // creates and owns

    PanelView *m_LeftPanelView;                 // creates and owns
    PanelData *m_LeftPanelData;                 // creates and owns
    PanelController *m_LeftPanelController;     // creates and owns
    
    PanelView *m_RightPanelView;                // creates and owns
    PanelData *m_RightPanelData;                // creates and owns
    PanelController *m_RightPanelController;    // creates and owns
    struct
    {
        NSLayoutConstraint *left_left;
        NSLayoutConstraint *left_bottom;
        NSLayoutConstraint *left_top;
        NSLayoutConstraint *left_right;
        NSLayoutConstraint *right_left;
        NSLayoutConstraint *right_bottom;
        NSLayoutConstraint *right_top;
        NSLayoutConstraint *right_right;
    } m_PanelConstraints;
    
    JobData *m_JobData;                         // creates and owns
    NSTimer *m_JobsUpdateTimer;
    
    OperationsController *m_OperationsController;
    OperationsSummaryViewController *m_OpSummaryController;
}

- (id)init {
    self = [super initWithWindowNibName:@"MainWindowController"];
    
    if (self)
    {
        m_OperationsController = [[OperationsController alloc] init];
        m_OpSummaryController = [[OperationsSummaryViewController alloc] initWthController:m_OperationsController];
    }
    
    return self;
}

-(void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)windowDidLoad
{
    [super windowDidLoad];
 
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    
    [m_OpSummaryController AddViewTo:self.OpSummaryBox];
    
    m_JobData = new JobData;

    struct passwd *pw = getpwuid(getuid());
    assert(pw);

    [self CreatePanels];
    [self CreatePanelConstraints];
    
    m_LeftPanelData = new PanelData;
    m_LeftPanelController = [PanelController new];
    [m_LeftPanelView SetPanelData:m_LeftPanelData];
    [m_LeftPanelController SetView:m_LeftPanelView];
    [m_LeftPanelController SetData:m_LeftPanelData];
    [m_LeftPanelController GoToDirectory:pw->pw_dir];

    m_RightPanelData = new PanelData;
    m_RightPanelController = [PanelController new];
    [m_RightPanelView SetPanelData:m_RightPanelData];
    [m_RightPanelController SetView:m_RightPanelView];
    [m_RightPanelController SetData:m_RightPanelData];
    [m_RightPanelController GoToDirectory:"/"];
    
    m_ActiveState = StateLeftPanel;
    [m_LeftPanelView Activate];

    [[self JobView] SetJobData:m_JobData];
    
    [[self window] makeFirstResponder:self];
    [[self window] setDelegate:self];
    
    m_JobsUpdateTimer = [NSTimer scheduledTimerWithTimeInterval: 0.05
                                                         target: self
                                                       selector:@selector(UpdateByJobsTimer:)
                                                       userInfo: nil
                                                        repeats: YES];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(DidBecomeKeyWindow)
                                                 name:NSWindowDidBecomeKeyNotification
                                               object:[self window]];
    
//    [[self window] visualizeConstraints:[[[self window] contentView] constraints]];
}

- (void)CreatePanels
{
    m_LeftPanelView = [[PanelView alloc] initWithFrame:NSMakeRect(0, 200, 100, 100)];
    [m_LeftPanelView setTranslatesAutoresizingMaskIntoConstraints:NO];
    [[[self window] contentView] addSubview:m_LeftPanelView];

    m_RightPanelView = [[PanelView alloc] initWithFrame:NSMakeRect(100, 100, 100, 100)];
    [m_RightPanelView setTranslatesAutoresizingMaskIntoConstraints:NO];
    [[[self window] contentView] addSubview:m_RightPanelView];    
}

- (void)CreatePanelConstraints
{
    const int topgap = 60;
    [[[self window] contentView] removeConstraint:m_PanelConstraints.left_left];
    [[[self window] contentView] removeConstraint:m_PanelConstraints.left_top];
    [[[self window] contentView] removeConstraint:m_PanelConstraints.left_right];
    [[[self window] contentView] removeConstraint:m_PanelConstraints.left_bottom];
    [[[self window] contentView] removeConstraint:m_PanelConstraints.right_left];
    [[[self window] contentView] removeConstraint:m_PanelConstraints.right_top];
    [[[self window] contentView] removeConstraint:m_PanelConstraints.right_right];
    [[[self window] contentView] removeConstraint:m_PanelConstraints.right_bottom];
    
    m_PanelConstraints.left_left = [NSLayoutConstraint constraintWithItem:m_LeftPanelView
                                                                attribute:NSLayoutAttributeLeft
                                                                relatedBy:NSLayoutRelationEqual
                                                                   toItem:[[self window] contentView]
                                                                attribute:NSLayoutAttributeLeft
                                                               multiplier:1
                                                                 constant:0];
    m_PanelConstraints.left_top = [NSLayoutConstraint constraintWithItem:m_LeftPanelView
                                                                attribute:NSLayoutAttributeTop
                                                                relatedBy:NSLayoutRelationEqual
                                                                   toItem:[[self window] contentView]
                                                                attribute:NSLayoutAttributeTop
                                                               multiplier:1
                                                                 constant:topgap];
    m_PanelConstraints.left_bottom = [NSLayoutConstraint constraintWithItem:m_LeftPanelView
                                                                attribute:NSLayoutAttributeBottom
                                                                relatedBy:NSLayoutRelationEqual
                                                                   toItem:[[self window] contentView]
                                                                attribute:NSLayoutAttributeBottom
                                                               multiplier:1
                                                                 constant:0];
    m_PanelConstraints.left_right = [NSLayoutConstraint constraintWithItem:m_LeftPanelView
                                                               attribute:NSLayoutAttributeRight
                                                               relatedBy:NSLayoutRelationEqual
                                                                  toItem:[[self window] contentView]
                                                               attribute:NSLayoutAttributeCenterX
                                                              multiplier:1
                                                                constant:0];
    m_PanelConstraints.right_left = [NSLayoutConstraint constraintWithItem:m_RightPanelView
                                                                attribute:NSLayoutAttributeLeft
                                                                relatedBy:NSLayoutRelationEqual
                                                                   toItem:[[self window] contentView]
                                                                attribute:NSLayoutAttributeCenterX
                                                               multiplier:1
                                                                 constant:0];
    m_PanelConstraints.right_top = [NSLayoutConstraint constraintWithItem:m_RightPanelView
                                                               attribute:NSLayoutAttributeTop
                                                               relatedBy:NSLayoutRelationEqual
                                                                  toItem:[[self window] contentView]
                                                               attribute:NSLayoutAttributeTop
                                                              multiplier:1
                                                                constant:topgap];
    m_PanelConstraints.right_bottom = [NSLayoutConstraint constraintWithItem:m_RightPanelView
                                                                  attribute:NSLayoutAttributeBottom
                                                                  relatedBy:NSLayoutRelationEqual
                                                                     toItem:[[self window] contentView]
                                                                  attribute:NSLayoutAttributeBottom
                                                                 multiplier:1
                                                                   constant:0];
    m_PanelConstraints.right_right = [NSLayoutConstraint constraintWithItem:m_RightPanelView
                                                                 attribute:NSLayoutAttributeRight
                                                                 relatedBy:NSLayoutRelationEqual
                                                                    toItem:[[self window] contentView]
                                                                 attribute:NSLayoutAttributeRight
                                                                multiplier:1
                                                                  constant:0];
    [[[self window] contentView] addConstraint:m_PanelConstraints.left_left];
    [[[self window] contentView] addConstraint:m_PanelConstraints.left_top];
    [[[self window] contentView] addConstraint:m_PanelConstraints.left_right];
    [[[self window] contentView] addConstraint:m_PanelConstraints.left_bottom];    
    [[[self window] contentView] addConstraint:m_PanelConstraints.right_left];
    [[[self window] contentView] addConstraint:m_PanelConstraints.right_top];
    [[[self window] contentView] addConstraint:m_PanelConstraints.right_right];
    [[[self window] contentView] addConstraint:m_PanelConstraints.right_bottom];

    [self UpdatePanelConstraints:[[self window] frame].size];
}

- (void)UpdatePanelConstraints: (NSSize)frameSize
{
    float gran = 9.;
    float center_x = frameSize.width / 2.;
    float rest = fmod(center_x, gran);
    m_PanelConstraints.left_right.constant = -rest+1;
    m_PanelConstraints.right_left.constant = -rest;

    [[[self window] contentView] setNeedsLayout:true];
}

- (void)windowDidResize:(NSNotification *)notification
{
    [self UpdatePanelConstraints:[[self window] frame].size];    
}

- (void)windowWillClose:(NSNotification *)notification
{
    [(AppDelegate*)[NSApp delegate] RemoveMainWindow:self];
}

- (void)DidBecomeKeyWindow
{
    // update key modifiers state for views    
    unsigned long flags = [NSEvent modifierFlags];
    [m_LeftPanelView ModifierFlagsChanged:flags];
    [m_RightPanelView ModifierFlagsChanged:flags];
}

- (void)UpdateByJobsTimer:(NSTimer*)theTimer
{
    if(m_JobData) m_JobData->PurgeDoneJobs();
    [[self JobView] UpdateByTimer];
}

- (BOOL)acceptsFirstResponder
{
    return YES;
}

- (bool) IsPanelActive
{
    return m_ActiveState == StateLeftPanel || m_ActiveState == StateRightPanel;
}

- (PanelView*) ActivePanelView
{
    if(m_ActiveState == StateLeftPanel)
    {
        return m_LeftPanelView;
    }
    else if(m_ActiveState == StateRightPanel)
    {
        return m_RightPanelView;
    }
    assert(0);
    return 0;
}

- (PanelData*) ActivePanelData
{
    if(m_ActiveState == StateLeftPanel)
    {
        return m_LeftPanelData;
    }
    else if(m_ActiveState == StateRightPanel)
    {
        return m_RightPanelData;
    }
    assert(0);
    return 0;
}

- (PanelController*) ActivePanelController
{
    if(m_ActiveState == StateLeftPanel)
    {
        return m_LeftPanelController;
    }
    else if(m_ActiveState == StateRightPanel)
    {
        return m_RightPanelController;
    }
    assert(0);
    return 0;
}

- (void) HandleTabButton
{
    if(m_ActiveState == StateLeftPanel)
    {
        m_ActiveState = StateRightPanel;
        [m_RightPanelView Activate];
        [m_LeftPanelView Disactivate];
    }
    else
    {
        m_ActiveState = StateLeftPanel;
        [m_LeftPanelView Activate];
        [m_RightPanelView Disactivate];
    }
}

- (void) HandleCopyAs // shift+F5
{
    assert([self IsPanelActive]);
    PanelView *curview = [self ActivePanelView];
    PanelData *curdata = [self ActivePanelData];
    
    int curpos = [curview GetCursorPosition];
    int rawpos = curdata->SortPosToRawPos(curpos);
    const DirectoryEntryInformation& entry = curdata->EntryAtRawPosition(rawpos);
    if(entry.isdotdot())
        return; // do no react on attempts to copy a parent dir
    if(!entry.isreg())
        return; // we can't copy dirs or other stuff for now
    NSString *orig_name = (__bridge_transfer NSString*) FileNameFromDirectoryEntryInformation(entry);
    
     CopyAsSheetController *ca = [[CopyAsSheetController alloc] init];
    
    [ca ShowSheet:[self window] initialname:orig_name handler:^(int _ret)
     {
         if(_ret == DialogResult::OK)
         {
             NSString *res = [[ca TextField] stringValue];
             char src[__DARWIN_MAXPATHLEN];
             curdata->ComposeFullPathForEntry(rawpos, src);
             FileCopy *fc = new FileCopy;
             fc->InitOpData(src, [res UTF8String], self);
             fc->Run();
             m_JobData->AddJob(fc);
         }
     }];

}

- (void) HandleCreateDirectory // F7
{
    assert([self IsPanelActive]);
    
    CreateDirectorySheetController *cd = [[CreateDirectorySheetController alloc] init];
    [cd ShowSheet:[self window] handler:^(int _ret)
     {
         if(_ret == DialogResult::Create)
         {
             NSString *name = [[cd TextField] stringValue];
             
             PanelData *curdata = [self ActivePanelData];
             char pdir[__DARWIN_MAXPATHLEN];
             curdata->GetDirectoryPath(pdir);
             
             DirectoryCreate *dc = new DirectoryCreate;
             dc->InitOpData([name UTF8String], pdir, self);
             dc->Run();
             m_JobData->AddJob(dc);
         }
     }];
}

- (void) HandleCopyCommand // F5
{
    assert([self IsPanelActive]);
    const PanelData *source, *destination;
    if(m_ActiveState == StateLeftPanel)
    {
        source = m_LeftPanelData;
        destination = m_RightPanelData;
    }
    else
    {
        source = m_RightPanelData;
        destination = m_LeftPanelData;
    }
    
    // TODO: implement a case for copying without selected items in source panel
    // we assume that there's selection for now
    
    char dirpath[__DARWIN_MAXPATHLEN];
    destination->GetDirectoryPathWithTrailingSlash(dirpath);
    NSString *nsdirpath = [NSString stringWithUTF8String:dirpath];
    MassCopySheetController *mc = [[MassCopySheetController alloc] init];
    [mc ShowSheet:[self window] initpath:nsdirpath handler:^(int _ret)
     {
         if(_ret == DialogResult::Copy)
         {
             NSString *copyto = [[mc TextField] stringValue];
             FileOpMassCopy *masscopy = new FileOpMassCopy;
             masscopy->InitOpDataWithPanel(*source, [copyto UTF8String], self);
             masscopy->Run();
             m_JobData->AddJob(masscopy);
         }
     }];
}

- (void) HandleDeleteCommand // F8
{
    assert([self IsPanelActive]);
    
    __block FlexChainedStringsChunk *files = 0;
    if([self ActivePanelData]->GetSelectedItemsCount() > 0 )
    {
        files = [self ActivePanelData]->StringsFromSelectedEntries();
    }
    else
    {
        int curpos = [[self ActivePanelView] GetCursorPosition];
        int rawpos = [self ActivePanelData]->SortPosToRawPos(curpos);
        auto const &item = [self ActivePanelData]->EntryAtRawPosition(rawpos);
        if(!item.isdotdot()) // do not try to delete a parent directory
            files = FlexChainedStringsChunk::AllocateWithSingleString(item.namec());
    }
    
    if(files)
    {
        MessageBox *mb = [MessageBox new];
        [mb setAlertStyle:NSCriticalAlertStyle];
        [mb setMessageText:@"Are you sure want to delete it?"];
        [mb addButtonWithTitle:@"Delete"];
        [mb addButtonWithTitle:@"Cancel"];
        [mb ShowSheetWithHandler: [self window] handler:^(int ret){
            if(ret == NSAlertFirstButtonReturn)
            {
                // kill it with fire!
//                FileDeletionOperationType type = FileDeletionOperationType::Delete;
                FileDeletionOperationType type = FileDeletionOperationType::MoveToTrash;
//                FileDeletionOperationType type = FileDeletionOperationType::SecureDelete;
                char root_path[MAXPATHLEN];
                [self ActivePanelData]->GetDirectoryPathWithTrailingSlash(root_path);
                
                [m_OperationsController AddOperation:[[FileDeletionOperation alloc] initWithFiles:files
                                                                                             type:type
                                                                                         rootpath:root_path]];
            }
            else
            {
                FlexChainedStringsChunk::FreeWithDescendants(&files);
            }
        }];
    }
}

- (void) FireDirectoryChanged: (const char*) _dir ticket:(unsigned long)_ticket
{
    [m_LeftPanelController FireDirectoryChanged:_dir ticket:_ticket];
    [m_RightPanelController FireDirectoryChanged:_dir ticket:_ticket];
}

- (void)keyDown:(NSEvent *)event
{
    NSString*  const character = [event charactersIgnoringModifiers];
    if ( [character length] != 1 ) return;
    unichar const unicode        = [character characterAtIndex:0];
    unsigned short const keycode = [event keyCode];
    NSUInteger const modif       = [event modifierFlags];
#define ISMODIFIER(_v) ( (modif&NSDeviceIndependentModifierFlagsMask) == (_v) )
    switch (unicode)
    {
        case NSHomeFunctionKey:
            if([self IsPanelActive])
                [[self ActivePanelView] HandleFirstFile];
            break;
        case NSEndFunctionKey:
            if([self IsPanelActive])
                [[self ActivePanelView] HandleLastFile];
            break;
        case NSLeftArrowFunctionKey:
            if([self IsPanelActive])
                [[self ActivePanelView] HandlePrevColumn];
            break;
        case NSRightArrowFunctionKey:
            if([self IsPanelActive])
                [[self ActivePanelView] HandleNextColumn];
            break;
        case NSUpArrowFunctionKey:
            if([self IsPanelActive])
                [[self ActivePanelView] HandlePrevFile];
            break;
        case NSDownArrowFunctionKey:
            if([self IsPanelActive])
                [[self ActivePanelView] HandleNextFile];
            break;
        case NSPageDownFunctionKey:
            if([self IsPanelActive])
                [[self ActivePanelView] HandleNextPage];
            break;
        case NSPageUpFunctionKey:
            if([self IsPanelActive])
                [[self ActivePanelView] HandlePrevPage];
            break;
        case NSCarriageReturnCharacter: // RETURN key
            if([self IsPanelActive])
            {
                if(ISMODIFIER(NSShiftKeyMask)) [[self ActivePanelController] HandleShiftReturnButton];
                else                           [[self ActivePanelController] HandleReturnButton];
            }
            break;
        case NSTabCharacter: // TAB key
            [self HandleTabButton];
            break;
        case NSF5FunctionKey:
            if([self IsPanelActive])
            {
                if(ISMODIFIER(NSShiftKeyMask|NSFunctionKeyMask))
                    [self HandleCopyAs];
                else // TODO: need to check of absence of any key modifiers here
                    [self HandleCopyCommand];
            }
            break;
        case NSF7FunctionKey:
            if([self IsPanelActive])
                [self HandleCreateDirectory];
            break;            
        case NSF8FunctionKey:
            if([self IsPanelActive] && ISMODIFIER(NSFunctionKeyMask))
                [self HandleDeleteCommand];
            break;
    };
    
    switch (keycode)
    {
        case 17: // t button on keyboard
        {
            if(ISMODIFIER(NSCommandKeyMask|NSAlternateKeyMask|NSControlKeyMask|NSShiftKeyMask))
            {
                [m_OperationsController AddOperation:
                 [[TimedDummyOperation alloc] initWithTime:(1 + rand()%10)]];
            }
            break;
        }
    }
#undef ISMODIFIER
}

- (void)flagsChanged:(NSEvent *)theEvent
{
    if([self IsPanelActive])
    {
        unsigned long flags = [theEvent modifierFlags];
        [m_LeftPanelView ModifierFlagsChanged:flags];
        [m_RightPanelView ModifierFlagsChanged:flags];
    }
}

- (IBAction)LeftPanelGoToButtonAction:(id)sender{
    [m_LeftPanelController GoToDirectory:[[[self LeftPanelGoToButton] GetCurrentSelectionPath] UTF8String]];
}

- (IBAction)RightPanelGoToButtonAction:(id)sender{
    [m_RightPanelController GoToDirectory:[[[self RightPanelGoToButton] GetCurrentSelectionPath] UTF8String]];
}

- (IBAction)ToggleShortViewMode:(id)sender {
    [[self ActivePanelController] ToggleShortViewMode];
}

- (IBAction)ToggleMediumViewMode:(id)sender {
    [[self ActivePanelController] ToggleMediumViewMode];
}

- (IBAction)ToggleWideViewMode:(id)sender{
    [[self ActivePanelController] ToggleWideViewMode];
}

- (IBAction)ToggleSortByName:(id)sender{
    [[self ActivePanelController] ToggleSortingByName];
}

- (IBAction)ToggleSortByExt:(id)sender{
    [[self ActivePanelController] ToggleSortingByExt];
}

- (IBAction)ToggleSortByMTime:(id)sender{
    [[self ActivePanelController] ToggleSortingByMTime];
}

- (IBAction)ToggleSortBySize:(id)sender{
    [[self ActivePanelController] ToggleSortingBySize];
}

- (IBAction)ToggleSortByBTime:(id)sender{
    [[self ActivePanelController] ToggleSortingByBTime];
}

- (IBAction)LeftPanelGoto:(id)sender{
    [[self LeftPanelGoToButton] performClick:self];    
}

- (IBAction)RightPanelGoto:(id)sender{
    [[self RightPanelGoToButton] performClick:self];
}

- (IBAction)OnSyncPanels:(id)sender{
    assert([self IsPanelActive]);
    char dirpath[__DARWIN_MAXPATHLEN];
    if(m_ActiveState == StateLeftPanel)
    {
        m_LeftPanelData->GetDirectoryPathWithTrailingSlash(dirpath);
        [m_RightPanelController GoToDirectory:dirpath];
    }
    else
    {
        m_RightPanelData->GetDirectoryPathWithTrailingSlash(dirpath);
        [m_LeftPanelController GoToDirectory:dirpath];
    }
}

- (IBAction)OnSwapPanels:(id)sender{
    assert([self IsPanelActive]);
    std::swap(m_LeftPanelView, m_RightPanelView);
    std::swap(m_LeftPanelData, m_RightPanelData);
    std::swap(m_LeftPanelController, m_RightPanelController);
    if(m_ActiveState == StateLeftPanel) m_ActiveState = StateRightPanel;
    else if(m_ActiveState == StateRightPanel) m_ActiveState = StateLeftPanel;
    [self CreatePanelConstraints];    
}

- (IBAction)OnRefreshPanel:(id)sender{
    assert([self IsPanelActive]);
    [[self ActivePanelController] RefreshDirectory];
}

- (IBAction)OnFileAttributes:(id)sender{
    assert([self IsPanelActive]);
    FileSysEntryAttrSheetController *sheet = [FileSysEntryAttrSheetController new];
    FileSysEntryAttrSheetCompletionHandler handler = ^(int result){
        if(result == DialogResult::Apply)
        {
            FileSysAttrAlterCommand *command = [sheet Result];
            [m_OperationsController AddOperation:[[FileSysAttrChangeOperation alloc] initWithCommand:command]];
        }
    };

    if([self ActivePanelData]->GetSelectedItemsCount() > 0 )
    {
        [sheet ShowSheet:[self window] selentries:[self ActivePanelData] handler:handler];
    }
    else
    {
        PanelView *curview = [self ActivePanelView];
        PanelData *curdata = [self ActivePanelData];
        int curpos = [curview GetCursorPosition];
        int rawpos = curdata->SortPosToRawPos(curpos);
        if(!curdata->EntryAtRawPosition(rawpos).isdotdot())
            [sheet ShowSheet:[self window] data:[self ActivePanelData] index:rawpos handler:handler];
    }
}

- (IBAction)OnDetailedVolumeInformation:(id)sender{
    assert([self IsPanelActive]);
    PanelView *curview = [self ActivePanelView];
    PanelData *curdata = [self ActivePanelData];
    int curpos = [curview GetCursorPosition];
    int rawpos = curdata->SortPosToRawPos(curpos);
    char src[__DARWIN_MAXPATHLEN];
    curdata->ComposeFullPathForEntry(rawpos, src);
    
    DetailedVolumeInformationSheetController *sheet = [DetailedVolumeInformationSheetController new];
    [sheet ShowSheet:[self window] destpath:src];
}

@end

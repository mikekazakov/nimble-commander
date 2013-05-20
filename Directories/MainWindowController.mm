
//
//  MainWindowController.m
//  Directories
//
//  Created by Michael G. Kazakov on 09.02.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "MainWindowController.h"
#import "PanelController.h"
#import "AppDelegate.h"
#import "CreateDirectorySheetController.h"
#import "MassCopySheetController.h"
#import "DetailedVolumeInformationSheetController.h"
#import "FileSysEntryAttrSheetController.h"
#import "FileDeletionSheetController.h"
#import "FlexChainedStringsChunk.h"
#import "OperationsController.h"
#import "OperationsSummaryViewController.h"
#import "FileSysAttrChangeOperation.h"
#import "FileDeletionOperation.h"
#import "CreateDirectoryOperation.h"
#import "FileCopyOperation.h"
#import "MessageBox.h"
#import "KQueueDirUpdate.h"
#import "FSEventsDirUpdate.h"
#import "PreferencesWindowController.h"
#import "QuickPreview.h"
#import "BigFileView.h"
#import <pwd.h>
#import <sys/types.h>
#import <sys/dirent.h>
#import <sys/stat.h>
#import <dirent.h>
#import <sys/time.h>
#import <sys/xattr.h>
#import <sys/attr.h>
#import <sys/vnode.h>
#import <sys/param.h>
#import <sys/mount.h>
#import <unistd.h>
#import <stdlib.h>

#import "ClassicPanelViewPresentation.h"
#import "ModernPanelViewPresentation.h"

// TODO: remove
#import "TimedDummyOperation.h"

@class QLPreviewPanel;

static bool CheckPath(const char *_path)
{
    DIR *dirp = opendir(_path);
    if(dirp == 0)
        return false;
    closedir(dirp);
    return true;
}




@interface MainWindowController ()

- (void)LoadPanelsSettings;
- (void)SavePanelsSettings;

@end

@implementation MainWindowController
{
    ApplicationSkin m_Skin;
    
    ActiveState m_ActiveState;                  // creates and owns

    PanelView *m_LeftPanelView;                 // creates and owns
    PanelData *m_LeftPanelData;                 // creates and owns
    PanelController *m_LeftPanelController;     // creates and owns
    
    PanelView *m_RightPanelView;                // creates and owns
    PanelData *m_RightPanelData;                // creates and owns
    PanelController *m_RightPanelController;    // creates and owns

    NSMutableArray *m_PanelConstraints;
    
    OperationsController *m_OperationsController;
    OperationsSummaryViewController *m_OpSummaryController;
}
@synthesize OperationsController = m_OperationsController;

- (id)init {
    self = [super initWithWindowNibName:@"MainWindowController"];
    
    if (self)
    {
        [self setShouldCascadeWindows:NO];
        
        m_PanelConstraints = [[NSMutableArray alloc] init];        
        m_OperationsController = [[OperationsController alloc] init];
        m_OpSummaryController = [[OperationsSummaryViewController alloc] initWthController:m_OperationsController];
        
        // Force window to load.
        [self window];
    }
    
    return self;
}

-(void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    // TODO: data, controllers and view deletion. leaks now
}

- (void)windowDidLoad
{
    [super windowDidLoad];
 
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    [m_OpSummaryController AddViewTo:self.OpSummaryBox];


    // panel creation and preparation
    [self CreatePanels];
    [self UpdatePanelFrames];
    m_LeftPanelData = new PanelData;
    m_LeftPanelController = [PanelController new];
    [m_LeftPanelView SetPanelData:m_LeftPanelData];
    [m_LeftPanelView SetPanelController:m_LeftPanelController];
    [m_LeftPanelController SetView:m_LeftPanelView];
    [m_LeftPanelController SetData:m_LeftPanelData];
    [m_LeftPanelController AttachToIndicator:self.LeftPanelSpinningIndicator];
    [m_LeftPanelController SetWindowController:self];
    m_RightPanelData = new PanelData;
    m_RightPanelController = [PanelController new];
    [m_RightPanelView SetPanelData:m_RightPanelData];
    [m_RightPanelView SetPanelController:m_RightPanelController];
    [m_RightPanelController SetView:m_RightPanelView];
    [m_RightPanelController SetData:m_RightPanelData];
    [m_RightPanelController AttachToIndicator:self.RightPanelSpinningIndicator];
    [m_RightPanelController SetWindowController:self];
    [self LoadPanelsSettings];
    
    // now load data into panels
    if( CheckPath([[defaults stringForKey:@"FirstPanelPath"] UTF8String]) )
        [m_LeftPanelController GoToDirectorySync:[[defaults stringForKey:@"FirstPanelPath"] UTF8String]];
    else
    {
        struct passwd *pw = getpwuid(getuid());
        assert(pw);
        assert(CheckPath(pw->pw_dir));
        [m_LeftPanelController GoToDirectorySync:pw->pw_dir];
    }
    
    if( CheckPath([[defaults stringForKey:@"SecondPanelPath"] UTF8String]) )
        [m_RightPanelController GoToDirectorySync:[[defaults stringForKey:@"SecondPanelPath"] UTF8String]];
    else
        [m_RightPanelController GoToDirectorySync:"/"];
    
    m_ActiveState = StateLeftPanel;
    [m_LeftPanelView Activate];

    [[self window] makeFirstResponder:self];
    [[self window] setDelegate:self];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(DidBecomeKeyWindow)
                                                 name:NSWindowDidBecomeKeyNotification
                                               object:[self window]];

//    [[self window] visualizeConstraints:[[[self window] contentView] constraints]];
}

- (void)CreatePanels
{
    m_LeftPanelView = [[PanelView alloc] initWithFrame:NSMakeRect(0, 200, 100, 100)];
    [[[self window] contentView] addSubview:m_LeftPanelView positioned:NSWindowBelow
                                 relativeTo:nil];

    m_RightPanelView = [[PanelView alloc] initWithFrame:NSMakeRect(100, 100, 100, 100)];
    [[[self window] contentView] addSubview:m_RightPanelView positioned:NSWindowBelow
                                 relativeTo:nil];
}

- (void)UpdatePanelFrames
{
    // Make panels fill content view, excluding top gap.
    // Make sure that x and width are integers.
    NSSize frameSize = [self.window contentRectForFrameRect:self.window.frame].size;
    
    const int topgap = 45;
    CGFloat panel_width = int(frameSize.width)/2;
    NSRect frame = NSMakeRect(0, 0, panel_width, frameSize.height - topgap);
    m_LeftPanelView.frame = frame;
    frame.origin.x = panel_width;
    frame.size.width = frameSize.width - panel_width;
    m_RightPanelView.frame = frame;

    if (m_Skin == ApplicationSkin::Classic)
        ClassicPanelViewPresentation::UpdatePanelFrames(m_LeftPanelView, m_RightPanelView, frameSize);
    else
        ModernPanelViewPresentation::UpdatePanelFrames(m_LeftPanelView, m_RightPanelView, frameSize);
}

- (void)LoadPanelsSettings
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [m_LeftPanelController LoadViewState:[defaults dictionaryForKey:@"FirstPanelViewState"]];
    [m_RightPanelController LoadViewState:[defaults dictionaryForKey:@"SecondPanelViewState"]];
}

- (void)SavePanelsSettings
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[m_LeftPanelController SaveViewState] forKey:@"FirstPanelViewState"];
    [defaults setObject:[m_RightPanelController SaveViewState] forKey:@"SecondPanelViewState"];    
}

- (void)windowDidResize:(NSNotification *)notification
{
    [self UpdatePanelFrames];
    [m_OpSummaryController OnWindowResize];
    [self UpdateTitle];
}

- (void)windowWillClose:(NSNotification *)notification
{
    [self SavePanelPaths];
    [(AppDelegate*)[NSApp delegate] RemoveMainWindow:self];
}

- (void)SavePanelPaths
{
    char path[MAXPATHLEN];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    m_LeftPanelData->GetDirectoryPathWithTrailingSlash(path);
    [defaults setObject:[NSString stringWithUTF8String:path] forKey:@"FirstPanelPath"];
    
    m_RightPanelData->GetDirectoryPathWithTrailingSlash(path);
    [defaults setObject:[NSString stringWithUTF8String:path] forKey:@"SecondPanelPath"];
}

- (void)UpdateTitle
{
    char path_raw[__DARWIN_MAXPATHLEN];
    [self ActivePanelData]->GetDirectoryPath(path_raw);
    NSString *path = [NSString stringWithUTF8String:path_raw];
    
    // find window geometry
    NSWindow* window = [self window];
    float leftEdge = NSMaxX([[window standardWindowButton:NSWindowZoomButton] frame]);
    NSButton* fsbutton = [window standardWindowButton:NSWindowFullScreenButton];
    float rightEdge = fsbutton ? [fsbutton frame].origin.x : NSMaxX([window frame]);
    
    // Leave 8 pixels of padding around the title.
    const int kTitlePadding = 8;
    float titleWidth = rightEdge - leftEdge - 2 * kTitlePadding;
    
    // Sending |titleBarFontOfSize| 0 returns default size
    NSDictionary* attributes = [NSDictionary dictionaryWithObject:[NSFont titleBarFontOfSize:0] forKey:NSFontAttributeName];
    self.window.title = StringByTruncatingToWidth(path, titleWidth, kTruncateAtStart, attributes);
}

- (void)PanelPathChanged:(PanelController*)_panel
{
    if(_panel == [self ActivePanelController])
    {
        [self UpdateTitle];
    }
    
    if(_panel == m_LeftPanelController)
    {
        char tmp[MAXPATHLEN];
        m_LeftPanelData->GetDirectoryPathWithTrailingSlash(tmp);
        [[self LeftPanelGoToButton] SetCurrentPath:tmp];
    }
    if(_panel == m_RightPanelController)
    {
        char tmp[MAXPATHLEN];
        m_RightPanelData->GetDirectoryPathWithTrailingSlash(tmp);
        [[self RightPanelGoToButton] SetCurrentPath:tmp];
    }
}

- (void)ApplySkin:(ApplicationSkin)_skin
{
    m_Skin = _skin;
    
    if (_skin == ApplicationSkin::Modern)
    {
        [m_LeftPanelView SetPresentation:new ModernPanelViewPresentation];
        [m_RightPanelView SetPresentation:new ModernPanelViewPresentation];
    }
    else if (_skin == ApplicationSkin::Classic)
    {
        [m_LeftPanelView SetPresentation:new ClassicPanelViewPresentation];
        [m_RightPanelView SetPresentation:new ClassicPanelViewPresentation];
    }
    
    [self UpdatePanelFrames];
}

- (BOOL)windowShouldClose:(id)sender
{
    if (m_OperationsController.OperationsCount == 0) return TRUE;

    MessageBox *dialog = [[MessageBox alloc] init];
    [dialog addButtonWithTitle:@"Stop And Close"];
    [dialog addButtonWithTitle:@"Cancel"];
    [dialog setMessageText:@"Window has running operations. Do you want to stop them and close the window?"];
    [dialog ShowSheetWithHandler:self.window handler:^(int result) {
        if (result == NSAlertFirstButtonReturn)
        {
            [m_OperationsController Stop];
            [dialog.window orderOut:nil];
            [self.window close];
        }
    }];
    
    return FALSE;
}

- (void)DidBecomeKeyWindow
{
    // update key modifiers state for views    
    unsigned long flags = [NSEvent modifierFlags];
    [m_LeftPanelController ModifierFlagsChanged:flags];
    [m_RightPanelController ModifierFlagsChanged:flags];
    
    if ([QuickPreview IsVisible])
        [[self ActivePanelView] UpdateQuickPreview];
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
    [self ActivatePanel:(m_ActiveState == StateLeftPanel ? StateRightPanel : StateLeftPanel)];
}

- (void)ActivatePanelByController:(PanelController *)controller
{
    if (controller == m_LeftPanelController)
        [self ActivatePanel:StateLeftPanel];
    else if (controller == m_RightPanelController)
        [self ActivatePanel:StateRightPanel];
    else
        assert(0);
}

- (void)ActivatePanel:(ActiveState)_state
{
    if (_state == m_ActiveState) return;
    
    if (_state == StateLeftPanel)
    {
        assert(m_ActiveState == StateRightPanel);
        
        m_ActiveState = StateLeftPanel;
        [m_LeftPanelView Activate];
        [m_RightPanelView Disactivate];
        [m_LeftPanelView UpdateQuickPreview];
    }
    else
    {
        assert(m_ActiveState == StateLeftPanel);
        
        m_ActiveState = StateRightPanel;
        [m_RightPanelView Activate];
        [m_LeftPanelView Disactivate];
        [m_RightPanelView UpdateQuickPreview];
    }
    
    [self UpdateTitle];
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

    if([self IsPanelActive])
        [[self ActivePanelController] keyDown:event]; 
    
    switch (unicode)
    {
        case NSTabCharacter: // TAB key
            [self HandleTabButton];
            break;
        // TODO: remove
        case ' ':
            {
                static bool modern = true;
                modern = !modern;
                if (modern)
                {
                    [self ApplySkin:ApplicationSkin::Modern];
                }
                else
                {
                    [self ApplySkin:ApplicationSkin::Classic];
                }
            }
            break;
        case NSF3FunctionKey:
            if(ISMODIFIER(NSCommandKeyMask|NSAlternateKeyMask|NSControlKeyMask|NSFunctionKeyMask) )
                [self OnFileBigFileViewCommand:nil];
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
        case 100: //f8
        {
            // TODO: refactor; need more high level key handler
            if ((modif & NSDeviceIndependentModifierFlagsMask) == NSShiftKeyMask
                || (modif & NSDeviceIndependentModifierFlagsMask) == (NSShiftKeyMask|NSFunctionKeyMask))
            {
                [self DeleteFiles:YES];
            }
        }
    }
#undef ISMODIFIER
}

- (void)flagsChanged:(NSEvent *)theEvent
{
    if([self IsPanelActive])
    {
        unsigned long flags = [theEvent modifierFlags];
        [m_LeftPanelController ModifierFlagsChanged:flags];
        [m_RightPanelController ModifierFlagsChanged:flags];
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
    [self SavePanelsSettings];
}

- (IBAction)ToggleMediumViewMode:(id)sender {
    [[self ActivePanelController] ToggleMediumViewMode];
    [self SavePanelsSettings];
}

- (IBAction)ToggleFullViewMode:(id)sender{
    [[self ActivePanelController] ToggleFullViewMode];
    [self SavePanelsSettings];
}

- (IBAction)ToggleWideViewMode:(id)sender{
    [[self ActivePanelController] ToggleWideViewMode];
    [self SavePanelsSettings];
}

- (IBAction)ToggleSortByName:(id)sender{
    [[self ActivePanelController] ToggleSortingByName];
    [self SavePanelsSettings];
}

- (IBAction)ToggleSortByExt:(id)sender{
    [[self ActivePanelController] ToggleSortingByExt];
    [self SavePanelsSettings];
}

- (IBAction)ToggleSortByMTime:(id)sender{
    [[self ActivePanelController] ToggleSortingByMTime];
    [self SavePanelsSettings];
}

- (IBAction)ToggleSortBySize:(id)sender{
    [[self ActivePanelController] ToggleSortingBySize];
    [self SavePanelsSettings];
}

- (IBAction)ToggleSortByBTime:(id)sender{
    [[self ActivePanelController] ToggleSortingByBTime];
    [self SavePanelsSettings];
}

- (IBAction)ToggleViewHiddenFiles:(id)sender{
    [[self ActivePanelController] ToggleViewHiddenFiles];
    [self SavePanelsSettings];
}

- (IBAction)ToggleSeparateFoldersFromFiles:(id)sender{
    [[self ActivePanelController] ToggleSeparateFoldersFromFiles];
    [self SavePanelsSettings];
}

- (IBAction)ToggleCaseSensitiveComparison:(id)sender{
    [[self ActivePanelController] ToggleCaseSensitiveComparison];
    [self SavePanelsSettings];
}

- (IBAction)LeftPanelGoto:(id)sender{
    [[self LeftPanelGoToButton] performClick:self];    
}

- (IBAction)RightPanelGoto:(id)sender{
    [[self RightPanelGoToButton] performClick:self];
}

- (IBAction)OnFileViewCommand:(id)sender{
    [[self ActivePanelController] HandleFileView];    
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
    [self UpdatePanelFrames];
    [m_LeftPanelController AttachToIndicator:self.LeftPanelSpinningIndicator];
    [m_RightPanelController AttachToIndicator:self.RightPanelSpinningIndicator];
    
    [self SavePanelsSettings];
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
        if(curpos >= 0)
        {
            int rawpos = curdata->SortPosToRawPos(curpos);
            if(!curdata->EntryAtRawPosition(rawpos).isdotdot())
                [sheet ShowSheet:[self window] data:[self ActivePanelData] index:rawpos handler:handler];
        }
        
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

- (void)DeleteFiles:(BOOL)_shift_behavior
{
    assert([self IsPanelActive]);
    
    __block FlexChainedStringsChunk *files = 0;
    if([self ActivePanelData]->GetSelectedItemsCount() > 0 )
    {
        files = [self ActivePanelData]->StringsFromSelectedEntries();
    }
    else
    {
        auto const *item = [[self ActivePanelView] CurrentItem];
        if(item && !item->isdotdot())
            files = FlexChainedStringsChunk::AllocateWithSingleString(item->namec());
    }
    
    if(!files)
        return;
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    FileDeletionOperationType type = (FileDeletionOperationType)(_shift_behavior
                                         ? [defaults integerForKey:@"ShiftDeleteBehavior"]
                                         : [defaults integerForKey:@"DeleteBehavior"]);
    
    FileDeletionSheetController *sheet = [[FileDeletionSheetController alloc] init];
    [sheet ShowSheet:self.window Files:files Type:type
             Handler:^(int result){
                 if (result == DialogResult::Delete)
                 {
                     FileDeletionOperationType type = [sheet GetType];
                     
                     char root_path[MAXPATHLEN];
                     [self ActivePanelData]->GetDirectoryPathWithTrailingSlash(root_path);
                     
                     FileDeletionOperation *op = [[FileDeletionOperation alloc]
                                                  initWithFiles:files
                                                  type:type
                                                  rootpath:root_path];
                     [m_OperationsController AddOperation:op];
                 }
                 else
                 {
                     FlexChainedStringsChunk::FreeWithDescendants(&files);
                 }
             }];

}

- (IBAction)OnDeleteCommand:(id)sender
{
    [self DeleteFiles:NO];
}

- (IBAction)OnCreateDirectoryCommand:(id)sender{
    assert([self IsPanelActive]);
    CreateDirectorySheetController *cd = [[CreateDirectorySheetController alloc] init];
    [cd ShowSheet:[self window] handler:^(int _ret)
     {
         if(_ret == DialogResult::Create)
         {             
             PanelData *curdata = [self ActivePanelData];
             char pdir[MAXPATHLEN];
             curdata->GetDirectoryPath(pdir);
             
             [m_OperationsController AddOperation:[[CreateDirectoryOperation alloc] initWithPath:[[cd.TextField stringValue] UTF8String]
                                                                                        rootpath:pdir
                                                   ]
                                        WithPanel:[self ActivePanelController]];
         }
     }];
}

- (IBAction)OnFileCopyCommand:(id)sender{
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
    
    __block FlexChainedStringsChunk *files = 0;
    if(source->GetSelectedItemsCount() > 0 )
    {
        files = source->StringsFromSelectedEntries();
    }
    else
    {
        auto const *item = [[self ActivePanelView] CurrentItem];
        if(item && !item->isdotdot())
            files = FlexChainedStringsChunk::AllocateWithSingleString(item->namec());
    }
    
    if(!files)
        return;

    char dest_path[MAXPATHLEN];
    destination->GetDirectoryPathWithTrailingSlash(dest_path);
    NSString *nsdirpath = [NSString stringWithUTF8String:dest_path];
    MassCopySheetController *mc = [[MassCopySheetController alloc] init];
    [mc ShowSheet:[self window] initpath:nsdirpath iscopying:true handler:^(int _ret)
     {
         if(_ret == DialogResult::Copy)
         {
             char root_path[MAXPATHLEN];
             source->GetDirectoryPathWithTrailingSlash(root_path);
             
             FileCopyOperationOptions opts;
             
             [m_OperationsController AddOperation:
              [[FileCopyOperation alloc] initWithFiles:files root:root_path dest:[[mc.TextField stringValue] UTF8String] options:&opts]];
         }
         else
         {
             FlexChainedStringsChunk::FreeWithDescendants(&files);
         
         }
     }];
}

- (IBAction)OnFileCopyAsCommand:(id)sender{
    // process only current cursor item
    assert([self IsPanelActive]);
    
    auto const *item = [[self ActivePanelView] CurrentItem];
    if(!item)
        return;
    if(item->isdotdot())
        return;

    __block FlexChainedStringsChunk *files = FlexChainedStringsChunk::AllocateWithSingleString(item->namec());
    
    MassCopySheetController *mc = [[MassCopySheetController alloc] init];
    [mc ShowSheet:[self window] initpath:[NSString stringWithUTF8String:item->namec()] iscopying:true handler:^(int _ret)
     {
         if(_ret == DialogResult::Copy)
         {
             char root_path[MAXPATHLEN];
             [self ActivePanelData]->GetDirectoryPathWithTrailingSlash(root_path);
             FileCopyOperationOptions opts;
             
             [m_OperationsController AddOperation:
              [[FileCopyOperation alloc] initWithFiles:files
                                                  root:root_path
                                                  dest:[[mc.TextField stringValue] UTF8String]
                                               options:&opts]];
         }
         else
         {
             FlexChainedStringsChunk::FreeWithDescendants(&files);
         }
     }];
}

- (IBAction)OnFileRenameMoveCommand:(id)sender{
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
    
    __block FlexChainedStringsChunk *files = 0;
    if(source->GetSelectedItemsCount() > 0 )
    {
        files = source->StringsFromSelectedEntries();
    }
    else
    {
        auto const *item = [[self ActivePanelView] CurrentItem];
        if(item && !item->isdotdot())
            files = FlexChainedStringsChunk::AllocateWithSingleString(item->namec());
    }

    if(!files)
        return;        
    
    char dest_path[MAXPATHLEN];
    destination->GetDirectoryPathWithTrailingSlash(dest_path);
    NSString *nsdirpath = [NSString stringWithUTF8String:dest_path];

    MassCopySheetController *mc = [[MassCopySheetController alloc] init];
    [mc ShowSheet:[self window] initpath:nsdirpath iscopying:false handler:^(int _ret)
     {
         if(_ret == DialogResult::Copy)
         {             
             char root_path[MAXPATHLEN];
             source->GetDirectoryPathWithTrailingSlash(root_path);
             
             FileCopyOperationOptions opts;
             opts.docopy = false;
             
             [m_OperationsController AddOperation:
              [[FileCopyOperation alloc] initWithFiles:files root:root_path dest:[[mc.TextField stringValue] UTF8String] options:&opts]];
         }
         else
         {
             FlexChainedStringsChunk::FreeWithDescendants(&files);           
         }
     }];    
}

- (IBAction)OnFileRenameMoveAsCommand:(id)sender {
    
    // process only current cursor item
    assert([self IsPanelActive]);
    
    auto const *item = [[self ActivePanelView] CurrentItem];
    if(!item)
        return;
    if(item->isdotdot())
        return;
    
    __block FlexChainedStringsChunk *files = FlexChainedStringsChunk::AllocateWithSingleString(item->namec());
    
    MassCopySheetController *mc = [[MassCopySheetController alloc] init];
    [mc ShowSheet:[self window] initpath:[NSString stringWithUTF8String:item->namec()] iscopying:false handler:^(int _ret)
     {
         if(_ret == DialogResult::Copy)
         {
             char root_path[MAXPATHLEN];
             [self ActivePanelData]->GetDirectoryPathWithTrailingSlash(root_path);
             FileCopyOperationOptions opts;
             opts.docopy = false;
             
             [m_OperationsController AddOperation:
              [[FileCopyOperation alloc] initWithFiles:files
                                                  root:root_path
                                                  dest:[[mc.TextField stringValue] UTF8String]
                                               options:&opts]];
         }
         else
         {
             FlexChainedStringsChunk::FreeWithDescendants(&files);
         }
     }];
}

- (void)OnPreferencesCommand:(id)sender
{
    [PreferencesWindowController ShowWindow];
}

- (NSRect)window:(NSWindow *)window willPositionSheet:(NSWindow *)sheet
       usingRect:(NSRect)rect
{
    NSRect field_rect = [self.SheetAnchorLine frame];
    field_rect.origin.y += 2;
    field_rect.size.height = 0;
    return field_rect;
}

- (void)windowWillBeginSheet:(NSNotification *)notification
{
    [m_OpSummaryController OnWindowBeginSheet];
}

- (void)windowDidEndSheet:(NSNotification *)notification
{
    [m_OpSummaryController OnWindowEndSheet];
}

- (BOOL) validateMenuItem:(NSMenuItem *)item
{
    static const auto upd_for_sort = ^(NSMenuItem *_item, PanelSortMode _mode, PanelSortMode::Mode _mask) {
        static NSImage *img = [NSImage imageNamed:NSImageNameRemoveTemplate];
        if(_mode.sort & _mask) {
            [_item setImage:_mode.isrevert() ? img : nil];
            [_item setState:NSOnState];
        }
        else {
            [_item setImage:nil];
            [_item setState:NSOffState];
        }
    };
    
    NSInteger tag = [item tag];
    auto *contr = [self ActivePanelController];
    switch (tag)
    {
        case MenuTags::PanelViewShortMode: [item setState:[contr GetViewType] == PanelViewType::ViewShort  ? NSOnState : NSOffState]; break;
        case MenuTags::PanelViewMediumMode:[item setState:[contr GetViewType] == PanelViewType::ViewMedium ? NSOnState : NSOffState]; break;
        case MenuTags::PanelViewFullMode:  [item setState:[contr GetViewType] == PanelViewType::ViewFull   ? NSOnState : NSOffState]; break;
        case MenuTags::PanelViewWideMode:  [item setState:[contr GetViewType] == PanelViewType::ViewWide   ? NSOnState : NSOffState]; break;
        case MenuTags::PanelSortByName:  upd_for_sort(item, [contr GetUserSortMode], PanelSortMode::SortByNameMask); break;
        case MenuTags::PanelSortByExt:   upd_for_sort(item, [contr GetUserSortMode], PanelSortMode::SortByExtMask); break;
        case MenuTags::PanelSortByMTime: upd_for_sort(item, [contr GetUserSortMode], PanelSortMode::SortByMTimeMask); break;
        case MenuTags::PanelSortBySize:  upd_for_sort(item, [contr GetUserSortMode], PanelSortMode::SortBySizeMask); break;
        case MenuTags::PanelSortByBTime: upd_for_sort(item, [contr GetUserSortMode], PanelSortMode::SortByBTimeMask); break;
        case MenuTags::PanelSortViewHidden: [item setState:[contr GetUserSortMode].show_hidden ? NSOnState : NSOffState]; break;
        case MenuTags::PanelSortSepDirs:    [item setState:[contr GetUserSortMode].sep_dirs    ? NSOnState : NSOffState]; break;
        case MenuTags::PanelSortCaseSensitive:[item setState:[contr GetUserSortMode].case_sens ? NSOnState : NSOffState]; break;            
    }

    return true; // will disable some items in the future
}

- (void)RevealEntries:(FlexChainedStringsChunk*)_entries inPath:(const char*)_path
{
    assert(dispatch_get_current_queue() == dispatch_get_main_queue());

    PanelController *panel = [self ActivePanelController];
    if([panel GoToDirectorySync:_path])
    {   
        if(_entries->amount > 0)
            [panel ScheduleDelayedSelectionChangeForC:_entries->strings[0].str()
                                           timeoutms:100
                                             checknow:true];

        if(_entries->amount > 1)
        {
            PanelData *data = [self ActivePanelData];
            data->CustomFlagsSelectAll(false);
            
            for(auto &i: *_entries)
            {
                int idx = data->FindEntryIndex(i.str());
                if(idx>=0)
                {
                    if(data->FindSortedEntryIndex(idx) >= 0) // check if requested element is currently visible or we can get nice artifacts
                        data->CustomFlagsSelect(idx, true);
                }
            }
            [[self ActivePanelView] setNeedsDisplay:true];
        }
    }

    FlexChainedStringsChunk::FreeWithDescendants(&_entries);
}

// Quick Look panel support
- (BOOL)acceptsPreviewPanelControl:(QLPreviewPanel *)panel;
{
    return YES;
}

- (void)beginPreviewPanelControl:(QLPreviewPanel *)panel
{
    [QuickPreview UpdateData];
}

- (void)endPreviewPanelControl:(QLPreviewPanel *)panel
{
}

// forwarding requests to panels
- (void)selectAll:(id)sender
{
    if([self IsPanelActive])
       [[self ActivePanelController] SelectAllEntries:true];
}

- (void)deselectAll:(id)sender
{
    if([self IsPanelActive])
        [[self ActivePanelController] SelectAllEntries:false];
}

- (IBAction)OnFileBigFileViewCommand:(id)sender
{
    if([self IsPanelActive])
    {
        auto *i = [[self ActivePanelView] CurrentItem];
        if(i)
        {
            char tmp[MAXPATHLEN];
            [self ActivePanelData]->GetDirectoryPathWithTrailingSlash(tmp);
            strcat(tmp, i->namec());
            
            FileWindow *fw = new FileWindow;
            if(fw->OpenFile(tmp) == 0)
            {
                BigFileView *bfv = [[BigFileView alloc] initWithFrame: [[[self window] contentView] frame]];
                [bfv SetFile:fw];
                [[[self window] contentView] addSubview:bfv];
                [[self window] makeFirstResponder: bfv];
            }
            else
            {
                delete fw;
            }
        }
    }
}

@end

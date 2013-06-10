//
//  MainWindowFilePanelState.m
//  Files
//
//  Created by Michael G. Kazakov on 04.06.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "MainWindowFilePanelState.h"
#import "PanelController.h"
#import "Common.h"
#import "ApplicationSkins.h"
#import "AppDelegate.h"
#import "ClassicPanelViewPresentation.h"
#import "ModernPanelViewPresentation.h"
#import "MainWndGoToButton.h"
#import "OperationsController.h"
#import "OperationsSummaryViewController.h"
#import "FileSysAttrChangeOperation.h"
#import "FileSysEntryAttrSheetController.h"
#import "DetailedVolumeInformationSheetController.h"
#import "FlexChainedStringsChunk.h"
#import "FileDeletionSheetController.h"
#import "MassCopySheetController.h"
#import "FileCopyOperation.h"
#import "CreateDirectorySheetController.h"
#import "CreateDirectoryOperation.h"
#import "MessageBox.h"
#import "QuickPreview.h"
#import "MainWindowController.h"

enum ActiveState
{
    StateLeftPanel,
    StateRightPanel
    // many more will be here
};

@implementation MainWindowFilePanelState
{
    ApplicationSkin m_Skin;    
    
    ActiveState m_ActiveState;    
    
    PanelView *m_LeftPanelView;                 // creates and owns
    PanelData *m_LeftPanelData;                 // creates and owns
    PanelController *m_LeftPanelController;     // creates and owns

    PanelView *m_RightPanelView;                // creates and owns
    PanelData *m_RightPanelData;                // creates and owns
    PanelController *m_RightPanelController;    // creates and owns

    MainWndGoToButton *m_LeftPanelGoToButton;
    MainWndGoToButton *m_RightPanelGoToButton;

    NSProgressIndicator *m_LeftPanelSpinningIndicator;
    NSProgressIndicator *m_RightPanelSpinningIndicator;
    
    NSBox               *m_SheetAnchorLine;
    
//    @property (strong) IBOutlet NSProgressIndicator *LeftPanelSpinningIndicator;
//    @property (strong) IBOutlet NSProgressIndicator *RightPanelSpinningIndicator;
    
    NSView               *m_OpSummaryBox;
    OperationsController *m_OperationsController;
    OperationsSummaryViewController *m_OpSummaryController;

}

@synthesize OperationsController = m_OperationsController;

- (id) initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if(self)
    {
        [self Init];
    }
    return self;
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (void) Init
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    m_OperationsController = [[OperationsController alloc] init];
    m_OpSummaryController = [[OperationsSummaryViewController alloc] initWthController:m_OperationsController];
    
    [self CreateControls];
    [m_OpSummaryController AddViewTo:m_OpSummaryBox];
    
    
    // panel creation and preparation
    [self CreatePanels];
    [self UpdatePanelFrames];
    m_LeftPanelData = new PanelData;
    m_LeftPanelController = [PanelController new];
    [m_LeftPanelView SetPanelData:m_LeftPanelData];
    [m_LeftPanelView SetPanelController:m_LeftPanelController];
    [m_LeftPanelController SetView:m_LeftPanelView];
    [m_LeftPanelController SetData:m_LeftPanelData];
    [m_LeftPanelController AttachToIndicator:m_LeftPanelSpinningIndicator];
//    [m_LeftPanelController SetWindowController:self];
    m_RightPanelData = new PanelData;
    m_RightPanelController = [PanelController new];
    [m_RightPanelView SetPanelData:m_RightPanelData];
    [m_RightPanelView SetPanelController:m_RightPanelController];
    [m_RightPanelController SetView:m_RightPanelView];
    [m_RightPanelController SetData:m_RightPanelData];
    [m_RightPanelController AttachToIndicator:m_RightPanelSpinningIndicator];
//    [m_RightPanelController SetWindowController:self];
    [self ApplySkin: ((AppDelegate*)[NSApp delegate]).Skin];
    [self LoadPanelsSettings];
    
    // now load data into panels
    if( IsDirectoryAvailableForBrowsing([[defaults stringForKey:@"FirstPanelPath"] UTF8String]) )
        [m_LeftPanelController GoToDirectorySync:[[defaults stringForKey:@"FirstPanelPath"] UTF8String]];
    else
    {
        char path[MAXPATHLEN];
        if(GetUserHomeDirectoryPath(path) && IsDirectoryAvailableForBrowsing(path)) // if saved dir is invalid - try home directory
            [m_LeftPanelController GoToDirectorySync:path];
        else // if home directory is invalid to - go to root
            [m_LeftPanelController GoToDirectorySync:"/"];
    }
    
    if( IsDirectoryAvailableForBrowsing([[defaults stringForKey:@"SecondPanelPath"] UTF8String]) )
        [m_RightPanelController GoToDirectorySync:[[defaults stringForKey:@"SecondPanelPath"] UTF8String]];
    else
        [m_RightPanelController GoToDirectorySync:"/"];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(frameDidChange)
                                                 name:NSViewFrameDidChangeNotification
                                               object:self];
    
    m_ActiveState = StateLeftPanel;
    [m_LeftPanelView Activate];
}

- (void)frameDidChange
{
    [self UpdatePanelFrames];
    
}

- (void)CreatePanels
{
    m_LeftPanelView = [[PanelView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
    [self addSubview:m_LeftPanelView positioned:NSWindowBelow relativeTo:nil];
    
    m_RightPanelView = [[PanelView alloc] initWithFrame:NSMakeRect(100, 100, 100, 100)];
    [self  addSubview:m_RightPanelView positioned:NSWindowBelow relativeTo:nil];
}

- (void) CreateControls
{
    m_LeftPanelGoToButton = [[MainWndGoToButton alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
    [m_LeftPanelGoToButton setTarget:self];
    [m_LeftPanelGoToButton setAction:@selector(LeftPanelGoToButtonAction:)];
    [m_LeftPanelGoToButton setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self addSubview:m_LeftPanelGoToButton];

    m_RightPanelGoToButton = [[MainWndGoToButton alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
    [m_RightPanelGoToButton setTarget:self];
    [m_RightPanelGoToButton setAction:@selector(RightPanelGoToButtonAction:)];
    [m_RightPanelGoToButton setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self addSubview:m_RightPanelGoToButton];

    m_LeftPanelSpinningIndicator = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
    [m_LeftPanelSpinningIndicator setIndeterminate:YES];
    [m_LeftPanelSpinningIndicator setStyle:NSProgressIndicatorSpinningStyle];
    [m_LeftPanelSpinningIndicator setTranslatesAutoresizingMaskIntoConstraints:NO];
    [m_LeftPanelSpinningIndicator setControlSize:NSSmallControlSize];
    [m_LeftPanelSpinningIndicator setDisplayedWhenStopped:NO];
    [self addSubview:m_LeftPanelSpinningIndicator];

    m_RightPanelSpinningIndicator = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
    [m_RightPanelSpinningIndicator setIndeterminate:YES];
    [m_RightPanelSpinningIndicator setStyle:NSProgressIndicatorSpinningStyle];
    [m_RightPanelSpinningIndicator setTranslatesAutoresizingMaskIntoConstraints:NO];
    [m_RightPanelSpinningIndicator setControlSize:NSSmallControlSize];
    [m_RightPanelSpinningIndicator setDisplayedWhenStopped:NO];
    [self addSubview:m_RightPanelSpinningIndicator];
        
    m_OpSummaryBox = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 350, 40)];
    [m_OpSummaryBox setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self addSubview:m_OpSummaryBox];
    
    m_SheetAnchorLine = [[NSBox alloc] initWithFrame:NSRect()];
    [m_SheetAnchorLine setTranslatesAutoresizingMaskIntoConstraints:NO];
    [m_SheetAnchorLine setBoxType:NSBoxSeparator];
    [self addSubview:m_SheetAnchorLine];
    
    NSDictionary *views = NSDictionaryOfVariableBindings(m_LeftPanelGoToButton, m_RightPanelGoToButton, m_LeftPanelSpinningIndicator,
            m_RightPanelSpinningIndicator, m_OpSummaryBox, m_SheetAnchorLine);

    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(==0)-[m_SheetAnchorLine]-(==0)-|" options:0 metrics:nil views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(==44)-[m_SheetAnchorLine(<=1)]" options:0 metrics:nil views:views]];    
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-[m_LeftPanelGoToButton(61)]-[m_LeftPanelSpinningIndicator(16)]" options:0 metrics:nil views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-[m_LeftPanelGoToButton(22)]" options:0 metrics:nil views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-[m_LeftPanelSpinningIndicator(16)]" options:0 metrics:nil views:views]];
    
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"[m_RightPanelSpinningIndicator(16)]-[m_RightPanelGoToButton(61)]-|" options:0 metrics:nil views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-[m_RightPanelGoToButton(22)]" options:0 metrics:nil views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-[m_RightPanelSpinningIndicator(16)]" options:0 metrics:nil views:views]];    
    
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(1)-[m_OpSummaryBox(40)]" options:0 metrics:nil views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"[m_OpSummaryBox(350)]" options:0 metrics:nil views:views]];    
    [self addConstraint: [NSLayoutConstraint constraintWithItem:m_OpSummaryBox
                                                      attribute:NSLayoutAttributeCenterX
                                                      relatedBy:NSLayoutRelationEqual
                                                         toItem:m_OpSummaryBox.superview
                                                      attribute:NSLayoutAttributeCenterX
                                                     multiplier:1.f constant:0.f]];
}

- (void)UpdatePanelFrames
{
    // Make panels fill content view, excluding top gap.
    // Make sure that x and width are integers.
//    NSSize frameSize = [self.window contentRectForFrameRect:self.window.frame].size;
    NSSize frameSize = [self frame].size;
    
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

- (NSView*) ContentView
{
    return self;
}

- (void) Assigned
{
    [self UpdateTitle];
}

- (void) Resigned
{
}

- (IBAction)LeftPanelGoToButtonAction:(id)sender{
    [m_LeftPanelController GoToDirectory:[[m_LeftPanelGoToButton GetCurrentSelectionPath] UTF8String]];
}

- (IBAction)RightPanelGoToButtonAction:(id)sender{
    [m_RightPanelController GoToDirectory:[[m_RightPanelGoToButton GetCurrentSelectionPath] UTF8String]];
}

- (IBAction)LeftPanelGoto:(id)sender{
    [m_LeftPanelGoToButton performClick:self];
}

- (IBAction)RightPanelGoto:(id)sender{
    [m_RightPanelGoToButton performClick:self];
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

- (void) UpdateTitle
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
    window.title = StringByTruncatingToWidth(path, titleWidth, kTruncateAtStart, attributes);
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
    };
    
    switch (keycode)
    {
/*        case 17: // t button on keyboard
        {
            if(ISMODIFIER(NSCommandKeyMask|NSAlternateKeyMask|NSControlKeyMask|NSShiftKeyMask))
            {
                [m_OperationsController AddOperation:
                 [[TimedDummyOperation alloc] initWithTime:(1 + rand()%10)]];
            }
            break;
        }*/
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
    
    [m_LeftPanelController AttachToIndicator:m_LeftPanelSpinningIndicator];
    [m_RightPanelController AttachToIndicator:m_RightPanelSpinningIndicator];
    
    [self SavePanelsSettings];
}

- (IBAction)OnRefreshPanel:(id)sender{
    assert([self IsPanelActive]);
    [[self ActivePanelController] RefreshDirectory];
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

- (void) FireDirectoryChanged: (const char*) _dir ticket:(unsigned long)_ticket
{
    [m_LeftPanelController FireDirectoryChanged:_dir ticket:_ticket];
    [m_RightPanelController FireDirectoryChanged:_dir ticket:_ticket];
}

- (void)PanelPathChanged:(PanelController*)_panel
{
    if(_panel == [self ActivePanelController])
        [self UpdateTitle];
     
    if(_panel == m_LeftPanelController)
    {
        char tmp[MAXPATHLEN];
        m_LeftPanelData->GetDirectoryPathWithTrailingSlash(tmp);
        [m_LeftPanelGoToButton SetCurrentPath:tmp];
    }
    if(_panel == m_RightPanelController)
    {
        char tmp[MAXPATHLEN];
        m_RightPanelData->GetDirectoryPathWithTrailingSlash(tmp);
        [m_RightPanelGoToButton SetCurrentPath:tmp];
    }
}

- (void) DidBecomeKeyWindow
{
    // update key modifiers state for views
    unsigned long flags = [NSEvent modifierFlags];
    [m_LeftPanelController ModifierFlagsChanged:flags];
    [m_RightPanelController ModifierFlagsChanged:flags];

    if ([QuickPreview IsVisible])
        [[self ActivePanelView] UpdateQuickPreview];
}

- (void)SkinSettingsChanged
{
    [m_LeftPanelView OnSkinSettingsChanged];
    [m_RightPanelView OnSkinSettingsChanged];
}

- (void)WindowDidResize
{
    [self UpdatePanelFrames];
    [m_OpSummaryController OnWindowResize];
    [self UpdateTitle];
}

- (void)WindowWillClose
{
   [self SavePanelPaths];
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

- (bool)WindowShouldClose:(id)sender
{
    if (m_OperationsController.OperationsCount == 0)
        return true;
    
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
    
    return false;
}

- (IBAction)OnFileInternalBigViewCommand:(id)sender
{
    if([self IsPanelActive])
    {
        auto *i = [[self ActivePanelView] CurrentItem];
        if(i)
        {
            char tmp[MAXPATHLEN];
            [self ActivePanelData]->GetDirectoryPathWithTrailingSlash(tmp);
            strcat(tmp, i->namec());
            [(MainWindowController*)[[self window] delegate] RequestBigFileView:tmp];
        }
    }
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

- (void)WindowWillBeginSheet
{
    [m_OpSummaryController OnWindowBeginSheet];
}

- (void)WindowDidEndSheet
{
    [m_OpSummaryController OnWindowEndSheet];
}

@end

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
#import "FileLinkNewSymlinkSheetController.h"
#import "FileLinkAlterSymlinkSheetController.h"
#import "FileLinkNewHardlinkSheetController.h"
#import "FileLinkOperation.h"
#import "StackOfDisappearingWidgets.h"
#import "SelectionWithMaskSheetController.h"

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
    NSButton            *m_LeftPanelEjectButton;
    NSButton            *m_RightPanelEjectButton;

    StackOfDisappearingWidgets *m_LeftStack;
    StackOfDisappearingWidgets *m_RightStack;
    
    NSBox               *m_SheetAnchorLine;
        
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

- (void) dealloc
{
    [m_LeftPanelView SetPanelData:0];
    [m_LeftPanelView SetPanelController:0];
    [m_LeftPanelController SetData:0];
    [m_LeftPanelController SetView:0];
    delete m_LeftPanelData;
    
    [m_RightPanelView SetPanelData:0];
    [m_RightPanelView SetPanelController:0];
    [m_RightPanelController SetData:0];
    [m_RightPanelController SetView:0];
    delete m_RightPanelData;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) Init
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    m_OperationsController = [[OperationsController alloc] init];
    m_OpSummaryController = [[OperationsSummaryViewController alloc] initWthController:m_OperationsController];
    
    [self CreateControls];
    [m_OpSummaryController AddViewTo:m_OpSummaryBox];
    
    // panel creation and preparation
    m_LeftPanelData = new PanelData;
    m_LeftPanelController = [PanelController new];
    [m_LeftPanelView SetPanelData:m_LeftPanelData];
    [m_LeftPanelView SetPanelController:m_LeftPanelController];
    [m_LeftPanelController SetView:m_LeftPanelView];
    [m_LeftPanelController SetData:m_LeftPanelData];
    [m_LeftPanelController AttachToControls:m_LeftPanelSpinningIndicator eject:m_LeftPanelEjectButton];
    
    m_RightPanelData = new PanelData;
    m_RightPanelController = [PanelController new];
    [m_RightPanelView SetPanelData:m_RightPanelData];
    [m_RightPanelView SetPanelController:m_RightPanelController];
    [m_RightPanelController SetView:m_RightPanelView];
    [m_RightPanelController SetData:m_RightPanelData];
    [m_RightPanelController AttachToControls:m_RightPanelSpinningIndicator eject:m_RightPanelEjectButton];

    m_Skin = ((AppDelegate*)[NSApp delegate]).Skin;
    if (m_Skin == ApplicationSkin::Modern)
    {
        [m_LeftPanelView SetPresentation:new ModernPanelViewPresentation];
        [m_RightPanelView SetPresentation:new ModernPanelViewPresentation];
    }
    else if (m_Skin == ApplicationSkin::Classic)
    {
        [m_LeftPanelView SetPresentation:new ClassicPanelViewPresentation];
        [m_RightPanelView SetPresentation:new ClassicPanelViewPresentation];
    }
    [self UpdatePanelFrames];
    
    [self LoadPanelsSettings];
    
    // now load data into panels
    if([m_LeftPanelController GoToGlobalHostsPathSync:[[defaults stringForKey:@"FirstPanelPath"] fileSystemRepresentation]] < 0)
    { // if saved dir is invalid - try home directory
        char path[MAXPATHLEN];
        if(!GetUserHomeDirectoryPath(path) || [m_LeftPanelController GoToGlobalHostsPathSync:path] < 0)
        {
            int ret = [m_LeftPanelController GoToRelativeToHostSync:"/"]; // if home directory is invalid too (lolwhat?) - go to root
            assert(ret == VFSError::Ok);
        }
    }
    
    if([m_RightPanelController GoToGlobalHostsPathSync:[[defaults stringForKey:@"SecondPanelPath"] fileSystemRepresentation]] < 0)
    {
        int ret = [m_RightPanelController GoToGlobalHostsPathSync:"/"];
        assert(ret == VFSError::Ok);
    }
    
    
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

- (void) CreateControls
{
    m_LeftPanelView = [[PanelView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
    [self addSubview:m_LeftPanelView positioned:NSWindowBelow relativeTo:nil];
    
    m_RightPanelView = [[PanelView alloc] initWithFrame:NSMakeRect(100, 100, 100, 100)];
    [self  addSubview:m_RightPanelView positioned:NSWindowBelow relativeTo:nil];
    
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

    m_LeftPanelSpinningIndicator = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(0, 0, 16, 16)];
    [m_LeftPanelSpinningIndicator setIndeterminate:YES];
    [m_LeftPanelSpinningIndicator setStyle:NSProgressIndicatorSpinningStyle];
    [m_LeftPanelSpinningIndicator setTranslatesAutoresizingMaskIntoConstraints:NO];
    [m_LeftPanelSpinningIndicator setControlSize:NSSmallControlSize];
    [m_LeftPanelSpinningIndicator setDisplayedWhenStopped:NO];
    [self addSubview:m_LeftPanelSpinningIndicator];

    m_RightPanelSpinningIndicator = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(0, 0, 16, 16)];
    [m_RightPanelSpinningIndicator setIndeterminate:YES];
    [m_RightPanelSpinningIndicator setStyle:NSProgressIndicatorSpinningStyle];
    [m_RightPanelSpinningIndicator setTranslatesAutoresizingMaskIntoConstraints:NO];
    [m_RightPanelSpinningIndicator setControlSize:NSSmallControlSize];
    [m_RightPanelSpinningIndicator setDisplayedWhenStopped:NO];
    [self addSubview:m_RightPanelSpinningIndicator];
    
    NSImage *eject_icon = [NSImage imageNamed:@"eject_icon.png"];
    [eject_icon setTemplate:true];
    
    m_LeftPanelEjectButton = [[NSButton alloc] initWithFrame:NSRect()];
    [m_LeftPanelEjectButton setTranslatesAutoresizingMaskIntoConstraints:NO];
    [m_LeftPanelEjectButton setImagePosition:NSImageOnly];
    [m_LeftPanelEjectButton setImage:eject_icon];
    [m_LeftPanelEjectButton setShowsBorderOnlyWhileMouseInside:YES];
    [m_LeftPanelEjectButton setBezelStyle:NSRecessedBezelStyle];
    [self addSubview:m_LeftPanelEjectButton];

    m_RightPanelEjectButton = [[NSButton alloc] initWithFrame:NSRect()];
    [m_RightPanelEjectButton setTranslatesAutoresizingMaskIntoConstraints:NO];
    [m_RightPanelEjectButton setImagePosition:NSImageOnly];
    [m_RightPanelEjectButton setImage:eject_icon];
    [m_RightPanelEjectButton setShowsBorderOnlyWhileMouseInside:YES];
    [m_RightPanelEjectButton setBezelStyle:NSRecessedBezelStyle];
    [self addSubview:m_RightPanelEjectButton];
    
    m_OpSummaryBox = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 350, 40)];
    [m_OpSummaryBox setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self addSubview:m_OpSummaryBox];
    
    m_SheetAnchorLine = [[NSBox alloc] initWithFrame:NSRect()];
    [m_SheetAnchorLine setTranslatesAutoresizingMaskIntoConstraints:NO];
    [m_SheetAnchorLine setBoxType:NSBoxSeparator];
    [self addSubview:m_SheetAnchorLine];
    
    NSDictionary *views = NSDictionaryOfVariableBindings(m_LeftPanelGoToButton, m_RightPanelGoToButton, m_OpSummaryBox, m_SheetAnchorLine);
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(==0)-[m_SheetAnchorLine]-(==0)-|" options:0 metrics:nil views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(==44)-[m_SheetAnchorLine(<=1)]" options:0 metrics:nil views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(10)-[m_LeftPanelGoToButton(61)]" options:NSLayoutFormatAlignAllCenterY metrics:nil views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(10)-[m_LeftPanelGoToButton(22)]" options:0 metrics:nil views:views]];

    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"[m_RightPanelGoToButton(61)]-(10)-|" options:NSLayoutFormatAlignAllCenterY metrics:nil views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(10)-[m_RightPanelGoToButton(22)]" options:0 metrics:nil views:views]];
    
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(1)-[m_OpSummaryBox(40)]" options:0 metrics:nil views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"[m_OpSummaryBox(350)]" options:0 metrics:nil views:views]];    
    [self addConstraint: [NSLayoutConstraint constraintWithItem:m_OpSummaryBox
                                                      attribute:NSLayoutAttributeCenterX
                                                      relatedBy:NSLayoutRelationEqual
                                                         toItem:m_OpSummaryBox.superview
                                                      attribute:NSLayoutAttributeCenterX
                                                     multiplier:1.f constant:0.f]];
    
    m_LeftStack = [[StackOfDisappearingWidgets alloc] initWithOrientation:StackOfDisappearingWidgetsOrientation::LeftToRight
                                                               AnchorView:m_LeftPanelGoToButton
                                                                SuperView:self];
    [m_LeftStack AddWidget:m_LeftPanelEjectButton];
    [m_LeftStack AddWidget:m_LeftPanelSpinningIndicator];
    [m_LeftStack Done];
    
    m_RightStack = [[StackOfDisappearingWidgets alloc] initWithOrientation:StackOfDisappearingWidgetsOrientation::RightToLeft
                                                               AnchorView:m_RightPanelGoToButton
                                                                SuperView:self];
    [m_RightStack AddWidget:m_RightPanelEjectButton];
    [m_RightStack AddWidget:m_RightPanelSpinningIndicator];
    [m_RightStack Done];
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
    // to cut reference cycle
    m_LeftStack = nil;
    m_RightStack = nil;
}

- (IBAction)LeftPanelGoToButtonAction:(id)sender{
    // TODO: some GoToGlobal should be here
    [m_LeftPanelController GoToRelativeToHostAsync:[[m_LeftPanelGoToButton GetCurrentSelectionPath] fileSystemRepresentation]];
}

- (IBAction)RightPanelGoToButtonAction:(id)sender{
    // TODO: some GoToGlobal should be here
    [m_RightPanelController GoToRelativeToHostAsync:[[m_RightPanelGoToButton GetCurrentSelectionPath] fileSystemRepresentation]];
}

- (IBAction)LeftPanelGoto:(id)sender{
    [m_LeftPanelGoToButton performClick:self];
}

- (IBAction)RightPanelGoto:(id)sender{
    [m_RightPanelGoToButton performClick:self];
}

- (void)ApplySkin:(ApplicationSkin)_skin
{
    if(m_Skin == _skin)
        return;

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
    char path_raw[MAXPATHLEN*8];
    
    [self ActivePanelData]->GetDirectoryFullHostsPathWithTrailingSlash(path_raw);
//    [[self ActivePanelController] ComposeFullHostsPath:path_raw];
    
    NSString *path = [NSString stringWithUTF8String:path_raw];
    if(path == nil)
    {
        [self window].title = @"...";
        return;
    }
    
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
    
    if([self IsPanelActive])
        [[self ActivePanelController] keyDown:event];
    
    if(unicode == NSTabCharacter) // TAB key
        [self HandleTabButton];
}

- (void)LoadPanelsSettings
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [m_LeftPanelController LoadViewState:[defaults dictionaryForKey:@"FilePanelsLeftPanelViewState"]];
    [m_RightPanelController LoadViewState:[defaults dictionaryForKey:@"FilePanelsRightPanelViewState"]];
}

- (void)SavePanelsSettings
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[m_LeftPanelController SaveViewState] forKey:@"FilePanelsLeftPanelViewState"];
    [defaults setObject:[m_RightPanelController SaveViewState] forKey:@"FilePanelsRightPanelViewState"];
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

- (IBAction)ToggleNumericComparison:(id)sender{
    [[self ActivePanelController] ToggleNumericComparison];
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
        [m_RightPanelController GoToRelativeToHostAsync:dirpath];
    }
    else
    {
        m_RightPanelData->GetDirectoryPathWithTrailingSlash(dirpath);
        [m_LeftPanelController GoToRelativeToHostAsync:dirpath];
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
    
    [m_LeftPanelController AttachToControls:m_LeftPanelSpinningIndicator eject:m_LeftPanelEjectButton];
    [m_RightPanelController AttachToControls:m_RightPanelSpinningIndicator eject:m_RightPanelEjectButton];
    
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
            if(!curdata->EntryAtRawPosition(rawpos).IsDotDot())
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
        case MenuTags::PanelSortNumeric:    [item setState:[contr GetUserSortMode].numeric_sort ? NSOnState : NSOffState]; break;
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
        if(item && !item->IsDotDot())
            files = FlexChainedStringsChunk::AllocateWithSingleString(item->Name());
    }
    
    if(!files)
        return;
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    FileDeletionOperationType type = (FileDeletionOperationType)(_shift_behavior
                                                                 ? [defaults integerForKey:@"FilePanelsShiftDeleteBehavior"]
                                                                 : [defaults integerForKey:@"FilePanelsDeleteBehavior"]);
    
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

- (IBAction)OnAlternativeDeleteCommand:(id)sender
{
    [self DeleteFiles:YES];
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
             
             [m_OperationsController AddOperation:[[CreateDirectoryOperation alloc] initWithPath:[[cd.TextField stringValue] fileSystemRepresentation]
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
        if(item && !item->IsDotDot())
            files = FlexChainedStringsChunk::AllocateWithSingleString(item->Name());
    }
    
    if(!files)
        return;
    
    char dest_path[MAXPATHLEN];
    destination->GetDirectoryPathWithTrailingSlash(dest_path);
    NSString *nsdirpath = [NSString stringWithUTF8String:dest_path];
    MassCopySheetController *mc = [MassCopySheetController new];
    [mc ShowSheet:[self window] initpath:nsdirpath iscopying:true items:files handler:^(int _ret)
     {
         if(_ret == DialogResult::Copy)
         {
             char root_path[MAXPATHLEN];
             source->GetDirectoryPathWithTrailingSlash(root_path);
             
             FileCopyOperationOptions opts;
             opts.docopy = true;
             [mc FillOptions:&opts];
             
             [m_OperationsController AddOperation:
              [[FileCopyOperation alloc] initWithFiles:files root:root_path dest:[[mc.TextField stringValue] fileSystemRepresentation] options:&opts]];
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
    if(item->IsDotDot())
        return;
    
    __block FlexChainedStringsChunk *files = FlexChainedStringsChunk::AllocateWithSingleString(item->Name());
    
    MassCopySheetController *mc = [MassCopySheetController new];
    [mc ShowSheet:[self window] initpath:[NSString stringWithUTF8String:item->Name()] iscopying:true items:files handler:^(int _ret)
     {
         if(_ret == DialogResult::Copy)
         {
             char root_path[MAXPATHLEN];
             [self ActivePanelData]->GetDirectoryPathWithTrailingSlash(root_path);
             FileCopyOperationOptions opts;
             opts.docopy = true;
             [mc FillOptions:&opts];
             
             [m_OperationsController AddOperation:
              [[FileCopyOperation alloc] initWithFiles:files
                                                  root:root_path
                                                  dest:[[mc.TextField stringValue] fileSystemRepresentation]
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
        if(item && !item->IsDotDot())
            files = FlexChainedStringsChunk::AllocateWithSingleString(item->Name());
    }
    
    if(!files)
        return;
    
    char dest_path[MAXPATHLEN];
    destination->GetDirectoryPathWithTrailingSlash(dest_path);
    NSString *nsdirpath = [NSString stringWithUTF8String:dest_path];
    
    MassCopySheetController *mc = [MassCopySheetController new];
    [mc ShowSheet:[self window] initpath:nsdirpath iscopying:false items:files handler:^(int _ret)
     {
         if(_ret == DialogResult::Copy)
         {
             char root_path[MAXPATHLEN];
             source->GetDirectoryPathWithTrailingSlash(root_path);
             
             FileCopyOperationOptions opts;
             opts.docopy = false;
             [mc FillOptions:&opts];
             
             [m_OperationsController AddOperation:
              [[FileCopyOperation alloc] initWithFiles:files root:root_path dest:[[mc.TextField stringValue] fileSystemRepresentation] options:&opts]];
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
    if(item->IsDotDot())
        return;
    
    __block FlexChainedStringsChunk *files = FlexChainedStringsChunk::AllocateWithSingleString(item->Name());
    
    MassCopySheetController *mc = [MassCopySheetController new];
    [mc ShowSheet:[self window] initpath:[NSString stringWithUTF8String:item->Name()] iscopying:false items:files handler:^(int _ret)
     {
         if(_ret == DialogResult::Copy)
         {
             char root_path[MAXPATHLEN];
             [self ActivePanelData]->GetDirectoryPathWithTrailingSlash(root_path);
             FileCopyOperationOptions opts;
             opts.docopy = false;
             [mc FillOptions:&opts];
             
             [m_OperationsController AddOperation:
              [[FileCopyOperation alloc] initWithFiles:files
                                                  root:root_path
                                                  dest:[[mc.TextField stringValue] fileSystemRepresentation]
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
    char path[MAXPATHLEN*8];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
     
//    m_LeftPanelData->GetDirectoryPathWithTrailingSlash(path);
    m_LeftPanelData->GetDirectoryFullHostsPathWithTrailingSlash(path);
    [defaults setObject:[NSString stringWithUTF8String:path] forKey:@"FirstPanelPath"];
     
//    m_RightPanelData->GetDirectoryPathWithTrailingSlash(path);
    m_RightPanelData->GetDirectoryFullHostsPathWithTrailingSlash(path);
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
            strcat(tmp, i->Name());
            [(MainWindowController*)[[self window] delegate] RequestBigFileView:tmp
             with_fs:[self ActivePanelData]->DirectoryEntries().Host()];
        }
    }
}


- (void)RevealEntries:(FlexChainedStringsChunk*)_entries inPath:(const char*)_path
{
    assert(dispatch_get_current_queue() == dispatch_get_main_queue());
    
    PanelController *panel = [self ActivePanelController];
    if([panel GoToRelativeToHostSync:_path])
    {
        if(_entries->Amount() > 0)
            [panel ScheduleDelayedSelectionChangeForC:(*_entries)[0].str()
                                            timeoutms:100
                                             checknow:true];
        
        if(_entries->Amount() > 1)
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

- (NSRect)window:(NSWindow *)window willPositionSheet:(NSWindow *)sheet usingRect:(NSRect)rect
{
    // TODO: refactor me (?)
    NSRect field_rect = [m_SheetAnchorLine frame];
    field_rect.origin.y += 2;
    field_rect.size.height = 0;
    return field_rect;
}

- (void)OnApplicationWillTerminate
{
    [self SavePanelPaths];
}

- (IBAction)OnCreateSymbolicLinkCommand:(id)sender
{
    assert([self IsPanelActive]);
    
    char source_path[MAXPATHLEN];
    char link_path[MAXPATHLEN];
    auto const *item = [[self ActivePanelView] CurrentItem];
    if(!item)
        return;
    
    [self ActivePanelData]->GetDirectoryPathWithTrailingSlash(source_path);
    if(!item->IsDotDot())
        strcat(source_path, item->Name());
    
    if(m_ActiveState == StateLeftPanel)
        m_RightPanelData->GetDirectoryPathWithTrailingSlash(link_path);
    else
        m_LeftPanelData->GetDirectoryPathWithTrailingSlash(link_path);
    
    if(!item->IsDotDot())
        strcat(link_path, item->Name());
    else
    {
        char tmp[256];
        [self ActivePanelData]->GetDirectoryPathShort(tmp);
        strcat(link_path, tmp);
    }

    FileLinkNewSymlinkSheetController *sheet = [FileLinkNewSymlinkSheetController new];
    [sheet ShowSheet:[self window]
          sourcepath:[NSString stringWithUTF8String:source_path]
            linkpath:[NSString stringWithUTF8String:link_path]
             handler:^(int result){
                 if(result == DialogResult::Create && [[sheet.LinkPath stringValue] length] > 0)
                     [m_OperationsController AddOperation:
                      [[FileLinkOperation alloc] initWithNewSymbolinkLink:[[sheet.SourcePath stringValue] fileSystemRepresentation]
                                                                 linkname:[[sheet.LinkPath stringValue] fileSystemRepresentation]
                       ]
                      ];
             }];
}

- (IBAction)OnEditSymbolicLinkCommand:(id)sender
{
    assert([self IsPanelActive]);
    
    char link_path[MAXPATHLEN];
    auto const *item = [[self ActivePanelView] CurrentItem];
    if(!item)
        return;
    if(item->IsDotDot())
        return;
    if(item->IsSymlink())
    {
        NSAlert *alert = [NSAlert new];
        [alert setMessageText: @"Failed to edit"];
        [alert setInformativeText:
         [NSString stringWithFormat:@"\'%@\' is not a symbolic link.", (__bridge NSString*)item->CFName()]];
        [alert runModal];
        return;
    }
    
    [self ActivePanelData]->GetDirectoryPathWithTrailingSlash(link_path);
    strcat(link_path, item->Name());
    NSString *linkpath = [NSString stringWithUTF8String:link_path];
    
    FileLinkAlterSymlinkSheetController *sheet = [FileLinkAlterSymlinkSheetController new];
    [sheet ShowSheet:[self window]
          sourcepath:[NSString stringWithUTF8String:item->Symlink()]
            linkname:[NSString stringWithUTF8String:item->Name()]
             handler:^(int _result){
                 if(_result == DialogResult::OK)
                 {
                     [m_OperationsController AddOperation:
                      [[FileLinkOperation alloc] initWithAlteringOfSymbolicLink:[[sheet.SourcePath stringValue] fileSystemRepresentation]
                                                                      linkname:[linkpath fileSystemRepresentation]]
                      ];
                 }
             }];
}

- (IBAction)OnCreateHardLinkCommand:(id)sender
{
    assert([self IsPanelActive]);
    
    auto const *item = [[self ActivePanelView] CurrentItem];
    if(!item)
        return;
    if(item->IsDotDot())
        return;
    if(item->IsDir())
    {
        NSAlert *alert = [NSAlert new];
        [alert setMessageText: @"Can't create a hardlink"];
        [alert setInformativeText: @"Hardlinks to directories are not supported."];
        [alert runModal];
        return;
    }
    
    char dir_path[MAXPATHLEN], src_path[MAXPATHLEN];
    [self ActivePanelData]->GetDirectoryPathWithTrailingSlash(dir_path);
    strcpy(src_path, dir_path);
    strcat(src_path, item->Name());
    NSString *srcpath = [NSString stringWithUTF8String:src_path];
    NSString *dirpath = [NSString stringWithUTF8String:dir_path];
    
    FileLinkNewHardlinkSheetController *sheet = [FileLinkNewHardlinkSheetController new];
    [sheet ShowSheet:[self window]
          sourcename:[NSString stringWithUTF8String:item->Name()]
             handler:^(int _result){
                 if(_result == DialogResult::Create)
                 {
                     NSString *name = [sheet.LinkName stringValue];
                     if([name length] == 0) return;
                     
                     if([name fileSystemRepresentation][0] != '/')
                         name = [NSString stringWithFormat:@"%@%@", dirpath, name];
                     
                    [m_OperationsController AddOperation:
                        [[FileLinkOperation alloc] initWithNewHardLink:[srcpath fileSystemRepresentation]
                                                              linkname:[name fileSystemRepresentation]]
                        ];
                 }                 
             }];
}

- (IBAction)OnSelectByMask:(id)sender
{
    SelectionWithMaskSheetController *sheet = [SelectionWithMaskSheetController new];
    [sheet ShowSheet:[self window]
             handler:^(int result) {
                 if(result == DialogResult::OK) {
                     NSString *mask = [sheet Mask];
                     [[self ActivePanelController] SelectEntriesByMask:mask select:true];
                 }
             }];
}

- (IBAction)OnDeselectByMask:(id)sender
{
    SelectionWithMaskSheetController *sheet = [SelectionWithMaskSheetController new];
    [sheet SetIsDeselect:true];
    [sheet ShowSheet:[self window]
             handler:^(int result) {
                 if(result == DialogResult::OK) {
                     NSString *mask = [sheet Mask];
                     [[self ActivePanelController] SelectEntriesByMask:mask select:false];
                 }
             }];
}

@end

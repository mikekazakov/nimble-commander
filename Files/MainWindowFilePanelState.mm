//
//  MainWindowFilePanelState.m
//  Files
//
//  Created by Michael G. Kazakov on 04.06.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "MainWindowFilePanelState.h"
#import "PanelController.h"
#import "PanelController+DataAccess.h"
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
#import "chained_strings.h"
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
#import "VFS.h"
#import "FilePanelMainSplitView.h"
#import "BriefSystemOverview.h"
#import "sysinfo.h"
#import "FileCompressOperation.h"
#import "LSUrls.h"

@implementation MainWindowFilePanelState

@synthesize OperationsController = m_OperationsController;

- (id) initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if(self)
        [self Init];
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
    
    m_LeftPanelController = [PanelController new];
    m_RightPanelController = [PanelController new];
    
    [self CreateControls];
    [m_OpSummaryController AddViewTo:m_OpSummaryBox];
    
    // panel creation and preparation
    m_LeftPanelController.state = self;
    [m_LeftPanelController AttachToControls:m_LeftPanelSpinningIndicator eject:m_LeftPanelEjectButton share:m_LeftPanelShareButton];

    m_RightPanelController.state = self;
    [m_RightPanelController AttachToControls:m_RightPanelSpinningIndicator eject:m_RightPanelEjectButton share:m_RightPanelShareButton];

    m_Skin = ((AppDelegate*)[NSApplication sharedApplication].delegate).Skin;
    if (m_Skin == ApplicationSkin::Modern)
    {
        [m_LeftPanelController.View SetPresentation:new ModernPanelViewPresentation];
        [m_RightPanelController.View SetPresentation:new ModernPanelViewPresentation];
    }
    else if (m_Skin == ApplicationSkin::Classic)
    {
        [m_LeftPanelController.View SetPresentation:new ClassicPanelViewPresentation];
        [m_RightPanelController.View SetPresentation:new ClassicPanelViewPresentation];
    }
    
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
        
    m_ActiveState = StateLeftPanel;
    [m_LeftPanelController.View Activate];
}

- (void) CreateControls
{
    m_MainSplitView = [[FilePanelMainSplitView alloc] initWithFrame:NSRect()];
    [m_MainSplitView setTranslatesAutoresizingMaskIntoConstraints:NO];
    [m_MainSplitView SetBasicViews:m_LeftPanelController.View second:m_RightPanelController.View];
    [self addSubview:m_MainSplitView];    
    
    m_LeftPanelGoToButton = [[MainWndGoToButton alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
    [m_LeftPanelGoToButton setTarget:self];
    [m_LeftPanelGoToButton setAction:@selector(LeftPanelGoToButtonAction:)];
    [m_LeftPanelGoToButton setTranslatesAutoresizingMaskIntoConstraints:NO];
    [m_LeftPanelGoToButton SetOwner:self];
    [self addSubview:m_LeftPanelGoToButton];

    m_RightPanelGoToButton = [[MainWndGoToButton alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
    [m_RightPanelGoToButton setTarget:self];
    [m_RightPanelGoToButton setAction:@selector(RightPanelGoToButtonAction:)];
    [m_RightPanelGoToButton setTranslatesAutoresizingMaskIntoConstraints:NO];
    [m_RightPanelGoToButton SetOwner:self];
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
    
    if(sysinfo::GetOSXVersion() >= sysinfo::OSXVersion::OSX_8)
    {
        m_LeftPanelShareButton = [[NSButton alloc] initWithFrame:NSRect()];
        [m_LeftPanelShareButton setTranslatesAutoresizingMaskIntoConstraints:NO];
        [m_LeftPanelShareButton setBezelStyle:NSTexturedRoundedBezelStyle];
        [m_LeftPanelShareButton setImage:[NSImage imageNamed:NSImageNameShareTemplate]];
        [m_LeftPanelShareButton sendActionOn:NSLeftMouseDownMask];
        [self addSubview:m_LeftPanelShareButton];

        m_RightPanelShareButton = [[NSButton alloc] initWithFrame:NSRect()];
        [m_RightPanelShareButton setTranslatesAutoresizingMaskIntoConstraints:NO];
        [m_RightPanelShareButton setBezelStyle:NSTexturedRoundedBezelStyle];
        [m_RightPanelShareButton setImage:[NSImage imageNamed:NSImageNameShareTemplate]];
        [m_RightPanelShareButton sendActionOn:NSLeftMouseDownMask];
        [self addSubview:m_RightPanelShareButton];
    }
    
    m_OpSummaryBox = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 350, 40)];
    [m_OpSummaryBox setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self addSubview:m_OpSummaryBox];
    
    m_SheetAnchorLine = [[NSBox alloc] initWithFrame:NSRect()];
    [m_SheetAnchorLine setTranslatesAutoresizingMaskIntoConstraints:NO];
    [m_SheetAnchorLine setBoxType:NSBoxSeparator];
    [self addSubview:m_SheetAnchorLine];
    
    NSDictionary *views = NSDictionaryOfVariableBindings(m_LeftPanelGoToButton, m_RightPanelGoToButton, m_OpSummaryBox, m_SheetAnchorLine, m_MainSplitView);
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(45)-[m_MainSplitView]-(0)-|" options:0 metrics:nil views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(0)-[m_MainSplitView]-(0)-|" options:0 metrics:nil views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(==0)-[m_SheetAnchorLine]-(==0)-|" options:0 metrics:nil views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(==44)-[m_SheetAnchorLine(<=1)]" options:0 metrics:nil views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(10)-[m_LeftPanelGoToButton(61)]" options:NSLayoutFormatAlignAllCenterY metrics:nil views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(10)-[m_LeftPanelGoToButton(22)]" options:0 metrics:nil views:views]];

    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"[m_RightPanelGoToButton(61)]-(10)-|" options:NSLayoutFormatAlignAllCenterY metrics:nil views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(10)-[m_RightPanelGoToButton(22)]" options:0 metrics:nil views:views]];
    
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(0)-[m_OpSummaryBox(40)]" options:0 metrics:nil views:views]];
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
    if(sysinfo::GetOSXVersion() >= sysinfo::OSXVersion::OSX_8)
        [m_LeftStack AddWidget:m_LeftPanelShareButton];
    [m_LeftStack AddWidget:m_LeftPanelEjectButton];
    [m_LeftStack AddWidget:m_LeftPanelSpinningIndicator];
    [m_LeftStack Done];
    
    m_RightStack = [[StackOfDisappearingWidgets alloc] initWithOrientation:StackOfDisappearingWidgetsOrientation::RightToLeft
                                                               AnchorView:m_RightPanelGoToButton
                                                                SuperView:self];
    if(sysinfo::GetOSXVersion() >= sysinfo::OSXVersion::OSX_8)
        [m_RightStack AddWidget:m_RightPanelShareButton];
    [m_RightStack AddWidget:m_RightPanelEjectButton];
    [m_RightStack AddWidget:m_RightPanelSpinningIndicator];
    [m_RightStack Done];
}

- (NSView*) ContentView
{
    return self;
}

- (void) Assigned
{
    [self UpdateTitle];
    [NSApp registerServicesMenuSendTypes:[NSArray arrayWithObjects:NSFilenamesPboardType, nil]
                             returnTypes:[NSArray arrayWithObjects:nil]];
}

- (id)validRequestorForSendType:(NSString *)sendType
                     returnType:(NSString *)returnType
{
    if([sendType isEqualToString:NSFilenamesPboardType] &&
       [self ActivePanelData]->Host()->IsNativeFS() )
        return self;
    
    return [super validRequestorForSendType:sendType returnType:returnType];
}

- (BOOL)writeSelectionToPasteboard:(NSPasteboard *)pboard
                             types:(NSArray *)types
{
    if ([types containsObject:NSFilenamesPboardType] == NO)
        return NO;
    
    return [self WriteToPasteboard:pboard];
}

- (bool)WriteToPasteboard:(NSPasteboard *)pboard
{
    if(![self ActivePanelData]->Host()->IsNativeFS())
        return false;
    
    NSMutableArray *filenames = [NSMutableArray new];
    
    PanelData *pd = [self ActivePanelData];
    string dir_path = pd->DirectoryPathWithTrailingSlash();
    if(pd->Stats().selected_entries_amount > 0) {
        for(auto &i: pd->StringsFromSelectedEntries())
            [filenames addObject:[NSString stringWithUTF8String:(dir_path + i.c_str()).c_str()]];
    }
    else {
        auto const *item = [[self ActivePanelView] CurrentItem];
        if(item && !item->IsDotDot())
            [filenames addObject:[NSString stringWithUTF8String:(dir_path + item->Name()).c_str()]];
    }
    
    if([filenames count] == 0)
        return false;
    
    [pboard clearContents];
    [pboard declareTypes:[NSArray arrayWithObject:NSFilenamesPboardType] owner:nil];
    return [pboard setPropertyList:filenames forType:NSFilenamesPboardType] == TRUE;
}

- (void) Resigned
{
    // to cut reference cycle
    m_LeftStack = nil;
    m_RightStack = nil;
}

- (IBAction)LeftPanelGoToButtonAction:(id)sender{
    [m_MainSplitView SetLeftOverlay:0]; // may cause bad situations with weak pointers inside panel controller here
    [m_LeftPanelController GoToGlobalHostsPathAsync:[[m_LeftPanelGoToButton GetCurrentSelectionPath] fileSystemRepresentation] select_entry:0];
}

- (IBAction)RightPanelGoToButtonAction:(id)sender{
    [m_MainSplitView SetRightOverlay:0]; // may cause bad situations with weak pointers inside panel controller here 
    [m_RightPanelController GoToGlobalHostsPathAsync:[[m_RightPanelGoToButton GetCurrentSelectionPath] fileSystemRepresentation] select_entry:0];
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
        [m_LeftPanelController.View SetPresentation:new ModernPanelViewPresentation];
        [m_RightPanelController.View SetPresentation:new ModernPanelViewPresentation];
    }
    else if (_skin == ApplicationSkin::Classic)
    {
        [m_LeftPanelController.View SetPresentation:new ClassicPanelViewPresentation];
        [m_RightPanelController.View SetPresentation:new ClassicPanelViewPresentation];
    }
}


- (bool) IsPanelActive
{
    return m_ActiveState == StateLeftPanel || m_ActiveState == StateRightPanel;
}

- (PanelView*) ActivePanelView
{
    if(m_ActiveState == StateLeftPanel)
    {
        return m_LeftPanelController.View;
    }
    else if(m_ActiveState == StateRightPanel)
    {
        return m_RightPanelController.View;
    }
    assert(0);
    return 0;
}

- (PanelData*) ActivePanelData
{
    if(m_ActiveState == StateLeftPanel)
    {
        return &m_LeftPanelController.Data;
    }
    else if(m_ActiveState == StateRightPanel)
    {
        return &m_RightPanelController.Data;
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
    if([m_MainSplitView AnyCollapsedOrOverlayed])
        return;
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
        [m_LeftPanelController.View Activate];
        [m_RightPanelController.View Disactivate];
    }
    else
    {
        assert(m_ActiveState == StateLeftPanel);
        
        m_ActiveState = StateRightPanel;
        [m_RightPanelController.View Activate];
        [m_LeftPanelController.View Disactivate];
    }
    
    [self UpdateTitle];
}

- (void) UpdateTitle
{
    char path_raw[MAXPATHLEN*8];
    [self ActivePanelData]->GetDirectoryFullHostsPathWithTrailingSlash(path_raw);
    
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
    NSString* character = [event charactersIgnoringModifiers];
    if ( [character length] != 1 ) {
        [super keyDown:event];
        return;
    }

    if([self IsPanelActive] && [[self ActivePanelController] ProcessKeyDown:event])
        return;
    
    if([character characterAtIndex:0] == NSTabCharacter)
        return [self HandleTabButton];
    
    [super keyDown:event];
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

- (IBAction)OnBriefSystemOverviewCommand:(id)sender{
    [[self ActivePanelController] HandleBriefSystemOverview];
}

- (IBAction)OnSyncPanels:(id)sender{
    assert([self IsPanelActive]);
    char dirpath[MAXPATHLEN];
    if([m_MainSplitView AnyCollapsedOrOverlayed])
        return;
    
    if(m_ActiveState == StateLeftPanel)
    {
        m_LeftPanelController.Data.GetDirectoryFullHostsPathWithTrailingSlash(dirpath);
        [m_RightPanelController GoToGlobalHostsPathAsync:dirpath select_entry:0];
    }
    else
    {
        m_RightPanelController.Data.GetDirectoryFullHostsPathWithTrailingSlash(dirpath);
        [m_LeftPanelController GoToGlobalHostsPathAsync:dirpath select_entry:0];
    }
}

- (IBAction)OnSwapPanels:(id)sender{
    assert([self IsPanelActive]);
    
    if([m_MainSplitView AnyCollapsed])
        return;
    
    swap(m_LeftPanelController, m_RightPanelController);
    if(m_ActiveState == StateLeftPanel) m_ActiveState = StateRightPanel;
    else if(m_ActiveState == StateRightPanel) m_ActiveState = StateLeftPanel;
    [m_MainSplitView SwapViews];
    
    [m_LeftPanelController AttachToControls:m_LeftPanelSpinningIndicator eject:m_LeftPanelEjectButton share:m_LeftPanelShareButton];
    [m_RightPanelController AttachToControls:m_RightPanelSpinningIndicator eject:m_RightPanelEjectButton share:m_RightPanelShareButton];
    
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
    if(![self ActivePanelData]->Host()->IsNativeFS())
        return; // currently support file info only on native fs
    if([m_MainSplitView IsViewCollapsedOrOverlayed:[self ActivePanelView]])
        return;
    
    FileSysEntryAttrSheetController *sheet = [FileSysEntryAttrSheetController new];
    FileSysEntryAttrSheetCompletionHandler handler = ^(int result){
        if(result == DialogResult::Apply)
        {
            FileSysAttrAlterCommand *command = [sheet Result];
            [m_OperationsController AddOperation:[[FileSysAttrChangeOperation alloc] initWithCommand:command]];
        }
    };

    if([self ActivePanelData]->Stats().selected_entries_amount > 0 )
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
            int rawpos = curdata->RawIndexForSortIndex(curpos);
            if(rawpos >= 0 &&
               curdata->EntryAtRawPosition(rawpos)->IsDotDot() == false)
                [sheet ShowSheet:[self window] data:[self ActivePanelData] index:rawpos handler:handler];
        }
    }
}

- (IBAction)OnDetailedVolumeInformation:(id)sender{
    assert([self IsPanelActive]);
    PanelView *curview = [self ActivePanelView];
    PanelData *curdata = [self ActivePanelData];
    if(!curdata->Host()->IsNativeFS())
        return; // currently support volume info only on native fs
    if([m_MainSplitView IsViewCollapsedOrOverlayed:[self ActivePanelView]])
        return;
    
    int curpos = [curview GetCursorPosition];
    if(curpos < 0) return;

    // TODO: THIS IS WRONG! using volume information on ".." should leave us in current directory
    string path = curdata->FullPathForEntry(curdata->RawIndexForSortIndex(curpos));
    
    DetailedVolumeInformationSheetController *sheet = [DetailedVolumeInformationSheetController new];
    [sheet ShowSheet:[self window] destpath:path.c_str()];
}

- (void)selectAll:(id)sender
{
    if([m_MainSplitView IsViewCollapsedOrOverlayed:[self ActivePanelView]])
        return;
    if([self IsPanelActive])
        [[self ActivePanelController] SelectAllEntries:true];
}

- (void)deselectAll:(id)sender
{
    if([m_MainSplitView IsViewCollapsedOrOverlayed:[self ActivePanelView]])
        return;
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
        case MenuTags::PanelSortViewHidden: [item setState:[contr GetUserHardFiltering].show_hidden ? NSOnState : NSOffState]; break;            
        case MenuTags::PanelSortSepDirs:    [item setState:[contr GetUserSortMode].sep_dirs    ? NSOnState : NSOffState]; break;
        case MenuTags::PanelSortCaseSensitive:[item setState:[contr GetUserSortMode].case_sens ? NSOnState : NSOffState]; break;
        case MenuTags::PanelSortNumeric:    [item setState:[contr GetUserSortMode].numeric_sort ? NSOnState : NSOffState]; break;
    }
    
    return true; // will disable some items in the future
}

- (void)DeleteFiles:(BOOL)_shift_behavior
{
    assert([self IsPanelActive]);
    if(![self ActivePanelData]->Host()->IsNativeFS())
        return; // currently support files deletion only on native fs
    if([m_MainSplitView IsViewCollapsedOrOverlayed:[self ActivePanelView]])
        return;
    
    auto files = make_shared<chained_strings>([self.ActivePanelController GetSelectedEntriesOrFocusedEntryWithoutDotDot]);
    if(files->empty())
        return;
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    FileDeletionOperationType type = (FileDeletionOperationType)(_shift_behavior
                                                                 ? [defaults integerForKey:@"FilePanelsShiftDeleteBehavior"]
                                                                 : [defaults integerForKey:@"FilePanelsDeleteBehavior"]);
    
    FileDeletionSheetController *sheet = [[FileDeletionSheetController alloc] init];
    [sheet ShowSheet:self.window Files:files.get() Type:type
             Handler:^(int result){
                 if (result == DialogResult::Delete)
                 {
                     FileDeletionOperationType type = [sheet GetType];
                     
                     string root_path = [self ActivePanelData]->DirectoryPathWithTrailingSlash();
                     
                     FileDeletionOperation *op = [[FileDeletionOperation alloc]
                                                  initWithFiles:move(*files.get())
                                                  type:type
                                                  rootpath:root_path.c_str()];
                     op.TargetPanel = [self ActivePanelController];
                     [m_OperationsController AddOperation:op];
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
    PanelData *curdata = [self ActivePanelData];
    if(!curdata->Host()->IsNativeFS())
        return; // currently support directory creation only on native fs
    if([m_MainSplitView IsViewCollapsedOrOverlayed:[self ActivePanelView]])
        return;
    
    CreateDirectorySheetController *cd = [[CreateDirectorySheetController alloc] init];
    [cd ShowSheet:[self window] handler:^(int _ret)
     {
         if(_ret == DialogResult::Create)
         {

             string pdir = curdata->DirectoryPathWithoutTrailingSlash();
             CreateDirectoryOperation *op = [[CreateDirectoryOperation alloc] initWithPath:[[cd.TextField stringValue] fileSystemRepresentation]
                                                                                  rootpath:pdir.c_str()
                                             ];
             op.TargetPanel = [self ActivePanelController];
             [m_OperationsController AddOperation:op];
         }
     }];
}

- (IBAction)OnFileCopyCommand:(id)sender{
    assert([self IsPanelActive]);
    if([m_MainSplitView AnyCollapsedOrOverlayed])
        return;
    
    const PanelData *source, *destination;
    if(m_ActiveState == StateLeftPanel) {
        source = &m_LeftPanelController.Data;
        destination = &m_RightPanelController.Data;
    }
    else {
        source = &m_RightPanelController.Data;
        destination = &m_LeftPanelController.Data;
    }
    
    auto files = make_shared<chained_strings>([self.ActivePanelController GetSelectedEntriesOrFocusedEntryWithoutDotDot]);
    if(files->empty())
        return;
    
    string dest_path = destination->DirectoryPathWithTrailingSlash();
    NSString *nsdirpath = [NSString stringWithUTF8String:dest_path.c_str()];
    MassCopySheetController *mc = [MassCopySheetController new];
    [mc ShowSheet:[self window] initpath:nsdirpath iscopying:true items:files.get() handler:^(int _ret)
     {
         if(_ret == DialogResult::Copy)
         {
             string root_path = source->DirectoryPathWithTrailingSlash();
             
             FileCopyOperationOptions opts;
             opts.docopy = true;
             [mc FillOptions:&opts];
             
             FileCopyOperation *op;
             if(source->Host()->IsNativeFS() && destination->Host()->IsNativeFS())
                  op = [[FileCopyOperation alloc] initWithFiles:move(*files.get())
                                                      root:root_path.c_str()
                                                      dest:[[mc.TextField stringValue] fileSystemRepresentation]
                                                   options:&opts];
             else if(destination->Host()->IsNativeFS() &&
                     strlen([[mc.TextField stringValue] fileSystemRepresentation]) > 0 &&
                     [[mc.TextField stringValue] fileSystemRepresentation][0] == '/'
                     )
                  op = [[FileCopyOperation alloc] initWithFiles:move(*files.get())
                                                      root:root_path.c_str()
                                                   rootvfs:source->Host()
                                                      dest:[[mc.TextField stringValue] fileSystemRepresentation]
                                                   options:&opts];
             [op AddOnFinishHandler:^{
                 dispatch_to_main_queue( ^{
                     [m_LeftPanelController RefreshDirectory];
                     [m_RightPanelController RefreshDirectory];
                 });
             }];
             [m_OperationsController AddOperation:op];
         }
     }];
}

- (IBAction)OnFileCopyAsCommand:(id)sender{
    // process only current cursor item
    assert([self IsPanelActive]);
    if(![self ActivePanelData]->Host()->IsNativeFS())
        return; // currently support copy as only on native fs (an easy way to prohibit it)
    if([m_MainSplitView IsViewCollapsedOrOverlayed:[self ActivePanelView]])
        return;
    
    auto const *item = [[self ActivePanelView] CurrentItem];
    if(!item)
        return;
    if(item->IsDotDot())
        return;
    
    auto files = make_shared<chained_strings>(item->Name());
    
    MassCopySheetController *mc = [MassCopySheetController new];
    [mc ShowSheet:[self window] initpath:[NSString stringWithUTF8String:item->Name()] iscopying:true items:files.get() handler:^(int _ret)
     {
         if(_ret == DialogResult::Copy)
         {
             string root_path = [self ActivePanelData]->DirectoryPathWithTrailingSlash();
             FileCopyOperationOptions opts;
             opts.docopy = true;
             [mc FillOptions:&opts];
             
             FileCopyOperation *op = [[FileCopyOperation alloc] initWithFiles:move(*files.get())
                                                                         root:root_path.c_str()
                                                                         dest:[[mc.TextField stringValue] fileSystemRepresentation]
                                                                      options:&opts];
             [op AddOnFinishHandler:^{
                 dispatch_to_main_queue( ^{
                     [m_LeftPanelController RefreshDirectory];
                     [m_RightPanelController RefreshDirectory];
                 });
             }];
             [m_OperationsController AddOperation:op];
         }
     }];
}

- (IBAction)OnFileRenameMoveCommand:(id)sender{
    assert([self IsPanelActive]);
    if([m_MainSplitView AnyCollapsedOrOverlayed])
        return;
    const PanelData *source, *destination;
    if(m_ActiveState == StateLeftPanel)
    {
        source = &m_LeftPanelController.Data;
        destination = &m_RightPanelController.Data;
    }
    else
    {
        source = &m_RightPanelController.Data;
        destination = &m_LeftPanelController.Data;
    }
    
    if(!source->Host()->IsNativeFS())
        return; // currently support rename only on native fs
    
    auto files = make_shared<chained_strings>([self.ActivePanelController GetSelectedEntriesOrFocusedEntryWithoutDotDot]);
    if(files->empty())
        return;
    
    string dest_path = destination->DirectoryPathWithTrailingSlash();
    NSString *nsdirpath = [NSString stringWithUTF8String:dest_path.c_str()];
    
    MassCopySheetController *mc = [MassCopySheetController new];
    [mc ShowSheet:[self window] initpath:nsdirpath iscopying:false items:files.get() handler:^(int _ret)
     {
         if(_ret == DialogResult::Copy)
         {
             string root_path = source->DirectoryPathWithTrailingSlash();
             
             FileCopyOperationOptions opts;
             opts.docopy = false;
             [mc FillOptions:&opts];
             
             
             FileCopyOperation *op = [[FileCopyOperation alloc] initWithFiles:move(*files.get())
                                                                         root:root_path.c_str()
                                                                         dest:[[mc.TextField stringValue] fileSystemRepresentation]
                                                                      options:&opts];
             [op AddOnFinishHandler:^{
                 dispatch_to_main_queue( ^{
                     [m_LeftPanelController RefreshDirectory];
                     [m_RightPanelController RefreshDirectory];
                 });
             }];
            [m_OperationsController AddOperation:op];
         }
     }];
}

- (IBAction)OnFileRenameMoveAsCommand:(id)sender {
    
    // process only current cursor item
    assert([self IsPanelActive]);
    if([m_MainSplitView IsViewCollapsedOrOverlayed:[self ActivePanelView]])
        return;
    if(![self ActivePanelData]->Host()->IsNativeFS())
        return; // currently support rename as only on native fs
    
    auto const *item = [[self ActivePanelView] CurrentItem];
    if(!item)
        return;
    if(item->IsDotDot())
        return;
    
    auto files = make_shared<chained_strings>(item->Name());
    
    MassCopySheetController *mc = [MassCopySheetController new];
    [mc ShowSheet:[self window] initpath:[NSString stringWithUTF8String:item->Name()] iscopying:false items:files.get() handler:^(int _ret)
     {
         if(_ret == DialogResult::Copy)
         {
             string root_path = [self ActivePanelData]->DirectoryPathWithTrailingSlash();
             FileCopyOperationOptions opts;
             opts.docopy = false;
             [mc FillOptions:&opts];
             
             
             FileCopyOperation *op = [[FileCopyOperation alloc] initWithFiles:move(*files.get())
                                                                         root:root_path.c_str()
                                                                         dest:[[mc.TextField stringValue] fileSystemRepresentation]
                                                                      options:&opts];
             [op AddOnFinishHandler:^{
                 dispatch_to_main_queue( ^{
                     [m_LeftPanelController RefreshDirectory];
                     [m_RightPanelController RefreshDirectory];
                 });
             }];             
             [m_OperationsController AddOperation:op];
         }
     }];
}

- (void)PanelPathChanged:(PanelController*)_panel
{
    if(_panel == [self ActivePanelController])
        [self UpdateTitle];
     
    if(_panel == m_LeftPanelController)
    {
        string tmp = m_LeftPanelController.GetCurrentDirectoryPathRelativeToHost;
        [m_LeftPanelGoToButton SetCurrentPath:tmp.c_str()];
    }
    if(_panel == m_RightPanelController)
    {
        string tmp = m_RightPanelController.GetCurrentDirectoryPathRelativeToHost;
        [m_RightPanelGoToButton SetCurrentPath:tmp.c_str()];
    }
}

- (void) DidBecomeKeyWindow
{
    // update key modifiers state for views
    unsigned long flags = [NSEvent modifierFlags];
    [m_LeftPanelController ModifierFlagsChanged:flags];
    [m_RightPanelController ModifierFlagsChanged:flags];
}

- (void)WindowDidResize
{
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
    
    m_LeftPanelController.Data.GetDirectoryFullHostsPathWithTrailingSlash(path);
    [defaults setObject:[NSString stringWithUTF8String:path] forKey:@"FirstPanelPath"];
     
    m_RightPanelController.Data.GetDirectoryFullHostsPathWithTrailingSlash(path);
    [defaults setObject:[NSString stringWithUTF8String:path] forKey:@"SecondPanelPath"];
}

- (bool)WindowShouldClose:(MainWindowController*)sender
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
    if([m_MainSplitView IsViewCollapsedOrOverlayed:[self ActivePanelView]])
        return;
    if([self IsPanelActive])
    {
        auto *i = [[self ActivePanelView] CurrentItem];
        if(i)
        {
            string tmp = [self ActivePanelData]->DirectoryPathWithTrailingSlash() + i->Name();
            [(MainWindowController*)[[self window] delegate] RequestBigFileView:tmp.c_str()
             with_fs:[self ActivePanelData]->DirectoryEntries().Host()];
        }
    }
}

- (void)RevealEntries:(chained_strings)_entries inPath:(const char*)_path
{
    assert(dispatch_is_main_queue());
    
    PanelController *panel = [self ActivePanelController];
    if([panel GoToGlobalHostsPathSync:_path] == VFSError::Ok)
    {
        if(!_entries.empty())
            [panel ScheduleDelayedSelectionChangeForC:_entries.front().c_str()
                                            timeoutms:100
                                             checknow:true];
        
        PanelData *data = [self ActivePanelData];
        for(auto &i: _entries)
            data->CustomFlagsSelectSorted(data->SortedIndexForName(i.c_str()), true);
        
        [[self ActivePanelView] setNeedsDisplay:true];
    }
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
    if([m_MainSplitView AnyCollapsedOrOverlayed])
        return;
    
    if(!m_RightPanelController.GetCurrentVFSHost->IsNativeFS() || !m_LeftPanelController.GetCurrentVFSHost->IsNativeFS())
        return; // currently support links only on native fs
    
    string link_path;
    auto const *item = [[self ActivePanelView] CurrentItem];
    if(!item)
        return;
    
    string source_path = [self ActivePanelData]->DirectoryPathWithTrailingSlash();
    if(!item->IsDotDot())
        source_path += item->Name();
    
    if(m_ActiveState == StateLeftPanel)
        link_path = m_RightPanelController.GetCurrentDirectoryPathRelativeToHost;
    else
        link_path = m_LeftPanelController.GetCurrentDirectoryPathRelativeToHost;

    if(!item->IsDotDot())
        link_path += item->Name();
    else
        link_path += [self ActivePanelData]->DirectoryPathShort();

    FileLinkNewSymlinkSheetController *sheet = [FileLinkNewSymlinkSheetController new];
    [sheet ShowSheet:[self window]
          sourcepath:[NSString stringWithUTF8String:source_path.c_str()]
            linkpath:[NSString stringWithUTF8String:link_path.c_str()]
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
    if([m_MainSplitView IsViewCollapsedOrOverlayed:[self ActivePanelView]])
        return;
    if(![self ActivePanelData]->Host()->IsNativeFS())
        return; // currently support links only on native fs
    
//    char link_path[MAXPATHLEN];
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
    
    string link_path = [self ActivePanelData]->DirectoryPathWithTrailingSlash() + item->Name();
    NSString *linkpath = [NSString stringWithUTF8String:link_path.c_str()];
    
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
    if([m_MainSplitView AnyCollapsedOrOverlayed])
        return;
    if(!m_RightPanelController.GetCurrentVFSHost->IsNativeFS() || !m_LeftPanelController.GetCurrentVFSHost->IsNativeFS())
        return; // currently support links only on native fs
    
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
    
//    char  src_path[MAXPATHLEN];
    string dir_path = [self ActivePanelData]->DirectoryPathWithTrailingSlash();
    string src_path = dir_path + item->Name();
    NSString *srcpath = [NSString stringWithUTF8String:src_path.c_str()];
    NSString *dirpath = [NSString stringWithUTF8String:dir_path.c_str()];
    
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
    if([m_MainSplitView IsViewCollapsedOrOverlayed:[self ActivePanelView]])
        return;
    SelectionWithMaskSheetController *sheet = [SelectionWithMaskSheetController new];
    [sheet ShowSheet:[self window]
             handler:^(int result) {
                 if(result == DialogResult::OK) {
                     [[self ActivePanelController] SelectEntriesByMask:[sheet Mask] select:true];
                 }
             }];
}

- (IBAction)OnDeselectByMask:(id)sender
{
    if([m_MainSplitView IsViewCollapsedOrOverlayed:[self ActivePanelView]])
        return;
    SelectionWithMaskSheetController *sheet = [SelectionWithMaskSheetController new];
    [sheet SetIsDeselect:true];
    [sheet ShowSheet:[self window]
             handler:^(int result) {
                 if(result == DialogResult::OK) {
                     [[self ActivePanelController] SelectEntriesByMask:[sheet Mask] select:false];
                 }
             }];
}

- (IBAction)OnGoToUpperDirectory:(id)sender
{
    assert([self IsPanelActive]);
    if([m_MainSplitView IsViewCollapsedOrOverlayed:[self ActivePanelView]])
        return;
    [[self ActivePanelController] GoToUpperDirectoryAsync];    
}

- (IBAction)OnCopyCurrentFileName:(id)sender
{
    auto focus = [self.ActivePanelController GetCurrentFocusedEntryFilename];
    NSPasteboard *pasteBoard = [NSPasteboard generalPasteboard];
    [pasteBoard declareTypes:[NSArray arrayWithObjects:NSStringPboardType, nil] owner:nil];
    [pasteBoard setString:[NSString stringWithUTF8String:focus.c_str()] forType:NSStringPboardType];
}

- (IBAction)OnCopyCurrentFilePath:(id)sender
{
    auto path = [self.ActivePanelController GetCurrentFocusedEntryFilePathRelativeToHost];
    NSPasteboard *pasteBoard = [NSPasteboard generalPasteboard];
    [pasteBoard declareTypes:[NSArray arrayWithObjects:NSStringPboardType, nil] owner:nil];
    [pasteBoard setString:[NSString stringWithUTF8String:path.c_str()] forType:NSStringPboardType];
}

- (IBAction)paste:(id)sender
{
    if([m_MainSplitView IsViewCollapsedOrOverlayed:[self ActivePanelView]])
        return;
    
    NSPasteboard *paste_board = [NSPasteboard generalPasteboard];

    // check what's inside pasteboard
    NSString *best_type = [paste_board availableTypeFromArray:[NSArray arrayWithObject:NSFilenamesPboardType]];
    if(!best_type)
        return;

    // check if we're on native fs now (all others vfs are r/o now)
    if(![self ActivePanelData]->Host()->IsNativeFS())
        return;
    
    // input should be an array of filepaths
    NSArray* ns_filenames = [paste_board propertyListForType:NSFilenamesPboardType];
    if(!ns_filenames)
        return;
    
    map<string, vector<string>> filenames; // root directory to containing filename maps
    for(NSString *ns_filename in ns_filenames)
    {
        // filenames are without trailing slashes for dirs here
        char dir[MAXPATHLEN], fn[MAXPATHLEN];
        if(!GetDirectoryContainingItemFromPath([ns_filename fileSystemRepresentation], dir))
            continue;
        if(!GetFilenameFromPath([ns_filename fileSystemRepresentation], fn))
           continue;
        filenames[dir].push_back(fn);
    }
    
    if(filenames.empty()) // invalid pasteboard?
        return;
    
    string destination = [self ActivePanelData]->DirectoryPathWithTrailingSlash();
    
    for(auto i: filenames)
    {
        chained_strings files;
        for(auto j: i.second)
            files.push_back(j.c_str(), (int)j.length(), nullptr);
        
        FileCopyOperationOptions opts;
        opts.docopy = true;
        
        [m_OperationsController AddOperation:
             [[FileCopyOperation alloc] initWithFiles:move(files)
                                                 root:i.first.c_str()
                                                 dest:destination.c_str()
                                              options:&opts]];
    }
}

- (IBAction)copy:(id)sender
{
    [self WriteToPasteboard:[NSPasteboard generalPasteboard]];
    // check if we're on native fs now (all others vfs are not-accessible by system and so useless)
}

- (void)GetFilePanelsGlobalPaths:(vector<string> &)_paths
{
    _paths.clear();
    char tmp[MAXPATHLEN*8];
    m_LeftPanelController.Data.GetDirectoryFullHostsPathWithTrailingSlash(tmp);
    _paths.push_back(tmp);
    m_RightPanelController.Data.GetDirectoryFullHostsPathWithTrailingSlash(tmp);
    _paths.push_back(tmp);
}

- (QuickLookView*)RequestQuickLookView:(PanelController*)_panel
{
    QuickLookView *view = [[QuickLookView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
    if(_panel == m_LeftPanelController)
        [m_MainSplitView SetRightOverlay:view];
    else if(_panel == m_RightPanelController)
        [m_MainSplitView SetLeftOverlay:view];
    else
        return nil;
    return view;
}

- (BriefSystemOverview*)RequestBriefSystemOverview:(PanelController*)_panel
{
    BriefSystemOverview *view = [[BriefSystemOverview alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
    if(_panel == m_LeftPanelController)
        [m_MainSplitView SetRightOverlay:view];
    else if(_panel == m_RightPanelController)
        [m_MainSplitView SetLeftOverlay:view];
    else
        return nil;
    return view;
}

- (void)CloseOverlay:(PanelController*)_panel
{
    if(_panel == m_LeftPanelController)
        [m_MainSplitView SetRightOverlay:0];
    else if(_panel == m_RightPanelController)
        [m_MainSplitView SetLeftOverlay:0];
}

- (IBAction)OnCompressFiles:(id)sender
{
    auto files = [self.ActivePanelController GetSelectedEntriesOrFocusedEntryWithoutDotDot];
    if(files.empty())
        return;
    shared_ptr<VFSHost> srcvfs, dstvfs;
    string srcroot, dstroot;
    PanelController *target_pc;
    if([self ActivePanelController] == m_LeftPanelController) {
        srcvfs = [m_LeftPanelController GetCurrentVFSHost];
        dstvfs = [m_RightPanelController GetCurrentVFSHost];
        srcroot = [m_LeftPanelController GetCurrentDirectoryPathRelativeToHost];
        dstroot = [m_RightPanelController GetCurrentDirectoryPathRelativeToHost];
        target_pc = m_RightPanelController;
    }
    else {
        srcvfs = [m_RightPanelController GetCurrentVFSHost];
        dstvfs = [m_LeftPanelController GetCurrentVFSHost];
        srcroot = [m_RightPanelController GetCurrentDirectoryPathRelativeToHost];
        dstroot = [m_LeftPanelController GetCurrentDirectoryPathRelativeToHost];
        target_pc = m_LeftPanelController;
    }
    
    FileCompressOperation *op = [[FileCompressOperation alloc] initWithFiles:move(files)
                                                                     srcroot:srcroot.c_str()
                                                                      srcvfs:srcvfs
                                                                     dstroot:dstroot.c_str()
                                                                      dstvfs:dstvfs];
    op.TargetPanel = target_pc;
    [m_OperationsController AddOperation:op];
}

- (void) AddOperation:(Operation*)_operation
{
    [m_OperationsController AddOperation:_operation];
}

///////////////////////////////////////////////////////////////
- (IBAction)OnShowTerminal:(id)sender
{
    string path;
    if([[self ActivePanelController] GetCurrentVFSHost]->IsNativeFS())
        path = [[self ActivePanelController] GetCurrentDirectoryPathRelativeToHost];
    [(MainWindowController*)[[self window] delegate] RequestTerminal:path.c_str()];
}
///////////////////////////////////////////////////////////////





@end

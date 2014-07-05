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
#import "VFS.h"
#import "FilePanelMainSplitView.h"
#import "BriefSystemOverview.h"
#import "sysinfo.h"
#import "LSUrls.h"
#import "ActionsShortcutsManager.h"
#import "MyToolbar.h"
#import "common_paths.h"
#import "SandboxManager.h"

static auto g_DefsPanelsLeftOptions  = @"FilePanelsLeftPanelViewState";
static auto g_DefsPanelsRightOptions = @"FilePanelsRightPanelViewState";

@implementation MainWindowFilePanelState

@synthesize OperationsController = m_OperationsController;

- (id) initWithFrame:(NSRect)frameRect Window:(NSWindow*)_wnd;
{
    self = [super initWithFrame:frameRect];
    if(self)
    {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        
        m_OperationsController = [[OperationsController alloc] init];
        m_OpSummaryController = [[OperationsSummaryViewController alloc] initWithController:m_OperationsController
                                                                                     window:_wnd];
        
        m_LeftPanelController = [PanelController new];
        m_RightPanelController = [PanelController new];
        
        [self CreateControls];
        
        // panel creation and preparation
        m_LeftPanelController.state = self;
        [m_LeftPanelController AttachToControls:m_LeftPanelSpinningIndicator share:m_LeftPanelShareButton];
        
        m_RightPanelController.state = self;
        [m_RightPanelController AttachToControls:m_RightPanelSpinningIndicator share:m_RightPanelShareButton];
        
        m_Skin = ((AppDelegate*)[NSApplication sharedApplication].delegate).Skin;
        if (m_Skin == ApplicationSkin::Modern)
        {
            [m_LeftPanelController.view SetPresentation:new ModernPanelViewPresentation];
            [m_RightPanelController.view SetPresentation:new ModernPanelViewPresentation];
        }
        else if (m_Skin == ApplicationSkin::Classic)
        {
            [m_LeftPanelController.view SetPresentation:new ClassicPanelViewPresentation];
            [m_RightPanelController.view SetPresentation:new ClassicPanelViewPresentation];
        }
        
        m_LeftPanelController.options = [NSUserDefaults.standardUserDefaults dictionaryForKey:g_DefsPanelsLeftOptions];
        m_RightPanelController.options = [NSUserDefaults.standardUserDefaults dictionaryForKey:g_DefsPanelsRightOptions];

        
        // now load data into panels, on any fails - go into home dir
        NSString *lp = [defaults stringForKey:@"FirstPanelPath"];
        NSString *rp = [defaults stringForKey:@"SecondPanelPath"];
        
        if(!configuration::is_sandboxed) { // regular waypath
            if(!lp || !lp.length || [m_LeftPanelController GoToDir:lp.fileSystemRepresentation
                                                               vfs:VFSNativeHost::SharedHost()
                                                      select_entry:""
                                                             async:false] < 0)
                [m_LeftPanelController GoToDir:CommonPaths::Get(CommonPaths::Home)
                                           vfs:VFSNativeHost::SharedHost()
                                  select_entry:""
                                         async:false];
        
            if(!rp || !rp.length || [m_RightPanelController GoToDir:rp.fileSystemRepresentation
                                                                vfs:VFSNativeHost::SharedHost()
                                                       select_entry:""
                                                              async:false] < 0)
                [m_RightPanelController GoToDir:"/"
                                            vfs:VFSNativeHost::SharedHost()
                                   select_entry:""
                                          async:false];
        }
        else { // on sandboxed version it's bit more complicated
            if(!lp ||
               !lp.length ||
               !SandboxManager::Instance().CanAccessFolder(lp.fileSystemRepresentation) ||
               [m_LeftPanelController GoToDir:lp.fileSystemRepresentation
                                          vfs:VFSNativeHost::SharedHost()
                                 select_entry:""
                                        async:false] < 0) {
                   // failed to load saved panel path (or there was no saved path)
                   // try to go to some path we can
                   if(SandboxManager::Instance().Empty() ||
                      [m_LeftPanelController GoToDir:SandboxManager::Instance().FirstFolderWithAccess()
                                                 vfs:VFSNativeHost::SharedHost()
                                        select_entry:""
                                               async:false] < 0) {
                          // failed to go to folder with granted access(or no such folders)
                          // as last resort - go to startup cwd
                          [m_LeftPanelController GoToDir:[[NSApp delegate] startupCWD]
                                                     vfs:VFSNativeHost::SharedHost()
                                            select_entry:""
                                                   async:false];
                    }
            }
            
            if(!rp ||
               !rp.length ||
               !SandboxManager::Instance().CanAccessFolder(rp.fileSystemRepresentation) ||
               [m_RightPanelController GoToDir:rp.fileSystemRepresentation
                                           vfs:VFSNativeHost::SharedHost()
                                  select_entry:""
                                         async:false] < 0) {
                   // failed to load saved panel path (or there was no saved path)
                   // try to go to some path we can
                   if(SandboxManager::Instance().Empty() ||
                      [m_RightPanelController GoToDir:SandboxManager::Instance().FirstFolderWithAccess()
                                                  vfs:VFSNativeHost::SharedHost()
                                         select_entry:""
                                                async:false] < 0) {
                          // failed to go to folder with granted access(or no such folders)
                          // as last resort - go to startup cwd
                          [m_RightPanelController GoToDir:[[NSApp delegate] startupCWD]
                                                      vfs:VFSNativeHost::SharedHost()
                                             select_entry:""
                                                    async:false];
                      }
               }
        }
    }
    return self;
}

- (BOOL)acceptsFirstResponder { return true; }
- (MyToolbar*)Toolbar { return m_Toolbar; }
- (NSView*) ContentView { return self; }

- (void) CreateControls
{
    m_Toolbar = [[MyToolbar alloc] initWithFrame:NSRect()];
    m_Toolbar.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:m_Toolbar];
    
    m_MainSplitView = [[FilePanelMainSplitView alloc] initWithFrame:NSRect()];
    m_MainSplitView.translatesAutoresizingMaskIntoConstraints = NO;
    [m_MainSplitView SetBasicViews:m_LeftPanelController.view second:m_RightPanelController.view];
    [self addSubview:m_MainSplitView];
    
    m_LeftPanelGoToButton = [[MainWndGoToButton alloc] initWithFrame:NSMakeRect(0, 0, 60, 23)];
    m_LeftPanelGoToButton.target = self;
    m_LeftPanelGoToButton.action = @selector(LeftPanelGoToButtonAction:);
    [m_LeftPanelGoToButton SetOwner:self];
    
    m_RightPanelGoToButton = [[MainWndGoToButton alloc] initWithFrame:NSMakeRect(0, 0, 60, 23)];
    m_RightPanelGoToButton.target = self;
    m_RightPanelGoToButton.action = @selector(RightPanelGoToButtonAction:);
    [m_RightPanelGoToButton SetOwner:self];
    
    if(sysinfo::GetOSXVersion() >= sysinfo::OSXVersion::OSX_8)
    {
        m_LeftPanelShareButton = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 40, 23)];
        m_LeftPanelShareButton.bezelStyle = NSTexturedRoundedBezelStyle;
        m_LeftPanelShareButton.image = [NSImage imageNamed:NSImageNameShareTemplate];
        [m_LeftPanelShareButton sendActionOn:NSLeftMouseDownMask];
        m_LeftPanelShareButton.refusesFirstResponder = true;
    
        m_RightPanelShareButton = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 40, 23)];
        m_RightPanelShareButton.bezelStyle = NSTexturedRoundedBezelStyle;
        m_RightPanelShareButton.image = [NSImage imageNamed:NSImageNameShareTemplate];
        [m_RightPanelShareButton sendActionOn:NSLeftMouseDownMask];
        m_RightPanelShareButton.refusesFirstResponder = true;
    }
    
    m_LeftPanelSpinningIndicator = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(0, 0, 16, 16)];
    m_LeftPanelSpinningIndicator.indeterminate = YES;
    m_LeftPanelSpinningIndicator.style = NSProgressIndicatorSpinningStyle;
    m_LeftPanelSpinningIndicator.controlSize = NSSmallControlSize;
    m_LeftPanelSpinningIndicator.displayedWhenStopped = NO;
    
    m_RightPanelSpinningIndicator = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(0, 0, 16, 16)];
    m_RightPanelSpinningIndicator.indeterminate = YES;
    m_RightPanelSpinningIndicator.style = NSProgressIndicatorSpinningStyle;
    m_RightPanelSpinningIndicator.controlSize = NSSmallControlSize;
    m_RightPanelSpinningIndicator.displayedWhenStopped = NO;
    
    m_SeparatorLine = [[NSBox alloc] initWithFrame:NSRect()];
    m_SeparatorLine.translatesAutoresizingMaskIntoConstraints = NO;
    m_SeparatorLine.boxType = NSBoxSeparator;
    [self addSubview:m_SeparatorLine];
    
    [m_Toolbar InsertView:m_LeftPanelGoToButton];
    if(sysinfo::GetOSXVersion() >= sysinfo::OSXVersion::OSX_8)
        [m_Toolbar InsertView:m_LeftPanelShareButton];
    [m_Toolbar InsertView:m_LeftPanelSpinningIndicator];
    [m_Toolbar InsertFlexSpace];
    [m_Toolbar InsertView:m_OpSummaryController.view];
    [m_Toolbar InsertFlexSpace];
    [m_Toolbar InsertView:m_RightPanelSpinningIndicator];
        if(sysinfo::GetOSXVersion() >= sysinfo::OSXVersion::OSX_8)
    [m_Toolbar InsertView:m_RightPanelShareButton];
    [m_Toolbar InsertView:m_RightPanelGoToButton];
    
    [self BuildLayout];
}

- (void) BuildLayout
{
    [self removeConstraints:self.constraints];
    
    NSDictionary *views = NSDictionaryOfVariableBindings(m_SeparatorLine, m_MainSplitView, m_Toolbar);
    
    if(m_Toolbar.isHidden == false)
    {
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(==0)-[m_Toolbar(==36)]-(==0)-[m_SeparatorLine(<=1)]-(==0)-[m_MainSplitView]-(==0)-|" options:0 metrics:nil views:views]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(0)-[m_Toolbar]-(0)-|" options:0 metrics:nil views:views]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(0)-[m_MainSplitView]-(0)-|" options:0 metrics:nil views:views]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(==0)-[m_SeparatorLine]-(==0)-|" options:0 metrics:nil views:views]];
    }
    else
    {
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(==0)-[m_SeparatorLine(<=1)]-(==0)-[m_MainSplitView]-(==0)-|" options:0 metrics:nil views:views]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(0)-[m_MainSplitView]-(0)-|" options:0 metrics:nil views:views]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(==0)-[m_SeparatorLine]-(==0)-|" options:0 metrics:nil views:views]];
    }
}

- (void)toggleToolbarShown:(id)sender
{
    m_Toolbar.Hidden = !m_Toolbar.isHidden;
    [self BuildLayout];    
}

- (void) Assigned
{
    [m_Toolbar UpdateVisibility];
    [self BuildLayout];
    [NSApp registerServicesMenuSendTypes:@[NSFilenamesPboardType] returnTypes:@[]];
    
    // if we alredy were active and have some focused view - restore it
    if(m_LastResponder)
        [self.window makeFirstResponder:m_LastResponder];
    m_LastResponder = nil;
    
    // if we don't know which view should be active - make left panel a first responder
    if(!self.isPanelActive)
        [self.window makeFirstResponder:m_LeftPanelController.view];
    
    [self UpdateTitle];
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
    if(!self.isPanelActive) return false;
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
        auto const *item = self.ActivePanelView.item;
        if(item && !item->IsDotDot())
            [filenames addObject:[NSString stringWithUTF8String:(dir_path + item->Name()).c_str()]];
    }
    
    if(filenames.count == 0)
        return false;
    
    [pboard clearContents];
    [pboard declareTypes:@[NSFilenamesPboardType] owner:nil];
    return [pboard setPropertyList:filenames forType:NSFilenamesPboardType] == TRUE;
}

- (void) Resigned
{
}

- (void)viewWillMoveToWindow:(NSWindow *)_wnd
{
    if(_wnd == nil)
    {
        m_LastResponder = nil;
        NSResponder *resp = self.window.firstResponder;
        if(resp != nil &&
           [resp isKindOfClass:NSView.class] &&
           [(NSView*)resp isDescendantOf:self] )
            m_LastResponder = resp;
    }
}

- (IBAction)LeftPanelGoToButtonAction:(id)sender
{
    m_MainSplitView.leftOverlay = nil; // may cause bad situations with weak pointers inside panel controller here
    [m_LeftPanelController GoToDir:m_LeftPanelGoToButton.path
                               vfs:VFSNativeHost::SharedHost()
                      select_entry:""
                             async:true];
}

- (IBAction)RightPanelGoToButtonAction:(id)sender{
    m_MainSplitView.rightOverlay = nil; // may cause bad situations with weak pointers inside panel controller here
    [m_RightPanelController GoToDir:m_RightPanelGoToButton.path
                               vfs:VFSNativeHost::SharedHost()
                      select_entry:""
                             async:true];
}

- (IBAction)LeftPanelGoto:(id)sender{
    NSPoint p = NSMakePoint(0, self.frame.size.height);
    p = [self convertPoint:p toView:nil];
    p = [self.window convertRectToScreen:NSMakeRect(p.x, p.y, 1, 1)].origin;
    [m_LeftPanelGoToButton SetAnchorPoint:p IsRight:false];
    [m_LeftPanelGoToButton performClick:self];
}

- (IBAction)RightPanelGoto:(id)sender{
    NSPoint p = NSMakePoint(self.frame.size.width, self.frame.size.height);
    p = [self convertPoint:p toView:nil];
    p = [self.window convertRectToScreen:NSMakeRect(p.x, p.y, 1, 1)].origin;
    [m_RightPanelGoToButton SetAnchorPoint:p IsRight:true];
    [m_RightPanelGoToButton performClick:self];
}

- (void)ApplySkin:(ApplicationSkin)_skin
{
    if(m_Skin == _skin)
        return;

    m_Skin = _skin;
    
    if (_skin == ApplicationSkin::Modern)
    {
        [m_LeftPanelController.view SetPresentation:new ModernPanelViewPresentation];
        [m_RightPanelController.view SetPresentation:new ModernPanelViewPresentation];
    }
    else if (_skin == ApplicationSkin::Classic)
    {
        [m_LeftPanelController.view SetPresentation:new ClassicPanelViewPresentation];
        [m_RightPanelController.view SetPresentation:new ClassicPanelViewPresentation];
    }
}

- (bool) isPanelActive
{
    return self.ActivePanelController != nil;
}

- (PanelView*) ActivePanelView
{
    PanelController *pc = self.ActivePanelController;
    return pc ? pc.view : nil;
}

- (PanelData*) ActivePanelData
{
    PanelController *pc = self.ActivePanelController;
    return pc ? &pc.data : nullptr;
}

- (PanelController*) ActivePanelController
{
    if(m_LeftPanelController.isActive)
        return m_LeftPanelController;
    else if(m_RightPanelController.isActive)
        return m_RightPanelController;
    return nil;
}

- (void) HandleTabButton
{
    if([m_MainSplitView AnyCollapsedOrOverlayed])
        return;
    if(m_LeftPanelController.isActive)
        [self ActivatePanelByController:m_RightPanelController];
    else if(m_RightPanelController.isActive)
        [self ActivatePanelByController:m_LeftPanelController];
    else ; // mb later ???
}

- (void)ActivatePanelByController:(PanelController *)controller
{
    if (controller == m_LeftPanelController)
        [self.window makeFirstResponder:m_LeftPanelController.view];
    else if (controller == m_RightPanelController)
        [self.window makeFirstResponder:m_RightPanelController.view];
    else
        assert(0);
    [self UpdateTitle];    
}

- (void) UpdateTitle
{
    auto data = self.ActivePanelData;
    if(!data) {
        self.window.title = @"";
        return;
    }
    string path_raw = data->VerboseDirectoryFullPath();
    
    NSString *path = [NSString stringWithUTF8String:path_raw.c_str()];
    if(path == nil)
    {
        self.window.title = @"...";
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

- (void)SavePanelsSettings
{
    [self savePanelOptionsFor:m_LeftPanelController];
    [self savePanelOptionsFor:m_RightPanelController];
}

- (void) savePanelOptionsFor:(PanelController*)_pc
{
    if(_pc == m_LeftPanelController)
        [NSUserDefaults.standardUserDefaults setObject:_pc.options forKey:g_DefsPanelsLeftOptions];
    else if(_pc == m_RightPanelController)
        [NSUserDefaults.standardUserDefaults setObject:_pc.options forKey:g_DefsPanelsRightOptions];
}

- (IBAction)OnSyncPanels:(id)sender{
    if(!self.isPanelActive || m_MainSplitView.AnyCollapsedOrOverlayed) return;
    
    if(m_LeftPanelController.isActive)
        [m_RightPanelController GoToDir:m_LeftPanelController.GetCurrentDirectoryPathRelativeToHost
                                    vfs:m_LeftPanelController.VFS
                           select_entry:""
                                  async:true];
    else
        [m_LeftPanelController GoToDir:m_RightPanelController.GetCurrentDirectoryPathRelativeToHost
                                   vfs:m_RightPanelController.VFS
                          select_entry:""
                                 async:true];
}

- (IBAction)OnSwapPanels:(id)sender{
    if(!self.isPanelActive || m_MainSplitView.AnyCollapsedOrOverlayed) return;
    
    swap(m_LeftPanelController, m_RightPanelController);
    [m_MainSplitView SwapViews];
    
    [m_LeftPanelController AttachToControls:m_LeftPanelSpinningIndicator share:m_LeftPanelShareButton];
    [m_RightPanelController AttachToControls:m_RightPanelSpinningIndicator share:m_RightPanelShareButton];
    
    [self SavePanelsSettings];
}

- (void)flagsChanged:(NSEvent *)event
{
    [m_LeftPanelController ModifierFlagsChanged:event.modifierFlags];
    [m_RightPanelController ModifierFlagsChanged:event.modifierFlags];
}

- (void)DeleteFiles:(BOOL)_shift_behavior
{
    if(!self.isPanelActive) return;
    if([m_MainSplitView IsViewCollapsedOrOverlayed:[self ActivePanelView]])
        return;
    
    auto files = make_shared<chained_strings>([self.ActivePanelController GetSelectedEntriesOrFocusedEntryWithoutDotDot]);
    if(files->empty())
        return;
    
    if([self ActivePanelData]->Host()->IsNativeFS())
    {
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
    else if([self ActivePanelData]->Host()->IsWriteable())
    {
        FileDeletionSheetController *sheet = [[FileDeletionSheetController alloc] init];
        [sheet ShowSheetForVFS:self.window
                         Files:files.get()
                       Handler:^(int result){
                           if (result == DialogResult::Delete)
                           {
                               string root_path = [self ActivePanelData]->DirectoryPathWithTrailingSlash();
                               FileDeletionOperation *op = [[FileDeletionOperation alloc]
                                                            initWithFiles:move(*files.get())
                                                            rootpath:root_path
                                                            at:[self ActivePanelData]->Host()];
                               op.TargetPanel = [self ActivePanelController];
                               [m_OperationsController AddOperation:op];
                           }
                       }];
    }
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
    if(!self.isPanelActive) return;
    if([m_MainSplitView IsViewCollapsedOrOverlayed:[self ActivePanelView]])
        return;
    PanelData *curdata = [self ActivePanelData];
    if( !curdata->Host()->IsWriteable() )
        return;

    CreateDirectorySheetController *cd = [CreateDirectorySheetController new];
    [cd ShowSheet:self.window handler:^(int _ret)
     {
         if(_ret == DialogResult::Create)
         {
             string pdir = curdata->DirectoryPathWithoutTrailingSlash();
             
             CreateDirectoryOperation *op = [CreateDirectoryOperation alloc];
             if(curdata->Host()->IsNativeFS())
                 op = [op initWithPath:cd.TextField.stringValue.fileSystemRepresentation
                              rootpath:pdir.c_str()
                       ];
             else
                 op = [op initWithPath:cd.TextField.stringValue.fileSystemRepresentation
                              rootpath:pdir.c_str()
                                    at:curdata->Host()
                       ];
             op.TargetPanel = [self ActivePanelController];
             [m_OperationsController AddOperation:op];
         }
     }];
}

- (IBAction)OnFileCopyCommand:(id)sender{
    if(!self.isPanelActive) return;
    if([m_MainSplitView AnyCollapsedOrOverlayed])
        return;
    
    const PanelData *source, *destination;
    if(m_LeftPanelController.isActive) {
        source = &m_LeftPanelController.data;
        destination = &m_RightPanelController.data;
    }
    else {
        source = &m_RightPanelController.data;
        destination = &m_LeftPanelController.data;
    }
    
    auto files = make_shared<chained_strings>([self.ActivePanelController GetSelectedEntriesOrFocusedEntryWithoutDotDot]);
    if(files->empty())
        return;
    
    string dest_path = destination->DirectoryPathWithTrailingSlash();
    NSString *nsdirpath = [NSString stringWithUTF8String:dest_path.c_str()];
    MassCopySheetController *mc = [MassCopySheetController new];
    [mc ShowSheet:self.window initpath:nsdirpath iscopying:true items:files.get() handler:^(int _ret)
     {
         path root_path = source->DirectoryPathWithTrailingSlash();
         path req_path = mc.TextField.stringValue.fileSystemRepresentation;
         if(_ret == DialogResult::Copy && !req_path.empty())
         {
             FileCopyOperationOptions opts;
             opts.docopy = true;
             [mc FillOptions:&opts];
             
             FileCopyOperation *op = [FileCopyOperation alloc];
             if(source->Host()->IsNativeFS() && destination->Host()->IsNativeFS())
                  op = [op initWithFiles:move(*files.get())
                                    root:root_path.c_str()
                                    dest:req_path.c_str()
                                 options:opts];
             else if(destination->Host()->IsNativeFS() && req_path.is_absolute() )
                  op = [op initWithFiles:move(*files.get())
                                    root:root_path.c_str()
                                 rootvfs:source->Host()
                                    dest:req_path.c_str()
                                 options:opts];
             else if( ( req_path.is_absolute() && destination->Host()->IsWriteable()) ||
                      (!req_path.is_absolute() && source->Host()->IsWriteable() )      )
                 op = [op initWithFiles:move(*files.get())
                                   root:root_path.c_str()
                                 srcvfs:source->Host()
                                   dest:req_path.c_str()
                                 dstvfs:destination->Host()
                                options:opts];
             else
                 op = nil;
             
            if(op) {
                [op AddOnFinishHandler:^{
                    dispatch_to_main_queue( ^{
                        [m_LeftPanelController RefreshDirectory];
                        [m_RightPanelController RefreshDirectory];
                    });
                }];
                [m_OperationsController AddOperation:op];
            }
         }
     }];
}

- (IBAction)OnFileCopyAsCommand:(id)sender{
    // process only current cursor item
    if(!self.isPanelActive) return;
    if([m_MainSplitView IsViewCollapsedOrOverlayed:[self ActivePanelView]])
        return;
    const PanelData *source, *destination;
    if(m_LeftPanelController.isActive)
    {
        source = &m_LeftPanelController.data;
        destination = &m_RightPanelController.data;
    }
    else
    {
        source = &m_RightPanelController.data;
        destination = &m_LeftPanelController.data;
    }
    
    auto const *item = self.ActivePanelView.item;
    if(!item || item->IsDotDot())
        return;
    
    auto files = make_shared<chained_strings>(item->Name());
    
    MassCopySheetController *mc = [MassCopySheetController new];
    [mc ShowSheet:self.window initpath:[NSString stringWithUTF8String:item->Name()] iscopying:true items:files.get() handler:^(int _ret)
     {
         path root_path = [self ActivePanelData]->DirectoryPathWithTrailingSlash();
         path req_path = mc.TextField.stringValue.fileSystemRepresentation;
         if(_ret == DialogResult::Copy && !req_path.empty())
         {
             FileCopyOperationOptions opts;
             opts.docopy = true;
             [mc FillOptions:&opts];
             
             FileCopyOperation *op = [FileCopyOperation alloc];
             if(source->Host()->IsNativeFS() &&
                ( destination->Host()->IsNativeFS() || !req_path.is_absolute() ) )
                 op = [op initWithFiles:move(*files.get())
                                   root:root_path.c_str()
                                   dest:req_path.c_str()
                                options:opts];
             else if(destination->Host()->IsNativeFS() && req_path.is_absolute() )
                 op = [op initWithFiles:move(*files.get())
                                   root:root_path.c_str()
                                rootvfs:source->Host()
                                   dest:req_path.c_str()
                                options:opts];
             else if( (destination->Host()->IsWriteable() && req_path.is_absolute()) ||
                      (source->Host()->IsWriteable()      &&!req_path.is_absolute())  )
                 op = [op initWithFiles:move(*files.get())
                                   root:root_path.c_str()
                                 srcvfs:source->Host()
                                   dest:req_path.c_str()
                                 dstvfs:destination->Host()
                                options:opts];
             else
                 op = nil;
                
             if(op)
             {
                 [op AddOnFinishHandler:^{
                    dispatch_to_main_queue( ^{
                        [m_LeftPanelController RefreshDirectory];
                        [m_RightPanelController RefreshDirectory];
                    });
                 }];
                 [m_OperationsController AddOperation:op];
             }
         }
     }];
}

- (IBAction)OnFileRenameMoveCommand:(id)sender{
    if(!self.isPanelActive) return;
    if([m_MainSplitView AnyCollapsedOrOverlayed])
        return;
    const PanelData *source, *destination;
    if(m_LeftPanelController.isActive)
    {
        source = &m_LeftPanelController.data;
        destination = &m_RightPanelController.data;
    }
    else
    {
        source = &m_RightPanelController.data;
        destination = &m_LeftPanelController.data;
    }
    
    if(!source->Host()->IsWriteable())
        return;
    
    auto files = make_shared<chained_strings>([self.ActivePanelController GetSelectedEntriesOrFocusedEntryWithoutDotDot]);
    if(files->empty())
        return;
    
    string dest_path = destination->DirectoryPathWithTrailingSlash();
    NSString *nsdirpath = [NSString stringWithUTF8String:dest_path.c_str()];
    
    MassCopySheetController *mc = [MassCopySheetController new];
    [mc ShowSheet:self.window initpath:nsdirpath iscopying:false items:files.get() handler:^(int _ret)
     {
         path root_path = source->DirectoryPathWithTrailingSlash();
         path req_path = mc.TextField.stringValue.fileSystemRepresentation;
         if(_ret == DialogResult::Copy && !req_path.empty())
         {
             FileCopyOperationOptions opts;
             opts.docopy = false;
             [mc FillOptions:&opts];
             
             FileCopyOperation *op = [FileCopyOperation alloc];
             if(source->Host()->IsNativeFS() &&
                ( destination->Host()->IsNativeFS() || !req_path.is_absolute() ) )
                 op = [op initWithFiles:move(*files.get())
                                   root:root_path.c_str()
                                   dest:req_path.c_str()
                                options:opts];
             else if( destination->Host()->IsWriteable() )
                 op = [op initWithFiles:move(*files.get())
                                   root:root_path.c_str()
                                 srcvfs:source->Host()
                                   dest:req_path.c_str()
                                 dstvfs:destination->Host()
                                options:opts];
             else
                 op = nil;
             
             
             if(op) {
                 [op AddOnFinishHandler:^{
                     dispatch_to_main_queue( ^{
                         [m_LeftPanelController RefreshDirectory];
                         [m_RightPanelController RefreshDirectory];
                     });
                 }];
                 [m_OperationsController AddOperation:op];
             }
         }
     }];
}

- (IBAction)OnFileRenameMoveAsCommand:(id)sender {
    
    // process only current cursor item
    if(!self.isPanelActive) return;
    if([m_MainSplitView IsViewCollapsedOrOverlayed:[self ActivePanelView]])
        return;
    
    const PanelData *source, *destination;
    if(m_LeftPanelController.isActive)
    {
        source = &m_LeftPanelController.data;
        destination = &m_RightPanelController.data;
    }
    else
    {
        source = &m_RightPanelController.data;
        destination = &m_LeftPanelController.data;
    }

    if(!source->Host()->IsWriteable())
        return;
    
    auto const *item = self.ActivePanelView.item;
    if(!item || item->IsDotDot())
        return;
    
    auto files = make_shared<chained_strings>(item->Name());
    
    MassCopySheetController *mc = [MassCopySheetController new];
    [mc ShowSheet:self.window initpath:[NSString stringWithUTF8String:item->Name()] iscopying:false items:files.get() handler:^(int _ret)
     {
         path root_path = source->DirectoryPathWithTrailingSlash();
         path req_path = mc.TextField.stringValue.fileSystemRepresentation;
         if(_ret == DialogResult::Copy && !req_path.empty())
         {
             FileCopyOperationOptions opts;
             opts.docopy = false;
             [mc FillOptions:&opts];
             
             FileCopyOperation *op = [FileCopyOperation alloc];
             
             if(source->Host()->IsNativeFS() &&
                ( destination->Host()->IsNativeFS() || !req_path.is_absolute() ))
                 op = [op initWithFiles:move(*files.get())
                                   root:root_path.c_str()
                                   dest:req_path.c_str()
                                options:opts];
             else if( destination->Host()->IsWriteable() )
                 op = [op initWithFiles:move(*files.get())
                                   root:root_path.c_str()
                                 srcvfs:source->Host()
                                   dest:req_path.c_str()
                                 dstvfs:destination->Host()
                                options:opts];
             else
                 op = nil;
             
             
             if(op) {
                 [op AddOnFinishHandler:^{
                     dispatch_to_main_queue( ^{
                         [m_LeftPanelController RefreshDirectory];
                         [m_RightPanelController RefreshDirectory];
                     });
                 }];
                 [m_OperationsController AddOperation:op];
             }
         }
     }];
}

- (void)PanelPathChanged:(PanelController*)_panel
{
    if(_panel == nil)
        return;

    if(_panel == self.ActivePanelController)
        [self UpdateTitle];
     
    if(_panel == m_LeftPanelController)
        [m_LeftPanelGoToButton SetCurrentPath:m_LeftPanelController.GetCurrentDirectoryPathRelativeToHost
                                           at:m_LeftPanelController.VFS];
    if(_panel == m_RightPanelController)
        [m_RightPanelGoToButton SetCurrentPath:m_RightPanelController.GetCurrentDirectoryPathRelativeToHost
                                            at:m_RightPanelController.VFS];
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
    [self UpdateTitle];
}

- (void)WindowWillClose
{
   [self SavePanelPaths];
}

- (void)SavePanelPaths
{
    string lp = m_LeftPanelController.VFS->IsNativeFS() ?
        m_LeftPanelController.GetCurrentDirectoryPathRelativeToHost : "";
    [NSUserDefaults.standardUserDefaults setObject:[NSString stringWithUTF8String:lp.c_str()] forKey:@"FirstPanelPath"];
    string rp = m_RightPanelController.VFS->IsNativeFS() ?
        m_RightPanelController.GetCurrentDirectoryPathRelativeToHost : "";
    [NSUserDefaults.standardUserDefaults setObject:[NSString stringWithUTF8String:rp.c_str()] forKey:@"SecondPanelPath"];
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

- (void)RevealEntries:(chained_strings)_entries inPath:(const string&)_path
{
    assert(dispatch_is_main_queue());
    auto data = self.ActivePanelData;
    if(!data)
        return;
    
    PanelController *panel = self.ActivePanelController;
    if([panel GoToDir:_path vfs:VFSNativeHost::SharedHost() select_entry:"" async:false] == VFSError::Ok)
    {
        if(!_entries.empty())
            [panel ScheduleDelayedSelectionChangeFor:_entries.front().c_str()
                                           timeoutms:100
                                            checknow:true];
        
        for(auto &i: _entries)
            data->CustomFlagsSelectSorted(data->SortedIndexForName(i.c_str()), true);
        
        [self.ActivePanelView setNeedsDisplay:true];
    }
}

- (void)OnApplicationWillTerminate
{
    [self SavePanelPaths];
}

- (IBAction)OnCreateSymbolicLinkCommand:(id)sender
{
    if(!self.isPanelActive) return;
    if(m_MainSplitView.AnyCollapsedOrOverlayed) return;
    
    if(!m_RightPanelController.VFS->IsNativeFS() || !m_LeftPanelController.VFS->IsNativeFS())
        return; // currently support links only on native fs
    
    string link_path;
    auto const *item = self.ActivePanelView.item;
    if(!item)
        return;
    
    string source_path = [self ActivePanelData]->DirectoryPathWithTrailingSlash();
    if(!item->IsDotDot())
        source_path += item->Name();
    
    if(m_LeftPanelController.isActive)
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
    auto data = self.ActivePanelData;
    if(!data) return;
    if([m_MainSplitView IsViewCollapsedOrOverlayed:self.ActivePanelView])
        return;
    if(!data->Host()->IsNativeFS())
        return; // currently support links only on native fs
    
//    char link_path[MAXPATHLEN];
    auto const *item = self.ActivePanelView.item;
    if(!item)
        return;
    if(item->IsDotDot())
        return;
    if(item->IsSymlink())
    {
        NSAlert *alert = [NSAlert new];
        [alert setMessageText: @"Failed to edit"];
        [alert setInformativeText:
         [NSString stringWithFormat:@"\'%@\' is not a symbolic link.", item->NSName()]];
        [alert runModal];
        return;
    }
    
    string link_path = data->DirectoryPathWithTrailingSlash() + item->Name();
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
    if(!self.isPanelActive) return;
    if([m_MainSplitView AnyCollapsedOrOverlayed])
        return;
    if(!m_RightPanelController.VFS->IsNativeFS() || !m_LeftPanelController.VFS->IsNativeFS())
        return; // currently support links only on native fs
    
    auto const *item = self.ActivePanelView.item;
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
                                              options:opts]];
    }
}

- (IBAction)copy:(id)sender
{
    [self WriteToPasteboard:NSPasteboard.generalPasteboard];
    // check if we're on native fs now (all others vfs are not-accessible by system and so useless)
}

- (void)GetFilePanelsNativePaths:(vector<string> &)_paths
{
    _paths.clear();
    if(m_LeftPanelController.VFS->IsNativeFS())
      _paths.push_back(m_LeftPanelController.GetCurrentDirectoryPathRelativeToHost);
    if(m_RightPanelController.VFS->IsNativeFS())
        _paths.push_back(m_LeftPanelController.GetCurrentDirectoryPathRelativeToHost);
}

- (QuickLookView*)RequestQuickLookView:(PanelController*)_panel
{
    QuickLookView *view = [[QuickLookView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
    if(_panel == m_LeftPanelController)
        m_MainSplitView.rightOverlay = view;
    else if(_panel == m_RightPanelController)
        m_MainSplitView.leftOverlay = view;
    else
        return nil;
    return view;
}

- (BriefSystemOverview*)RequestBriefSystemOverview:(PanelController*)_panel
{
    BriefSystemOverview *view = [[BriefSystemOverview alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
    if(_panel == m_LeftPanelController)
        m_MainSplitView.rightOverlay = view;
    else if(_panel == m_RightPanelController)
        m_MainSplitView.leftOverlay = view;
    else
        return nil;
    return view;
}

- (void)CloseOverlay:(PanelController*)_panel
{
    if(_panel == m_LeftPanelController)
        m_MainSplitView.rightOverlay = 0;
    else if(_panel == m_RightPanelController)
        m_MainSplitView.leftOverlay = 0;
}

- (void) AddOperation:(Operation*)_operation
{
    [m_OperationsController AddOperation:_operation];
}

@end

//
//  MainWindowFilePanelState+Menu.m
//  Files
//
//  Created by Michael G. Kazakov on 19.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "MainWindowFilePanelState+Menu.h"
#import "ActionsShortcutsManager.h"
#import "PanelController.h"
#import "FileDeletionOperation.h"
#import "FilePanelMainSplitView.h"
#import "OperationsController.h"
#import "Common.h"
#import "common_paths.h"
#import "ExternalEditorInfo.h"
#import "MainWindowController.h"
#import "FileCompressOperation.h"
#import "FileLinkNewSymlinkSheetController.h"
#import "FileLinkAlterSymlinkSheetController.h"
#import "FileLinkNewHardlinkSheetController.h"
#import "FileLinkOperation.h"
#import "FileCopyOperation.h"
#import "MassCopySheetController.h"

static auto g_DefsGeneralShowTabs = @"GeneralShowTabs";

@implementation MainWindowFilePanelState (Menu)

- (BOOL) validateMenuItem:(NSMenuItem *)item
{
    auto tag = item.tag;
    IF_MENU_TAG("menu.view.swap_panels")             return self.isPanelActive && !m_MainSplitView.anyCollapsedOrOverlayed;
    IF_MENU_TAG("menu.view.sync_panels")             return self.isPanelActive && !m_MainSplitView.anyCollapsedOrOverlayed;
    IF_MENU_TAG("menu.file.open_in_opposite_panel")  return self.isPanelActive && !m_MainSplitView.anyCollapsedOrOverlayed && self.activePanelView.item && self.activePanelView.item->IsDir();
    IF_MENU_TAG("menu.command.compress")             return self.isPanelActive && !m_MainSplitView.anyCollapsedOrOverlayed && self.activePanelView.item && !self.activePanelView.item->IsDotDot();
    IF_MENU_TAG("menu.command.link_create_soft")     return self.isPanelActive && !m_MainSplitView.anyCollapsedOrOverlayed && self.activePanelView.item && !self.activePanelView.item->IsDotDot() && self.leftPanelController.vfs->IsNativeFS() && self.rightPanelController.vfs->IsNativeFS();
    IF_MENU_TAG("menu.command.link_create_hard")     return self.isPanelActive && !m_MainSplitView.anyCollapsedOrOverlayed && self.activePanelView.item && self.leftPanelController.vfs->IsNativeFS() && self.rightPanelController.vfs->IsNativeFS() && !self.activePanelView.item->IsDir();
    IF_MENU_TAG("menu.command.link_edit")            return self.isPanelActive && !m_MainSplitView.anyCollapsedOrOverlayed && self.activePanelView.item && self.activePanelController.vfs->IsNativeFS() && self.activePanelView.item->IsSymlink();
    IF_MENU_TAG("menu.command.copy_to")              return self.isPanelActive && !m_MainSplitView.anyCollapsedOrOverlayed;
    IF_MENU_TAG("menu.command.copy_as")              return self.isPanelActive && !m_MainSplitView.anyCollapsedOrOverlayed;
    IF_MENU_TAG("menu.command.move_to")              return self.isPanelActive && !m_MainSplitView.anyCollapsedOrOverlayed;
    IF_MENU_TAG("menu.command.move_as")              return self.isPanelActive && !m_MainSplitView.anyCollapsedOrOverlayed;
    IF_MENU_TAG("menu.file.close") {
        unsigned tabs = self.currentSideTabsCount;
        if( tabs == 0 ) {
            // in this case (no other adequate responders) - pass validation  up
            NSResponder *resp = self;
            while( (resp = resp.nextResponder) )
                if( [resp respondsToSelector:item.action] && [resp respondsToSelector:@selector(validateMenuItem:)] )
                    return [resp validateMenuItem:item];
            return true;
        }
        item.title = tabs > 1 ? @"Close Tab" : @"Close Window" ;
        return true;
    }
    IF_MENU_TAG("menu.file.close_window") {
        item.hidden = self.currentSideTabsCount < 2;
        return true;
    }
    IF_MENU_TAG("menu.window.show_previous_tab")    return self.currentSideTabsCount > 1;
    IF_MENU_TAG("menu.window.show_next_tab")        return self.currentSideTabsCount > 1;
    IF_MENU_TAG("menu.view.show_tabs") {
        item.title = [NSUserDefaults.standardUserDefaults boolForKey:g_DefsGeneralShowTabs] ?
            @"Hide Tab Bar" : @"Show Tab Bar";
        return true;
    }
    IF_MENU_TAG("menu.view.show_terminal") {
        item.title = @"Show Terminal";
        return true;
    }
    
    return true;
}

- (IBAction)OnSyncPanels:(id)sender
{
    if(!self.activePanelController || !self.oppositePanelController || m_MainSplitView.anyCollapsedOrOverlayed)
        return;
    
    [self.oppositePanelController GoToDir:self.activePanelController.currentDirectoryPath
                                      vfs:self.activePanelController.vfs
                             select_entry:""
                                    async:true];
}

- (IBAction)OnSwapPanels:(id)sender
{
    if(m_MainSplitView.anyCollapsedOrOverlayed)
        return;
    
    swap(m_LeftPanelControllers, m_RightPanelControllers);
    [m_MainSplitView SwapViews];
    
    [self.leftPanelController AttachToControls:m_LeftPanelSpinningIndicator share:m_LeftPanelShareButton];
    [self.rightPanelController AttachToControls:m_RightPanelSpinningIndicator share:m_RightPanelShareButton];
    
    [self savePanelsOptions];
}

- (IBAction)OnShowTerminal:(id)sender
{
    string path = "";
    if(self.isPanelActive && self.activePanelController.vfs->IsNativeFS())
        path = self.activePanelController.currentDirectoryPath;
    [(MainWindowController*)self.window.delegate RequestTerminal:path];
}

- (IBAction)OnFileOpenInOppositePanel:(id)sender
{
    if(!self.isPanelActive || m_MainSplitView.anyCollapsedOrOverlayed || !self.activePanelView.item || !self.activePanelView.item->IsDir()) return;
    auto cur = self.activePanelController;
    auto opp = self.oppositePanelController;
    [opp GoToDir:cur.currentFocusedEntryPath
             vfs:cur.vfs
    select_entry:""
           async:true];
}

- (IBAction)OnCompressFiles:(id)sender
{
    if(!self.isPanelActive || m_MainSplitView.anyCollapsedOrOverlayed) return;
    
    auto files = self.activePanelController.selectedEntriesOrFocusedEntryFilenames;
    if(files.empty())
        return;

    FileCompressOperation *op = [[FileCompressOperation alloc] initWithFiles:move(files)
                                                                     srcroot:self.activePanelController.currentDirectoryPath
                                                                      srcvfs:self.activePanelController.vfs
                                                                     dstroot:self.oppositePanelController.currentDirectoryPath
                                                                      dstvfs:self.oppositePanelController.vfs];
    op.TargetPanel = self.oppositePanelController;
    [m_OperationsController AddOperation:op];
}

- (IBAction)OnCreateSymbolicLinkCommand:(id)sender
{
    if(!self.activePanelController || !self.oppositePanelController)
        return;
    
    auto const *item = self.activePanelView.item;
    if(!item)
        return;
    
    string source_path = [self activePanelData]->DirectoryPathWithTrailingSlash();
    if(!item->IsDotDot())
        source_path += item->Name();
    
    string link_path = self.oppositePanelController.currentDirectoryPath;
    
    if(!item->IsDotDot())
        link_path += item->Name();
    else
        link_path += [self activePanelData]->DirectoryPathShort();
    
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
    auto data = self.activePanelData;
    auto const *item = self.activePanelView.item;
    assert(item->IsSymlink());
    
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
    auto const *item = self.activePanelView.item;
    assert(not item->IsDir());
    
    string dir_path = [self activePanelData]->DirectoryPathWithTrailingSlash();
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

- (IBAction)OnFileCopyCommand:(id)sender{
    if(!self.activePanelController || !self.oppositePanelController) return;
    if([m_MainSplitView anyCollapsedOrOverlayed])
        return;
    
    const PanelData *source, *destination;
    source = &self.activePanelController.data;
    destination = &self.oppositePanelController.data;
    __weak PanelController *act = self.activePanelController;
    __weak PanelController *opp = self.oppositePanelController;
    
    auto files = make_shared<chained_strings>([self.activePanelController GetSelectedEntriesOrFocusedEntryWithoutDotDot]);
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
                     dispatch_to_main_queue( [=]{
                         [(PanelController*)act RefreshDirectory];
                         [(PanelController*)opp RefreshDirectory];
                     });
                 }];
                 [m_OperationsController AddOperation:op];
             }
         }
     }];
}

- (IBAction)OnFileCopyAsCommand:(id)sender{
    // process only current cursor item
    if(!self.activePanelController || !self.oppositePanelController) return;
    if([m_MainSplitView isViewCollapsedOrOverlayed:self.activePanelView])
        return;
    const PanelData *source, *destination;
    source = &self.activePanelController.data;
    destination = &self.oppositePanelController.data;
    __weak PanelController *act = self.activePanelController;
    __weak PanelController *opp = self.oppositePanelController;
    
    auto const *item = self.activePanelView.item;
    if(!item || item->IsDotDot())
        return;
    
    auto files = make_shared<chained_strings>(item->Name());
    
    MassCopySheetController *mc = [MassCopySheetController new];
    [mc ShowSheet:self.window initpath:[NSString stringWithUTF8String:item->Name()] iscopying:true items:files.get() handler:^(int _ret)
     {
         path root_path = self.activePanelData->DirectoryPathWithTrailingSlash();
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
                     dispatch_to_main_queue( [=]{
                         [(PanelController*)act RefreshDirectory];
                         [(PanelController*)opp RefreshDirectory];
                     });
                 }];
                 [m_OperationsController AddOperation:op];
             }
         }
     }];
}

- (IBAction)OnFileRenameMoveCommand:(id)sender{
    if(!self.activePanelController || !self.oppositePanelController) return;
    if([m_MainSplitView anyCollapsedOrOverlayed])
        return;
    const PanelData *source, *destination;
    source = &self.activePanelController.data;
    destination = &self.oppositePanelController.data;
    __weak PanelController *act = self.activePanelController;
    __weak PanelController *opp = self.oppositePanelController;
    
    if(!source->Host()->IsWriteable())
        return;
    
    auto files = make_shared<chained_strings>([self.activePanelController GetSelectedEntriesOrFocusedEntryWithoutDotDot]);
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
                     dispatch_to_main_queue( [=]{
                         [(PanelController*)act RefreshDirectory];
                         [(PanelController*)opp RefreshDirectory];
                     });
                 }];
                 [m_OperationsController AddOperation:op];
             }
         }
     }];
}

- (IBAction)OnFileRenameMoveAsCommand:(id)sender {
    
    // process only current cursor item
    if(!self.activePanelController || !self.oppositePanelController) return;
    if([m_MainSplitView isViewCollapsedOrOverlayed:self.activePanelView])
        return;
    
    const PanelData *source, *destination;
    source = &self.activePanelController.data;
    destination = &self.oppositePanelController.data;
    __weak PanelController *act = self.activePanelController;
    __weak PanelController *opp = self.oppositePanelController;
    
    if(!source->Host()->IsWriteable())
        return;
    
    auto const *item = self.activePanelView.item;
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
                 string single_fn_rename;
                 if( req_path.native().find('/') == string::npos )
                     single_fn_rename = req_path.filename().native();
                 
                 [op AddOnFinishHandler:^{
                     dispatch_to_main_queue( [=]{
                         PanelController* active = act;
                         [active RefreshDirectory];
                         [(PanelController*)opp RefreshDirectory];
                         PanelControllerDelayedSelection req;
                         req.filename = single_fn_rename;
                         [active ScheduleDelayedSelectionChangeFor:req checknow:true];
                     });
                 }];
                 [m_OperationsController AddOperation:op];
             }
         }
     }];
}

- (IBAction)OnFileNewTab:(id)sender
{
    if(!self.activePanelController)
        return;
    if(self.activePanelController == self.leftPanelController)
       [self addNewTabToTabView:m_MainSplitView.leftTabbedHolder.tabView];
    else if(self.activePanelController == self.rightPanelController)
        [self addNewTabToTabView:m_MainSplitView.rightTabbedHolder.tabView];
}

- (IBAction)performClose:(id)sender
{
    PanelController *cur = self.activePanelController;
    int tabs = 1;
    if( [self isLeftController:cur] )
        tabs = m_MainSplitView.leftTabbedHolder.tabsCount;
    if( [self isRightController:cur] )
        tabs = m_MainSplitView.rightTabbedHolder.tabsCount;

    if(tabs > 1)
        [self closeCurrentTab];
    else
        [self.window performClose:sender];
}

- (IBAction)OnFileCloseWindow:(id)sender
{
    [self.window performClose:sender];
}

- (IBAction)OnWindowShowPreviousTab:(id)sender
{
    [self selectPreviousFilePanelTab];
}

- (IBAction)OnWindowShowNextTab:(id)sender
{
    [self selectNextFilePanelTab];
}

- (BOOL)performKeyEquivalent:(NSEvent *)theEvent
{
    NSString* characters = theEvent.charactersIgnoringModifiers;
    if ( characters.length != 1 )
        return [super performKeyEquivalent:theEvent];
    
    auto mod = theEvent.modifierFlags;
    mod &= ~NSAlphaShiftKeyMask;
    mod &= ~NSNumericPadKeyMask;
    mod &= ~NSFunctionKeyMask;
    auto unicode = [characters characterAtIndex:0];
    
    // workaround for (shift)+ctrl+tab when it's menu item is disabled. mysterious stuff...
    if( unicode == NSTabCharacter && (mod & NSDeviceIndependentModifierFlagsMask) == NSControlKeyMask ) {
        static const int next_tab = ActionsShortcutsManager::Instance().TagFromAction("menu.window.show_next_tab");
        if([NSApplication.sharedApplication.menu itemWithTagHierarchical:next_tab].enabled)
            return [super performKeyEquivalent:theEvent];
        return true;
    }
    if( unicode == NSTabCharacter && (mod & NSDeviceIndependentModifierFlagsMask) == (NSControlKeyMask|NSShiftKeyMask) ) {
        static const int prev_tab = ActionsShortcutsManager::Instance().TagFromAction("menu.window.show_previous_tab");
        if([NSApplication.sharedApplication.menu itemWithTagHierarchical:prev_tab].enabled)
            return [super performKeyEquivalent:theEvent];
        return true;
    }
    
    return [super performKeyEquivalent:theEvent];
}

- (IBAction)OnShowTabs:(id)sender
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:![defaults boolForKey:g_DefsGeneralShowTabs] forKey:g_DefsGeneralShowTabs];
}

@end

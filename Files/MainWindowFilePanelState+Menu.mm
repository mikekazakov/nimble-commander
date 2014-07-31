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

@implementation MainWindowFilePanelState (Menu)

- (BOOL) validateMenuItem:(NSMenuItem *)item
{
#define TAG(name, str) static const int name = ActionsShortcutsManager::Instance().TagFromAction(str)
    TAG(tag_view_swap_panels,           "menu.view.swap_panels");
    TAG(tag_view_sync_panels,           "menu.view.sync_panels");
    TAG(tag_file_open_in_opp,           "menu.file.open_in_opposite_panel");
    TAG(tag_cmd_compress,               "menu.command.compress");
    TAG(tag_cmd_link_soft,              "menu.command.link_create_soft");
    TAG(tag_cmd_link_hard,              "menu.command.link_create_hard");
    TAG(tag_cmd_link_edit,              "menu.command.link_edit");
#undef TAG
    
    auto tag = item.tag;
#define IF(a) else if(tag == a)
    if(false);
    IF(tag_view_swap_panels)        return self.isPanelActive && !m_MainSplitView.AnyCollapsedOrOverlayed;
    IF(tag_view_sync_panels)        return self.isPanelActive && !m_MainSplitView.AnyCollapsedOrOverlayed;
    IF(tag_file_open_in_opp)        return self.isPanelActive && !m_MainSplitView.AnyCollapsedOrOverlayed && self.ActivePanelView.item && self.ActivePanelView.item->IsDir();
    IF(tag_cmd_compress)            return self.isPanelActive && !m_MainSplitView.AnyCollapsedOrOverlayed && self.ActivePanelView.item && !self.ActivePanelView.item->IsDotDot();
    IF(tag_cmd_link_soft)           return self.isPanelActive && !m_MainSplitView.AnyCollapsedOrOverlayed && self.ActivePanelView.item && !self.ActivePanelView.item->IsDotDot() && m_LeftPanelController.VFS->IsNativeFS() && m_RightPanelController.VFS->IsNativeFS();
    IF(tag_cmd_link_hard)           return self.isPanelActive && !m_MainSplitView.AnyCollapsedOrOverlayed && self.ActivePanelView.item && m_LeftPanelController.VFS->IsNativeFS() && m_RightPanelController.VFS->IsNativeFS() && !self.ActivePanelView.item->IsDir();
    IF(tag_cmd_link_edit)           return self.isPanelActive && !m_MainSplitView.AnyCollapsedOrOverlayed && self.ActivePanelView.item && self.ActivePanelController.VFS->IsNativeFS() && !self.ActivePanelView.item->IsDir() && self.ActivePanelView.item->IsSymlink();
#undef IF
    
    return true;
}

- (IBAction)OnSyncPanels:(id)sender
{
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

- (IBAction)OnSwapPanels:(id)sender
{
    swap(m_LeftPanelController, m_RightPanelController);
    [m_MainSplitView SwapViews];
    
    [m_LeftPanelController AttachToControls:m_LeftPanelSpinningIndicator share:m_LeftPanelShareButton];
    [m_RightPanelController AttachToControls:m_RightPanelSpinningIndicator share:m_RightPanelShareButton];
    
    [self savePanelsOptions];
}

- (IBAction)OnShowTerminal:(id)sender
{
    string path = "";
    if(self.isPanelActive && self.ActivePanelController.VFS->IsNativeFS())
        path = self.ActivePanelController.GetCurrentDirectoryPathRelativeToHost;
    [(MainWindowController*)self.window.delegate RequestTerminal:path];
}

- (IBAction)OnFileOpenInOppositePanel:(id)sender
{
    if(!self.isPanelActive || m_MainSplitView.AnyCollapsedOrOverlayed || !self.ActivePanelView.item || !self.ActivePanelView.item->IsDir()) return;
    auto cur = self.ActivePanelController == m_LeftPanelController ? m_LeftPanelController : m_RightPanelController;
    auto opp = self.ActivePanelController == m_LeftPanelController ?  m_RightPanelController : m_LeftPanelController;
    [opp GoToDir:cur.GetCurrentFocusedEntryFilePathRelativeToHost
             vfs:cur.VFS
    select_entry:""
           async:true];
}

- (IBAction)OnCompressFiles:(id)sender
{
    if(!self.isPanelActive || m_MainSplitView.AnyCollapsedOrOverlayed) return;
    
    auto files = [self.ActivePanelController GetSelectedEntriesOrFocusedEntryWithoutDotDot];
    if(files.empty())
        return;
    shared_ptr<VFSHost> srcvfs, dstvfs;
    string srcroot, dstroot;
    PanelController *target_pc;
    if([self ActivePanelController] == m_LeftPanelController) {
        srcvfs = m_LeftPanelController.VFS;
        dstvfs = m_RightPanelController.VFS;
        srcroot = [m_LeftPanelController GetCurrentDirectoryPathRelativeToHost];
        dstroot = [m_RightPanelController GetCurrentDirectoryPathRelativeToHost];
        target_pc = m_RightPanelController;
    }
    else {
        srcvfs = m_RightPanelController.VFS;
        dstvfs = m_LeftPanelController.VFS;
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

- (IBAction)OnCreateSymbolicLinkCommand:(id)sender
{
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
    auto const *item = self.ActivePanelView.item;
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
    auto const *item = self.ActivePanelView.item;
    assert(not item->IsDir());
    
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

@end

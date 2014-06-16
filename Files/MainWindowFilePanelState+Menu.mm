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

@implementation MainWindowFilePanelState (Menu)

- (BOOL) validateMenuItem:(NSMenuItem *)item
{
#define TAG(name, str) static const int name = ActionsShortcutsManager::Instance().TagFromAction(str)
    TAG(tag_file_open_in_opp,           "menu.file.open_in_opposite_panel");
    TAG(tag_cmd_compress,               "menu.command.compress");
    TAG(tag_cmd_move_to_trash,          "menu.command.move_to_trash");
#undef TAG
    
    auto tag = item.tag;
#define IF(a) else if(tag == a)
    if(false);
    IF(tag_file_open_in_opp)        return self.isPanelActive && !m_MainSplitView.AnyCollapsedOrOverlayed && self.ActivePanelView.item && self.ActivePanelView.item->IsDir();
    IF(tag_cmd_compress)            return self.isPanelActive && !m_MainSplitView.AnyCollapsedOrOverlayed && self.ActivePanelView.item && !self.ActivePanelView.item->IsDotDot();
    IF(tag_cmd_move_to_trash)       return self.isPanelActive && self.ActivePanelView.item && (!self.ActivePanelView.item->IsDotDot() || self.ActivePanelData->Stats().selected_entries_amount > 0)  && (self.ActivePanelController.VFS->IsNativeFS() || self.ActivePanelController.VFS->IsWriteable());
#undef IF
    
    return true;
}

- (IBAction)OnMoveToTrash:(id)sender
{
    if(!self.isPanelActive) return;
    
    if(self.ActivePanelController.VFS->IsNativeFS() == false &&
       self.ActivePanelController.VFS->IsWriteable() == true )
    {
        // instead of trying to silently reap files on VFS like FTP (that means we'll erase it, not move to trash) -
        // forward request as a regular F8 delete
        [self OnDeleteCommand:self];
        return;
    }
    
    auto files = self.ActivePanelController.GetSelectedEntriesOrFocusedEntryWithoutDotDot;
    if(files.empty())
        return;
    
    FileDeletionOperation *op = [[FileDeletionOperation alloc]
                                 initWithFiles:move(files)
                                 type:FileDeletionOperationType::MoveToTrash
                                 rootpath:[self ActivePanelData]->DirectoryPathWithTrailingSlash().c_str()];
    op.TargetPanel = [self ActivePanelController];
    [m_OperationsController AddOperation:op];
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

@end

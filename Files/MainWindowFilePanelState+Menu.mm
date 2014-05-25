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

@implementation MainWindowFilePanelState (Menu)

- (BOOL) validateMenuItem:(NSMenuItem *)item
{
#define TAG(name, str) static const int name = ActionsShortcutsManager::Instance().TagFromAction(str)
    TAG(tag_file_open_in_opp,         "menu.file.open_in_opposite_panel");
#undef TAG
    
    auto tag = item.tag;
#define IF(a) else if(tag == a)
    if(false);
    IF(tag_file_open_in_opp)        return self.isPanelActive && !m_MainSplitView.AnyCollapsedOrOverlayed && self.ActivePanelView.item && self.ActivePanelView.item->IsDir();
#undef IF
    
    return true;
}

- (IBAction)OnMoveToTrash:(id)sender
{
    if([m_MainSplitView IsViewCollapsedOrOverlayed:[self ActivePanelView]])
        return;
    
    if([self ActivePanelData]->Host()->IsNativeFS() == false &&
       [self ActivePanelData]->Host()->IsWriteable() == true )
    {
        // instead of trying to silently reap files on VFS like FTP (that means we'll erase it, not move to trash) -
        // forward request as a regular F8 delete
        [self OnDeleteCommand:self];
        return;
    }
    
    auto files = [self.ActivePanelController GetSelectedEntriesOrFocusedEntryWithoutDotDot];
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
@end

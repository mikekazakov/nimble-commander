//
//  MainWindowFilePanelState+Menu.m
//  Files
//
//  Created by Michael G. Kazakov on 19.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "MainWindowFilePanelState+Menu.h"
#import "PanelController.h"
#import "FileDeletionOperation.h"
#import "FilePanelMainSplitView.h"
#import "GoToFolderSheetController.h"
#import "OperationsController.h"
#import "Common.h"
#import "common_paths.h"
#import "ExternalEditorInfo.h"
#import "MainWindowController.h"

@implementation MainWindowFilePanelState (Menu)

- (IBAction)OnGoToHome:(id)sender
{
    [self DoGoToNativeDirectoryFromMenuItem:CommonPaths::Get(CommonPaths::Home)];
}

- (IBAction)OnGoToDocuments:(id)sender
{
    [self DoGoToNativeDirectoryFromMenuItem:CommonPaths::Get(CommonPaths::Documents)];
}

- (IBAction)OnGoToDesktop:(id)sender
{
    [self DoGoToNativeDirectoryFromMenuItem:CommonPaths::Get(CommonPaths::Desktop)];
}

- (IBAction)OnGoToDownloads:(id)sender
{
    [self DoGoToNativeDirectoryFromMenuItem:CommonPaths::Get(CommonPaths::Downloads)];
}

- (IBAction)OnGoToApplications:(id)sender
{
    [self DoGoToNativeDirectoryFromMenuItem:CommonPaths::Get(CommonPaths::Applications)];
}

- (IBAction)OnGoToUtilities:(id)sender
{
    [self DoGoToNativeDirectoryFromMenuItem:CommonPaths::Get(CommonPaths::Utilities)];
}

- (IBAction)OnGoToLibrary:(id)sender
{
    [self DoGoToNativeDirectoryFromMenuItem:CommonPaths::Get(CommonPaths::Library)];
}

- (void) DoGoToNativeDirectoryFromMenuItem:(string)_path
{
    if(m_LeftPanelController.isActive)
    {
        m_MainSplitView.leftOverlay = nil; // seem to be a redundant
        [m_LeftPanelController GoToDir:_path
                                   vfs:VFSNativeHost::SharedHost()
                          select_entry:""
                                 async:true];
    }
    else if(m_RightPanelController.isActive)
    {
        m_MainSplitView.rightOverlay = nil; // seem to be a redundant
        [m_RightPanelController GoToDir:_path
                                    vfs:VFSNativeHost::SharedHost()
                           select_entry:""
                                  async:true];
    }
}

- (IBAction)OnGoBack:(id)sender
{
    [self.ActivePanelController OnGoBack];
}

- (IBAction)OnGoForward:(id)sender
{
    [self.ActivePanelController OnGoForward];
}

- (IBAction)OnGoToFolder:(id)sender
{
    GoToFolderSheetController *sheet = [GoToFolderSheetController new];
    [sheet ShowSheet:self.window handler:^int(){
        string path = [sheet.Text.stringValue fileSystemRepresentation];
        assert(!path.empty());
        if(path[0] == '/') {
            // absolute path
            [self.ActivePanelController GoToDir:path
                                        vfs:VFSNativeHost::SharedHost()
                               select_entry:""
                                      async:true];
        } else if(path[0] == '~') {
            // relative to home
            path.replace(0, 1, CommonPaths::Get(CommonPaths::Home));
            [self.ActivePanelController GoToDir:path
                                            vfs:VFSNativeHost::SharedHost()
                                   select_entry:""
                                          async:true];
        } else {
            // sub-dir
            path.insert(0, [self.ActivePanelController GetCurrentDirectoryPathRelativeToHost]);
            [self.ActivePanelController GoToDir:path
                                            vfs:VFSNativeHost::SharedHost() // not sure if this is right, mb .VFS?
                                   select_entry:""
                                          async:true];
        }

        return 0;
    }];

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

- (IBAction)OnOpenWithExternalEditor:(id)sender
{
    if([m_MainSplitView IsViewCollapsedOrOverlayed:[self ActivePanelView]])
        return;
    
    if(self.ActivePanelController.VFS->IsNativeFS() == false)
        return;
    
    auto item = self.ActivePanelView.item;
    if(item != nullptr && item->IsDotDot() == false)
    {
        ExternalEditorInfo *ed = [ExternalEditorsList.sharedList FindViableEditorForItem:*item];
        if(ed == nil)
        {
            NSBeep();
            return;
        }

        string fn_path = self.ActivePanelController.GetCurrentDirectoryPathRelativeToHost + item->Name();
        if(ed.terminal == false)
        {
            if (![NSWorkspace.sharedWorkspace openFile:[NSString stringWithUTF8String:fn_path.c_str()]
                                       withApplication:ed.path
                                         andDeactivate:true])
                NSBeep();
        }
        else
        {
            MainWindowController* wnd = (MainWindowController*)self.window.delegate;
            [wnd RequestExternalEditorTerminalExecution:ed.path.fileSystemRepresentation
                                                 params:[ed substituteFileName:fn_path]
                                                   file:fn_path
             ];
        }
    }
}

@end

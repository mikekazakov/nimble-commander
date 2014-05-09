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

- (IBAction)OnOpen:(id)sender
{
    [[self ActivePanelController] HandleGoIntoDirOrOpenInSystem];
}

- (IBAction)OnOpenNatively:(id)sender
{
    [[self ActivePanelController] HandleOpenInSystem];
}

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

- (void) DoGoToNativeDirectoryFromMenuItem:(std::string)_path
{
    if(m_ActiveState == StateLeftPanel)
    {
        [m_MainSplitView SetLeftOverlay:0]; // seem to be a redundant
        [m_LeftPanelController GoToGlobalHostsPathAsync:_path.c_str()];
    }
    else if(m_ActiveState == StateRightPanel)
    {
        [m_MainSplitView SetRightOverlay:0]; // seem to be a redundant
        [m_RightPanelController GoToGlobalHostsPathAsync:_path.c_str()];
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
            return [self.ActivePanelController GoToGlobalHostsPathSync: path.c_str()];
        } else if(path[0] == '~') {
            // relative to home
            path.replace(0, 1, CommonPaths::Get(CommonPaths::Home));
            return [self.ActivePanelController GoToGlobalHostsPathSync: path.c_str()];
        } else {
            // sub-dir
            path.insert(0, [self.ActivePanelController GetCurrentDirectoryPathRelativeToHost]);
            return [self.ActivePanelController GoToGlobalHostsPathSync:path.c_str()];
        }

        return 0;
    }];
}

- (IBAction)OnCalculateSizes:(id)sender
{
    [[self ActivePanelController] HandleCalculateSizes];
}

- (IBAction)OnCalculateAllSizes:(id)sender
{
    [[self ActivePanelController] HandleCalculateAllSizes];
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

- (IBAction)performFindPanelAction:(id)sender
{
    if([m_MainSplitView IsViewCollapsedOrOverlayed:[self ActivePanelView]])
        return;
    [self.ActivePanelController HandleFileSearch];
}

- (IBAction)OnEjectVolume:(id)sender
{
    if([m_MainSplitView IsViewCollapsedOrOverlayed:[self ActivePanelView]])
        return;
    
    [self.ActivePanelController HandleEjectVolume];    
}

- (IBAction)OnGoToUpperDirectory:(id)sender
{
    if([m_MainSplitView IsViewCollapsedOrOverlayed:[self ActivePanelView]])
        return;
    [[self ActivePanelController] GoToUpperDirectoryAsync];
}

- (IBAction)OnGoIntoDirectory:(id)sender
{
    if([m_MainSplitView IsViewCollapsedOrOverlayed:[self ActivePanelView]])
        return;
    auto item = self.ActivePanelView.CurrentItem;
    if(item != nullptr && item->IsDotDot() == false)
        [[self ActivePanelController] HandleGoIntoDir];
}

- (IBAction)OnOpenWithExternalEditor:(id)sender
{
    if([m_MainSplitView IsViewCollapsedOrOverlayed:[self ActivePanelView]])
        return;
    
    if(self.ActivePanelController.GetCurrentVFSHost->IsNativeFS() == false)
        return;
    
    auto item = self.ActivePanelView.CurrentItem;
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

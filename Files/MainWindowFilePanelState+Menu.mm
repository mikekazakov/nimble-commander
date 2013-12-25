//
//  MainWindowFilePanelState+Menu.m
//  Files
//
//  Created by Michael G. Kazakov on 19.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <assert.h>
#import "MainWindowFilePanelState+Menu.h"
#import "PanelController.h"
#import "FileDeletionOperation.h"
#import "FilePanelMainSplitView.h"
#import "GoToFolderSheetController.h"
#import "OperationsController.h"
#import "Common.h"
#import "common_paths.h"

@implementation MainWindowFilePanelState (Menu)

- (IBAction)OnOpen:(id)sender
{
    [[self ActivePanelController] HandleReturnButton];
}

- (IBAction)OnOpenNatively:(id)sender
{
    [[self ActivePanelController] HandleShiftReturnButton];
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

- (IBAction)OnMoveToTrash:(id)sender
{
    if(![self ActivePanelData]->Host()->IsNativeFS())
        return; // currently support files deletion only on native fs
    if([m_MainSplitView IsViewCollapsedOrOverlayed:[self ActivePanelView]])
        return;
    
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

@end

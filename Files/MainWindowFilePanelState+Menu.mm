//
//  MainWindowFilePanelState+Menu.m
//  Files
//
//  Created by Michael G. Kazakov on 19.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <pwd.h>
#import <assert.h>
#import "MainWindowFilePanelState+Menu.h"
#import "PanelController.h"
#import "FilePanelMainSplitView.h"

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
    [self DoGoToNativeDirectoryFromMenuItem:getpwuid(getuid())->pw_dir];
}

- (IBAction)OnGoToDocuments:(id)sender
{
    NSArray* paths = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
    [self DoGoToNativeDirectoryFromMenuItem: [[paths objectAtIndex:0] fileSystemRepresentation]];
}

- (IBAction)OnGoToDesktop:(id)sender
{
    NSArray* paths = [[NSFileManager defaultManager] URLsForDirectory:NSDesktopDirectory inDomains:NSUserDomainMask];
    [self DoGoToNativeDirectoryFromMenuItem: [[paths objectAtIndex:0] fileSystemRepresentation]];    
}

- (IBAction)OnGoToDownloads:(id)sender
{
    NSArray* paths = [[NSFileManager defaultManager] URLsForDirectory:NSDownloadsDirectory inDomains:NSUserDomainMask];
    [self DoGoToNativeDirectoryFromMenuItem: [[paths objectAtIndex:0] fileSystemRepresentation]];
}

- (IBAction)OnGoToApplications:(id)sender
{
    [self DoGoToNativeDirectoryFromMenuItem:"/Applications/"];
}

- (IBAction)OnGoToUtilities:(id)sender
{
    [self DoGoToNativeDirectoryFromMenuItem:"/Applications/Utilities/"];
}

- (void) DoGoToNativeDirectoryFromMenuItem: (const char*)_path
{
    if(_path == 0) return;
    
    if(m_ActiveState == StateLeftPanel)
    {
        [m_MainSplitView SetLeftOverlay:0]; // seem to be a redundant
        [m_LeftPanelController GoToGlobalHostsPathAsync:_path];
    }
    else if(m_ActiveState == StateRightPanel)
    {
        [m_MainSplitView SetRightOverlay:0]; // seem to be a redundant
        [m_RightPanelController GoToGlobalHostsPathAsync:_path];
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

@end

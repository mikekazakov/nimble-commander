//
//  MainWindowFilePanelState+Menu.h
//  Files
//
//  Created by Michael G. Kazakov on 19.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "MainWindowFilePanelState.h"

@interface MainWindowFilePanelState (Menu)

- (IBAction)OnOpen:(id)sender;
- (IBAction)OnOpenNatively:(id)sender;

// Navigation
- (IBAction)OnGoBack:(id)sender;
- (IBAction)OnGoForward:(id)sender;
- (IBAction)OnGoToHome:(id)sender;
- (IBAction)OnGoToDocuments:(id)sender;
- (IBAction)OnGoToDesktop:(id)sender;
- (IBAction)OnGoToDownloads:(id)sender;
- (IBAction)OnGoToLibrary:(id)sender;
- (IBAction)OnGoToApplications:(id)sender;
- (IBAction)OnGoToUtilities:(id)sender;
- (IBAction)OnGoToFolder:(id)sender;

@end

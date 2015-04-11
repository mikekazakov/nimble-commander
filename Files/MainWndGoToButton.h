//
//  MainWndGoToButton.h
//  Directories
//
//  Created by Michael G. Kazakov on 11.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "VFS.h"
#import "SavedNetworkConnectionsManager.h"

@class MainWindowFilePanelState;

@interface MainWndGoToButtonSelection : NSObject
@end

@interface MainWndGoToButtonSelectionVFSPath : MainWndGoToButtonSelection
@property string path;
@property VFSHostWeakPtr vfs;
@end

@interface MainWndGoToButtonSelectionSavedNetworkConnection : MainWndGoToButtonSelection
@property shared_ptr<SavedNetworkConnectionsManager::AbstractConnection> connection;
@end

@interface MainWndGoToButton : NSPopUpButton<NSMenuDelegate>
@property (nonatomic) __weak MainWindowFilePanelState *owner;
@property (nonatomic) bool isRight;
@property (nonatomic, readonly) MainWndGoToButtonSelection *selection;

- (void) popUp;

@end

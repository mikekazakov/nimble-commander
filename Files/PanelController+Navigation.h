//
//  PanelController+Navigation.h
//  Files
//
//  Created by Michael G. Kazakov on 21.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "PanelController.h"

class PanelControllerGoToDirContext
{
public:
    /* required */
    string              RequestedDirectory      = "";
    VFSHostPtr          VFS                     = nullptr;
    
    /* optional */
    string              RequestFocusedEntry     = "";
    bool                PerformAsynchronous     = true;
    bool                LoadPreviousViewState   = false;
    
    /**
     * This will be called from a thread which is loading a vfs listing with
     * vfs result code.
     * This thread may be main or background depending on PerformAsynchronous.
     * Will be called on any error canceling process or with 0 on successful loading.
     */
    function<void(int)> LoadingResultCallback    = nullptr;
    
    /**
     * Return code of a VFS->FetchDirectoryListing will be placed here.
     */
    int                 LoadingResultCode        = 0;
};

@interface PanelController (Navigation)

- (int) GoToDirWithContext:(shared_ptr<PanelControllerGoToDirContext>)_context;


// will not load previous view state if any
// don't use the following methds. use GoToDirWithContext instead.
- (int) GoToDir:(const string&)_dir
            vfs:(VFSHostPtr)_vfs
   select_entry:(const string&)_filename
          async:(bool)_asynchronous;

- (int) GoToDir:(const string&)_dir
            vfs:(VFSHostPtr)_vfs
   select_entry:(const string&)_filename
loadPreviousState:(bool)_load_state
          async:(bool)_asynchronous;

// sync operation
- (void) loadNonUniformListing:(const shared_ptr<VFSListing>&)_listing;

// will load previous view state if any
- (void) GoToVFSPathStack:(const VFSPathStack&)_stack;
// some params later

- (void) RecoverFromInvalidDirectory;

@end

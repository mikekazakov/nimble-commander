//
//  PanelAux.h
//  Files
//
//  Created by Michael G. Kazakov on 18.09.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include "vfs/VFS.h"
#include "Operations/Copy/Options.h"

@class PanelController;
@class ExternalEditorInfo;

// this class allows opening file in VFS with regular [NSWorkspace open]
// after refactoring the need to keep this class at all is in doubts
// opening files in writable non-native vfs will start background changes tracking and uploading changes back
class PanelVFSFileWorkspaceOpener
{
public:
    // can be called from main thread - it will execute it's job in background
    static void Open(string _filepath,
                     VFSHostPtr _host,
                     PanelController *_panel
                     );
    
    static void Open(string _filepath,
                     VFSHostPtr _host,
                     string _with_app_path, // can be "", use default app in such case
                     PanelController *_panel
                     );
    
    static void Open(vector<string> _filepaths,
                     VFSHostPtr _host,
                     NSString *_with_app_bundle, // can be nil, use default app in such case
                     PanelController *_panel
                     );
    
    static void OpenInExternalEditorTerminal(string _filepath,
                                             VFSHostPtr _host,
                                             ExternalEditorInfo *_ext_ed,
                                             string _file_title,
                                             PanelController *_panel);
};

namespace panel
{
    bool IsEligbleToTryToExecuteInConsole(const VFSListingItem& _item);
    FileCopyOperationOptions MakeDefaultFileCopyOptions();
    FileCopyOperationOptions MakeDefaultFileMoveOptions();
    bool IsExtensionInArchivesWhitelist( const char *_ext ) noexcept;
}

//
//  PanelAux.h
//  Files
//
//  Created by Michael G. Kazakov on 18.09.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include "vfs/VFS.h"

// this class allows opening file in VFS with regular [NSWorkspace open]
// after refactoring the need to keep this class at all is in doubts
class PanelVFSFileWorkspaceOpener
{
public:
    // can be called from main thread - it will execute it's job in background
    static void Open(string _filename,
                     shared_ptr<VFSHost> _host
                     );
    
    static void Open(string _filename,
                     shared_ptr<VFSHost> _host,
                     string _with_app_path // can be "", use default app in such case
                     );
    
    static void Open(vector<string> _filenames,
                     shared_ptr<VFSHost> _host,
                     NSString *_with_app_bundle // can be nil, use default app in such case
                    );
    
};

namespace panel
{
    bool IsEligbleToTryToExecuteInConsole(const VFSFlexibleListingItem& _item);
}

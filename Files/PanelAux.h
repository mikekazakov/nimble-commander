//
//  PanelAux.h
//  Files
//
//  Created by Michael G. Kazakov on 18.09.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "VFS.h"

// this class allows opening file in VFS with regular [NSWorkspace open]
// after refactoring the need to keep this class at all is in doubts
class PanelVFSFileWorkspaceOpener
{
public:
    // can be called from main thread - it will execute it's job in background
    static void Open(const char* _filename, std::shared_ptr<VFSHost> _host);
    
};

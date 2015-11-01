//
//  LSUrls.h
//  Files
//
//  Created by Michael G. Kazakov on 06.11.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "vfs/VFS.h"

struct LauchServicesHandlers
{
    /**
     * unsorted apps list
     */
    vector<string>  paths{};
    
    /**
     * common UTI if any (if there was different UTI before merge - this field will be "")
     */
    string          uti = "";
    
    /**
     * may be < 0, so there's no default handler fow those types
     */
    int             default_path = -1;
    
    static LauchServicesHandlers GetForItem(const VFSFlexibleListingItem &_item);
    static void DoMerge(const list<LauchServicesHandlers>& _input, LauchServicesHandlers& _result);
    static bool SetDefaultHandler(const string &_uti, const string &_path);
};

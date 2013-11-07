//
//  LSUrls.h
//  Files
//
//  Created by Michael G. Kazakov on 06.11.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <vector>
#import <list>
#import "VFS.h"

struct LauchServicesHandlers
{
    std::vector<std::string> paths; // unsorted list
    int default_path; // may be < 0, so there's no default handler fow those types

    static void DoOnItem(const VFSListingItem* _it, std::shared_ptr<VFSHost> _host, const char* _path, LauchServicesHandlers* _result);
    static void DoMerge(const std::list<LauchServicesHandlers>* _input, LauchServicesHandlers* _result);
};

//
//  VFSArchiveProxy.h
//  Files
//
//  Created by Michael G. Kazakov on 09.03.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include "VFSHost.h"


class VFSArchiveProxy
{
public:
    
//static bool CanOpenFileAsArchive(const string &_path,
//                                  shared_ptr<VFSHost> _parent
//                                  );

    static VFSHostPtr OpenFileAsArchive(const string &_path,
                                        const VFSHostPtr &_parent,
                                        function<string()> _passwd = nullptr
                                        );
};


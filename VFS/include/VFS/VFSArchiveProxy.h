// Copyright (C) 2014-2017 Michael Kazakov. Subject to GNU General Public License version 3.

#pragma once

#include "Host.h"


class VFSArchiveProxy
{
public:
    
//static bool CanOpenFileAsArchive(const string &_path,
//                                  shared_ptr<VFSHost> _parent
//                                  );

    static VFSHostPtr OpenFileAsArchive(const string &_path,
                                        const VFSHostPtr &_parent,
                                        function<string()> _passwd = nullptr,
                                        VFSCancelChecker _cancel_checker = nullptr
                                        );
};


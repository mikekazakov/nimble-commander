// Copyright (C) 2014-2023 Michael Kazakov. Subject to GNU General Public License version 3.

#pragma once

#include "Host.h"

class VFSArchiveProxy
{
public:
    static VFSHostPtr OpenFileAsArchive(const std::string &_path,
                                        const VFSHostPtr &_parent,
                                        std::function<std::string()> _passwd = nullptr,
                                        VFSCancelChecker _cancel_checker = nullptr);
};

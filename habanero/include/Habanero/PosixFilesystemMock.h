// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "PosixFilesystem.h"
#include <gmock/gmock.h>

namespace nc::hbn {

class PosixFilesystemMock : public PosixFilesystem
{
public:
    MOCK_METHOD1(close, int(int));
    MOCK_METHOD3(write, ssize_t(int, const void *, size_t));
    MOCK_METHOD1(unlink, int(const char *));
    MOCK_METHOD2(rename, int(const char *, const char *));
    MOCK_METHOD1(mkstemp, int(char *));
};
    
}

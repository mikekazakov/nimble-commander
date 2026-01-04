// Copyright (C) 2014-2026 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <string>

class KeychainServices
{
public:
    KeychainServices(const KeychainServices &) = delete;
    void operator=(const KeychainServices &) = delete;
    static KeychainServices &Instance();

    // will override on duplicate
    static bool SetPassword(const std::string &_where, const std::string &_account, const std::string &_password);

    static bool GetPassword(const std::string &_where, const std::string &_account, std::string &_password);

    static bool ErasePassword(const std::string &_where, const std::string &_account);

private:
    KeychainServices();
};

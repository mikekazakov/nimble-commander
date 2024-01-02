// Copyright (C) 2014-2016 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <string>

class KeychainServices
{
public:
    static KeychainServices &Instance();

    // will override on duplicate
    bool SetPassword(const std::string& _where, const std::string &_account, const std::string &_password);
    
    bool GetPassword(const std::string& _where, const std::string &_account, std::string &_password);
    
    bool ErasePassword(const std::string& _where, const std::string &_account);
    
private:
    KeychainServices();
    KeychainServices(const KeychainServices&) = delete;
    void operator=(const KeychainServices&) = delete;
};

//
//  KeychainServices.h
//  Files
//
//  Created by Michael G. Kazakov on 22/12/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

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

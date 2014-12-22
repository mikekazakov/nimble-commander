//
//  KeychainServices.h
//  Files
//
//  Created by Michael G. Kazakov on 22/12/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once

class KeychainServices
{
public:
    static KeychainServices &Instance();

    // will override on duplicate
    bool SetPassword(const string& _where, const string &_account, const string &_password);
    
    bool GetPassword(const string& _where, const string &_account, string &_password);
    
private:
    KeychainServices();
    KeychainServices(const KeychainServices&) = delete;
    void operator=(const KeychainServices&) = delete;
};

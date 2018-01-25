// Copyright (C) 2016 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

class NetworkConnectionsManager;

class AppDelegateCPP
{
public:
    static const string &ConfigDirectory();
    static const string &StateDirectory();
    static const string &SupportDirectory();
    static const shared_ptr<NetworkConnectionsManager> &NetworkConnectionsManager();
    
};

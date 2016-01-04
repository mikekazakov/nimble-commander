//
//  SavedNetworkConnectionsManager.h
//  Files
//
//  Created by Michael G. Kazakov on 22/12/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once

// this class serves only for migration purpose only, not used anywhere else
// should be removed in 1.1.2

class SavedNetworkConnectionsManager
{
public:
    struct AbstractConnection;
    struct FTPConnection;
    struct SFTPConnection;

    static SavedNetworkConnectionsManager &Instance();
    
private:
    
    /**
     * inserts a connection in front of connections list.
     * remove duplicates if any.
     * saving changes immediately.
     */
    void InsertConnection(const shared_ptr<AbstractConnection> &_conn);
    
    /**
     * removes connection from a stored list if found idential or equal one.
     * saving changes immediately.
     */
    void RemoveConnection(const shared_ptr<AbstractConnection> &_conn);
    
    vector<shared_ptr<AbstractConnection>> Connections() const;
    
    vector<shared_ptr<FTPConnection>> FTPConnections() const;
    void EraseAllFTPConnections();
    
    vector<shared_ptr<SFTPConnection>> SFTPConnections() const;
    void EraseAllSFTPConnections();
    
    bool SetPassword(const shared_ptr<AbstractConnection> &_conn, const string& _password);
    bool GetPassword(const AbstractConnection &_conn, string& _password);
    bool GetPassword(const shared_ptr<AbstractConnection> &_conn, string& _password);
    
    string TitleForConnection(const shared_ptr<AbstractConnection> &_conn);

    SavedNetworkConnectionsManager();
    static void SaveConnections(const vector<shared_ptr<AbstractConnection>> &_conns);
    static vector<shared_ptr<AbstractConnection>> LoadConnections();
    
    vector<shared_ptr<AbstractConnection>> m_Connections;
    mutable mutex m_Lock;
};


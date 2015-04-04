//
//  SavedNetworkConnectionsManager.h
//  Files
//
//  Created by Michael G. Kazakov on 22/12/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once

class SavedNetworkConnectionsManager
{
public:
    struct AbstractConnection;
    struct FTPConnection;
    struct SFTPConnection;

    static SavedNetworkConnectionsManager &Instance();
    
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
private:
    SavedNetworkConnectionsManager();
    static void SaveConnections(const vector<shared_ptr<AbstractConnection>> &_conns);
    static vector<shared_ptr<AbstractConnection>> LoadConnections();
    
    vector<shared_ptr<AbstractConnection>> m_Connections;
    mutable mutex m_Lock;
};

struct SavedNetworkConnectionsManager::AbstractConnection
{
    AbstractConnection(const string &_title);
    virtual ~AbstractConnection();
    
    const string title; // arbitrary and should not be used in Equal() comparison
    
    virtual bool Equal(const AbstractConnection& _rhs) const = 0;
    virtual string KeychainWhere() const = 0;
    virtual string KeychainAccount() const = 0;
};

struct SavedNetworkConnectionsManager::FTPConnection : AbstractConnection
{
    FTPConnection( const string &_title, const string &_user, const string &_host, const string &_path, long  _port );
    const string user;
    const string host;
    const string path;
    const long   port;

    virtual bool Equal(const AbstractConnection& _rhs) const override;
    virtual string KeychainWhere() const override;
    virtual string KeychainAccount() const override;
};

struct SavedNetworkConnectionsManager::SFTPConnection : AbstractConnection
{
    SFTPConnection( const string &_title, const string &_user, const string &_host, const string &_keypath, long  _port );
    const string user;
    const string host;
    const string keypath;
    const long   port;
    
    virtual bool Equal(const AbstractConnection& _rhs) const override;
    virtual string KeychainWhere() const override;
    virtual string KeychainAccount() const override;
};

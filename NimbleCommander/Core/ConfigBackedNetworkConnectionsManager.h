// Copyright (C) 2015-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "NetworkConnectionsManager.h"
#include <boost/uuid/uuid.hpp>
#include <boost/functional/hash.hpp>
#include <VFS/VFS.h>
#include <NimbleCommander/Bootstrap/Config.h>

class ConfigBackedNetworkConnectionsManager : public NetworkConnectionsManager
{
public:
    ConfigBackedNetworkConnectionsManager(const string &_config_directory);
    ~ConfigBackedNetworkConnectionsManager();

    optional<Connection> ConnectionByUUID(const boost::uuids::uuid& _uuid) const override;
    optional<Connection> ConnectionForVFS(const VFSHost& _vfs) const override;
    
    void InsertConnection( const Connection &_connection ) override;
    void RemoveConnection( const Connection &_connection ) override;
    
    void ReportUsage( const Connection &_connection ) override;
    
    vector<Connection> AllConnectionsByMRU() const override;
    vector<Connection> FTPConnectionsByMRU() const override;
    vector<Connection> SFTPConnectionsByMRU() const override;
    vector<Connection> LANShareConnectionsByMRU() const override;
    
    bool SetPassword(const Connection &_conn, const string& _password) override;
    
    /**
     * Retrieves password stored in Keychain and returns it.
     */
    bool GetPassword(const Connection &_conn, string& _password) override;
    
    /**
     * Runs modal UI Dialog and asks user to enter an appropriate password
     */
    bool AskForPassword(const Connection &_conn, string& _password) override;
    
    
    VFSHostPtr SpawnHostFromConnection(const Connection &_conn,
                                       bool _allow_password_ui = true) override;

    bool MountShareAsync(const Connection &_conn,
                         const string &_password,
                         MountShareCallback _callback) override;
    
private:
    void Save();
    void Load();
    void NetFSCallback(int _status, void *_requestID, CFArrayRef _mountpoints);
    
    vector<Connection>                              m_Connections;
    vector<boost::uuids::uuid>                      m_MRU;
    mutable mutex                                   m_Lock;
    GenericConfig                                   m_Config;
    vector<GenericConfig::ObservationTicket>        m_ConfigObservations;
    bool                                            m_IsWritingConfig;
    
    mutable mutex                                   m_PendingMountRequestsLock;
    vector< pair<void*, MountShareCallback> >       m_PendingMountRequests;
};

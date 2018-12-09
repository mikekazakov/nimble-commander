// Copyright (C) 2015-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "NetworkConnectionsManager.h"
#include <boost/uuid/uuid.hpp>
#include <boost/functional/hash.hpp>
#include <VFS/VFS.h>
#include <Config/Config.h>

class ConfigBackedNetworkConnectionsManager : public NetworkConnectionsManager
{
public:
    ConfigBackedNetworkConnectionsManager(nc::config::Config &_config);
    ~ConfigBackedNetworkConnectionsManager();

    std::optional<Connection> ConnectionByUUID(const boost::uuids::uuid& _uuid) const override;
    std::optional<Connection> ConnectionForVFS(const VFSHost& _vfs) const override;
    
    void InsertConnection( const Connection &_connection ) override;
    void RemoveConnection( const Connection &_connection ) override;
    
    void ReportUsage( const Connection &_connection ) override;
    
    std::vector<Connection> AllConnectionsByMRU() const override;
    std::vector<Connection> FTPConnectionsByMRU() const override;
    std::vector<Connection> SFTPConnectionsByMRU() const override;
    std::vector<Connection> LANShareConnectionsByMRU() const override;
    
    bool SetPassword(const Connection &_conn, const std::string& _password) override;
    
    /**
     * Retrieves password stored in Keychain and returns it.
     */
    bool GetPassword(const Connection &_conn, std::string& _password) override;
    
    /**
     * Runs modal UI Dialog and asks user to enter an appropriate password
     */
    bool AskForPassword(const Connection &_conn, std::string& _password) override;
    
    
    VFSHostPtr SpawnHostFromConnection(const Connection &_conn,
                                       bool _allow_password_ui = true) override;

    bool MountShareAsync(const Connection &_conn,
                         const std::string &_password,
                         MountShareCallback _callback) override;
    
private:
    void Save();
    void Load();
    void NetFSCallback(int _status, void *_requestID, CFArrayRef _mountpoints);
    
    std::vector<Connection>                         m_Connections;
    std::vector<boost::uuids::uuid>                 m_MRU;
    mutable std::mutex                              m_Lock;
    nc::config::Config                             &m_Config;
    std::vector<nc::config::Token>                  m_ConfigObservations;
    bool                                            m_IsWritingConfig;
    
    mutable std::mutex                              m_PendingMountRequestsLock;
    std::vector< std::pair<void*, MountShareCallback> >  m_PendingMountRequests;
};

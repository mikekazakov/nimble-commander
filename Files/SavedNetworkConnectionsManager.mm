//
//  SavedNetworkConnectionsManager.cpp
//  Files
//
//  Created by Michael G. Kazakov on 22/12/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#include "KeychainServices.h"
#include "SavedNetworkConnectionsManager.h"
#include "Common.h"

static NSString *g_DefKey = @"FilePanelsSavedNetworkConnections";

static NSDictionary *SaveFTP(const SavedNetworkConnectionsManager::FTPConnection& _conn)
{
    return @{
        @"type": @"ftp",
        @"user": [NSString stringWithUTF8StdString:_conn.user],
        @"host": [NSString stringWithUTF8StdString:_conn.host],
        @"path": [NSString stringWithUTF8StdString:_conn.path],
        @"port": @(_conn.port)
    };
}

static shared_ptr<SavedNetworkConnectionsManager::AbstractConnection> LoadFTP(NSDictionary *_from)
{
    if( !_from || !_from[@"type"] || ![_from[@"type"] isEqualTo:@"ftp"] )
        return nullptr;
    if( !_from[@"user"] ||
        ![_from[@"user"] isKindOfClass:NSString.class] ||
        !_from[@"host"] ||
        ![_from[@"host"] isKindOfClass:NSString.class] ||
        !_from[@"path"] ||
        ![_from[@"path"] isKindOfClass:NSString.class] ||
        !_from[@"port"] ||
        ![_from[@"port"] isKindOfClass:NSNumber.class] )
        return nullptr;
    return make_shared<SavedNetworkConnectionsManager::FTPConnection>
    (
     [_from[@"user"] UTF8String],
     [_from[@"host"] UTF8String],
     [_from[@"path"] fileSystemRepresentationSafe],
     [_from[@"port"] longValue]
     );
}

static NSDictionary *SaveSFTP(const SavedNetworkConnectionsManager::SFTPConnection& _conn)
{
    return @{
        @"type": @"sftp",
        @"user": [NSString stringWithUTF8StdString:_conn.user],
        @"host": [NSString stringWithUTF8StdString:_conn.host],
        @"keypath": [NSString stringWithUTF8StdString:_conn.keypath],
        @"port": @(_conn.port)
    };
}

static shared_ptr<SavedNetworkConnectionsManager::AbstractConnection> LoadSFTP(NSDictionary *_from)
{
    if( !_from || !_from[@"type"] || ![_from[@"type"] isEqualTo:@"sftp"] )
        return nullptr;
    if( !_from[@"user"] ||
       ![_from[@"user"] isKindOfClass:NSString.class] ||
       !_from[@"host"] ||
       ![_from[@"host"] isKindOfClass:NSString.class] ||
       !_from[@"keypath"] ||
       ![_from[@"keypath"] isKindOfClass:NSString.class] ||
       !_from[@"port"] ||
       ![_from[@"port"] isKindOfClass:NSNumber.class] )
        return nullptr;
    return make_shared<SavedNetworkConnectionsManager::SFTPConnection>
    (
     [_from[@"user"] UTF8String],
     [_from[@"host"] UTF8String],
     [_from[@"keypath"] fileSystemRepresentationSafe],
     [_from[@"port"] longValue]
     );
}

SavedNetworkConnectionsManager::AbstractConnection::AbstractConnection()
{
}

SavedNetworkConnectionsManager::AbstractConnection::~AbstractConnection()
{
}

SavedNetworkConnectionsManager::FTPConnection::FTPConnection(const string &_user, const string &_host, const string &_path, long  _port):
    user(_user), host(_host), path(_path), port(_port)
{
}

string SavedNetworkConnectionsManager::FTPConnection::KeychainWhere() const
{
    return "ftp://" + host;
}

string SavedNetworkConnectionsManager::FTPConnection::KeychainAccount() const
{
    return user;
}

bool SavedNetworkConnectionsManager::FTPConnection::Equal(const AbstractConnection& _rhs) const
{
    if(!dynamic_cast<const FTPConnection*>(&_rhs))
        return false;
    auto &rhs = static_cast<const FTPConnection&>(_rhs);
    return user == rhs.user && host == rhs.host && path == rhs.path && port == rhs.port;
}

SavedNetworkConnectionsManager::SFTPConnection::SFTPConnection(const string &_user, const string &_host, const string &_keypath, long  _port):
user(_user), host(_host), keypath(_keypath), port(_port)
{
}

string SavedNetworkConnectionsManager::SFTPConnection::KeychainWhere() const
{
    return "sftp://" + host;
}

string SavedNetworkConnectionsManager::SFTPConnection::KeychainAccount() const
{
    return user;
}

bool SavedNetworkConnectionsManager::SFTPConnection::Equal(const AbstractConnection& _rhs) const
{
    if(!dynamic_cast<const SFTPConnection*>(&_rhs))
        return false;
    auto &rhs = static_cast<const SFTPConnection&>(_rhs);
    return user == rhs.user && host == rhs.host && keypath == rhs.keypath && port == rhs.port;
}

SavedNetworkConnectionsManager &SavedNetworkConnectionsManager::Instance()
{
    static auto inst = new SavedNetworkConnectionsManager;
    return *inst;
}

SavedNetworkConnectionsManager::SavedNetworkConnectionsManager()
{
    m_Connections = LoadConnections();
}

void SavedNetworkConnectionsManager::InsertConnection(const shared_ptr<AbstractConnection> &_conn )
{
    assert(_conn);
    lock_guard<mutex> lock(m_Lock);
    m_Connections.erase(remove_if(begin(m_Connections),
                                  end(m_Connections),
                                  [&](auto &_t) {
                                      return _t == _conn || _t->Equal(*_conn);
                                  }),
                        end(m_Connections)
                        );
    m_Connections.insert(begin(m_Connections), _conn);
    SaveConnections(m_Connections);
}

void SavedNetworkConnectionsManager::RemoveConnection(const shared_ptr<AbstractConnection> &_conn)
{
    assert(_conn);
    lock_guard<mutex> lock(m_Lock);
    m_Connections.erase(remove_if(begin(m_Connections),
                                  end(m_Connections),
                                  [&](auto &_t) {
                                      return _t == _conn || _t->Equal(*_conn);
                                  }),
                        end(m_Connections)
                        );
    SaveConnections(m_Connections);
}

bool SavedNetworkConnectionsManager::SetPassword(const shared_ptr<AbstractConnection> &_conn, const string& _password)
{
    assert(_conn);
    return KeychainServices::Instance().SetPassword(_conn->KeychainWhere(), _conn->KeychainAccount(), _password);
}

bool SavedNetworkConnectionsManager::GetPassword(const shared_ptr<AbstractConnection> &_conn, string& _password)
{
    assert(_conn);
    return GetPassword(*_conn, _password);
}

bool SavedNetworkConnectionsManager::GetPassword(const AbstractConnection &_conn, string& _password)
{
    return KeychainServices::Instance().GetPassword(_conn.KeychainWhere(), _conn.KeychainAccount(), _password);
}

void SavedNetworkConnectionsManager::SaveConnections(const vector<shared_ptr<AbstractConnection>> &_conns)
{
    NSMutableArray *array = [NSMutableArray new];
    for(auto &i: _conns) {
        if(auto conn = dynamic_pointer_cast<FTPConnection>(i))
            [array addObject:SaveFTP(*conn)];
        else if(auto conn = dynamic_pointer_cast<SFTPConnection>(i))
            [array addObject:SaveSFTP(*conn)];
    }
    
    [NSUserDefaults.standardUserDefaults setObject:array forKey:g_DefKey];
}

vector<shared_ptr<SavedNetworkConnectionsManager::AbstractConnection>> SavedNetworkConnectionsManager::LoadConnections()
{
    NSArray *connections = [NSUserDefaults.standardUserDefaults objectForKey:g_DefKey];
    if(!connections || ![connections isKindOfClass:NSArray.class])
        return {};

    vector<shared_ptr<SavedNetworkConnectionsManager::AbstractConnection>> result;
    
    for(id obj: connections) {
        if(![obj isKindOfClass:NSDictionary.class])
            continue;
        NSDictionary *dict = obj;
        
        if(auto ftp = LoadFTP(dict))
            result.emplace_back(ftp);
        else if(auto sftp = LoadSFTP(dict))
            result.emplace_back(sftp);
    }
    
    return result;
}

vector<shared_ptr<SavedNetworkConnectionsManager::AbstractConnection>> SavedNetworkConnectionsManager::Connections() const
{
    lock_guard<mutex> lock(m_Lock);
    return m_Connections;
}

vector<shared_ptr<SavedNetworkConnectionsManager::FTPConnection>> SavedNetworkConnectionsManager::FTPConnections() const
{
    lock_guard<mutex> lock(m_Lock);
    vector<shared_ptr<SavedNetworkConnectionsManager::FTPConnection>> result;
    for(auto &i: m_Connections)
        if(auto conn = dynamic_pointer_cast<FTPConnection>(i))
            result.emplace_back(move(conn));
    return result;
}

void SavedNetworkConnectionsManager::EraseAllFTPConnections()
{
    lock_guard<mutex> lock(m_Lock);
    m_Connections.erase(remove_if(begin(m_Connections),
                                  end(m_Connections),
                                  [&](auto &_t) {
                                      if(auto p = dynamic_pointer_cast<FTPConnection>(_t)) {
                                          KeychainServices::Instance().ErasePassword(p->KeychainWhere(), p->KeychainAccount());
                                          return true;
                                      }
                                      return false;
                                  }),
                        end(m_Connections)
                        );
    SaveConnections(m_Connections);
}

vector<shared_ptr<SavedNetworkConnectionsManager::SFTPConnection>> SavedNetworkConnectionsManager::SFTPConnections() const
{
    lock_guard<mutex> lock(m_Lock);
    vector<shared_ptr<SavedNetworkConnectionsManager::SFTPConnection>> result;
    for(auto &i: m_Connections)
        if(auto conn = dynamic_pointer_cast<SFTPConnection>(i))
            result.emplace_back(move(conn));
    return result;
}

void SavedNetworkConnectionsManager::EraseAllSFTPConnections()
{
    lock_guard<mutex> lock(m_Lock);
    m_Connections.erase(remove_if(begin(m_Connections),
                                  end(m_Connections),
                                  [&](auto &_t) {
                                      if(auto p = dynamic_pointer_cast<SFTPConnection>(_t)) {
                                          KeychainServices::Instance().ErasePassword(p->KeychainWhere(), p->KeychainAccount());
                                          return true;
                                      }
                                      return false;
                                  }),
                        end(m_Connections)
                        );
    SaveConnections(m_Connections);
}

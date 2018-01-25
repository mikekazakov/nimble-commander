// Copyright (C) 2015-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <boost/uuid/uuid.hpp>
#include <VFS/VFS.h>

class NetworkConnectionsManager
{
public:
    virtual ~NetworkConnectionsManager() = default;

    class Connection;
    class BaseConnection;
        class FTP;
        class SFTP;
        class LANShare;
        class Dropbox;
        class WebDAV;
    class ConnectionVisitor;
    
    
    static boost::uuids::uuid MakeUUID();
    
    /**
     * Returns connections path is the following format: protocol://[user@]domain[/resource]
     * e.g. sftp://migun@192.168.2.1, dropbox://mike.kazakov@gmail.com,
     * sftp://migun@magnumbytes.com.
     */
    static string MakeConnectionPath(const Connection &_conn);
    
    /**
     * Returns a verbose title for connections with the following format:
     * title - path
     * or when there's no title:
     * path
     */
    static string TitleForConnection(const Connection &_conn);

    virtual optional<Connection> ConnectionByUUID(const boost::uuids::uuid& _uuid) const = 0;
    virtual optional<Connection> ConnectionForVFS(const VFSHost& _vfs) const = 0 ;
    
    virtual void InsertConnection( const Connection &_connection ) = 0;
    virtual void RemoveConnection( const Connection &_connection ) = 0;
    
    virtual void ReportUsage( const Connection &_connection ) = 0;
    
    virtual vector<Connection> AllConnectionsByMRU() const = 0;
    virtual vector<Connection> FTPConnectionsByMRU() const = 0;
    virtual vector<Connection> SFTPConnectionsByMRU() const = 0;
    virtual vector<Connection> LANShareConnectionsByMRU() const = 0;
    
    virtual bool SetPassword(const Connection &_conn, const string& _password) = 0;
    virtual bool GetPassword(const Connection &_conn, string& _password) = 0;
    
    virtual bool AskForPassword(const Connection &_conn, string& _password) = 0;
    
    /**
     * May throw VFSErrorException on error.
     */
    virtual shared_ptr<VFSHost> SpawnHostFromConnection(const Connection &_conn,
                                                        bool _allow_password_ui = true) = 0;

    using MountShareCallback = function<void(const string&_mounted_path, const string&_error)>;
    /**
     * MountShareAsync assumes that _conn is a Network share, exits immediately otherwise.
     * _callback will be called in the future, either with a string containing a mount path, or
     * with reason of failure.
     */
    virtual bool MountShareAsync(const Connection &_conn,
                                 const string &_password,
                                 MountShareCallback _callback) = 0;
};

class NetworkConnectionsManager::ConnectionVisitor
{
public:
    virtual ~ConnectionVisitor();
    virtual void Visit( const NetworkConnectionsManager::FTP &_ftp );
    virtual void Visit( const NetworkConnectionsManager::SFTP &_sftp );
    virtual void Visit( const NetworkConnectionsManager::LANShare &_share );
    virtual void Visit( const NetworkConnectionsManager::Dropbox &_account );
    virtual void Visit( const NetworkConnectionsManager::WebDAV &_webdav );
};

class NetworkConnectionsManager::Connection
{
public:
    Connection();
    
    template <class T>
    explicit Connection(T _t):
        m_Object( make_shared<Model<T>>( move(_t) ) )
    {
        static_assert( is_class<T>::value, "connection should be a class/struct" );
    }
    
    template <class T>
    bool IsType() const noexcept
    {
        return dynamic_pointer_cast<const Model<T>>( m_Object ) != nullptr;
    }
    
    template <class T>
    const T &Get() const
    {
        if( auto p = dynamic_pointer_cast<const Model<T>>( m_Object ) )
            return p->obj;
        throw domain_error("invalid cast request");
    }
    
    template <class T>
    const T* Cast() const noexcept
    {
        if( auto p = dynamic_pointer_cast<const Model<T>>( m_Object ) )
            return &p->obj;
        return nullptr;
    }
    
    void Accept( NetworkConnectionsManager::ConnectionVisitor &_visitor ) const;

    const string& Title() const noexcept;
    const boost::uuids::uuid& Uuid() const noexcept;

    bool operator==(const Connection&_rhs) const noexcept;
    bool operator!=(const Connection&_rhs) const noexcept;
private:
    struct Concept;
    template <class T> struct Model;
    shared_ptr<const Concept> m_Object;
};

class NetworkConnectionsManager::BaseConnection
{
public:
    string              title; // arbitrary user-defined title
    boost::uuids::uuid  uuid;
    bool operator==(const BaseConnection&_rhs) const noexcept;
};

class NetworkConnectionsManager::FTP : public NetworkConnectionsManager::BaseConnection
{
public:
    string user;
    string host;
    string path;
    long   port;
    bool operator==(const FTP&_rhs) const noexcept;
};

class NetworkConnectionsManager::SFTP : public NetworkConnectionsManager::BaseConnection
{
public:
    string user;
    string host;
    string keypath;
    long   port;
    bool operator==(const SFTP&_rhs) const noexcept;
};

class NetworkConnectionsManager::LANShare : public NetworkConnectionsManager::BaseConnection
{
public:
    enum class Protocol { /* persistent values, do not change */
        SMB = 0,
        AFP = 1,
        NFS = 2
    };
    string host; // host adress in ip or network name form. should not have protocol specification.
    string user; // empty user means 'guest'
    string share; // must be not empty at the time, to eliminate a need for UI upon connection
    string mountpoint; // empty mountpoint means that system will decide it itself
    Protocol proto;
    bool operator==(const LANShare&_rhs) const noexcept;
};

class NetworkConnectionsManager::Dropbox : public NetworkConnectionsManager::BaseConnection
{
public:
    string account;
    bool operator==(const Dropbox&_rhs) const noexcept;
};

class NetworkConnectionsManager::WebDAV : public NetworkConnectionsManager::BaseConnection
{
public:
    string host;
    string path;
    string user;
    int port;
    bool https;
    bool operator==(const WebDAV&_rhs) const noexcept;
};

struct NetworkConnectionsManager::Connection::Concept
{
    virtual ~Concept() = default;
    virtual const string& Title() const noexcept = 0;
    virtual const boost::uuids::uuid& Uuid() const noexcept = 0;
    virtual void Accept( NetworkConnectionsManager::ConnectionVisitor &_visitor ) const = 0;
    virtual const type_info &TypeID() const noexcept = 0;
    virtual bool Equal( const Concept &_rhs ) const noexcept = 0;
};

template <class T>
struct NetworkConnectionsManager::Connection::Model final :
    NetworkConnectionsManager::Connection::Concept
{
    const T obj;
    
    Model(T _t): obj( move(_t) )
    {
    }
    
    virtual const string& Title() const noexcept override
    {
        return obj.title;
    }
    
    virtual const boost::uuids::uuid& Uuid() const noexcept override
    {
        return obj.uuid;
    }
    
    virtual void Accept( NetworkConnectionsManager::ConnectionVisitor &_visitor ) const override
    {
        _visitor.Visit(obj);
    }
    
    virtual const type_info &TypeID() const noexcept override
    {
        return typeid( T );
    }
    
    virtual bool Equal( const Concept &_rhs ) const noexcept override
    {
        return TypeID() == _rhs.TypeID() && obj == static_cast<const Model<T>&>(_rhs).obj;
    }
};

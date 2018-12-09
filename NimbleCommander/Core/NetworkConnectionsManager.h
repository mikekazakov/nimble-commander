// Copyright (C) 2015-2018 Michael Kazakov. Subject to GNU General Public License version 3.
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
    static std::string MakeConnectionPath(const Connection &_conn);
    
    /**
     * Returns a verbose title for connections with the following format:
     * title - path
     * or when there's no title:
     * path
     */
    static std::string TitleForConnection(const Connection &_conn);

    virtual std::optional<Connection> ConnectionByUUID(const boost::uuids::uuid& _uuid) const = 0;
    virtual std::optional<Connection> ConnectionForVFS(const VFSHost& _vfs) const = 0 ;
    
    virtual void InsertConnection( const Connection &_connection ) = 0;
    virtual void RemoveConnection( const Connection &_connection ) = 0;
    
    virtual void ReportUsage( const Connection &_connection ) = 0;
    
    virtual std::vector<Connection> AllConnectionsByMRU() const = 0;
    virtual std::vector<Connection> FTPConnectionsByMRU() const = 0;
    virtual std::vector<Connection> SFTPConnectionsByMRU() const = 0;
    virtual std::vector<Connection> LANShareConnectionsByMRU() const = 0;
    
    virtual bool SetPassword(const Connection &_conn, const std::string& _password) = 0;
    virtual bool GetPassword(const Connection &_conn, std::string& _password) = 0;
    
    virtual bool AskForPassword(const Connection &_conn, std::string& _password) = 0;
    
    /**
     * May throw VFSErrorException on error.
     */
    virtual std::shared_ptr<VFSHost> SpawnHostFromConnection(const Connection &_conn,
                                                        bool _allow_password_ui = true) = 0;

    using MountShareCallback = std::function<void(const std::string&_mounted_path,
                                                  const std::string&_error)>;
    /**
     * MountShareAsync assumes that _conn is a Network share, exits immediately otherwise.
     * _callback will be called in the future, either with a string containing a mount path, or
     * with reason of failure.
     */
    virtual bool MountShareAsync(const Connection &_conn,
                                 const std::string &_password,
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
        m_Object( std::make_shared<Model<T>>( std::move(_t) ) )
    {
        static_assert( std::is_class<T>::value, "connection should be a class/struct" );
    }
    
    template <class T>
    bool IsType() const noexcept
    {
        return std::dynamic_pointer_cast<const Model<T>>( m_Object ) != nullptr;
    }
    
    template <class T>
    const T &Get() const
    {
        if( auto p = std::dynamic_pointer_cast<const Model<T>>( m_Object ) )
            return p->obj;
        throw std::domain_error("invalid cast request");
    }
    
    template <class T>
    const T* Cast() const noexcept
    {
        if( auto p = std::dynamic_pointer_cast<const Model<T>>( m_Object ) )
            return &p->obj;
        return nullptr;
    }
    
    void Accept( NetworkConnectionsManager::ConnectionVisitor &_visitor ) const;

    const std::string& Title() const noexcept;
    const boost::uuids::uuid& Uuid() const noexcept;

    bool operator==(const Connection&_rhs) const noexcept;
    bool operator!=(const Connection&_rhs) const noexcept;
private:
    struct Concept;
    template <class T> struct Model;
    std::shared_ptr<const Concept> m_Object;
};

class NetworkConnectionsManager::BaseConnection
{
public:
    std::string         title; // arbitrary user-defined title
    boost::uuids::uuid  uuid;
    bool operator==(const BaseConnection&_rhs) const noexcept;
};

class NetworkConnectionsManager::FTP : public NetworkConnectionsManager::BaseConnection
{
public:
    std::string user;
    std::string host;
    std::string path;
    long   port;
    bool operator==(const FTP&_rhs) const noexcept;
};

class NetworkConnectionsManager::SFTP : public NetworkConnectionsManager::BaseConnection
{
public:
    std::string user;
    std::string host;
    std::string keypath;
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
    std::string host; // host adress in ip or network name form. should not have protocol specification.
    std::string user; // empty user means 'guest'
    std::string share; // must be not empty at the time, to eliminate a need for UI upon connection
    std::string mountpoint; // empty mountpoint means that system will decide it itself
    Protocol proto;
    bool operator==(const LANShare&_rhs) const noexcept;
};

class NetworkConnectionsManager::Dropbox : public NetworkConnectionsManager::BaseConnection
{
public:
    std::string account;
    bool operator==(const Dropbox&_rhs) const noexcept;
};

class NetworkConnectionsManager::WebDAV : public NetworkConnectionsManager::BaseConnection
{
public:
    std::string host;
    std::string path;
    std::string user;
    int port;
    bool https;
    bool operator==(const WebDAV&_rhs) const noexcept;
};

struct NetworkConnectionsManager::Connection::Concept
{
    virtual ~Concept() = default;
    virtual const std::string& Title() const noexcept = 0;
    virtual const boost::uuids::uuid& Uuid() const noexcept = 0;
    virtual void Accept( NetworkConnectionsManager::ConnectionVisitor &_visitor ) const = 0;
    virtual const std::type_info &TypeID() const noexcept = 0;
    virtual bool Equal( const Concept &_rhs ) const noexcept = 0;
};

template <class T>
struct NetworkConnectionsManager::Connection::Model final :
    NetworkConnectionsManager::Connection::Concept
{
    const T obj;
    
    Model(T _t): obj( std::move(_t) )
    {
    }
    
    virtual const std::string& Title() const noexcept override
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
    
    virtual const std::type_info &TypeID() const noexcept override
    {
        return typeid( T );
    }
    
    virtual bool Equal( const Concept &_rhs ) const noexcept override
    {
        return TypeID() == _rhs.TypeID() && obj == static_cast<const Model<T>&>(_rhs).obj;
    }
};

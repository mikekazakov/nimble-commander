#pragma once

#include <boost/uuid/uuid.hpp>
#include <boost/functional/hash.hpp>
#include <VFS/VFS.h>
#include <NimbleCommander/Bootstrap/Config.h>

class NetworkConnectionsManager
{
    NetworkConnectionsManager();
public:
    class Connection;
    class BaseConnection;
    class FTPConnection;
    class SFTPConnection;
    
    static NetworkConnectionsManager& Instance();
    
    static boost::uuids::uuid MakeUUID();

    optional<Connection> ConnectionByUUID(const boost::uuids::uuid& _uuid) const;
    optional<Connection> ConnectionForVFS(const VFSHost& _vfs) const;    
    
    void InsertConnection( const Connection &_connection );
    void RemoveConnection( const Connection &_connection );
    
    void ReportUsage( const Connection &_connection );
    
    vector<Connection> AllConnectionsByMRU() const;
    vector<Connection> FTPConnectionsByMRU() const;
    vector<Connection> SFTPConnectionsByMRU() const;
    
    bool SetPassword(const Connection &_conn, const string& _password);
    
    /**
     * Retrieves password stored in Keychain and returns it.
     */
    bool GetPassword(const Connection &_conn, string& _password);
    
    /**
     * Runs modal UI Dialog and asks user to enter an appropriate password
     */
    bool AskForPassword(const Connection &_conn, string& _password);
//#ifdef __OBJC__
//    bool GetPassword(const Connection &_conn, string& _password, NSWindow *_window_for_passwd_sheet);
//#endif
    
    string TitleForConnection(const Connection &_conn) const;
    
    VFSHostPtr SpawnHostFromConnection(const Connection &_conn, bool _allow_password_ui = true);
    
private:
    void Save();
    void Load();
    
    vector<Connection>                              m_Connections;
    vector<boost::uuids::uuid>                      m_MRU;
    mutable mutex                                   m_Lock;
    GenericConfig                                   m_Config;
    vector<GenericConfig::ObservationTicket>        m_ConfigObservations;
};

class NetworkConnectionsManager::Connection
{
public:
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

    const string&               Title() const noexcept { return m_Object->Title(); }
    const boost::uuids::uuid&   Uuid()  const noexcept { return m_Object->Uuid(); }

    // shallow comparison only
    inline bool operator==(const Connection&_rhs)const noexcept {return m_Object == _rhs.m_Object;}
    inline bool operator!=(const Connection&_rhs)const noexcept {return m_Object != _rhs.m_Object;}
private:

    struct Concept
    {
        virtual ~Concept() = default;
        virtual const string& Title() const noexcept = 0;
        virtual const boost::uuids::uuid& Uuid() const noexcept = 0;
    };
    
    template <class T>
    struct Model final : Concept
    {
        T obj;
        
        Model(T _t): obj( move(_t) ) {};
        virtual const string& Title() const noexcept override { return obj.title; }
        virtual const boost::uuids::uuid& Uuid() const noexcept override { return obj.uuid; };
    };
    
    shared_ptr<const Concept> m_Object;
};

class NetworkConnectionsManager::BaseConnection
{
public:
    string              title; // arbitrary user-defined title
    boost::uuids::uuid  uuid;
};

class NetworkConnectionsManager::FTPConnection : public NetworkConnectionsManager::BaseConnection
{
public:
    string user;
    string host;
    string path;
    long   port;
};

class NetworkConnectionsManager::SFTPConnection : public NetworkConnectionsManager::BaseConnection
{
public:
    string user;
    string host;
    string keypath;
    long   port;
};

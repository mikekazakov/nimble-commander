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
    class LANShare;
    
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
    
    static string TitleForConnection(const Connection &_conn);
    
    VFSHostPtr SpawnHostFromConnection(const Connection &_conn, bool _allow_password_ui = true);

    using MountShareCallback = function<void(const string&_mounted_path, const string&_error)>;
    /**
     * MountShareAsync assumes that _conn is a Network share, exits immediately otherwise.
     * _callback will be called in the future, either with a string containing a mount path, or
     * with reason of failure.
     */
    bool MountShareAsync(const Connection &_conn,
                         MountShareCallback _callback,
                         bool _allow_password_ui = true);
    bool MountShareAsync(const Connection &_conn,
                         const string &_password,
                         MountShareCallback _callback);
    
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

class NetworkConnectionsManager::LANShare : public NetworkConnectionsManager::BaseConnection
{
public:
    enum class Protocol { /* persistent values, do not change */
        SMB = 0,
        AFP = 1
    };
    string host; // host adress in ip or network name form. should not have protocol specification.
    string user; // empty user means 'guest'
    string share; // must be not empty at the time, to eliminate a need for UI upon connection
    string mountpoint; // empty mountpoint means that system will decide it itself
    Protocol proto;
};

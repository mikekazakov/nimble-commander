#include "NetworkConnectionsManager.h"
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wshadow"
#include <boost/uuid/random_generator.hpp>
#include <boost/uuid/string_generator.hpp>
#include <boost/uuid/uuid_io.hpp>
#pragma clang diagnostic pop

boost::uuids::uuid NetworkConnectionsManager::MakeUUID()
{
    static spinlock lock;
    static boost::uuids::basic_random_generator<boost::mt19937> gen;

    lock_guard<spinlock> guard(lock);
    return gen();
}

static const string& PrefixForShareProtocol( NetworkConnectionsManager::LANShare::Protocol p )
{
    static const auto smb = "smb"s, afp = "afp"s, nfs = "nfs"s, unknown = ""s;
    if( p == NetworkConnectionsManager::LANShare::Protocol::SMB ) return smb;
    if( p == NetworkConnectionsManager::LANShare::Protocol::AFP ) return afp;
    if( p == NetworkConnectionsManager::LANShare::Protocol::NFS ) return nfs;
    return unknown;
}

string NetworkConnectionsManager::TitleForConnection(const Connection &_conn)
{
    string title_prefix = _conn.Title().empty() ? "" : _conn.Title() + " - ";
    
    if( auto ftp = _conn.Cast<FTPConnection>() ) {
        if(!ftp->user.empty())
            return title_prefix + "ftp://" + ftp->user + "@" + ftp->host;
        else
            return title_prefix + "ftp://" + ftp->host;
    }
    if( auto sftp = _conn.Cast<SFTPConnection>() ) {
        return title_prefix + "sftp://" + sftp->user + "@" + sftp->host;
    }
    if( auto share = _conn.Cast<NetworkConnectionsManager::LANShare>() ) {
        if( share->user.empty() )
            return title_prefix + PrefixForShareProtocol(share->proto) + "://" +
                share->host + "/" + share->share;
        else
            return title_prefix + PrefixForShareProtocol(share->proto) + "://" +
                share->user + "@" + share->host + "/" + share->share;
    }
    return title_prefix;
}

NetworkConnectionsManager::~NetworkConnectionsManager()
{
}


NetworkConnectionsManager::Connection::Connection() :
    m_Object{nullptr}
{
    throw domain_error("invalid connection construction");
}

const string& NetworkConnectionsManager::Connection::Title() const noexcept
{
    return m_Object->Title();
}

const boost::uuids::uuid& NetworkConnectionsManager::Connection::Uuid() const noexcept
{
    return m_Object->Uuid();
}

bool NetworkConnectionsManager::Connection::operator==(const Connection&_rhs) const noexcept
{
    return m_Object == _rhs.m_Object || m_Object->Equal(*_rhs.m_Object);
}

bool NetworkConnectionsManager::Connection::operator!=(const Connection&_rhs) const noexcept
{
    return !(*this == _rhs);
}

void NetworkConnectionsManager::Connection::Accept(
    NetworkConnectionsManager::ConnectionVisitor &_visitor ) const
{
    m_Object->Accept(_visitor);
}

void NetworkConnectionsManager::ConnectionVisitor::Visit(
    const NetworkConnectionsManager::FTPConnection &_ftp )
{
}

void NetworkConnectionsManager::ConnectionVisitor::Visit(
    const NetworkConnectionsManager::SFTPConnection &_sftp )
{
}

void NetworkConnectionsManager::ConnectionVisitor::Visit(
    const NetworkConnectionsManager::LANShare &_share )
{
}

bool NetworkConnectionsManager::BaseConnection::operator==(const BaseConnection&_rhs) const noexcept
{
    return uuid == _rhs.uuid && title == _rhs.title;
}

bool NetworkConnectionsManager::FTPConnection::operator==(const FTPConnection&_rhs) const noexcept
{
    return BaseConnection::operator==(_rhs) &&
        user == _rhs.user &&
        host == _rhs.host &&
        path == _rhs.path &&
        port == _rhs.port;
}

bool NetworkConnectionsManager::SFTPConnection::operator==(const SFTPConnection&_rhs) const noexcept
{
    return BaseConnection::operator==(_rhs) &&
        user == _rhs.user &&
        host == _rhs.host &&
        keypath == _rhs.keypath &&
        port == _rhs.port;
}

bool NetworkConnectionsManager::LANShare::operator==(const LANShare&_rhs) const noexcept
{
    return BaseConnection::operator==(_rhs) &&
        host == _rhs.host &&
        user == _rhs.user &&
        share == _rhs.share &&
        mountpoint == _rhs.mountpoint &&
        proto == _rhs.proto;
}

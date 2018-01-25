// Copyright (C) 2015-2017 Michael Kazakov. Subject to GNU General Public License version 3.
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

struct ConnectionPathBuilder : public NetworkConnectionsManager::ConnectionVisitor
{
    ConnectionPathBuilder(const NetworkConnectionsManager::Connection &_connection):
        connection(_connection)
    {
        connection.Accept(*this);
    }
    string Path()
    {
        return move(path);
    }
private:
    void Visit( const NetworkConnectionsManager::FTP &ftp )
    {
        path = "ftp://" + (ftp.user.empty() ? ftp.host : ftp.user + "@" + ftp.host);
    }
    void Visit( const NetworkConnectionsManager::SFTP &sftp )
    {
        path = "sftp://" + sftp.user + "@" + sftp.host;
    }
    void Visit( const NetworkConnectionsManager::LANShare &share )
    {
        path = PrefixForShareProtocol(share.proto) + "://" +
            (share.user.empty() ?
                share.host + "/" + share.share :
                share.user + "@" + share.host + "/" + share.share);
    }
    void Visit( const NetworkConnectionsManager::Dropbox &dropbox )
    {
        path = "dropbox://" + dropbox.account;
    }
    void Visit( const NetworkConnectionsManager::WebDAV &webdav )
    {
        path = (webdav.https ? "https://" : "http://") +
            (webdav.user.empty() ? "" : webdav.user + "@" ) +
            webdav.host +
            (webdav.path.empty() ? "" :  "/" + webdav.path );
    }
    
    string path;
    const NetworkConnectionsManager::Connection &connection;
};

string NetworkConnectionsManager::MakeConnectionPath(const Connection &_connection)
{
    return ConnectionPathBuilder{_connection}.Path();
}

string NetworkConnectionsManager::TitleForConnection(const Connection &_conn)
{
    return _conn.Title().empty() ?
        MakeConnectionPath(_conn) :
        _conn.Title() + " - " + MakeConnectionPath(_conn);
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

NetworkConnectionsManager::ConnectionVisitor::~ConnectionVisitor()
{
}

void NetworkConnectionsManager::ConnectionVisitor::Visit(
    const NetworkConnectionsManager::FTP &_ftp )
{
}

void NetworkConnectionsManager::ConnectionVisitor::Visit(
    const NetworkConnectionsManager::SFTP &_sftp )
{
}

void NetworkConnectionsManager::ConnectionVisitor::Visit(
    const NetworkConnectionsManager::LANShare &_share )
{
}

void NetworkConnectionsManager::ConnectionVisitor::Visit(
    const NetworkConnectionsManager::Dropbox &_account )
{
}

void NetworkConnectionsManager::ConnectionVisitor::Visit(
    const NetworkConnectionsManager::WebDAV &_webdav )
{
}

bool NetworkConnectionsManager::BaseConnection::operator==(const BaseConnection&_rhs) const noexcept
{
    return uuid == _rhs.uuid && title == _rhs.title;
}

bool NetworkConnectionsManager::FTP::operator==(const FTP&_rhs) const noexcept
{
    return BaseConnection::operator==(_rhs) &&
        user == _rhs.user &&
        host == _rhs.host &&
        path == _rhs.path &&
        port == _rhs.port;
}

bool NetworkConnectionsManager::SFTP::operator==(const SFTP&_rhs) const noexcept
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

bool NetworkConnectionsManager::Dropbox::operator==(const Dropbox&_rhs) const noexcept
{
    return BaseConnection::operator==(_rhs) &&
        account == _rhs.account;
}

bool NetworkConnectionsManager::WebDAV::operator==(const WebDAV&_rhs) const noexcept
{
    return BaseConnection::operator==(_rhs) &&
        host == _rhs.host &&
        path == _rhs.path &&
        user == _rhs.user &&
        port == _rhs.port &&
        https== _rhs.https;
}

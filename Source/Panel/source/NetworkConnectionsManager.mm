// Copyright (C) 2015-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "NetworkConnectionsManager.h"

namespace nc::panel {

using namespace std::literals;

nc::base::UUID NetworkConnectionsManager::MakeUUID()
{
    return nc::base::UUID::Generate();
}

static const std::string &PrefixForShareProtocol(NetworkConnectionsManager::LANShare::Protocol p)
{
    [[clang::no_destroy]] static const auto smb = "smb"s;
    [[clang::no_destroy]] static const auto afp = "afp"s;
    [[clang::no_destroy]] static const auto nfs = "nfs"s;
    [[clang::no_destroy]] static const auto unknown = ""s;
    if( p == NetworkConnectionsManager::LANShare::Protocol::SMB )
        return smb;
    if( p == NetworkConnectionsManager::LANShare::Protocol::AFP )
        return afp;
    if( p == NetworkConnectionsManager::LANShare::Protocol::NFS )
        return nfs;
    return unknown;
}

struct ConnectionPathBuilder : public NetworkConnectionsManager::ConnectionVisitor {
    ConnectionPathBuilder(const NetworkConnectionsManager::Connection &_connection) : connection(_connection)
    {
        connection.Accept(*this);
    }
    std::string Path() { return std::move(path); }

private:
    void Visit(const NetworkConnectionsManager::FTP &ftp) override
    {
        path = "ftp://" + (ftp.user.empty() ? ftp.host : ftp.user + "@" + ftp.host);
    }
    void Visit(const NetworkConnectionsManager::SFTP &sftp) override { path = "sftp://" + sftp.user + "@" + sftp.host; }
    void Visit(const NetworkConnectionsManager::LANShare &share) override
    {
        path =
            PrefixForShareProtocol(share.proto) + "://" +
            (share.user.empty() ? share.host + "/" + share.share : share.user + "@" + share.host + "/" + share.share);
    }
    void Visit(const NetworkConnectionsManager::Dropbox &dropbox) override { path = "dropbox://" + dropbox.account; }
    void Visit(const NetworkConnectionsManager::WebDAV &webdav) override
    {
        path = (webdav.https ? "https://" : "http://") + (webdav.user.empty() ? "" : webdav.user + "@") + webdav.host +
               (webdav.path.empty() ? "" : "/" + webdav.path);
    }

    std::string path;
    const NetworkConnectionsManager::Connection &connection;
};

std::string NetworkConnectionsManager::MakeConnectionPath(const Connection &_connection)
{
    return ConnectionPathBuilder{_connection}.Path();
}

std::string NetworkConnectionsManager::TitleForConnection(const Connection &_conn)
{
    return _conn.Title().empty() ? MakeConnectionPath(_conn) : _conn.Title() + " - " + MakeConnectionPath(_conn);
}

NetworkConnectionsManager::Connection::Connection() : m_Object{nullptr}
{
    throw std::domain_error("invalid connection construction");
}

const std::string &NetworkConnectionsManager::Connection::Title() const noexcept
{
    return m_Object->Title();
}

const nc::base::UUID &NetworkConnectionsManager::Connection::Uuid() const noexcept
{
    return m_Object->Uuid();
}

bool NetworkConnectionsManager::Connection::operator==(const Connection &_rhs) const noexcept
{
    return m_Object == _rhs.m_Object || m_Object->Equal(*_rhs.m_Object);
}

bool NetworkConnectionsManager::Connection::operator!=(const Connection &_rhs) const noexcept
{
    return !(*this == _rhs);
}

void NetworkConnectionsManager::Connection::Accept(NetworkConnectionsManager::ConnectionVisitor &_visitor) const
{
    m_Object->Accept(_visitor);
}

NetworkConnectionsManager::ConnectionVisitor::~ConnectionVisitor() = default;

void NetworkConnectionsManager::ConnectionVisitor::Visit(const NetworkConnectionsManager::FTP & /*unused*/)
{
}

void NetworkConnectionsManager::ConnectionVisitor::Visit(const NetworkConnectionsManager::SFTP & /*unused*/)
{
}

void NetworkConnectionsManager::ConnectionVisitor::Visit(const NetworkConnectionsManager::LANShare & /*unused*/)
{
}

void NetworkConnectionsManager::ConnectionVisitor::Visit(const NetworkConnectionsManager::Dropbox & /*unused*/)
{
}

void NetworkConnectionsManager::ConnectionVisitor::Visit(const NetworkConnectionsManager::WebDAV & /*unused*/)
{
}

bool NetworkConnectionsManager::FTP::operator==(const FTP &_rhs) const noexcept
{
    return BaseConnection::operator==(_rhs) && user == _rhs.user && host == _rhs.host && path == _rhs.path &&
           port == _rhs.port && active == _rhs.active;
}

bool NetworkConnectionsManager::SFTP::operator==(const SFTP &_rhs) const noexcept
{
    return BaseConnection::operator==(_rhs) && user == _rhs.user && host == _rhs.host && keypath == _rhs.keypath &&
           port == _rhs.port;
}

bool NetworkConnectionsManager::LANShare::operator==(const LANShare &_rhs) const noexcept
{
    return BaseConnection::operator==(_rhs) && host == _rhs.host && user == _rhs.user && share == _rhs.share &&
           mountpoint == _rhs.mountpoint && proto == _rhs.proto;
}

bool NetworkConnectionsManager::Dropbox::operator==(const Dropbox &_rhs) const noexcept
{
    return BaseConnection::operator==(_rhs) && account == _rhs.account;
}

bool NetworkConnectionsManager::WebDAV::operator==(const WebDAV &_rhs) const noexcept
{
    return BaseConnection::operator==(_rhs) && host == _rhs.host && path == _rhs.path && user == _rhs.user &&
           port == _rhs.port && https == _rhs.https;
}

} // namespace nc::panel

// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "AccountsFetcher.h"
#include <Base/algo.h>
#include <VFS/VFSError.h>
#include <algorithm>
#include <unordered_map>

// libssh2 has macros with C-style casts
#pragma clang diagnostic ignored "-Wold-style-cast"

namespace nc::vfs::sftp {

AccountsFetcher::AccountsFetcher(LIBSSH2_SESSION *_session, OSType _os_type) : m_Session(_session), m_OSType(_os_type)
{
}

int AccountsFetcher::FetchUsers(std::vector<VFSUser> &_target)
{
    _target.clear();

    int rc = VFSError::Ok;
    if( m_OSType == OSType::Linux || m_OSType == OSType::xBSD )
        rc = GetUsersViaGetent(_target);
    else if( m_OSType == OSType::MacOSX )
        rc = GetUsersViaOpenDirectory(_target);
    else
        rc = VFSError::FromErrno(ENODEV);

    if( rc != VFSError::Ok )
        return rc;

    std::ranges::sort(_target, [](const auto &_1, const auto &_2) {
        return static_cast<signed>(_1.uid) < static_cast<signed>(_2.uid);
    });
    _target.erase(std::ranges::unique(_target, [](const auto &_1, const auto &_2) { return _1.uid == _2.uid; }).begin(),
                  std::end(_target));

    return VFSError::Ok;
}

int AccountsFetcher::FetchGroups(std::vector<VFSGroup> &_target)
{
    _target.clear();

    int rc = VFSError::Ok;
    if( m_OSType == OSType::Linux || m_OSType == OSType::xBSD )
        rc = GetGroupsViaGetent(_target);
    else if( m_OSType == OSType::MacOSX )
        rc = GetGroupsViaOpenDirectory(_target);
    else
        rc = VFSError::FromErrno(ENODEV);

    if( rc != VFSError::Ok )
        return rc;

    std::ranges::sort(_target, [](const auto &_1, const auto &_2) {
        return static_cast<signed>(_1.gid) < static_cast<signed>(_2.gid);
    });
    _target.erase(std::ranges::unique(_target, [](const auto &_1, const auto &_2) { return _1.gid == _2.gid; }).begin(),
                  std::end(_target));

    return VFSError::Ok;
}

int AccountsFetcher::GetUsersViaGetent(std::vector<VFSUser> &_target)
{
    const auto getent = Execute("getent passwd");
    if( !getent )
        return VFSError::FromErrno(ENODEV);

    const std::vector<std::string> entries = base::SplitByDelimiter(*getent, '\n');
    for( const auto &e : entries ) {
        const std::vector<std::string> fields = base::SplitByDelimiter(e, ':', false);
        const auto passwd_fields = 7;
        if( fields.size() == passwd_fields ) {
            VFSUser user;
            user.name = fields[0];
            user.gecos = fields[4];
            user.gecos = std::string{base::TrimRight(user.gecos, ',')};
            user.uid = static_cast<unsigned>(std::atoi(fields[2].c_str()));
            _target.emplace_back(std::move(user));
        }
    }

    return VFSError::Ok;
}

int AccountsFetcher::GetGroupsViaGetent(std::vector<VFSGroup> &_target)
{
    const auto getent = Execute("getent group");
    if( !getent )
        return VFSError::FromErrno(ENODEV);

    const std::vector<std::string> entries = base::SplitByDelimiter(*getent, '\n');

    for( const auto &e : entries ) {
        const std::vector<std::string> fields = base::SplitByDelimiter(e, ':', false);
        const auto group_fields_at_least = 3;
        if( fields.size() >= group_fields_at_least ) {
            VFSGroup group;
            group.name = fields[0];
            group.gid = static_cast<unsigned>(std::atoi(fields[2].c_str()));
            _target.emplace_back(std::move(group));
        }
    }

    return VFSError::Ok;
}

int AccountsFetcher::GetUsersViaOpenDirectory(std::vector<VFSUser> &_target)
{
    const auto ds_ids = Execute("dscl . -list /Users UniqueID");
    if( !ds_ids )
        return VFSError::FromErrno(ENODEV);

    const auto ds_gecos = Execute("dscl . -list /Users RealName");
    if( !ds_gecos )
        return VFSError::FromErrno(ENODEV);

    std::unordered_map<std::string, std::pair<uint32_t, std::string>> users; // user -> uid, gecos
    std::vector<std::string> entries = base::SplitByDelimiter(*ds_ids, '\n');
    for( const auto &e : entries )
        if( const auto fs = e.find(' '); fs != std::string::npos ) {
            const auto name = e.substr(0, fs);
            auto uid_str = std::string{base::TrimLeft(e.substr(fs), ' ')};
            users[name].first = static_cast<uint32_t>(std::atoi(uid_str.c_str()));
        }

    entries = base::SplitByDelimiter(*ds_gecos, '\n');
    for( const auto &e : entries )
        if( const auto fs = e.find(' '); fs != std::string::npos ) {
            const auto name = e.substr(0, fs);
            auto gecos = e.substr(fs);
            users[name].second = base::TrimLeft(gecos, ' ');
        }

    for( const auto &u : users ) {
        VFSUser user;
        user.name = u.first;
        user.uid = u.second.first;
        user.gecos = u.second.second;
        _target.emplace_back(std::move(user));
    }

    return VFSError::Ok;
}

int AccountsFetcher::GetGroupsViaOpenDirectory(std::vector<VFSGroup> &_target)
{
    const auto ds_ids = Execute("dscl . -list /Groups PrimaryGroupID");
    if( !ds_ids )
        return VFSError::FromErrno(ENODEV);

    const auto ds_gecos = Execute("dscl . -list /Groups RealName");
    if( !ds_gecos )
        return VFSError::FromErrno(ENODEV);

    std::unordered_map<std::string, std::pair<uint32_t, std::string>> groups; // group -> gid, gecos
    std::vector<std::string> entries = base::SplitByDelimiter(*ds_ids, '\n');

    for( const auto &e : entries )
        if( const auto fs = e.find(' '); fs != std::string::npos ) {
            const auto name = e.substr(0, fs);
            auto gid_str = std::string{base::TrimLeft(e.substr(fs), ' ')};
            groups[name].first = static_cast<uint32_t>(std::atoi(gid_str.c_str()));
        }

    entries = base::SplitByDelimiter(*ds_gecos, '\n');
    for( const auto &e : entries )
        if( const auto fs = e.find(' '); fs != std::string::npos ) {
            const auto name = e.substr(0, fs);
            auto gecos = e.substr(fs);
            groups[name].second = base::TrimLeft(gecos, ' ');
        }

    for( const auto &g : groups ) {
        VFSGroup group;
        group.name = g.first;
        group.gid = g.second.first;
        group.gecos = g.second.second;
        _target.emplace_back(std::move(group));
    }

    return VFSError::Ok;
}

std::optional<std::string> AccountsFetcher::Execute(const std::string &_command)
{
    LIBSSH2_CHANNEL *channel = libssh2_channel_open_session(m_Session);
    if( channel == nullptr )
        return std::nullopt;

    int rc = libssh2_channel_exec(channel, _command.c_str());
    if( rc < 0 ) {
        libssh2_channel_close(channel);
        libssh2_channel_free(channel);
        return std::nullopt;
    }

    std::string response;

    char buffer[4096];
    while( (rc = (int)libssh2_channel_read(channel, buffer, sizeof(buffer) - 1)) > 0 ) {
        buffer[rc] = 0;
        response += buffer;
    }

    libssh2_channel_close(channel);
    libssh2_channel_free(channel);

    if( rc < 0 )
        return std::nullopt;

    return std::move(response);
}

} // namespace nc::vfs::sftp

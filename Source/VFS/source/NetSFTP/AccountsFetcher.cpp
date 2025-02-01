// Copyright (C) 2017-2025 Michael Kazakov. Subject to GNU General Public License version 3.
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

std::expected<std::vector<VFSUser>, Error> AccountsFetcher::FetchUsers()
{
    std::expected<std::vector<VFSUser>, Error> res = std::unexpected(Error{Error::POSIX, ENODEV});
    if( m_OSType == OSType::Linux || m_OSType == OSType::xBSD )
        res = GetUsersViaGetent();
    else if( m_OSType == OSType::MacOSX )
        res = GetUsersViaOpenDirectory();

    if( res ) {
        std::vector<VFSUser> &users = res.value();
        std::ranges::sort(users, [](const auto &_1, const auto &_2) {
            return static_cast<signed>(_1.uid) < static_cast<signed>(_2.uid);
        });
        users.erase(std::ranges::unique(users, [](const auto &_1, const auto &_2) { return _1.uid == _2.uid; }).begin(),
                    users.end());
    }
    return res;
}

std::expected<std::vector<VFSGroup>, Error> AccountsFetcher::FetchGroups()
{
    std::expected<std::vector<VFSGroup>, Error> res = std::unexpected(Error{Error::POSIX, ENODEV});
    if( m_OSType == OSType::Linux || m_OSType == OSType::xBSD )
        res = GetGroupsViaGetent();
    else if( m_OSType == OSType::MacOSX )
        res = GetGroupsViaOpenDirectory();

    if( res ) {
        std::vector<VFSGroup> &groups = res.value();
        std::ranges::sort(groups, [](const auto &_1, const auto &_2) {
            return static_cast<signed>(_1.gid) < static_cast<signed>(_2.gid);
        });
        groups.erase(
            std::ranges::unique(groups, [](const auto &_1, const auto &_2) { return _1.gid == _2.gid; }).begin(),
            groups.end());
    }
    return res;
}

std::expected<std::vector<VFSUser>, Error> AccountsFetcher::GetUsersViaGetent()
{
    const auto getent = Execute("getent passwd");
    if( !getent )
        return std::unexpected(Error{Error::POSIX, ENODEV});

    const std::vector<std::string> entries = base::SplitByDelimiter(*getent, '\n');
    std::vector<VFSUser> users;
    for( const auto &e : entries ) {
        const std::vector<std::string> fields = base::SplitByDelimiter(e, ':', false);
        const auto passwd_fields = 7;
        if( fields.size() == passwd_fields ) {
            VFSUser user;
            user.name = fields[0];
            user.gecos = fields[4];
            user.gecos = std::string{base::TrimRight(user.gecos, ',')};
            user.uid = static_cast<unsigned>(std::atoi(fields[2].c_str()));
            users.emplace_back(std::move(user));
        }
    }

    return std::move(users);
}

std::expected<std::vector<VFSGroup>, Error> AccountsFetcher::GetGroupsViaGetent()
{
    const auto getent = Execute("getent group");
    if( !getent )
        return std::unexpected(Error{Error::POSIX, ENODEV});

    const std::vector<std::string> entries = base::SplitByDelimiter(*getent, '\n');

    std::vector<VFSGroup> groups;
    for( const auto &e : entries ) {
        const std::vector<std::string> fields = base::SplitByDelimiter(e, ':', false);
        const auto group_fields_at_least = 3;
        if( fields.size() >= group_fields_at_least ) {
            VFSGroup group;
            group.name = fields[0];
            group.gid = static_cast<unsigned>(std::atoi(fields[2].c_str()));
            groups.emplace_back(std::move(group));
        }
    }

    return std::move(groups);
}

std::expected<std::vector<VFSUser>, Error> AccountsFetcher::GetUsersViaOpenDirectory()
{
    const auto ds_ids = Execute("dscl . -list /Users UniqueID");
    if( !ds_ids )
        return std::unexpected(Error{Error::POSIX, ENODEV});

    const auto ds_gecos = Execute("dscl . -list /Users RealName");
    if( !ds_gecos )
        return std::unexpected(Error{Error::POSIX, ENODEV});

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

    std::vector<VFSUser> target;
    for( const auto &u : users ) {
        VFSUser user;
        user.name = u.first;
        user.uid = u.second.first;
        user.gecos = u.second.second;
        target.emplace_back(std::move(user));
    }

    return std::move(target);
}

std::expected<std::vector<VFSGroup>, Error> AccountsFetcher::GetGroupsViaOpenDirectory()
{
    const auto ds_ids = Execute("dscl . -list /Groups PrimaryGroupID");
    if( !ds_ids )
        return std::unexpected(Error{Error::POSIX, ENODEV});

    const auto ds_gecos = Execute("dscl . -list /Groups RealName");
    if( !ds_gecos )
        return std::unexpected(Error{Error::POSIX, ENODEV});

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

    std::vector<VFSGroup> target;
    for( const auto &g : groups ) {
        VFSGroup group;
        group.name = g.first;
        group.gid = g.second.first;
        group.gecos = g.second.second;
        target.emplace_back(std::move(group));
    }

    return std::move(target);
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

// Copyright (C) 2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "OpenDirectory.h"
#include <OpenDirectory/OpenDirectory.h>
#include <Utility/ObjCpp.h>
#include <algorithm>

namespace nc::vfs::native {

std::expected<std::vector<VFSUser>, Error> FetchUsers()
{
    NSError *error;
    const auto node_name = @"/Local/Default";
    const auto node = [ODNode nodeWithSession:ODSession.defaultSession name:node_name error:&error];
    if( !node )
        return std::unexpected(Error{error});

    const auto attributes = @[kODAttributeTypeUniqueID, kODAttributeTypeFullName];
    const auto query = [ODQuery queryWithNode:node
                               forRecordTypes:kODRecordTypeUsers
                                    attribute:nil
                                    matchType:0
                                  queryValues:nil
                             returnAttributes:attributes
                               maximumResults:0
                                        error:&error];
    if( !query )
        return std::unexpected(Error{error});

    const auto records = [query resultsAllowingPartial:false error:&error];
    if( !records )
        return std::unexpected(Error{error});

    std::vector<VFSUser> users;
    for( ODRecord *record in records ) {
        const auto uid_values = [record valuesForAttribute:kODAttributeTypeUniqueID error:nil];
        if( uid_values == nil || uid_values.count == 0 )
            continue;
        const auto uid = static_cast<uint32_t>(objc_cast<NSString>(uid_values.firstObject).integerValue);

        const auto gecos_values = [record valuesForAttribute:kODAttributeTypeFullName error:nil];
        const auto gecos =
            (gecos_values && gecos_values.count > 0) ? objc_cast<NSString>(gecos_values.firstObject).UTF8String : "";

        VFSUser user;
        user.uid = uid;
        user.name = record.recordName.UTF8String;
        user.gecos = gecos;
        users.emplace_back(std::move(user));
    }

    std::ranges::sort(users, [](const auto &_1, const auto &_2) {
        return static_cast<signed>(_1.uid) < static_cast<signed>(_2.uid);
    });
    users.erase(std::ranges::unique(users, [](const auto &_1, const auto &_2) { return _1.uid == _2.uid; }).begin(),
                users.end());

    return std::move(users);
}

std::expected<std::vector<VFSGroup>, Error> FetchGroups()
{
    NSError *error;
    const auto node_name = @"/Local/Default";
    const auto node = [ODNode nodeWithSession:ODSession.defaultSession name:node_name error:&error];
    if( !node )
        return std::unexpected(Error{error});

    const auto attributes = @[kODAttributeTypePrimaryGroupID, kODAttributeTypeFullName];
    const auto query = [ODQuery queryWithNode:node
                               forRecordTypes:kODRecordTypeGroups
                                    attribute:nil
                                    matchType:0
                                  queryValues:nil
                             returnAttributes:attributes
                               maximumResults:0
                                        error:&error];
    if( !query )
        return std::unexpected(Error{error});

    const auto records = [query resultsAllowingPartial:false error:&error];
    if( !records )
        return std::unexpected(Error{error});

    std::vector<VFSGroup> groups;
    for( ODRecord *record in records ) {
        const auto gid_values = [record valuesForAttribute:kODAttributeTypePrimaryGroupID error:nil];
        if( gid_values == nil || gid_values.count == 0 )
            continue;
        const auto gid = static_cast<uint32_t>(objc_cast<NSString>(gid_values.firstObject).integerValue);

        const auto gecos_values = [record valuesForAttribute:kODAttributeTypeFullName error:nil];
        const auto gecos =
            (gecos_values && gecos_values.count > 0) ? objc_cast<NSString>(gecos_values.firstObject).UTF8String : "";

        VFSGroup group;
        group.gid = gid;
        group.name = record.recordName.UTF8String;
        group.gecos = gecos;
        groups.emplace_back(std::move(group));
    }

    std::ranges::sort(groups, [](const auto &_1, const auto &_2) {
        return static_cast<signed>(_1.gid) < static_cast<signed>(_2.gid);
    });
    groups.erase(std::ranges::unique(groups, [](const auto &_1, const auto &_2) { return _1.gid == _2.gid; }).begin(),
                 groups.end());

    return std::move(groups);
}

} // namespace nc::vfs::native

// Copyright (C) 2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include "FollowSymlink.h"
#include "../PanelController.h"
#include "../PanelView.h"

namespace nc::panel::actions {

bool FollowSymlink::Predicate(PanelController *_target) const
{
    const auto item = _target.view.item;
    if( !item )
        return false;

    return item.IsSymlink();
}

bool FollowSymlink::ValidateMenuItem(PanelController *_target, NSMenuItem *_item) const
{
    if( auto vfs_item = _target.view.item ) {
        _item.title = [NSString
            stringWithFormat:NSLocalizedString(@"Follow \u201c%@\u201d", "Follow a symlink"), vfs_item.DisplayNameNS()];
    }

    return Predicate(_target);
}

void FollowSymlink::Perform(PanelController *_target, [[maybe_unused]] id _sender) const
{
    const auto item = _target.view.item;
    if( !item )
        return;

    if( !item.IsSymlink() || !item.HasSymlink() )
        return;

    // poor man's symlink resolution:
    const auto symlink_target =
        (std::filesystem::path(item.Directory()) / std::filesystem::path(item.Symlink())).lexically_normal();
    if( symlink_target.empty() )
        return;

    auto request = std::make_shared<DirectoryChangeRequest>();
    request->VFS = item.Host();
    request->LoadPreviousViewState = false;
    request->PerformAsynchronous = true;
    request->InitiatedByUser = true;
    request->RequestedDirectory = symlink_target.parent_path();
    request->RequestFocusedEntry = symlink_target.filename();
    [_target GoToDirWithContext:request];
}

} // namespace nc::panel::actions

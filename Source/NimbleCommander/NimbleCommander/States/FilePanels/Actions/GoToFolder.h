// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "DefaultAction.h"
#include <Panel/NetworkConnectionsManager.h>

@class PanelController;

namespace nc::panel::actions {

// external dependencies:
// - nc::bootstrap::NativeVFSHostInstance()

struct GoToFolder final : PanelAction {
    void Perform(PanelController *_target, id _sender) const override;
};

struct GoToHomeFolder final : PanelAction {
    void Perform(PanelController *_target, id _sender) const override;
};

struct GoToDocumentsFolder final : PanelAction {
    void Perform(PanelController *_target, id _sender) const override;
};

struct GoToDesktopFolder final : PanelAction {
    void Perform(PanelController *_target, id _sender) const override;
};

struct GoToDownloadsFolder final : PanelAction {
    void Perform(PanelController *_target, id _sender) const override;
};

struct GoToApplicationsFolder final : PanelAction {
    void Perform(PanelController *_target, id _sender) const override;
};

struct GoToUtilitiesFolder final : PanelAction {
    void Perform(PanelController *_target, id _sender) const override;
};

struct GoToLibraryFolder final : PanelAction {
    void Perform(PanelController *_target, id _sender) const override;
};

struct GoToRootFolder final : PanelAction {
    void Perform(PanelController *_target, id _sender) const override;
};

struct GoToProcessesList final : PanelAction {
    void Perform(PanelController *_target, id _sender) const override;
};

struct GoToFavoriteLocation final : PanelAction {
    GoToFavoriteLocation(NetworkConnectionsManager &_net_mgr);
    void Perform(PanelController *_target, id _sender) const override;

private:
    NetworkConnectionsManager &m_NetMgr;
};

struct GoToEnclosingFolder final : PanelAction {
    bool Predicate(PanelController *_target) const override;
    void Perform(PanelController *_target, id _sender) const override;
};

struct GoIntoFolder final : PanelAction {
    GoIntoFolder(bool _force_checking_for_archive = false);
    bool Predicate(PanelController *_target) const override;
    bool ValidateMenuItem(PanelController *_target, NSMenuItem *_item) const override;
    void Perform(PanelController *_target, id _sender) const override;

private:
    const bool m_ForceArchivesChecking;
};

}; // namespace nc::panel::actions

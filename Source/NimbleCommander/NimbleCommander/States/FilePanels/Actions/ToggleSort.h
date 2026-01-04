// Copyright (C) 2017-2021 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "DefaultAction.h"

@class PanelController;

namespace nc::panel::actions {

struct ToggleSortingByName final : PanelAction {
    [[nodiscard]] bool ValidateMenuItem(PanelController *_target, NSMenuItem *_item) const override;
    void Perform(PanelController *_target, id _sender) const override;
};

struct ToggleSortingByExtension final : PanelAction {
    [[nodiscard]] bool ValidateMenuItem(PanelController *_target, NSMenuItem *_item) const override;
    void Perform(PanelController *_target, id _sender) const override;
};

struct ToggleSortingBySize final : PanelAction {
    [[nodiscard]] bool ValidateMenuItem(PanelController *_target, NSMenuItem *_item) const override;
    void Perform(PanelController *_target, id _sender) const override;
};

struct ToggleSortingByModifiedTime final : PanelAction {
    [[nodiscard]] bool ValidateMenuItem(PanelController *_target, NSMenuItem *_item) const override;
    void Perform(PanelController *_target, id _sender) const override;
};

struct ToggleSortingByCreatedTime final : PanelAction {
    [[nodiscard]] bool ValidateMenuItem(PanelController *_target, NSMenuItem *_item) const override;
    void Perform(PanelController *_target, id _sender) const override;
};

struct ToggleSortingByAddedTime final : PanelAction {
    [[nodiscard]] bool ValidateMenuItem(PanelController *_target, NSMenuItem *_item) const override;
    void Perform(PanelController *_target, id _sender) const override;
};

struct ToggleSortingByAccessedTime final : PanelAction {
    [[nodiscard]] bool ValidateMenuItem(PanelController *_target, NSMenuItem *_item) const override;
    void Perform(PanelController *_target, id _sender) const override;
};

struct ToggleSortingNaturalCollation final : PanelAction {
    [[nodiscard]] bool ValidateMenuItem(PanelController *_target, NSMenuItem *_item) const override;
    void Perform(PanelController *_target, id _sender) const override;
};

struct ToggleSortingCaseInsensitiveCollation final : PanelAction {
    [[nodiscard]] bool ValidateMenuItem(PanelController *_target, NSMenuItem *_item) const override;
    void Perform(PanelController *_target, id _sender) const override;
};

struct ToggleSortingCaseSensitiveCollation final : PanelAction {
    [[nodiscard]] bool ValidateMenuItem(PanelController *_target, NSMenuItem *_item) const override;
    void Perform(PanelController *_target, id _sender) const override;
};

struct ToggleSortingFoldersSeparation final : PanelAction {
    [[nodiscard]] bool ValidateMenuItem(PanelController *_target, NSMenuItem *_item) const override;
    void Perform(PanelController *_target, id _sender) const override;
};

struct ToggleSortingExtensionlessFolders final : PanelAction {
    [[nodiscard]] bool ValidateMenuItem(PanelController *_target, NSMenuItem *_item) const override;
    void Perform(PanelController *_target, id _sender) const override;
};

struct ToggleSortingShowHidden final : PanelAction {
    [[nodiscard]] bool ValidateMenuItem(PanelController *_target, NSMenuItem *_item) const override;
    void Perform(PanelController *_target, id _sender) const override;
};

}; // namespace nc::panel::actions

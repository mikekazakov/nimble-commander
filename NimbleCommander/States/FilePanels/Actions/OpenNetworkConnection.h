// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "DefaultAction.h"

namespace nc::panel::actions {

struct OpenNewFTPConnection final : PanelAction
{
    void Perform( PanelController *_target, id _sender ) const override;
};

struct OpenNewSFTPConnection final : PanelAction
{
    void Perform( PanelController *_target, id _sender ) const override;
};

struct OpenNewWebDAVConnection final : PanelAction
{
    void Perform( PanelController *_target, id _sender ) const override;
};

struct OpenNewDropboxStorage final : PanelAction
{
    void Perform( PanelController *_target, id _sender ) const override;
};

struct OpenNewLANShare final : PanelAction
{
    void Perform( PanelController *_target, id _sender ) const override;
};

struct OpenNetworkConnections final : PanelAction
{
    void Perform( PanelController *_target, id _sender ) const override;
};

// will extract additional context from _sender.representedObject
struct OpenExistingNetworkConnection final : PanelAction
{
    void Perform( PanelController *_target, id _sender ) const override;
};

}

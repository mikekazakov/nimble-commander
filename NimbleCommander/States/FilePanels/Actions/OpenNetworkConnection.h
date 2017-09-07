#pragma once

#include "DefaultAction.h"

namespace nc::panel::actions {

struct OpenNewFTPConnection : PanelAction
{
    void Perform( PanelController *_target, id _sender ) const override;
};

struct OpenNewSFTPConnection : PanelAction
{
    void Perform( PanelController *_target, id _sender ) const override;
};

struct OpenNewWebDAVConnection : PanelAction
{
    void Perform( PanelController *_target, id _sender ) const override;
};

struct OpenNewDropboxStorage : PanelAction
{
    void Perform( PanelController *_target, id _sender ) const override;
};

struct OpenNewLANShare : PanelAction
{
    void Perform( PanelController *_target, id _sender ) const override;
};

struct OpenNetworkConnections : PanelAction
{
    void Perform( PanelController *_target, id _sender ) const override;
};

// will extract additional context from _sender.representedObject
struct OpenExistingNetworkConnection : PanelAction
{
    void Perform( PanelController *_target, id _sender ) const override;
};

}

#pragma once

#include "DefaultAction.h"

@class PanelController;

namespace nc::panel::actions {

// external dependency - SanboxManager

struct GoToFolder : PanelAction
{
    void Perform( PanelController *_target, id _sender ) const override;
};

struct GoToHomeFolder : PanelAction
{
    void Perform( PanelController *_target, id _sender ) const override;
};

struct GoToDocumentsFolder : PanelAction
{
    void Perform( PanelController *_target, id _sender ) const override;
};

struct GoToDesktopFolder : PanelAction
{
    void Perform( PanelController *_target, id _sender ) const override;
};

struct GoToDownloadsFolder : PanelAction
{
    void Perform( PanelController *_target, id _sender ) const override;
};

struct GoToApplicationsFolder : PanelAction
{
    void Perform( PanelController *_target, id _sender ) const override;
};

struct GoToUtilitiesFolder : PanelAction
{
    void Perform( PanelController *_target, id _sender ) const override;
};

struct GoToLibraryFolder : PanelAction
{
    void Perform( PanelController *_target, id _sender ) const override;
};

struct GoToRootFolder : PanelAction
{
    void Perform( PanelController *_target, id _sender ) const override;
};

struct GoToProcessesList : PanelAction
{
    void Perform( PanelController *_target, id _sender ) const override;
};

struct GoToFavoriteLocation : PanelAction
{
    void Perform( PanelController *_target, id _sender ) const override;
};

struct GoToEnclosingFolder : PanelAction
{
    bool Predicate( PanelController *_target ) const override;
    void Perform( PanelController *_target, id _sender ) const override;
};

};

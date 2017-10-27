// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "DefaultAction.h"

@class PanelController;

namespace nc::panel::actions {

// external dependency - SanboxManager and ActivationManager

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

struct GoIntoFolder : PanelAction
{
    GoIntoFolder( bool _force_checking_for_archive = false );
    bool Predicate( PanelController *_target ) const override;
    void Perform( PanelController *_target, id _sender ) const override;
private:
    const bool m_ForceArchivesChecking;
};


};

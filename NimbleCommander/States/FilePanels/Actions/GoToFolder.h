// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "DefaultAction.h"

@class PanelController;

namespace nc::panel::actions {

// external dependency - SanboxManager

struct GoToFolder final : PanelAction
{
    void Perform( PanelController *_target, id _sender ) const override;
};

struct GoToHomeFolder final : PanelAction
{
    void Perform( PanelController *_target, id _sender ) const override;
};

struct GoToDocumentsFolder final : PanelAction
{
    void Perform( PanelController *_target, id _sender ) const override;
};

struct GoToDesktopFolder final : PanelAction
{
    void Perform( PanelController *_target, id _sender ) const override;
};

struct GoToDownloadsFolder final : PanelAction
{
    void Perform( PanelController *_target, id _sender ) const override;
};

struct GoToApplicationsFolder final : PanelAction
{
    void Perform( PanelController *_target, id _sender ) const override;
};

struct GoToUtilitiesFolder final : PanelAction
{
    void Perform( PanelController *_target, id _sender ) const override;
};

struct GoToLibraryFolder final : PanelAction
{
    void Perform( PanelController *_target, id _sender ) const override;
};

struct GoToRootFolder final : PanelAction
{
    void Perform( PanelController *_target, id _sender ) const override;
};

struct GoToProcessesList final : PanelAction
{
    void Perform( PanelController *_target, id _sender ) const override;
};

struct GoToFavoriteLocation final : PanelAction
{
    void Perform( PanelController *_target, id _sender ) const override;
};

struct GoToEnclosingFolder final : PanelAction
{
    bool Predicate( PanelController *_target ) const override;
    void Perform( PanelController *_target, id _sender ) const override;
};

struct GoIntoFolder final : PanelAction
{
    GoIntoFolder(bool _support_archives = false, 
                 bool _force_checking_for_archive = false );
    bool Predicate( PanelController *_target ) const override;
    void Perform( PanelController *_target, id _sender ) const override;
private:
    const bool m_SupportArchives;    
    const bool m_ForceArchivesChecking;
};

};

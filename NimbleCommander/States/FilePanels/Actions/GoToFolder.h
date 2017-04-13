#pragma once

#include "DefaultAction.h"

@class PanelController;

namespace panel::actions {

// external dependency - SanboxManager

struct GoToFolder : PanelAction
{
    void Perform( PanelController *_target, id _sender );
};

struct GoToHomeFolder : PanelAction
{
    void Perform( PanelController *_target, id _sender );
};

struct GoToDocumentsFolder : PanelAction
{
    void Perform( PanelController *_target, id _sender );
};

struct GoToDesktopFolder : PanelAction
{
    void Perform( PanelController *_target, id _sender );
};

struct GoToDownloadsFolder : PanelAction
{
    void Perform( PanelController *_target, id _sender );
};

struct GoToApplicationsFolder : PanelAction
{
    void Perform( PanelController *_target, id _sender );
};

struct GoToUtilitiesFolder : PanelAction
{
    void Perform( PanelController *_target, id _sender );
};

struct GoToLibraryFolder : PanelAction
{
    void Perform( PanelController *_target, id _sender );
};

struct GoToRootFolder : PanelAction
{
    void Perform( PanelController *_target, id _sender );
};

struct GoToProcessesList : PanelAction
{
    void Perform( PanelController *_target, id _sender );
};

};

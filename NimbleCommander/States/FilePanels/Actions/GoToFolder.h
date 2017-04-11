#pragma once

#include "DefaultAction.h"

@class PanelController;

namespace panel::actions {

// external dependency - SanboxManager

struct GoToFolder : DefaultPanelAction
{
    static void Perform( PanelController *_target, id _sender );
};

struct GoToHomeFolder : DefaultPanelAction
{
    static void Perform( PanelController *_target, id _sender );
};

struct GoToDocumentsFolder : DefaultPanelAction
{
    static void Perform( PanelController *_target, id _sender );
};

struct GoToDesktopFolder : DefaultPanelAction
{
    static void Perform( PanelController *_target, id _sender );
};

struct GoToDownloadsFolder : DefaultPanelAction
{
    static void Perform( PanelController *_target, id _sender );
};

struct GoToApplicationsFolder : DefaultPanelAction
{
    static void Perform( PanelController *_target, id _sender );
};

struct GoToUtilitiesFolder : DefaultPanelAction
{
    static void Perform( PanelController *_target, id _sender );
};

struct GoToLibraryFolder : DefaultPanelAction
{
    static void Perform( PanelController *_target, id _sender );
};

struct GoToRootFolder : DefaultPanelAction
{
    static void Perform( PanelController *_target, id _sender );
};

struct GoToProcessesList : DefaultPanelAction
{
    static void Perform( PanelController *_target, id _sender );
};

};

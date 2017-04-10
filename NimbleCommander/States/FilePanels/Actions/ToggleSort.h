#pragma once

#include "DefaultAction.h"

@class PanelController;

namespace panel::actions {

struct ToggleSortingByName : DefaultPanelAction
{
    static bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item );
    static void Perform( PanelController *_target, id _sender );
};

struct ToggleSortingByExtension : DefaultPanelAction
{
    static bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item );
    static void Perform( PanelController *_target, id _sender );
};

struct ToggleSortingBySize : DefaultPanelAction
{
    static bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item );
    static void Perform( PanelController *_target, id _sender );
};

struct ToggleSortingByModifiedTime : DefaultPanelAction
{
    static bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item );
    static void Perform( PanelController *_target, id _sender );
};

struct ToggleSortingByCreatedTime : DefaultPanelAction
{
    static bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item );
    static void Perform( PanelController *_target, id _sender );
};

struct ToggleSortingByAddedTime : DefaultPanelAction
{
    static bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item );
    static void Perform( PanelController *_target, id _sender );
};

struct ToggleSortingCaseSensitivity : DefaultPanelAction
{
    static bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item );
    static void Perform( PanelController *_target, id _sender );
};

struct ToggleSortingFoldersSeparation : DefaultPanelAction
{
    static bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item );
    static void Perform( PanelController *_target, id _sender );
};

struct ToggleSortingNumerical : DefaultPanelAction
{
    static bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item );
    static void Perform( PanelController *_target, id _sender );
};

struct ToggleSortingShowHidden : DefaultPanelAction
{
    static bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item );
    static void Perform( PanelController *_target, id _sender );
};

};

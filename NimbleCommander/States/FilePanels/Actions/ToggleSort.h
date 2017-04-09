#pragma once

#include "DefaultAction.h"

@class PanelController;

namespace panel::actions {

struct ToggleSortingByName : DefaultAction
{
    static bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item );
    static void Perform( PanelController *_target, id _sender );
};

struct ToggleSortingByExtension : DefaultAction
{
    static bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item );
    static void Perform( PanelController *_target, id _sender );
};

struct ToggleSortingBySize : DefaultAction
{
    static bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item );
    static void Perform( PanelController *_target, id _sender );
};

struct ToggleSortingByModifiedTime : DefaultAction
{
    static bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item );
    static void Perform( PanelController *_target, id _sender );
};

struct ToggleSortingByCreatedTime : DefaultAction
{
    static bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item );
    static void Perform( PanelController *_target, id _sender );
};

struct ToggleSortingByAddedTime : DefaultAction
{
    static bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item );
    static void Perform( PanelController *_target, id _sender );
};

struct ToggleSortingCaseSensitivity : DefaultAction
{
    static bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item );
    static void Perform( PanelController *_target, id _sender );
};

struct ToggleSortingFoldersSeparation : DefaultAction
{
    static bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item );
    static void Perform( PanelController *_target, id _sender );
};

struct ToggleSortingNumerical : DefaultAction
{
    static bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item );
    static void Perform( PanelController *_target, id _sender );
};

struct ToggleSortingShowHidden : DefaultAction
{
    static bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item );
    static void Perform( PanelController *_target, id _sender );
};

};

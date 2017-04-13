#pragma once

#include "DefaultAction.h"

@class PanelController;

namespace panel::actions {

struct ToggleSortingByName : PanelAction
{
    bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item );
    void Perform( PanelController *_target, id _sender );
};

struct ToggleSortingByExtension : PanelAction
{
    bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item );
    void Perform( PanelController *_target, id _sender );
};

struct ToggleSortingBySize : PanelAction
{
    bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item );
    void Perform( PanelController *_target, id _sender );
};

struct ToggleSortingByModifiedTime : PanelAction
{
    bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item );
    void Perform( PanelController *_target, id _sender );
};

struct ToggleSortingByCreatedTime : PanelAction
{
    bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item );
    void Perform( PanelController *_target, id _sender );
};

struct ToggleSortingByAddedTime : PanelAction
{
    bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item );
    void Perform( PanelController *_target, id _sender );
};

struct ToggleSortingCaseSensitivity : PanelAction
{
    bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item );
    void Perform( PanelController *_target, id _sender );
};

struct ToggleSortingFoldersSeparation : PanelAction
{
    bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item );
    void Perform( PanelController *_target, id _sender );
};

struct ToggleSortingNumerical : PanelAction
{
    bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item );
    void Perform( PanelController *_target, id _sender );
};

struct ToggleSortingShowHidden : PanelAction
{
    bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item );
    void Perform( PanelController *_target, id _sender );
};

};

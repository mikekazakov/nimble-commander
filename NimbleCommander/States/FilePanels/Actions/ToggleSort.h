#pragma once

#include "DefaultAction.h"

@class PanelController;

namespace nc::panel::actions {

struct ToggleSortingByName : PanelAction
{
    bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item ) const override;
    void Perform( PanelController *_target, id _sender ) const override;
};

struct ToggleSortingByExtension : PanelAction
{
    bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item ) const override;
    void Perform( PanelController *_target, id _sender ) const override;
};

struct ToggleSortingBySize : PanelAction
{
    bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item ) const override;
    void Perform( PanelController *_target, id _sender ) const override;
};

struct ToggleSortingByModifiedTime : PanelAction
{
    bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item ) const override;
    void Perform( PanelController *_target, id _sender ) const override;
};

struct ToggleSortingByCreatedTime : PanelAction
{
    bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item ) const override;
    void Perform( PanelController *_target, id _sender ) const override;
};

struct ToggleSortingByAddedTime : PanelAction
{
    bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item ) const override;
    void Perform( PanelController *_target, id _sender ) const override;
};

struct ToggleSortingCaseSensitivity : PanelAction
{
    bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item ) const override;
    void Perform( PanelController *_target, id _sender ) const override;
};

struct ToggleSortingFoldersSeparation : PanelAction
{
    bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item ) const override;
    void Perform( PanelController *_target, id _sender ) const override;
};

struct ToggleSortingExtensionlessFolders : PanelAction
{
    bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item ) const override;
    void Perform( PanelController *_target, id _sender ) const override;
};

struct ToggleSortingNumerical : PanelAction
{
    bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item ) const override;
    void Perform( PanelController *_target, id _sender ) const override;
};

struct ToggleSortingShowHidden : PanelAction
{
    bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item ) const override;
    void Perform( PanelController *_target, id _sender ) const override;
};

};

#pragma once

#include "DefaultAction.h"

namespace panel::actions {

struct CopyFileName : PanelAction
{
    bool Predicate( PanelController *_source ) const override;
    void Perform( PanelController *_source, id _sender ) const override;
};

struct CopyFilePath : PanelAction
{
    bool Predicate( PanelController *_source ) const override;
    void Perform( PanelController *_source, id _sender ) const override;
};
    
}

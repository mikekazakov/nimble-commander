#pragma once

#include "DefaultAction.h"

namespace panel::actions {

struct CopyFileName : PanelAction
{
    bool Predicate( PanelController *_source );
    void Perform( PanelController *_source, id _sender );
};

struct CopyFilePath : PanelAction
{
    bool Predicate( PanelController *_source );
    void Perform( PanelController *_source, id _sender );
};
    
}

#pragma once

@class PanelController;

namespace panel::actions {

struct CopyFileName
{
    static bool ValidateMenuItem( PanelController *_source, NSMenuItem *_item );
    static void Perform( PanelController *_source, id _sender );
};

struct CopyFilePath
{
    static bool ValidateMenuItem( PanelController *_source, NSMenuItem *_item );
    static void Perform( PanelController *_source, id _sender );
};
    
}

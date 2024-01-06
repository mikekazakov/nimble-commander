// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Config/RapidJSON_fwd.h>
#include <Utility/NativeFSManager.h>
#include <NimbleCommander/Core/VFSInstanceManager.h>

@class PanelController;

namespace nc::panel {
    
struct PersistentLocation;
    
struct ControllerStateEncoding
{
    enum Options {
        EncodeDataOptions   =  1,
        EncodeViewOptions   =  2,
        EncodeContentState  =  4,
            
        EncodeNothing       =  0,
        EncodeEverything    = -1
    };
};
  
// encoders / decoders assume beging called from the main thread, will assert() otherwise
    
class ControllerStateJSONEncoder
{
public:
    ControllerStateJSONEncoder(PanelController *_panel);
    
    config::Value Encode(ControllerStateEncoding::Options _options);
    
private:
    PanelController *m_Panel;
};

class ControllerStateJSONDecoder
{
public:
    ControllerStateJSONDecoder(const utility::NativeFSManager &_fs_manager,
                               nc::core::VFSInstanceManager &_vfs_instance_manager);
    
    void Decode(const config::Value &_state, PanelController *_panel);
    
private:
    void RecoverSavedContentAsync(PersistentLocation _location,
                                  PanelController *_panel );    
    void RecoverSavedContentSync(const PersistentLocation &_location,
                                 PanelController *_panel );    
    void RecoverSavedContent(const config::Value &_saved_state,
                                    PanelController *_panel );    
    bool AllowSyncRecovery(const PersistentLocation &_location) const;    
    
    const utility::NativeFSManager &m_NativeFSManager;    
    nc::core::VFSInstanceManager &m_VFSInstanceManager;
};
    
}

// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelControllerPersistency.h"
#include "PanelController.h"
#include "PanelData.h"
#include "PanelDataOptionsPersistence.h"
#include "PanelDataPersistency.h"
#include <VFS/Native.h>
#include <Habanero/CommonPaths.h>

namespace nc::panel {

static const auto g_RestorationDataKey = "data";
static const auto g_RestorationSortingKey = "sorting";
static const auto g_RestorationLayoutKey = "layout";

ControllerStateJSONEncoder::ControllerStateJSONEncoder(PanelController *_panel):
    m_Panel(_panel)
{
}

optional<rapidjson::StandaloneValue>
ControllerStateJSONEncoder::Encode(ControllerStateEncoding::Options _options)
{
    assert(dispatch_is_main_queue());
    rapidjson::StandaloneValue json(rapidjson::kObjectType);
    
    if( _options & ControllerStateEncoding::EncodeContentState ) {
        if( auto v = PanelDataPersisency::EncodeVFSPath(m_Panel.data.Listing()) )
            json.AddMember(rapidjson::MakeStandaloneString(g_RestorationDataKey),
                           move(*v),
                           rapidjson::g_CrtAllocator );
        else
            return nullopt;
    }
    
    if( _options & ControllerStateEncoding::EncodeDataOptions ) {
        json.AddMember(rapidjson::MakeStandaloneString(g_RestorationSortingKey),
                       data::OptionsExporter{m_Panel.data}.Export(), rapidjson::g_CrtAllocator );
    }
    
    if( _options & ControllerStateEncoding::EncodeViewOptions ) {
        json.AddMember(rapidjson::MakeStandaloneString(g_RestorationLayoutKey),
                       rapidjson::StandaloneValue(m_Panel.layoutIndex), rapidjson::g_CrtAllocator );
    }
    
    return move(json);
}

ControllerStateJSONDecoder::ControllerStateJSONDecoder(PanelController *_panel):
    m_Panel(_panel)
{
}
    
static void LoadHomeDirectory(PanelController *_panel)
{
    auto context = make_shared<DirectoryChangeRequest>();
    context->VFS = VFSNativeHost::SharedHost();
    context->PerformAsynchronous = true;
    context->RequestedDirectory = CommonPaths::Home();
    [_panel GoToDirWithContext:context];
}

// will go async
static void RecoverSavedContent( shared_ptr<rapidjson::StandaloneValue> _saved_state,
                                PanelController *_panel )
{
    auto workload = [_panel, _saved_state](const function<bool()> &_cancel_checker){
        VFSHostPtr host;
        if( PanelDataPersisency::CreateVFSFromState(*_saved_state, host) == VFSError::Ok ) {
            string path = PanelDataPersisency::GetPathFromState(*_saved_state);
            dispatch_to_main_queue([=]{
                auto context = make_shared<DirectoryChangeRequest>();
                context->VFS = host;
                context->PerformAsynchronous = true;
                context->RequestedDirectory = path;
                [_panel GoToDirWithContext:context];
            });
        }
        else if( !_panel.data.IsLoaded() ) {
            // we should not leave panel in empty/dummy state,
            // lets go to home directory as a fallback path
            dispatch_to_main_queue([=]{
                LoadHomeDirectory(_panel);
            });
        }
    };
    
    [_panel commitCancelableLoadingTask:move(workload)];
}

void ControllerStateJSONDecoder::Decode(const rapidjson::StandaloneValue &_state)
{
    assert(dispatch_is_main_queue());
    
    if( !_state.IsObject() )
        return;
        
    if( _state.HasMember(g_RestorationSortingKey) )
        [m_Panel changeDataOptions:[&](data::Model &_data){
            data::OptionsImporter{_data}.Import( _state[g_RestorationSortingKey] );
        }];
    
    if( _state.HasMember(g_RestorationLayoutKey) )
        if( _state[g_RestorationLayoutKey].IsNumber() )
            m_Panel.layoutIndex = _state[g_RestorationLayoutKey].GetInt();
    
    if( _state.HasMember(g_RestorationDataKey) ) {
        auto data = make_shared<rapidjson::StandaloneValue>();
        data->CopyFrom(_state[g_RestorationDataKey], rapidjson::g_CrtAllocator);
        RecoverSavedContent(data, m_Panel);
    }
}

}

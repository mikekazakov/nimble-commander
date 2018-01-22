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
    
static void RecoverSavedPathAtVFS(const VFSHostPtr &_host,
                                 const string &_path,
                                 PanelController *_panel)
{
    auto shared_request = make_shared<DirectoryChangeRequest>();
    auto &ctx = *shared_request;
    ctx.VFS = _host;
    ctx.PerformAsynchronous = true;
    ctx.RequestedDirectory = _path;
    ctx.LoadingResultCallback = [=](int _rc){
        if( _rc != VFSError::Ok && !_panel.data.IsLoaded() ) {
            // failed to load a listing on this VFS on specified path
            // will try upper directories on this VFS up to the root,
            // in case if everyone fails we will fallback to Home Directory on native VFS.
            auto fs_path = path{_path};
            if( fs_path.filename() == "." )
                fs_path.remove_filename();
            
            if( fs_path.has_parent_path() ) {
                auto upper_dir = fs_path.parent_path().native();
                dispatch_to_main_queue([=]{
                    RecoverSavedPathAtVFS(_host, upper_dir, _panel);
                });
            }
            else {
                dispatch_to_main_queue([=]{
                    LoadHomeDirectory(_panel);
                });
            }
        }
    };
    [_panel GoToDirWithContext:shared_request];
}

// will go async
static void RecoverSavedContent(shared_ptr<rapidjson::StandaloneValue> _saved_state,
                                PanelController *_panel )
{
    auto workload = [_panel, _saved_state](const function<bool()> &_cancel_checker){
        VFSHostPtr host;
        const auto rc = PanelDataPersisency::CreateVFSFromState(*_saved_state, host);
        if( rc == VFSError::Ok ) {
            // the VFS was recovered, lets go inside it.
            string path = PanelDataPersisency::GetPathFromState(*_saved_state);
            dispatch_to_main_queue([=]{
                RecoverSavedPathAtVFS(host, path, _panel);
            });
        }
        else if( !_panel.data.IsLoaded() ) {
            // the VFS was not recovered.
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
    
    if( auto layout_index = GetOptionalIntFromObject(_state, g_RestorationLayoutKey) )
        m_Panel.layoutIndex = *layout_index;
    
    if( _state.HasMember(g_RestorationDataKey) ) {
        auto data = make_shared<rapidjson::StandaloneValue>();
        data->CopyFrom(_state[g_RestorationDataKey], rapidjson::g_CrtAllocator);
        RecoverSavedContent(data, m_Panel);
    }
}

}

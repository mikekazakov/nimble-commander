// Copyright (C) 2018-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelControllerPersistency.h"
#include "PanelController.h"
#include "PanelData.h"
#include "PanelDataOptionsPersistence.h"
#include "PanelDataPersistency.h"
#include <VFS/Native.h>
#include <Habanero/CommonPaths.h>
#include <Config/RapidJSON.h>
#include <Habanero/dispatch_cpp.h>

namespace nc::panel {

static const auto g_RestorationDataKey = "data";
static const auto g_RestorationSortingKey = "sorting";
static const auto g_RestorationLayoutKey = "layout";

ControllerStateJSONEncoder::ControllerStateJSONEncoder(PanelController *_panel):
    m_Panel(_panel)
{
}

config::Value
ControllerStateJSONEncoder::Encode(ControllerStateEncoding::Options _options)
{
    assert(dispatch_is_main_queue());
    config::Value json(rapidjson::kObjectType);
    
    if( _options & ControllerStateEncoding::EncodeContentState ) {
        if( auto v = PanelDataPersisency::EncodeVFSPath(m_Panel.data.Listing());
           v.GetType() != rapidjson::kNullType )
            json.AddMember(config::MakeStandaloneString(g_RestorationDataKey),
                           std::move(v),
                           config::g_CrtAllocator );
        else
            return config::Value{rapidjson::kNullType};
    }
    
    if( _options & ControllerStateEncoding::EncodeDataOptions ) {
        json.AddMember(config::MakeStandaloneString(g_RestorationSortingKey),
                       data::OptionsExporter{m_Panel.data}.Export(), config::g_CrtAllocator );
    }
    
    if( _options & ControllerStateEncoding::EncodeViewOptions ) {
        json.AddMember(config::MakeStandaloneString(g_RestorationLayoutKey),
                       config::Value(m_Panel.layoutIndex), config::g_CrtAllocator );
    }
    
    return json;
}

ControllerStateJSONDecoder::ControllerStateJSONDecoder
    (const utility::NativeFSManager &_fs_manager,
     nc::core::VFSInstanceManager &_vfs_instance_manager):
    m_NativeFSManager(_fs_manager),
    m_VFSInstanceManager(_vfs_instance_manager)
{
}
    
static void LoadHomeDirectory(PanelController *_panel)
{
    auto context = std::make_shared<DirectoryChangeRequest>();
    context->VFS = VFSNativeHost::SharedHost();
    context->PerformAsynchronous = true;
    context->RequestedDirectory = CommonPaths::Home();
    [_panel GoToDirWithContext:context];
}
    
static void EnsureNonEmptyStateAsync(PanelController *_panel)
{
    if( !_panel.data.IsLoaded() ) {
        // the VFS was not recovered.
        // we should not leave panel in empty/dummy state,
        // lets go to home directory as a fallback path
        dispatch_to_main_queue([=]{
            LoadHomeDirectory(_panel);
        });
    }
}
    
static void RecoverSavedPathAtVFSAsync(const VFSHostPtr &_host,
                                       const std::string &_path,
                                       PanelController *_panel)
{
    auto shared_request = std::make_shared<DirectoryChangeRequest>();
    auto &ctx = *shared_request;
    ctx.VFS = _host;
    ctx.PerformAsynchronous = true;
    ctx.RequestedDirectory = _path;
    ctx.LoadingResultCallback = [=](int _rc){
        if( _rc != VFSError::Ok && !_panel.data.IsLoaded() ) {
            // failed to load a listing on this VFS on specified path
            // will try upper directories on this VFS up to the root,
            // in case if everyone fails we will fallback to Home Directory on native VFS.
            auto fs_path = boost::filesystem::path{_path};
            if( fs_path.filename() == "." )
                fs_path.remove_filename();
            
            if( fs_path.has_parent_path() ) {
                auto upper_dir = fs_path.parent_path().native();
                dispatch_to_main_queue([=]{
                    RecoverSavedPathAtVFSAsync(_host, upper_dir, _panel);
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

/**
 * This is a pessimistic procedure which task is to allow synchronous panel loading only when 
 * following is true:
 *   - the FS is Native
 *   - Native FS description can be retrieved 
 *   - the volume is attached directly and isn't removable
 */
bool ControllerStateJSONDecoder::AllowSyncRecovery(const PersistentLocation &_location) const
{
    if( _location.is_native() == false )
        return false;
    
    const auto &path = _location.path;
    const auto fs_info = m_NativeFSManager.VolumeFromPathFast(path);
    if( fs_info == nullptr )
        return false;
    
    const auto mount_flags = fs_info->mount_flags;
    if( mount_flags.ejectable == false &&
        mount_flags.removable == false &&
        mount_flags.local == true &&
        mount_flags.internal == true )
        return true;
    
    return false;
}    

void ControllerStateJSONDecoder::RecoverSavedContentSync(const PersistentLocation &_location,
                                                         PanelController *_panel )
{
    VFSHostPtr host;        
    const auto rc = PanelDataPersisency::CreateVFSFromLocation(_location,
                                                               host,
                                                               m_VFSInstanceManager);
    if( rc != VFSError::Ok ) {
        EnsureNonEmptyStateAsync(_panel);
        return;
    }
    
    auto &path = _location.path;
    auto request = std::make_shared<DirectoryChangeRequest>();
    request->VFS = host;
    request->PerformAsynchronous = false;
    request->RequestedDirectory = _location.path;
    request->LoadingResultCallback = [host, path, _panel](int _rc){
        if( _rc != VFSError::Ok && !_panel.data.IsLoaded() ) {
            // failed to load a listing on this VFS on specified path
            // will try upper directories on this VFS up to the root,
            // in case if everyone fails we will fallback to Home Directory on native VFS.
            auto fs_path = boost::filesystem::path{path};
            if( fs_path.filename() == "." )
                fs_path.remove_filename();
            
            if( fs_path.has_parent_path() ) {
                auto upper_dir = fs_path.parent_path().native();
                dispatch_to_main_queue([=]{
                    RecoverSavedPathAtVFSAsync(host, upper_dir, _panel);
                });
            }
            else {
                dispatch_to_main_queue([=]{
                    LoadHomeDirectory(_panel);
                });
            }
        }
    };
    [_panel GoToDirWithContext:request];
}

void ControllerStateJSONDecoder::RecoverSavedContentAsync(PersistentLocation _location,
                                                          PanelController *_panel )
{
    auto workload = [this, _panel, location=std::move(_location)]
        ([[maybe_unused]] const std::function<bool()> &_cancel_checker)
    {        
        VFSHostPtr host;        
        const auto rc = PanelDataPersisency::CreateVFSFromLocation(location,
                                                                   host,
                                                                   m_VFSInstanceManager);
        if( rc == VFSError::Ok && host != nullptr) {
            // the VFS was recovered, lets go inside it.
            auto path = location.path;
            dispatch_to_main_queue([=]{
                RecoverSavedPathAtVFSAsync(host, path, _panel);
            });
        }
        else {
            EnsureNonEmptyStateAsync(_panel);
            return;            
        }        
    };
    [_panel commitCancelableLoadingTask:std::move(workload)]; 
}

void ControllerStateJSONDecoder::RecoverSavedContent(const config::Value &_saved_state,
                                                     PanelController *_panel )
{
    auto location = PanelDataPersisency::JSONToLocation(_saved_state);
    if( location == std::nullopt )
        return;
    
    if( AllowSyncRecovery(*location) )
        RecoverSavedContentSync(*location, _panel);
    else
        RecoverSavedContentAsync( std::move(*location), _panel);
}

void ControllerStateJSONDecoder::Decode(const config::Value &_state, PanelController *_panel)
{
    assert(dispatch_is_main_queue());
    
    if( !_state.IsObject() )
        return;
        
    if( _state.HasMember(g_RestorationSortingKey) )
        [_panel changeDataOptions:[&](data::Model &_data){
            data::OptionsImporter{_data}.Import( _state[g_RestorationSortingKey] );
        }];
    
    if( auto layout_index = config::GetOptionalIntFromObject(_state, g_RestorationLayoutKey) )
        _panel.layoutIndex = *layout_index;

    if( auto it = _state.FindMember(g_RestorationDataKey); it != _state.MemberEnd() ) {
        RecoverSavedContent(it->value, _panel);        
    }
}

}

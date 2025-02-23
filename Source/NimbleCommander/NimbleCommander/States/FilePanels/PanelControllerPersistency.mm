// Copyright (C) 2018-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelControllerPersistency.h"
#include "PanelController.h"
#include <Panel/PanelData.h>
#include "PanelDataOptionsPersistence.h"
#include "PanelDataPersistency.h"
#include <VFS/Native.h>
#include <Base/CommonPaths.h>
#include <Config/RapidJSON.h>
#include <Base/dispatch_cpp.h>
#include <Utility/PathManip.h>
#include <NimbleCommander/Bootstrap/NativeVFSHostInstance.h>

namespace nc::panel {

static const auto g_RestorationDataKey = "data";
static const auto g_RestorationSortingKey = "sorting";
static const auto g_RestorationLayoutKey = "layout";

ControllerStateJSONEncoder::ControllerStateJSONEncoder(PanelController *_panel, PanelDataPersistency &_persistency)
    : m_Panel(_panel), m_Persistency(_persistency)
{
}

config::Value ControllerStateJSONEncoder::Encode(ControllerStateEncoding::Options _options)
{
    assert(dispatch_is_main_queue());
    config::Value json(rapidjson::kObjectType);

    if( _options & ControllerStateEncoding::EncodeContentState ) {
        if( auto v = m_Persistency.EncodeVFSPath(m_Panel.data.Listing()); v.GetType() != rapidjson::kNullType )
            json.AddMember(config::MakeStandaloneString(g_RestorationDataKey), std::move(v), config::g_CrtAllocator);
        else
            return config::Value{rapidjson::kNullType};
    }

    if( _options & ControllerStateEncoding::EncodeDataOptions ) {
        json.AddMember(config::MakeStandaloneString(g_RestorationSortingKey),
                       data::OptionsExporter{m_Panel.data}.Export(),
                       config::g_CrtAllocator);
    }

    if( _options & ControllerStateEncoding::EncodeViewOptions ) {
        json.AddMember(config::MakeStandaloneString(g_RestorationLayoutKey),
                       config::Value(m_Panel.layoutIndex),
                       config::g_CrtAllocator);
    }

    return json;
}

ControllerStateJSONDecoder::ControllerStateJSONDecoder(const utility::NativeFSManager &_fs_manager,
                                                       nc::core::VFSInstanceManager &_vfs_instance_manager,
                                                       PanelDataPersistency &_persistency)
    : m_NativeFSManager(_fs_manager), m_VFSInstanceManager(_vfs_instance_manager), m_Persistency(_persistency)
{
}

static void LoadHomeDirectory(PanelController *_panel)
{
    auto context = std::make_shared<DirectoryChangeRequest>();
    context->VFS = nc::bootstrap::NativeVFSHostInstance().SharedPtr();
    context->PerformAsynchronous = true;
    context->RequestedDirectory = base::CommonPaths::Home();
    [_panel GoToDirWithContext:context];
}

static void EnsureNonEmptyStateAsync(PanelController *_panel)
{
    if( !_panel.data.IsLoaded() ) {
        // the VFS was not recovered.
        // we should not leave panel in empty/dummy state,
        // lets go to home directory as a fallback path
        dispatch_to_main_queue([=] { LoadHomeDirectory(_panel); });
    }
}

static void RecoverSavedPathAtVFSAsync(const VFSHostPtr &_host, const std::string &_path, PanelController *_panel)
{
    auto shared_request = std::make_shared<DirectoryChangeRequest>();
    auto &ctx = *shared_request;
    ctx.VFS = _host;
    ctx.PerformAsynchronous = true;
    ctx.RequestedDirectory = _path;
    ctx.LoadingResultCallback = [=](const std::expected<void, Error> &_result) {
        if( !_result && !_panel.data.IsLoaded() ) {
            // failed to load a listing on this VFS on specified path
            // will try upper directories on this VFS up to the root,
            // in case if everyone fails we will fallback to Home Directory on native VFS.
            auto fs_path = std::filesystem::path{EnsureNoTrailingSlash(_path)};
            if( fs_path.has_parent_path() ) {
                auto upper_dir = fs_path.parent_path().native();
                dispatch_to_main_queue([=] { RecoverSavedPathAtVFSAsync(_host, upper_dir, _panel); });
            }
            else {
                dispatch_to_main_queue([=] { LoadHomeDirectory(_panel); });
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
    if( !_location.is_native() )
        return false;

    const auto &path = _location.path;
    const auto fs_info = m_NativeFSManager.VolumeFromPath(path);
    if( fs_info == nullptr )
        return false;

    const auto mount_flags = fs_info->mount_flags;
    return !mount_flags.ejectable && !mount_flags.removable && mount_flags.local && mount_flags.internal;
}

void ControllerStateJSONDecoder::RecoverSavedContentSync(const PersistentLocation &_location, PanelController *_panel)
{
    const std::expected<VFSHostPtr, Error> exp_host =
        m_Persistency.CreateVFSFromLocation(_location, m_VFSInstanceManager);
    if( !exp_host ) {
        EnsureNonEmptyStateAsync(_panel);
        return;
    }
    const VFSHostPtr &host = *exp_host;

    auto &path = _location.path;
    auto request = std::make_shared<DirectoryChangeRequest>();
    request->VFS = host;
    request->PerformAsynchronous = false;
    request->RequestedDirectory = _location.path;
    request->LoadingResultCallback = [host, path, _panel](const std::expected<void, Error> &_result) {
        if( !_result && !_panel.data.IsLoaded() ) {
            // failed to load a listing on this VFS on specified path
            // will try upper directories on this VFS up to the root,
            // in case if everyone fails we will fallback to Home Directory on native VFS.
            auto fs_path = std::filesystem::path{EnsureNoTrailingSlash(path)};

            if( fs_path.has_parent_path() ) {
                auto upper_dir = fs_path.parent_path().native();
                dispatch_to_main_queue([=] { RecoverSavedPathAtVFSAsync(host, upper_dir, _panel); });
            }
            else {
                dispatch_to_main_queue([=] { LoadHomeDirectory(_panel); });
            }
        }
    };
    [_panel GoToDirWithContext:request];
}

void ControllerStateJSONDecoder::RecoverSavedContentAsync(PersistentLocation _location, PanelController *_panel)
{
    auto workload =
        [this, _panel, location = std::move(_location)]([[maybe_unused]] const std::function<bool()> &_cancel_checker) {
            const std::expected<VFSHostPtr, Error> exp_host =
                m_Persistency.CreateVFSFromLocation(location, m_VFSInstanceManager);
            if( exp_host && *exp_host != nullptr ) {
                // the VFS was recovered, lets go inside it.
                const VFSHostPtr &host = *exp_host;
                auto path = location.path;
                dispatch_to_main_queue([=] { RecoverSavedPathAtVFSAsync(host, path, _panel); });
            }
            else {
                EnsureNonEmptyStateAsync(_panel);
                return;
            }
        };
    [_panel commitCancelableLoadingTask:std::move(workload)];
}

void ControllerStateJSONDecoder::RecoverSavedContent(const config::Value &_saved_state, PanelController *_panel)
{
    auto location = m_Persistency.JSONToLocation(_saved_state);
    if( location == std::nullopt )
        return;

    if( AllowSyncRecovery(*location) )
        RecoverSavedContentSync(*location, _panel);
    else
        RecoverSavedContentAsync(std::move(*location), _panel);
}

void ControllerStateJSONDecoder::Decode(const config::Value &_state, PanelController *_panel)
{
    assert(dispatch_is_main_queue());

    if( !_state.IsObject() )
        return;

    if( _state.HasMember(g_RestorationSortingKey) )
        [_panel changeDataOptions:[&](data::Model &_data) {
            data::OptionsImporter{_data}.Import(_state[g_RestorationSortingKey]);
        }];

    if( auto layout_index = config::GetOptionalIntFromObject(_state, g_RestorationLayoutKey) )
        _panel.layoutIndex = *layout_index;

    if( auto it = _state.FindMember(g_RestorationDataKey); it != _state.MemberEnd() ) {
        RecoverSavedContent(it->value, _panel);
    }
}

} // namespace nc::panel

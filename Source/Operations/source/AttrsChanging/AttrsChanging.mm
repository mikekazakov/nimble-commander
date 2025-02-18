// Copyright (C) 2017-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include <memory>

#include "AttrsChanging.h"
#include "AttrsChangingJob.h"
#include "../AsyncDialogResponse.h"
#include "../Internal.h"
#include "../ModalDialogResponses.h"
#include "../GenericErrorDialog.h"

// TODO: remove once callback results are no longer wrapped into 'int'
#pragma clang diagnostic ignored "-Wold-style-cast"

namespace nc::ops {

using Callbacks = AttrsChangingJobCallbacks;

AttrsChanging::AttrsChanging(AttrsChangingCommand _command)
{
    m_Job = std::make_unique<AttrsChangingJob>(std::move(_command));
    m_Job->m_OnSourceAccessError = [this](Error _err, const std::string &_path, VFSHost &_vfs) {
        return (Callbacks::SourceAccessErrorResolution)OnSourceAccessError(_err, _path, _vfs);
    };
    m_Job->m_OnChmodError = [this](Error _err, const std::string &_path, VFSHost &_vfs) {
        return (Callbacks::ChmodErrorResolution)OnChmodError(_err, _path, _vfs);
    };
    m_Job->m_OnChownError = [this](Error _err, const std::string &_path, VFSHost &_vfs) {
        return (Callbacks::ChownErrorResolution)OnChownError(_err, _path, _vfs);
    };
    m_Job->m_OnFlagsError = [this](Error _err, const std::string &_path, VFSHost &_vfs) {
        return (Callbacks::FlagsErrorResolution)OnFlagsError(_err, _path, _vfs);
    };
    m_Job->m_OnTimesError = [this](Error _err, const std::string &_path, VFSHost &_vfs) {
        return (Callbacks::TimesErrorResolution)OnTimesError(_err, _path, _vfs);
    };
    auto title = NSLocalizedString(@"Altering file attributes", "Title for attributes changing operation");
    SetTitle(title.UTF8String);
}

AttrsChanging::~AttrsChanging()
{
    Wait();
}

Job *AttrsChanging::GetJob() noexcept
{
    return m_Job.get();
}

int AttrsChanging::OnSourceAccessError(Error _err, const std::string &_path, VFSHost &_vfs)
{
    if( m_SkipAll || !IsInteractive() )
        return m_SkipAll ? (int)Callbacks::SourceAccessErrorResolution::Skip
                         : (int)Callbacks::SourceAccessErrorResolution::Stop;
    const auto ctx = std::make_shared<AsyncDialogResponse>();

    ShowGenericDialog(GenericDialog::AbortSkipSkipAllRetry,
                      NSLocalizedString(@"Failed to access an item", ""),
                      _err,
                      {_vfs, _path},
                      ctx);
    WaitForDialogResponse(ctx);

    if( ctx->response == NSModalResponseSkip )
        return (int)Callbacks::SourceAccessErrorResolution::Skip;
    else if( ctx->response == NSModalResponseSkipAll ) {
        m_SkipAll = true;
        return (int)Callbacks::SourceAccessErrorResolution::Skip;
    }
    else if( ctx->response == NSModalResponseRetry )
        return (int)Callbacks::SourceAccessErrorResolution::Retry;
    else
        return (int)Callbacks::SourceAccessErrorResolution::Stop;
}

int AttrsChanging::OnChmodError(Error _err, const std::string &_path, VFSHost &_vfs)
{
    if( m_SkipAll || !IsInteractive() )
        return m_SkipAll ? (int)Callbacks::ChmodErrorResolution::Skip : (int)Callbacks::ChmodErrorResolution::Stop;

    const auto ctx = std::make_shared<AsyncDialogResponse>();
    ShowGenericDialog(GenericDialog::AbortSkipSkipAllRetry,
                      NSLocalizedString(@"Failed to perform chmod", ""),
                      _err,
                      {_vfs, _path},
                      ctx);
    WaitForDialogResponse(ctx);

    if( ctx->response == NSModalResponseSkip )
        return (int)Callbacks::ChmodErrorResolution::Skip;
    else if( ctx->response == NSModalResponseSkipAll ) {
        m_SkipAll = true;
        return (int)Callbacks::ChmodErrorResolution::Skip;
    }
    else if( ctx->response == NSModalResponseRetry )
        return (int)Callbacks::ChmodErrorResolution::Retry;
    else
        return (int)Callbacks::ChmodErrorResolution::Stop;
}

int AttrsChanging::OnChownError(Error _err, const std::string &_path, VFSHost &_vfs)
{
    if( m_SkipAll || !IsInteractive() )
        return m_SkipAll ? (int)Callbacks::ChownErrorResolution::Skip : (int)Callbacks::ChownErrorResolution::Stop;

    const auto ctx = std::make_shared<AsyncDialogResponse>();
    ShowGenericDialog(GenericDialog::AbortSkipSkipAllRetry,
                      NSLocalizedString(@"Failed to perform chown", ""),
                      _err,
                      {_vfs, _path},
                      ctx);
    WaitForDialogResponse(ctx);

    if( ctx->response == NSModalResponseSkip )
        return (int)Callbacks::ChownErrorResolution::Skip;
    else if( ctx->response == NSModalResponseSkipAll ) {
        m_SkipAll = true;
        return (int)Callbacks::ChownErrorResolution::Skip;
    }
    else if( ctx->response == NSModalResponseRetry )
        return (int)Callbacks::ChownErrorResolution::Retry;
    else
        return (int)Callbacks::ChownErrorResolution::Stop;
}

int AttrsChanging::OnFlagsError(Error _err, const std::string &_path, VFSHost &_vfs)
{
    if( m_SkipAll || !IsInteractive() )
        return m_SkipAll ? (int)Callbacks::FlagsErrorResolution::Skip : (int)Callbacks::FlagsErrorResolution::Stop;

    const auto ctx = std::make_shared<AsyncDialogResponse>();
    ShowGenericDialog(GenericDialog::AbortSkipSkipAllRetry,
                      NSLocalizedString(@"Failed to perform chflags", ""),
                      _err,
                      {_vfs, _path},
                      ctx);
    WaitForDialogResponse(ctx);

    if( ctx->response == NSModalResponseSkip )
        return (int)Callbacks::FlagsErrorResolution::Skip;
    else if( ctx->response == NSModalResponseSkipAll ) {
        m_SkipAll = true;
        return (int)Callbacks::FlagsErrorResolution::Skip;
    }
    else if( ctx->response == NSModalResponseRetry )
        return (int)Callbacks::FlagsErrorResolution::Retry;
    else
        return (int)Callbacks::FlagsErrorResolution::Stop;
}

int AttrsChanging::OnTimesError(Error _err, const std::string &_path, VFSHost &_vfs)
{
    if( m_SkipAll || !IsInteractive() )
        return m_SkipAll ? (int)Callbacks::TimesErrorResolution::Skip : (int)Callbacks::TimesErrorResolution::Stop;

    const auto ctx = std::make_shared<AsyncDialogResponse>();
    ShowGenericDialog(GenericDialog::AbortSkipSkipAllRetry,
                      NSLocalizedString(@"Failed to set file time", ""),
                      _err,
                      {_vfs, _path},
                      ctx);
    WaitForDialogResponse(ctx);

    if( ctx->response == NSModalResponseSkip )
        return (int)Callbacks::TimesErrorResolution::Skip;
    else if( ctx->response == NSModalResponseSkipAll ) {
        m_SkipAll = true;
        return (int)Callbacks::TimesErrorResolution::Skip;
    }
    else if( ctx->response == NSModalResponseRetry )
        return (int)Callbacks::TimesErrorResolution::Retry;
    else
        return (int)Callbacks::TimesErrorResolution::Stop;
}

} // namespace nc::ops

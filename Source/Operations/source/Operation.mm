// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Operation.h"
#include "Job.h"
#include "AsyncDialogResponse.h"
#include "ModalDialogResponses.h"
#include <VFS/VFS.h>
#include "HaltReasonDialog.h"
#include "GenericErrorDialog.h"
#include "Statistics.h"
#include "Internal.h"
#include <iostream>
#include <Base/dispatch_cpp.h>

namespace nc::ops {

Operation::Operation() = default;

Operation::~Operation()
{
    if( IsWaitingForUIResponse() )
        std::cerr << "Warning: an operation at address " << reinterpret_cast<void *>(this)
                  << " was destroyed while it was waiting for a UI response!" << '\n';
}

Job *Operation::GetJob() noexcept
{
    if( typeid(*this) != typeid(Operation) )
        std::cerr << "Warning: operation's implementation class " << typeid(*this).name()
                  << " has no GetJob() overload!" << '\n';
    return nullptr;
}

const Job *Operation::GetJob() const
{
    return const_cast<Operation *>(this)->GetJob();
}

const class Statistics &Operation::Statistics() const
{
    if( auto job = GetJob() )
        return job->Statistics();
    throw std::logic_error("Operation::Statistics(): no valid Job object to access to");
}

OperationState Operation::State() const
{
    if( auto j = GetJob() ) {
        if( j->IsPaused() )
            return OperationState::Paused;
        if( j->IsRunning() )
            return OperationState::Running;
        if( j->IsCompleted() )
            return OperationState::Completed;
        if( j->IsStopped() )
            return OperationState::Stopped;
    }
    return OperationState::Cold;
}

void Operation::Start()
{
    if( auto j = GetJob() ) {
        if( j->IsRunning() )
            return;

        j->SetFinishCallback([this] { JobFinished(); });
        j->SetPauseCallback([this] { JobPaused(); });
        j->SetResumeCallback([this] { JobPaused(); });

        j->Run();

        FireObservers(NotifyAboutStart);
    }
}

void Operation::Pause()
{
    if( auto j = GetJob() )
        j->Pause();
}

void Operation::Resume()
{
    if( auto j = GetJob() )
        j->Resume();
}

void Operation::Stop()
{
    if( auto j = GetJob() ) {
        const auto is_running = j->IsRunning();
        j->Stop();
        if( !is_running )
            JobFinished();
    }
}

void Operation::Wait() const
{
    Wait(std::chrono::nanoseconds::max());
}

bool Operation::Wait(std::chrono::nanoseconds _wait_for_time) const
{
    const auto pred = [this] {
        const auto s = State();
        return s != OperationState::Running && s != OperationState::Paused;
    };
    if( pred() )
        return true;

    [[clang::no_destroy]] static std::mutex m; // wtf is this???
    std::unique_lock<std::mutex> lock{m};
    if( _wait_for_time == std::chrono::nanoseconds::max() ) {
        m_FinishCV.wait(lock, pred);
        return true;
    }
    else {
        return m_FinishCV.wait_for(lock, _wait_for_time, pred);
    }
}

void Operation::JobFinished()
{
    OnJobFinished();

    const auto state = State();
    if( state == OperationState::Completed )
        FireObservers(NotifyAboutCompletion);
    if( state == OperationState::Stopped )
        FireObservers(NotifyAboutStop);

    m_FinishCV.notify_all();
}

void Operation::JobPaused()
{
    OnJobPaused();
    FireObservers(NotifyAboutPause);
}

void Operation::JobResumed()
{
    OnJobResumed();
    FireObservers(NotifyAboutResume);
}

void Operation::OnJobFinished()
{
}

void Operation::OnJobPaused()
{
}

void Operation::OnJobResumed()
{
}

Operation::ObservationTicket Operation::Observe(uint64_t _notification_mask, std::function<void()> _callback)
{
    return AddTicketedObserver(std::move(_callback), _notification_mask);
}

void Operation::ObserveUnticketed(uint64_t _notification_mask, std::function<void()> _callback)
{
    AddUnticketedObserver(std::move(_callback), _notification_mask);
}

void Operation::SetDialogCallback(std::function<bool(NSWindow *, std::function<void(NSModalResponse)>)> _callback)
{
    const auto guard = std::lock_guard{m_DialogCallbackLock};
    m_DialogCallback = std::move(_callback);
}

bool Operation::IsInteractive() const noexcept
{
    const auto guard = std::lock_guard{m_DialogCallbackLock};
    return m_DialogCallback != nullptr;
}

void Operation::Show(NSWindow *_dialog, std::shared_ptr<AsyncDialogResponse> _response)
{
    dispatch_assert_main_queue();
    if( !_dialog || !_response )
        return;

    {
        const auto guard = std::lock_guard{m_DialogCallbackLock};
        if( m_DialogCallback ) {
            const auto controller = _dialog.windowController;
            const auto dialog_callback = [_response, controller](NSModalResponse _dialog_response) {
                _response->Commit(_dialog_response);
                dispatch_to_main_queue([controller] {
                    (void)controller;
                    /* solely to extend the lifetime */
                });
            };
            const auto shown = m_DialogCallback(_dialog, dialog_callback);
            if( shown )
                return;
        }
    }

    _response->Abort();
}

void Operation::AddButtonsForGenericDialog(const GenericDialog _dialog_type, NCOpsGenericErrorDialog *_dialog)
{
    if( _dialog_type == GenericDialog::AbortRetry ) {
        [_dialog addButtonWithTitle:NSLocalizedString(@"Abort", "") responseCode:NSModalResponseStop];
        [_dialog addButtonWithTitle:NSLocalizedString(@"Retry", "") responseCode:NSModalResponseRetry];
    }
    if( _dialog_type == GenericDialog::Continue ) {
        [_dialog addButtonWithTitle:NSLocalizedString(@"Continue", "") responseCode:NSModalResponseContinue];
    }
    if( _dialog_type == GenericDialog::AbortSkipSkipAll ) {
        [_dialog addButtonWithTitle:NSLocalizedString(@"Abort", "") responseCode:NSModalResponseStop];
        [_dialog addButtonWithTitle:NSLocalizedString(@"Skip", "") responseCode:NSModalResponseSkip];
        [_dialog addButtonWithTitle:NSLocalizedString(@"Skip All", "") responseCode:NSModalResponseSkipAll];
    }
    if( _dialog_type == GenericDialog::AbortSkipSkipAllRetry ) {
        [_dialog addButtonWithTitle:NSLocalizedString(@"Abort", "") responseCode:NSModalResponseStop];
        [_dialog addButtonWithTitle:NSLocalizedString(@"Skip", "") responseCode:NSModalResponseSkip];
        [_dialog addButtonWithTitle:NSLocalizedString(@"Skip All", "") responseCode:NSModalResponseSkipAll];
        [_dialog addButtonWithTitle:NSLocalizedString(@"Retry", "") responseCode:NSModalResponseRetry];
    }
    if( _dialog_type == GenericDialog::AbortSkipSkipAllOverwrite ) {
        [_dialog addButtonWithTitle:NSLocalizedString(@"Abort", "") responseCode:NSModalResponseStop];
        [_dialog addButtonWithTitle:NSLocalizedString(@"Skip", "") responseCode:NSModalResponseSkip];
        [_dialog addButtonWithTitle:NSLocalizedString(@"Skip All", "") responseCode:NSModalResponseSkipAll];
        [_dialog addButtonWithTitle:NSLocalizedString(@"Overwrite", "") responseCode:NSModalResponseOverwrite];
    }
}

// TODO: remove this
void Operation::ShowGenericDialog(GenericDialog _dialog_type,
                                  NSString *_message,
                                  int _err,
                                  vfs::VFSPath _path,
                                  std::shared_ptr<AsyncDialogResponse> _ctx)
{
    ShowGenericDialog(_dialog_type, _message, VFSError::ToError(_err), _path, _ctx);
}

void Operation::ShowGenericDialog(GenericDialog _dialog_type,
                                  NSString *_message,
                                  Error _err,
                                  vfs::VFSPath _path,
                                  std::shared_ptr<AsyncDialogResponse> _ctx)
{
    if( !dispatch_is_main_queue() ) {
        dispatch_to_main_queue([=, this] { ShowGenericDialog(_dialog_type, _message, _err, _path, _ctx); });
        return;
    }

    const auto sheet = [[NCOpsGenericErrorDialog alloc] init];
    sheet.style = GenericErrorDialogStyle::Caution;
    sheet.message = _message;
    sheet.path = [NSString stringWithUTF8String:_path.Path().c_str()];
    sheet.error = _err;
    AddButtonsForGenericDialog(_dialog_type, sheet);
    Show(sheet.window, _ctx);
}

void Operation::WaitForDialogResponse(std::shared_ptr<AsyncDialogResponse> _response)
{
    dispatch_assert_background_queue();
    if( !_response )
        return;

    const StatisticsTimingPauser timing_pauser{GetJob()->Statistics()};

    {
        const auto guard = std::lock_guard{m_PendingResponseLock};
        m_PendingResponse = _response;
    }

    _response->Wait();
    assert(_response->response);

    {
        const auto guard = std::lock_guard{m_PendingResponseLock};
        m_PendingResponse.reset();
    }
}

bool Operation::IsWaitingForUIResponse() const noexcept
{
    const auto guard = std::lock_guard{m_PendingResponseLock};
    return !m_PendingResponse.expired();
}

void Operation::AbortUIWaiting() noexcept
{
    const auto guard = std::lock_guard{m_PendingResponseLock};
    if( auto r = m_PendingResponse.lock() )
        r->Abort();
}

// TODO: remove me
void Operation::ReportHaltReason(NSString *_message,
                                 int _error,
                                 const std::string &_path,
                                 [[maybe_unused]] VFSHost &_vfs)
{
    dispatch_assert_background_queue();
    if( !IsInteractive() )
        return;
    const auto ctx = std::make_shared<AsyncDialogResponse>();
    dispatch_to_main_queue([=, this] {
        const auto sheet = [[NCOpsHaltReasonDialog alloc] init];
        sheet.message = _message;
        sheet.path = [NSString stringWithUTF8String:_path.c_str()];
        sheet.errorNo = _error;
        Show(sheet.window, ctx);
    });
    WaitForDialogResponse(ctx);
}

void Operation::ReportHaltReason(NSString *_message,
                                 const Error &_error,
                                 const std::string &_path,
                                 [[maybe_unused]] VFSHost &_vfs)
{
    dispatch_assert_background_queue();
    if( !IsInteractive() )
        return;
    const auto ctx = std::make_shared<AsyncDialogResponse>();
    dispatch_to_main_queue([=, this] {
        const auto sheet = [[NCOpsHaltReasonDialog alloc] init];
        sheet.message = _message;
        sheet.path = [NSString stringWithUTF8String:_path.c_str()];
        sheet.error = _error;
        Show(sheet.window, ctx);
    });
    WaitForDialogResponse(ctx);
}

std::string Operation::Title() const
{
    const auto guard = std::lock_guard{m_TitleLock};
    return m_Title;
}

void Operation::SetTitle(std::string _title)
{
    {
        const auto guard = std::lock_guard{m_TitleLock};
        if( m_Title == _title )
            return;
        m_Title = std::move(_title);
    }
    FireObservers(NotifyAboutTitleChange);
}

void Operation::SetItemStatusCallback(ItemStateReportCallback _callback)
{
    if( auto job = GetJob() ) {
        job->SetItemStateReportCallback(std::move(_callback));
    }
}

} // namespace nc::ops

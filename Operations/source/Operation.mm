#include "Operation.h"
#include "Job.h"
#include "AsyncDialogResponse.h"
#include "ModalDialogResponses.h"
#include <VFS/VFS.h>
#include "HaltReasonDialog.h"
#include "GenericErrorDialog.h"
#include <cxxabi.h>

namespace nc::ops
{

Operation::Operation()
{
}

Operation::~Operation()
{
    if( IsWaitingForUIResponse() )
        cerr << "Warning: an operation at address " << (void*)this <<
            " was destroyed while it was waiting for a UI response!" << endl;
}

Job *Operation::GetJob() noexcept
{
    if( typeid(*this) != typeid(Operation) )
        cerr << "Warning: operation's implementation class " << typeid(*this).name() <<
            " has no GetJob() overload!" << endl;
    return nullptr;
}

const Job *Operation::GetJob() const
{
    return const_cast<Operation*>(this)->GetJob();
}

const class Statistics &Operation::Statistics() const
{
    if( auto job = GetJob() )
        return job->Statistics();
    throw logic_error("Operation::Statistics(): no valid Job object to access to");
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
    
        j->SetFinishCallback(   [this]{ JobFinished();  });
        j->SetPauseCallback(    [this]{ JobPaused();    });
        j->SetResumeCallback(   [this]{ JobPaused();    });
        
        j->Run();
        
        FireObservers( NotifyAboutStart );
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
    Wait( nanoseconds::max() );
}

bool Operation::Wait( nanoseconds _wait_for_time ) const
{
    const auto pred = [this]{
        const auto s = State();
        return s != OperationState::Running && s != OperationState::Paused;
    };
    if( pred() )
        return true;
    
    static std::mutex m;
    std::unique_lock<std::mutex> lock{m};
    if( _wait_for_time == nanoseconds::max() ) {
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
        FireObservers( NotifyAboutCompletion );
    if( state == OperationState::Stopped )
        FireObservers( NotifyAboutStop );

    m_FinishCV.notify_all();
}

void Operation::JobPaused()
{
    OnJobPaused();
    FireObservers( NotifyAboutPause );
}

void Operation::JobResumed()
{
    OnJobResumed();
    FireObservers( NotifyAboutResume );
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

Operation::ObservationTicket Operation::Observe
    ( uint64_t _notification_mask, function<void()> _callback )
{
    return AddTicketedObserver(move(_callback), _notification_mask);
}

void Operation::ObserveUnticketed( uint64_t _notification_mask, function<void()> _callback )
{
    return AddUnticketedObserver(move(_callback), _notification_mask);
}

void Operation::SetDialogCallback
    (function<bool(NSWindow *, function<void(NSModalResponse)>)> _callback)
{
    LOCK_GUARD(m_DialogCallbackLock)
        m_DialogCallback = move(_callback);
}

bool Operation::IsInteractive() const noexcept
{
    LOCK_GUARD(m_DialogCallbackLock)
        return m_DialogCallback != nullptr;
}

void Operation::Show( NSWindow *_dialog, shared_ptr<AsyncDialogResponse> _response )
{
    dispatch_assert_main_queue();
    if( !_dialog || !_response )
        return;
    
    LOCK_GUARD(m_DialogCallbackLock)
        if( m_DialogCallback ) {
            const auto controller = _dialog.windowController;
            const auto dialog_callback = [_response, controller](NSModalResponse _dialog_response){
                _response->Commit(_dialog_response);
                dispatch_to_main_queue([controller]{ /* solely to extend the lifetime */ });
            };
            const auto shown = m_DialogCallback(_dialog, dialog_callback);
            if( shown )
                return;
        }
    _response->Abort();
}

void Operation::ShowGenericDialogWithAbortSkipAndSkipAllButtons
    (NSString *_message, int _err, const string &_path, shared_ptr<VFSHost> _vfs,
    shared_ptr<AsyncDialogResponse> _ctx)
{
    const auto sheet = [[NCOpsGenericErrorDialog alloc] init];

    sheet.style = GenericErrorDialogStyle::Caution;
    sheet.message = _message;
    sheet.path = [NSString stringWithUTF8String:_path.c_str()];
    sheet.errorNo = _err;
    [sheet addButtonWithTitle:@"Abort" responseCode:NSModalResponseStop];
    [sheet addButtonWithTitle:@"Skip" responseCode:NSModalResponseSkip];
    [sheet addButtonWithTitle:@"Skip All" responseCode:NSModalResponseSkipAll];

    Show(sheet.window, _ctx);
}

void Operation::WaitForDialogResponse( shared_ptr<AsyncDialogResponse> _response )
{
    dispatch_assert_background_queue();
    if( !_response )
        return;
    
    StatisticsTimingPauser timing_pauser{GetJob()->Statistics()};
    
    LOCK_GUARD(m_PendingResponseLock)
        m_PendingResponse = _response;
    
    _response->Wait();
    assert( _response->response );
    
    LOCK_GUARD(m_PendingResponseLock)
        m_PendingResponse.reset();
}

bool Operation::IsWaitingForUIResponse() const noexcept
{
    LOCK_GUARD(m_PendingResponseLock)
        return !m_PendingResponse.expired();
}

void Operation::AbortUIWaiting() noexcept
{
    LOCK_GUARD(m_PendingResponseLock)
        if( auto r = m_PendingResponse.lock() )
            r->Abort();
}

void Operation::ReportHaltReason( NSString *_message, int _error, const string &_path, VFSHost &_vfs )
{
    dispatch_assert_background_queue();
    if( !IsInteractive() )
        return;
    const auto ctx = make_shared<AsyncDialogResponse>();
    dispatch_to_main_queue([=]{
        const auto sheet = [[NCOpsHaltReasonDialog alloc] init];
        sheet.message = _message;
        sheet.path = [NSString stringWithUTF8String:_path.c_str()];
        sheet.errorNo = _error;
        Show(sheet.window, ctx);
    });
    WaitForDialogResponse(ctx);
}

string Operation::Title() const
{
    LOCK_GUARD(m_TitleLock)
        return m_Title;
}

void Operation::SetTitle( const string &_title )
{
    LOCK_GUARD(m_TitleLock) {
        if( m_Title == _title )
            return;
        m_Title = _title;
    }
    FireObservers(NotifyAboutTitleChange);
}

}

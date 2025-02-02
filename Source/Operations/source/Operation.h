// Copyright (C) 2017-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Base/ScopedObservable.h>
#include <VFS/VFS.h>
#include <string_view>

#include "ItemStateReport.h"

#ifdef __OBJC__
@class NSWindow;
@class NSString;
@class NCOpsGenericErrorDialog;
#else
#include <Utility/NSCppDeclarations.h>
using NCOpsGenericErrorDialog = void *;
#endif

namespace nc::ops {

class Job;
class Statistics;
struct AsyncDialogResponse;

enum class OperationState {
    Cold = 0,
    Running = 1,
    Paused = 2,
    Stopped = 3,
    Completed = 4
};
#if 0
 Cold ---> Running -----------> Stopped
          ^    |      ^   |
          |    v      |   |---> Completed
          --Paused ---|
#endif

class Operation : private base::ScopedObservableBase
{
public:
    virtual ~Operation();

    void Start();
    void Pause();
    void Resume();
    void Stop();

    std::string Title() const;
    OperationState State() const;
    const class Statistics &Statistics() const;

    void Wait() const;
    bool Wait(std::chrono::nanoseconds _wait_for_time) const;

    enum {
        NotifyAboutStart = 1 << 0,
        NotifyAboutPause = 1 << 1,
        NotifyAboutResume = 1 << 2,
        NotifyAboutStop = 1 << 3,
        NotifyAboutCompletion = 1 << 4,
        NotifyAboutTitleChange = 1 << 5,
        NotifyAboutFinish = NotifyAboutStop | NotifyAboutCompletion,
        NotifyAboutStateChange =
            NotifyAboutStart | NotifyAboutPause | NotifyAboutResume | NotifyAboutStop | NotifyAboutCompletion
    };
    using ObservationTicket = ScopedObservableBase::ObservationTicket;
    ObservationTicket Observe(uint64_t _notification_mask, std::function<void()> _callback);
    void ObserveUnticketed(uint64_t _notification_mask, std::function<void()> _callback);

    void SetDialogCallback(std::function<bool(NSWindow *, std::function<void(long)>)> _callback);
    bool IsWaitingForUIResponse() const noexcept;
    void AbortUIWaiting() noexcept;

    // This callback will be fired from a background job thread.
    void SetItemStatusCallback(ItemStateReportCallback _callback);

protected:
    enum class GenericDialog {
        AbortRetry,
        AbortSkipSkipAll,
        AbortSkipSkipAllRetry,
        AbortSkipSkipAllOverwrite,
        Continue
    };

    Operation();
    virtual Job *GetJob() noexcept;
    virtual void OnJobFinished();
    virtual void OnJobPaused();
    virtual void OnJobResumed();
    bool IsInteractive() const noexcept;
    void Show(NSWindow *_dialog, std::shared_ptr<AsyncDialogResponse> _response);
    static void AddButtonsForGenericDialog(GenericDialog _dialog_type, NCOpsGenericErrorDialog *_dialog);
    void ShowGenericDialog(GenericDialog _dialog_type,
                           NSString *_message,
                           int _err,
                           vfs::VFSPath _path,
                           std::shared_ptr<AsyncDialogResponse> _ctx);
    void ShowGenericDialog(GenericDialog _dialog_type,
                           NSString *_message,
                           Error _err,
                           vfs::VFSPath _path,
                           std::shared_ptr<AsyncDialogResponse> _ctx);
    void WaitForDialogResponse(std::shared_ptr<AsyncDialogResponse> _response);
    void ReportHaltReason(NSString *_message, int _error, const std::string &_path, VFSHost &_vfs);
    void SetTitle(std::string _title);

private:
    Operation(const Operation &) = delete;
    void operator=(const Operation &) = delete;
    const Job *GetJob() const;
    void JobFinished();
    void JobPaused();
    void JobResumed();

    mutable std::condition_variable m_FinishCV;

    std::function<bool(NSWindow *dialog, std::function<void(long response)>)> m_DialogCallback;
    mutable spinlock m_DialogCallbackLock;

    std::weak_ptr<AsyncDialogResponse> m_PendingResponse;
    mutable spinlock m_PendingResponseLock;

    std::string m_Title;
    mutable spinlock m_TitleLock;
};

} // namespace nc::ops

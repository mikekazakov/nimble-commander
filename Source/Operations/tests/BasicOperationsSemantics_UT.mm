// Copyright (C) 2017-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include <thread>
#include "../include/Operations/Operation.h"
#include "../include/Operations/Job.h"

using namespace std;
using namespace nc::ops;

namespace {

struct MyJob : public Job {
    void Perform() override
    {
        std::this_thread::sleep_for(std::chrono::milliseconds{500});
        SetCompleted();
    }
};

struct MyOperation : public Operation {
    ~MyOperation() override { Wait(); }
    Job *GetJob() noexcept override { return &job; }
    MyJob job;
};

} // namespace

#define PREFIX "Basic Operations Semantics: "

TEST_CASE(PREFIX "External wait")
{
    MyOperation myop;

    std::mutex cv_lock;
    std::condition_variable cv;

    myop.ObserveUnticketed(Operation::NotifyAboutFinish, [&] { cv.notify_all(); });

    myop.Start();
    REQUIRE(myop.State() == OperationState::Running);

    std::unique_lock<std::mutex> lock{cv_lock};
    cv.wait(lock, [&] { return myop.State() >= OperationState::Stopped; });

    REQUIRE(myop.State() == OperationState::Completed);
}

TEST_CASE(PREFIX "builtin wait")
{
    MyOperation myop;
    myop.Start();
    myop.Wait();
    REQUIRE(myop.State() == OperationState::Completed);
}

TEST_CASE(PREFIX "builtin partial wait")
{
    MyOperation myop;
    myop.Start();
    REQUIRE(myop.Wait(std::chrono::milliseconds{200}) == false);
    REQUIRE(myop.State() == OperationState::Running);
}

TEST_CASE(PREFIX "accidental operation wait")
{
    MyOperation myop;
    myop.Start();
    REQUIRE(myop.State() == OperationState::Running);
}

TEST_CASE(PREFIX "non-started operation behaviour")
{
    const MyOperation myop;
    REQUIRE(myop.State() == OperationState::Cold);
}

// Copyright (C) 2021-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include "TestEnv.h"
#include "../source/Pool.h"
#include "../source/Job.h"
#include "../source/Operation.h"
#include <Base/mach_time.h>
#include <chrono>
#include <thread>

using namespace nc;
using namespace nc::ops;
using namespace std::chrono_literals;
using VecOp = std::vector<std::shared_ptr<Operation>>;

#define PREFIX "nc::ops::Pool "

static bool check_until_or_die(std::function<bool()> _predicate, std::chrono::nanoseconds _deadline)
{
    assert(_predicate);
    const auto _poll_period = std::chrono::microseconds(10);
    const auto deadline = nc::base::machtime() + _deadline;
    while( true ) {
        if( _predicate() )
            return true;
        if( nc::base::machtime() >= deadline )
            return false;
        std::this_thread::sleep_for(_poll_period);
    }
}

TEST_CASE(PREFIX "Is constructible and empty by default")
{
    auto pool = Pool::Make();
    CHECK(pool->Empty());
    CHECK(pool->OperationsCount() == 0);
    CHECK(pool->RunningOperationsCount() == 0);
    CHECK(pool->Operations().empty());
    CHECK(pool->RunningOperations().empty());
    CHECK(pool->IsInteractive() == false);
}

TEST_CASE(PREFIX "Enques and reports the operation back as running")
{
    struct MyJob : public Job {
        void Perform() override
        {
            while( !done )
                std::this_thread::sleep_for(std::chrono::microseconds{100});
            SetCompleted();
        }
        std::atomic_bool done{false};
    };
    struct MyOperation : public Operation {
        ~MyOperation() override { Wait(); }
        Job *GetJob() noexcept override { return &job; }
        MyJob job;
    };

    auto pool = Pool::Make();

    // add an operation and check it's running and reported
    auto op = std::make_shared<MyOperation>();
    CHECK(op->State() == nc::ops::OperationState::Cold);

    pool->Enqueue(op);
    CHECK(op->State() == nc::ops::OperationState::Running);
    CHECK(pool->Empty() == false);
    CHECK(pool->OperationsCount() == 1);
    CHECK(pool->RunningOperationsCount() == 1);
    CHECK(pool->Operations() == VecOp{op});
    CHECK(pool->RunningOperations() == VecOp{op});

    // now finish the operation and wait for the pool to drain
    op->job.done = true;
    CHECK(check_until_or_die([&] { return pool->Empty(); }, 1s));
    CHECK(op->State() == nc::ops::OperationState::Completed);
    CHECK(pool->Empty() == true);
    CHECK(pool->OperationsCount() == 0);
    CHECK(pool->RunningOperationsCount() == 0);
    CHECK(pool->Operations().empty());
    CHECK(pool->RunningOperations().empty());
}

TEST_CASE(PREFIX "Obeys concurrency settings")
{
    auto pool = Pool::Make();

    struct MyJob : public Job {
        void Perform() override
        {
            while( !done )
                std::this_thread::sleep_for(std::chrono::microseconds{100});
            SetCompleted();
        }
        std::atomic_bool done{false};
    };
    struct MyOperation : public Operation {
        ~MyOperation() override { Wait(); }
        Job *GetJob() noexcept override { return &job; }
        MyJob job;
    };
    auto op1 = std::make_shared<MyOperation>();
    auto op2 = std::make_shared<MyOperation>();
    auto op3 = std::make_shared<MyOperation>();
    SECTION("Concurrency = 5")
    {
        pool->SetConcurrency(5);
        pool->Enqueue(op1);
        pool->Enqueue(op2);
        pool->Enqueue(op3);
        CHECK(op1->State() == nc::ops::OperationState::Running);
        CHECK(op2->State() == nc::ops::OperationState::Running);
        CHECK(op3->State() == nc::ops::OperationState::Running);
        CHECK(pool->Empty() == false);
        CHECK(pool->OperationsCount() == 3);
        CHECK(pool->RunningOperationsCount() == 3);
        CHECK(pool->Operations() == VecOp{op1, op2, op3});
        CHECK(pool->RunningOperations() == VecOp{op1, op2, op3});
    }
    SECTION("Concurrency = 2")
    {
        pool->SetConcurrency(2);
        pool->Enqueue(op1);
        pool->Enqueue(op2);
        pool->Enqueue(op3);
        CHECK(op1->State() == nc::ops::OperationState::Running);
        CHECK(op2->State() == nc::ops::OperationState::Running);
        CHECK(op3->State() == nc::ops::OperationState::Cold);
        CHECK(pool->Empty() == false);
        CHECK(pool->OperationsCount() == 3);
        CHECK(pool->RunningOperationsCount() == 2);
        CHECK(pool->Operations() == VecOp{op1, op2, op3});
        CHECK(pool->RunningOperations() == VecOp{op1, op2});
    }
    SECTION("Concurrency = 1")
    {
        pool->SetConcurrency(1);
        pool->Enqueue(op1);
        pool->Enqueue(op2);
        pool->Enqueue(op3);
        CHECK(op1->State() == nc::ops::OperationState::Running);
        CHECK(op2->State() == nc::ops::OperationState::Cold);
        CHECK(op3->State() == nc::ops::OperationState::Cold);
        CHECK(pool->Empty() == false);
        CHECK(pool->OperationsCount() == 3);
        CHECK(pool->RunningOperationsCount() == 1);
        CHECK(pool->Operations() == VecOp{op1, op2, op3});
        CHECK(pool->RunningOperations() == VecOp{op1});
    }
    op1->job.done = true;
    op2->job.done = true;
    op3->job.done = true;
}

TEST_CASE(PREFIX "Drains pending queues as operation complete")
{
    auto pool = Pool::Make();
    pool->SetConcurrency(1);

    struct MyJob : public Job {
        void Perform() override
        {
            while( !done )
                std::this_thread::sleep_for(std::chrono::microseconds{100});
            SetCompleted();
        }
        std::atomic_bool done{false};
    };
    struct MyOperation : public Operation {
        ~MyOperation() override { Wait(); }
        Job *GetJob() noexcept override { return &job; }
        MyJob job;
    };

    auto op1 = std::make_shared<MyOperation>();
    auto op2 = std::make_shared<MyOperation>();
    auto op3 = std::make_shared<MyOperation>();
    pool->Enqueue(op1);
    pool->Enqueue(op2);
    pool->Enqueue(op3);

    CHECK(op1->State() == nc::ops::OperationState::Running);
    CHECK(op2->State() == nc::ops::OperationState::Cold);
    CHECK(op3->State() == nc::ops::OperationState::Cold);

    op1->job.done = true;
    CHECK(check_until_or_die([&] { return op2->State() == nc::ops::OperationState::Running; }, 1s));
    CHECK(op1->State() == nc::ops::OperationState::Completed);
    CHECK(op2->State() == nc::ops::OperationState::Running);
    CHECK(op3->State() == nc::ops::OperationState::Cold);

    op2->job.done = true;
    CHECK(check_until_or_die([&] { return op3->State() == nc::ops::OperationState::Running; }, 1s));
    CHECK(op1->State() == nc::ops::OperationState::Completed);
    CHECK(op2->State() == nc::ops::OperationState::Completed);
    CHECK(op3->State() == nc::ops::OperationState::Running);

    op3->job.done = true;
    CHECK(check_until_or_die([&] { return pool->Empty(); }, 1s));
    CHECK(op1->State() == nc::ops::OperationState::Completed);
    CHECK(op2->State() == nc::ops::OperationState::Completed);
    CHECK(op3->State() == nc::ops::OperationState::Completed);
}

TEST_CASE(PREFIX "Does enqueueing as the callback says")
{
    auto pool = Pool::Make();
    struct MyJob : public Job {
        void Perform() override
        {
            while( !done )
                std::this_thread::sleep_for(std::chrono::microseconds{100});
            SetCompleted();
        }
        std::atomic_bool done{false};
    };
    struct MyOperation : public Operation {
        ~MyOperation() override { Wait(); }
        Job *GetJob() noexcept override { return &job; }
        MyJob job;
    };

    auto op1 = std::make_shared<MyOperation>();
    auto op2 = std::make_shared<MyOperation>();
    bool enqueue_1st = true;
    bool enqueue_2nd = true;
    pool->SetEnqueuingCallback([&](const Operation &_operation) {
        if( &_operation == op1.get() )
            return enqueue_1st;
        if( &_operation == op2.get() )
            return enqueue_2nd;
        throw std::logic_error("");
    });
    SECTION("concurrency = 1")
    {
        pool->SetConcurrency(1);
        SECTION("true, true")
        {
            enqueue_1st = true;
            enqueue_2nd = true;
            pool->Enqueue(op1);
            pool->Enqueue(op2);
            CHECK(op1->State() == nc::ops::OperationState::Running);
            CHECK(op2->State() == nc::ops::OperationState::Cold);
            op1->job.done = true;
            CHECK(check_until_or_die([&] { return op2->State() == nc::ops::OperationState::Running; }, 1s));
            CHECK(op1->State() == nc::ops::OperationState::Completed);
            CHECK(op2->State() == nc::ops::OperationState::Running);
            op2->job.done = true;
            CHECK(check_until_or_die([&] { return pool->Empty(); }, 1s));
            CHECK(op1->State() == nc::ops::OperationState::Completed);
            CHECK(op2->State() == nc::ops::OperationState::Completed);
        }
        SECTION("true, false")
        {
            enqueue_1st = true;
            enqueue_2nd = false;
            pool->Enqueue(op1);
            pool->Enqueue(op2);
            CHECK(op1->State() == nc::ops::OperationState::Running);
            CHECK(op2->State() == nc::ops::OperationState::Running);
            op1->job.done = true;
            op2->job.done = true;
            CHECK(check_until_or_die([&] { return pool->Empty(); }, 1s));
            CHECK(op1->State() == nc::ops::OperationState::Completed);
            CHECK(op2->State() == nc::ops::OperationState::Completed);
        }
        SECTION("false, false")
        {
            enqueue_1st = false;
            enqueue_2nd = false;
            pool->Enqueue(op1);
            pool->Enqueue(op2);
            CHECK(op1->State() == nc::ops::OperationState::Running);
            CHECK(op2->State() == nc::ops::OperationState::Running);
            op1->job.done = true;
            op2->job.done = true;
            CHECK(check_until_or_die([&] { return pool->Empty(); }, 1s));
            CHECK(op1->State() == nc::ops::OperationState::Completed);
            CHECK(op2->State() == nc::ops::OperationState::Completed);
        }
        SECTION("false, true")
        {
            enqueue_1st = false;
            enqueue_2nd = true;
            pool->Enqueue(op1);
            pool->Enqueue(op2);
            CHECK(op1->State() == nc::ops::OperationState::Running);
            CHECK(op2->State() == nc::ops::OperationState::Cold);
            op1->job.done = true;
            CHECK(check_until_or_die([&] { return op2->State() == nc::ops::OperationState::Running; }, 1s));
            CHECK(op1->State() == nc::ops::OperationState::Completed);
            CHECK(op2->State() == nc::ops::OperationState::Running);
            op2->job.done = true;
            CHECK(check_until_or_die([&] { return pool->Empty(); }, 1s));
            CHECK(op1->State() == nc::ops::OperationState::Completed);
            CHECK(op2->State() == nc::ops::OperationState::Completed);
        }
    }
    SECTION("concurrency = 2")
    {
        pool->SetConcurrency(2);
        SECTION("false, false")
        {
            enqueue_1st = false;
            enqueue_2nd = false;
        }
        SECTION("false, true")
        {
            enqueue_1st = false;
            enqueue_2nd = true;
        }
        SECTION("true, false")
        {
            enqueue_1st = true;
            enqueue_2nd = false;
        }
        SECTION("true, true")
        {
            enqueue_1st = true;
            enqueue_2nd = true;
        }
        pool->Enqueue(op1);
        pool->Enqueue(op2);
        CHECK(op1->State() == nc::ops::OperationState::Running);
        CHECK(op2->State() == nc::ops::OperationState::Running);
        op1->job.done = true;
        op2->job.done = true;
        CHECK(check_until_or_die([&] { return pool->Empty(); }, 1s));
        CHECK(op1->State() == nc::ops::OperationState::Completed);
        CHECK(op2->State() == nc::ops::OperationState::Completed);
    }
}

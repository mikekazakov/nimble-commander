// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include <VFSIcon/IconRepositoryImpl.h>
#include <VFS/VFSListingInput.h>
#include "Tests.h"

using namespace nc::vfsicon;
using ::testing::_;
using ::testing::AnyNumber;
using ::testing::Invoke;
using ::testing::NiceMock;
using ::testing::Return;
using base = detail::IconRepositoryImplBase;

namespace {

struct IconBuilderMock : IconBuilder {
    MOCK_METHOD2(LookupExistingIcon, LookupResult(const VFSListingItem &, int));
    MOCK_METHOD3(BuildRealIcon, BuildResult(const VFSListingItem &, int, const CancelChecker &));
};

struct ExecutorMock : base::Executor {
    MOCK_METHOD1(Execute, void(std::function<void()>));
};

struct LimitedConcurrentQueueMock : base::LimitedConcurrentQueue {
    MOCK_METHOD1(Execute, void(std::function<void()>));
    MOCK_CONST_METHOD0(QueueLength, int());
};

} // namespace

static VFSListingItem CookListingItem();
static VFSListingItem CookListingItem(uint64_t _size, time_t _mtime, mode_t _mode);
static IconBuilder::BuildResult CookSomeBuildResult();

TEST_CASE("IconRepositoryImpl allocates a valid slot")
{
    auto icon_builder = std::make_shared<IconBuilderMock>();
    auto executor = std::make_shared<ExecutorMock>();
    auto queue = std::make_unique<NiceMock<LimitedConcurrentQueueMock>>();
    EXPECT_CALL(*icon_builder, LookupExistingIcon);
    IconRepositoryImpl repository{icon_builder, std::move(queue), executor};

    auto key = repository.Register(CookListingItem());

    CHECK(repository.IsValidSlot(key));
}

TEST_CASE("IconRepositoryImpl tracks its capacity")
{
    auto icon_builder = std::make_shared<IconBuilderMock>();
    auto executor = std::make_shared<ExecutorMock>();
    auto queue = std::make_unique<NiceMock<LimitedConcurrentQueueMock>>();
    EXPECT_CALL(*icon_builder, LookupExistingIcon);
    auto some_big_max_length = 500;
    IconRepositoryImpl repository{icon_builder, std::move(queue), executor, some_big_max_length, 1};

    auto item = CookListingItem();
    CHECK(repository.IsValidSlot(repository.Register(item)) == true);
    CHECK(repository.IsValidSlot(repository.Register(item)) == false);
}

TEST_CASE("IconRepositoryImpl does lookup for existing icon when registering")
{
    auto icon_builder = std::make_shared<IconBuilderMock>();
    auto executor = std::make_shared<ExecutorMock>();
    auto queue = std::make_unique<LimitedConcurrentQueueMock>();

    EXPECT_CALL(*icon_builder, LookupExistingIcon).Times(1);

    IconRepositoryImpl repository{icon_builder, std::move(queue), executor};

    repository.Register(CookListingItem());
}

TEST_CASE("IconRepositoryImpl returns lookup results got from IconBuilder")
{
    auto icon_builder = std::make_shared<IconBuilderMock>();
    auto executor = std::make_shared<ExecutorMock>();
    auto queue = std::make_unique<LimitedConcurrentQueueMock>();

    SECTION("only generic")
    {
        IconBuilder::LookupResult lr;
        lr.generic = [[NSImage alloc] init];
        EXPECT_CALL(*icon_builder, LookupExistingIcon).WillRepeatedly(Return(lr));
        IconRepositoryImpl repository{icon_builder, std::move(queue), executor};

        const auto key = repository.Register(CookListingItem());
        const auto image = repository.AvailableIconForSlot(key);

        CHECK(image == lr.generic);
    }
    SECTION("only filetype")
    {
        IconBuilder::LookupResult lr;
        lr.filetype = [[NSImage alloc] init];
        EXPECT_CALL(*icon_builder, LookupExistingIcon).WillRepeatedly(Return(lr));
        IconRepositoryImpl repository{icon_builder, std::move(queue), executor};

        const auto key = repository.Register(CookListingItem());
        const auto image = repository.AvailableIconForSlot(key);

        CHECK(image == lr.filetype);
    }
    SECTION("only thumbnail")
    {
        IconBuilder::LookupResult lr;
        lr.thumbnail = [[NSImage alloc] init];
        EXPECT_CALL(*icon_builder, LookupExistingIcon).WillRepeatedly(Return(lr));
        IconRepositoryImpl repository{icon_builder, std::move(queue), executor};

        const auto key = repository.Register(CookListingItem());
        const auto image = repository.AvailableIconForSlot(key);

        CHECK(image == lr.thumbnail);
    }
    SECTION("all three")
    {
        IconBuilder::LookupResult lr;
        lr.thumbnail = [[NSImage alloc] init];
        lr.filetype = [[NSImage alloc] init];
        lr.generic = [[NSImage alloc] init];
        EXPECT_CALL(*icon_builder, LookupExistingIcon).WillRepeatedly(Return(lr));
        IconRepositoryImpl repository{icon_builder, std::move(queue), executor};

        const auto key = repository.Register(CookListingItem());
        const auto image = repository.AvailableIconForSlot(key);

        CHECK(image == lr.thumbnail);
    }
}

TEST_CASE("IconRepositoryImpl returns a valid array of registered slot keys")
{
    auto icon_builder = std::make_shared<IconBuilderMock>();
    auto executor = std::make_shared<ExecutorMock>();
    auto queue = std::make_unique<LimitedConcurrentQueueMock>();
    EXPECT_CALL(*icon_builder, LookupExistingIcon).Times(2);
    IconRepositoryImpl repository{icon_builder, std::move(queue), executor};

    auto item = CookListingItem();
    const auto key1 = repository.Register(item);
    const auto key2 = repository.Register(item);

    const auto all_keys = repository.AllSlots();
    REQUIRE(all_keys.size() == 2);
    CHECK(all_keys[0] == key1);
    CHECK(all_keys[1] == key2);
}

TEST_CASE("IconRepositoryImpl makes an unregistered key invalid")
{
    auto icon_builder = std::make_shared<IconBuilderMock>();
    auto executor = std::make_shared<ExecutorMock>();
    auto queue = std::make_unique<LimitedConcurrentQueueMock>();
    EXPECT_CALL(*icon_builder, LookupExistingIcon);
    IconRepositoryImpl repository{icon_builder, std::move(queue), executor};

    auto key = repository.Register(CookListingItem());
    repository.Unregister(key);

    CHECK(repository.IsValidSlot(key) == false);
    CHECK(repository.AllSlots().empty());
}

TEST_CASE("IconRepositoryImpl reuses unregistered keys")
{
    auto icon_builder = std::make_shared<IconBuilderMock>();
    auto executor = std::make_shared<ExecutorMock>();
    auto queue = std::make_unique<LimitedConcurrentQueueMock>();
    EXPECT_CALL(*icon_builder, LookupExistingIcon).Times(AnyNumber());
    IconRepositoryImpl repository{icon_builder, std::move(queue), executor};

    const auto item = CookListingItem();
    SECTION("1,2,(2),2")
    {
        repository.Register(item);
        const auto key2 = repository.Register(item);
        repository.Unregister(key2);
        const auto key3 = repository.Register(item);
        CHECK(key3 == key2);
    }
    SECTION("1,2,(1),1")
    {
        const auto key1 = repository.Register(item);
        repository.Register(item);
        repository.Unregister(key1);
        const auto key3 = repository.Register(item);
        CHECK(key3 == key1);
    }
}

TEST_CASE("IconRepositoryImpl passes the right icon size to IconBuilder")
{
    auto icon_builder = std::make_shared<IconBuilderMock>();
    auto executor = std::make_shared<ExecutorMock>();
    auto queue = std::make_unique<LimitedConcurrentQueueMock>();
    const auto px_size = 96;
    EXPECT_CALL(*icon_builder, LookupExistingIcon(_, px_size));
    IconRepositoryImpl repository{icon_builder, std::move(queue), executor};
    repository.SetPxSize(px_size);
    repository.Register(CookListingItem());
}

TEST_CASE("IconRepositoryImpl uses a concurrent queue to produce real icons")
{
    auto icon_builder = std::make_shared<IconBuilderMock>();
    auto executor = std::make_shared<ExecutorMock>();
    auto queue = std::make_unique<NiceMock<LimitedConcurrentQueueMock>>();
    EXPECT_CALL(*icon_builder, LookupExistingIcon);
    EXPECT_CALL(*queue, Execute);
    IconRepositoryImpl repository{icon_builder, std::move(queue), executor};
    const auto item = CookListingItem();
    const auto key = repository.Register(item);
    repository.ScheduleIconProduction(key, item);
}

TEST_CASE("IconRepositoryImpl uses updated results from IconBuilder")
{
    auto icon_builder = std::make_shared<IconBuilderMock>();
    auto executor = std::make_shared<ExecutorMock>();
    auto queue = std::make_unique<NiceMock<LimitedConcurrentQueueMock>>();
    EXPECT_CALL(*queue, Execute).WillRepeatedly(Invoke([](const std::function<void()> &f) { f(); }));
    EXPECT_CALL(*executor, Execute).WillRepeatedly(Invoke([](const std::function<void()> &f) { f(); }));
    EXPECT_CALL(*icon_builder, LookupExistingIcon);

    SECTION("Thumbnail passage")
    {
        IconBuilder::BuildResult br;
        br.thumbnail = [[NSImage alloc] init];
        EXPECT_CALL(*icon_builder, BuildRealIcon).WillRepeatedly(Return(br));

        IconRepositoryImpl repository{icon_builder, std::move(queue), executor};
        const auto item = CookListingItem();
        const auto key = repository.Register(item);
        repository.ScheduleIconProduction(key, item);

        const auto img = repository.AvailableIconForSlot(key);
        CHECK(img == br.thumbnail);
    }
    SECTION("Filetype passage")
    {
        IconBuilder::BuildResult br;
        br.filetype = [[NSImage alloc] init];
        EXPECT_CALL(*icon_builder, BuildRealIcon).WillRepeatedly(Return(br));

        IconRepositoryImpl repository{icon_builder, std::move(queue), executor};
        const auto item = CookListingItem();
        const auto key = repository.Register(item);
        repository.ScheduleIconProduction(key, item);

        const auto img = repository.AvailableIconForSlot(key);
        CHECK(img == br.filetype);
    }
}

TEST_CASE("IconRepositoryImpl doesn't call IconBuilder concurrently for a single item")
{
    auto icon_builder = std::make_shared<IconBuilderMock>();
    auto executor = std::make_shared<ExecutorMock>();
    auto queue = std::make_unique<NiceMock<LimitedConcurrentQueueMock>>();
    EXPECT_CALL(*queue, Execute).WillRepeatedly(Invoke([](const std::function<void()> &f) { f(); }));
    EXPECT_CALL(*executor, Execute).WillRepeatedly(Invoke([](const std::function<void()> &) { /* no-op */ }));
    EXPECT_CALL(*icon_builder, LookupExistingIcon);

    const auto br = CookSomeBuildResult();
    EXPECT_CALL(*icon_builder, BuildRealIcon).Times(1).WillRepeatedly(Return(br));

    IconRepositoryImpl repository{icon_builder, std::move(queue), executor};
    const auto item = CookListingItem();
    const auto key = repository.Register(item);
    repository.ScheduleIconProduction(key, item);
    repository.ScheduleIconProduction(key, item);
}

TEST_CASE("IconRepositoryImpl doesn't call IconBuilder again if entry didn't change")
{
    auto icon_builder = std::make_shared<IconBuilderMock>();
    auto executor = std::make_shared<ExecutorMock>();
    auto queue = std::make_unique<NiceMock<LimitedConcurrentQueueMock>>();
    EXPECT_CALL(*queue, Execute).WillRepeatedly(Invoke([](const std::function<void()> &f) { f(); }));
    EXPECT_CALL(*executor, Execute).WillRepeatedly(Invoke([](const std::function<void()> &f) { f(); }));
    EXPECT_CALL(*icon_builder, LookupExistingIcon);

    const auto br = CookSomeBuildResult();
    EXPECT_CALL(*icon_builder, BuildRealIcon).Times(1).WillRepeatedly(Return(br));

    IconRepositoryImpl repository{icon_builder, std::move(queue), executor};
    const auto item = CookListingItem();
    const auto key = repository.Register(item);
    repository.ScheduleIconProduction(key, item);
    repository.ScheduleIconProduction(key, item);
}

TEST_CASE("IconRepositoryImpl call IconBuilder again if entry did change")
{
    auto icon_builder = std::make_shared<IconBuilderMock>();
    auto executor = std::make_shared<ExecutorMock>();
    auto queue = std::make_unique<NiceMock<LimitedConcurrentQueueMock>>();
    EXPECT_CALL(*queue, Execute).WillRepeatedly(Invoke([](const std::function<void()> &f) { f(); }));
    EXPECT_CALL(*executor, Execute).WillRepeatedly(Invoke([](const std::function<void()> &f) { f(); }));
    EXPECT_CALL(*icon_builder, LookupExistingIcon);

    const auto br = CookSomeBuildResult();
    EXPECT_CALL(*icon_builder, BuildRealIcon).Times(2).WillRepeatedly(Return(br));

    IconRepositoryImpl repository{icon_builder, std::move(queue), executor};
    const auto item1 = CookListingItem(1234, 4567, 2467);
    const auto key = repository.Register(item1);
    repository.ScheduleIconProduction(key, item1);
    SECTION("Changed size")
    {
        const auto item2 = CookListingItem(3456, 4567, 2467);
        repository.ScheduleIconProduction(key, item2);
    }
    SECTION("Changed mtime")
    {
        const auto item2 = CookListingItem(1234, 3244, 2467);
        repository.ScheduleIconProduction(key, item2);
    }
    SECTION("Changed mode")
    {
        const auto item2 = CookListingItem(1234, 3244, 453);
        repository.ScheduleIconProduction(key, item2);
    }
}

TEST_CASE("IconRepositoryImpl calls a callback when icon changes")
{
    auto icon_builder = std::make_shared<IconBuilderMock>();
    auto executor = std::make_shared<ExecutorMock>();
    auto queue = std::make_unique<NiceMock<LimitedConcurrentQueueMock>>();
    EXPECT_CALL(*queue, Execute).WillRepeatedly(Invoke([](const std::function<void()> &f) { f(); }));
    EXPECT_CALL(*executor, Execute).WillRepeatedly(Invoke([](const std::function<void()> &f) { f(); }));
    EXPECT_CALL(*icon_builder, LookupExistingIcon);

    const auto br = CookSomeBuildResult();
    EXPECT_CALL(*icon_builder, BuildRealIcon).Times(1).WillRepeatedly(Return(br));

    IconRepositoryImpl repository{icon_builder, std::move(queue), executor};
    const auto item = CookListingItem();
    const auto key = repository.Register(item);
    bool called = false;
    auto callback = [&called, key, br](IconRepository::SlotKey _key, NSImage *_img) -> void {
        called = true;
        CHECK(_key == key);
        CHECK(_img == br.thumbnail);
    };
    repository.SetUpdateCallback(callback);
    repository.ScheduleIconProduction(key, item);
    CHECK(called == true);
}

TEST_CASE("IconRepositoryImpl doesn't call a callback when icon is the same")
{
    auto icon_builder = std::make_shared<IconBuilderMock>();
    auto executor = std::make_shared<ExecutorMock>();
    auto queue = std::make_unique<NiceMock<LimitedConcurrentQueueMock>>();
    EXPECT_CALL(*queue, Execute).WillRepeatedly(Invoke([](const std::function<void()> &f) { f(); }));
    EXPECT_CALL(*executor, Execute).WillRepeatedly(Invoke([](const std::function<void()> &f) { f(); }));
    auto img = [[NSImage alloc] init];
    IconBuilder::LookupResult lr;
    lr.thumbnail = img;
    EXPECT_CALL(*icon_builder, LookupExistingIcon).WillRepeatedly(Return(lr));

    IconBuilder::BuildResult br;
    br.thumbnail = img;
    EXPECT_CALL(*icon_builder, BuildRealIcon).WillRepeatedly(Return(br));

    IconRepositoryImpl repository{icon_builder, std::move(queue), executor};
    const auto item = CookListingItem();
    const auto key = repository.Register(item);
    bool called = false;
    auto callback = [&called](IconRepository::SlotKey, NSImage *) -> void { called = true; };
    repository.SetUpdateCallback(callback);
    repository.ScheduleIconProduction(key, item);
    CHECK(called == false);
}

TEST_CASE("IconRepositoryImpl doesn't call IconBuilder concurrently when prod queue is too long")
{
    auto icon_builder = std::make_shared<IconBuilderMock>();
    auto executor = std::make_shared<ExecutorMock>();
    auto queue = std::make_unique<NiceMock<LimitedConcurrentQueueMock>>();
    EXPECT_CALL(*queue, Execute).Times(1);
    EXPECT_CALL(*queue, QueueLength).WillOnce(Return(0)).WillOnce(Return(1));
    EXPECT_CALL(*icon_builder, LookupExistingIcon).Times(2);

    IconRepositoryImpl repository{icon_builder, std::move(queue), executor, 1};
    const auto item = CookListingItem();
    const auto key1 = repository.Register(item);
    const auto key2 = repository.Register(item);
    repository.ScheduleIconProduction(key1, item);
    repository.ScheduleIconProduction(key2, item);
}

static IconBuilder::BuildResult CookSomeBuildResult()
{
    IconBuilder::BuildResult br;
    br.thumbnail = [[NSImage alloc] init];
    br.filetype = [[NSImage alloc] init];
    return br;
}

static VFSListingItem CookListingItem()
{
    return CookListingItem(1234, 4567, 2467);
}

static VFSListingItem CookListingItem(uint64_t _size, time_t _mtime, mode_t _mode)
{
    nc::vfs::ListingInput l;
    l.directories[0] = "/DOESN'T MATTER/";
    l.hosts[0] = VFSHost::DummyHost();
    l.filenames.emplace_back("SOME FILENAME");
    l.unix_modes.emplace_back(_mode);
    l.unix_types.emplace_back(0);
    l.sizes.insert(0, _size);
    l.mtimes.insert(0, _mtime);

    auto listing = VFSListing::Build(std::move(l));
    return listing->Item(0);
}

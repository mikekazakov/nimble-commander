// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include <VFSIcon/WorkspaceIconsCacheImpl.h>
#include "Tests.h"

using namespace nc::vfsicon;
using ::testing::_;
using ::testing::Return;
using base = detail::WorkspaceIconsCacheImplBase;

namespace {

struct FileStateReaderMock : base::FileStateReader {
    MOCK_METHOD1(ReadState, std::optional<base::FileStateHint>(const std::string &));
};
struct IconBuilderMock : base::IconBuilder {
    MOCK_METHOD1(Build, NSImage *(const std::string &));
};

} // namespace

TEST_CASE("WorkspaceIconsCacheImpl doesn't call IconBuilder when file is inaccessible")
{
    FileStateReaderMock file_state_reader;
    IconBuilderMock icon_builder;
    EXPECT_CALL(file_state_reader, ReadState(_)).Times(1).WillRepeatedly(Return(std::nullopt));
    WorkspaceIconsCacheImpl cache{file_state_reader, icon_builder};
    cache.ProduceIcon("/Fake/Path.png");
}

TEST_CASE("WorkspaceIconsCacheImpl calls IconBuilder when file is accessible")
{
    FileStateReaderMock file_state_reader;
    IconBuilderMock icon_builder;
    EXPECT_CALL(file_state_reader, ReadState(_)).Times(1).WillRepeatedly(Return(base::FileStateHint{}));
    EXPECT_CALL(icon_builder, Build(_)).Times(1).WillRepeatedly(Return(nil));
    WorkspaceIconsCacheImpl cache{file_state_reader, icon_builder};
    cache.ProduceIcon("/Fake/Path.png");
}

TEST_CASE("WorkspaceIconsCacheImpl calls IconBuilder only once if file wasn't changed")
{
    FileStateReaderMock file_state_reader;
    IconBuilderMock icon_builder;
    EXPECT_CALL(file_state_reader, ReadState(_)).Times(2).WillRepeatedly(Return(base::FileStateHint{}));
    EXPECT_CALL(icon_builder, Build(_)).Times(1).WillRepeatedly(Return(nil));
    WorkspaceIconsCacheImpl cache{file_state_reader, icon_builder};
    cache.ProduceIcon("/Fake/Path.png");
    cache.ProduceIcon("/Fake/Path.png");
}

TEST_CASE("WorkspaceIconsCacheImpl evicts the least recently used icons")
{
    FileStateReaderMock file_state_reader;
    IconBuilderMock icon_builder;
    EXPECT_CALL(file_state_reader, ReadState(_))
        .Times(WorkspaceIconsCacheImpl::CacheMaxSize() * 4)
        .WillRepeatedly(Return(base::FileStateHint{}));
    EXPECT_CALL(icon_builder, Build(_)).Times(WorkspaceIconsCacheImpl::CacheMaxSize() * 3).WillRepeatedly(Return(nil));
    WorkspaceIconsCacheImpl cache{file_state_reader, icon_builder};
    for( int i = 0; i < WorkspaceIconsCacheImpl::CacheMaxSize(); ++i )
        cache.ProduceIcon(std::to_string(i));
    for( int i = 0; i < WorkspaceIconsCacheImpl::CacheMaxSize(); ++i )
        cache.ProduceIcon(std::to_string(i));
    for( int i = 0; i < WorkspaceIconsCacheImpl::CacheMaxSize(); ++i )
        cache.ProduceIcon(std::to_string(-i - 1));
    for( int i = 0; i < WorkspaceIconsCacheImpl::CacheMaxSize(); ++i )
        cache.ProduceIcon(std::to_string(i));
}

// Copyright (C) 2014-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include "TestEnv.h"
#include <VFS/VFS.h>
#include <VFS/FileWindow.h>
#include <random>

using namespace nc;
using nc::vfs::FileWindow;

#define PREFIX "nc::vfs::FileWindow "

class TestGenericMemReadOnlyFile : public VFSFile
{
public:
    TestGenericMemReadOnlyFile(std::string_view _relative_path,
                               std::shared_ptr<VFSHost> _host,
                               const void *_memory,
                               uint64_t _mem_size,
                               ReadParadigm _behave_as);

    int Open(unsigned long _open_flags, const VFSCancelChecker &_cancel_checker) override;
    bool IsOpened() const override { return m_Opened; }
    int Close() override;

    ssize_t Read(void *_buf, size_t _size) override;
    std::expected<size_t, nc::Error> ReadAt(off_t _pos, void *_buf, size_t _size) override;
    ReadParadigm GetReadParadigm() const override;
    off_t Seek(off_t _off, int _basis) override;
    ssize_t Pos() const override;
    ssize_t Size() const override;
    bool Eof() const override;

private:
    ReadParadigm m_Behaviour;
    const void *const m_Mem;
    const uint64_t m_Size;
    ssize_t m_Pos = 0;
    bool m_Opened = false;
};

TestGenericMemReadOnlyFile::TestGenericMemReadOnlyFile(std::string_view _relative_path,
                                                       std::shared_ptr<VFSHost> _host,
                                                       const void *_memory,
                                                       uint64_t _mem_size,
                                                       ReadParadigm _behave_as)
    : VFSFile(_relative_path, _host), m_Behaviour(_behave_as), m_Mem(_memory), m_Size(_mem_size)
{
}

ssize_t TestGenericMemReadOnlyFile::Read(void *_buf, size_t _size)
{
    if( !IsOpened() )
        return VFSError::InvalidCall;

    if( _buf == nullptr )
        return VFSError::InvalidCall;

    if( _size == 0 )
        return 0;

    // we can only deal with cache buffer now, need another branch later
    if( m_Pos == static_cast<ssize_t>(m_Size) )
        return 0;

    const size_t to_read = MIN(m_Size - m_Pos, _size);
    std::memcpy(_buf, static_cast<const char *>(m_Mem) + m_Pos, to_read);
    m_Pos += to_read;
    assert(m_Pos <= static_cast<ssize_t>(m_Size)); // just a sanity check

    return to_read;
}

std::expected<size_t, nc::Error> TestGenericMemReadOnlyFile::ReadAt(off_t _pos, void *_buf, size_t _size)
{
    if( m_Behaviour < VFSFile::ReadParadigm::Random )
        return SetLastError(Error{Error::POSIX, ENOTSUP});

    if( !IsOpened() )
        return SetLastError(Error{Error::POSIX, EINVAL});

    // we can only deal with cache buffer now, need another branch later
    if( _pos < 0 || _pos > static_cast<ssize_t>(m_Size) )
        return SetLastError(Error{Error::POSIX, EINVAL});

    const size_t toread = std::min(static_cast<size_t>(m_Size) - static_cast<size_t>(_pos), _size);
    std::memcpy(_buf, static_cast<const char *>(m_Mem) + _pos, toread);
    return toread;
}

off_t TestGenericMemReadOnlyFile::Seek(off_t _off, int _basis)
{
    if( m_Behaviour < VFSFile::ReadParadigm::Seek )
        return VFSError::NotSupported;

    if( !IsOpened() )
        return VFSError::InvalidCall;

    off_t req_pos = 0;
    if( _basis == VFSFile::Seek_Set )
        req_pos = _off;
    else if( _basis == VFSFile::Seek_End )
        req_pos = m_Size + _off;
    else if( _basis == VFSFile::Seek_Cur )
        req_pos = m_Pos + _off;
    else
        return VFSError::InvalidCall;

    if( req_pos < 0 )
        return VFSError::InvalidCall;
    if( req_pos > static_cast<ssize_t>(m_Size) )
        req_pos = m_Size;
    m_Pos = req_pos;

    return m_Pos;
}

VFSFile::ReadParadigm TestGenericMemReadOnlyFile::GetReadParadigm() const
{
    return m_Behaviour;
}

ssize_t TestGenericMemReadOnlyFile::Pos() const
{
    if( !IsOpened() )
        return VFSError::InvalidCall;
    return m_Pos;
}

ssize_t TestGenericMemReadOnlyFile::Size() const
{
    return m_Size;
}

bool TestGenericMemReadOnlyFile::Eof() const
{
    if( !IsOpened() )
        return true;
    return m_Pos == static_cast<ssize_t>(m_Size);
}

int TestGenericMemReadOnlyFile::Open([[maybe_unused]] unsigned long _open_flags,
                                     [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    m_Opened = true;
    return 0;
}

int TestGenericMemReadOnlyFile::Close()
{
    m_Opened = false;
    return 0;
}

TEST_CASE(PREFIX "random access")
{
    const auto data_size = 1024 * 1024;
    const std::unique_ptr<uint8_t[]> data(new uint8_t[data_size]);
    for( int i = 0; i < data_size; ++i )
        data[i] = static_cast<unsigned char>(rand() % 256);

    auto vfs_file =
        std::make_shared<TestGenericMemReadOnlyFile>("", nullptr, data.get(), data_size, VFSFile::ReadParadigm::Random);
    vfs_file->Open(0, nullptr);

    FileWindow fw;
    REQUIRE(fw.Attach(vfs_file));

    std::mt19937 mt((std::random_device())());
    std::uniform_int_distribution<size_t> dist(0, fw.FileSize() - fw.WindowSize());

    for( int i = 0; i < 10000; ++i ) {
        auto pos = dist(mt);
        REQUIRE(fw.MoveWindow(pos));
        const int cmp = memcmp(fw.Window(), &data[pos], fw.WindowSize());
        REQUIRE(cmp == 0);
    }
}

TEST_CASE(PREFIX "sequential access")
{
    const auto data_size = 100 * 1024 * 1024;
    const std::unique_ptr<uint8_t[]> data(new uint8_t[data_size]);
    for( int i = 0; i < data_size; ++i )
        data[i] = static_cast<unsigned char>(rand() % 256);

    auto vfs_file = std::make_shared<TestGenericMemReadOnlyFile>(
        "", nullptr, data.get(), data_size, VFSFile::ReadParadigm::Sequential);
    vfs_file->Open(0, nullptr);

    FileWindow fw;
    REQUIRE(fw.Attach(vfs_file));

    std::mt19937 mt((std::random_device())());
    std::uniform_int_distribution<size_t> dist(0, fw.WindowSize() * 10);

    while( true ) {
        const int cmp = memcmp(fw.Window(), &data[fw.WindowPos()], fw.WindowSize());
        REQUIRE(cmp == 0);

        auto off = dist(mt);
        auto pos = fw.WindowPos() + off;
        if( pos > fw.FileSize() - fw.WindowSize() )
            break;

        REQUIRE(fw.MoveWindow(pos));
    }
}

TEST_CASE(PREFIX "seek access")
{
    const auto data_size = 10 * 1024 * 1024;
    const std::unique_ptr<uint8_t[]> data(new uint8_t[data_size]);
    for( int i = 0; i < data_size; ++i )
        data[i] = static_cast<unsigned char>(rand() % 256);

    auto vfs_file =
        std::make_shared<TestGenericMemReadOnlyFile>("", nullptr, data.get(), data_size, VFSFile::ReadParadigm::Seek);
    vfs_file->Open(0, nullptr);

    FileWindow fw;
    REQUIRE(fw.Attach(vfs_file));

    std::mt19937 mt((std::random_device())());
    std::uniform_int_distribution<size_t> dist(0, fw.FileSize() - fw.WindowSize());

    for( int i = 0; i < 10000; ++i ) {
        auto pos = dist(mt);
        REQUIRE(fw.MoveWindow(pos));
        const int cmp = memcmp(fw.Window(), &data[pos], fw.WindowSize());
        REQUIRE(cmp == 0);
    }
}

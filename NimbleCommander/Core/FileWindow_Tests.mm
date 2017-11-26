// Copyright (C) 2014-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#import <XCTest/XCTest.h>
#include <VFS/VFS.h>
#include <NimbleCommander/States/FilePanels/PanelData.h>
#include <NimbleCommander/Core/FileWindow.h>
#include <random>

class TestGenericMemReadOnlyFile : public VFSFile
{
public:
    TestGenericMemReadOnlyFile(const char* _relative_path,
                              shared_ptr<VFSHost> _host,
                              const void *_memory,
                              uint64_t _mem_size,
                              ReadParadigm _behave_as);
    
    
    virtual int     Open(unsigned long _open_flags, const VFSCancelChecker &_cancel_checker) override;
    virtual bool    IsOpened() const override {return m_Opened;}
    virtual int     Close() override;
    
    virtual ssize_t Read(void *_buf, size_t _size) override;
    virtual ssize_t ReadAt(off_t _pos, void *_buf, size_t _size) override;
    virtual ReadParadigm GetReadParadigm() const override;
    virtual off_t Seek(off_t _off, int _basis) override;
    virtual ssize_t Pos() const override;
    virtual ssize_t Size() const override;
    virtual bool Eof() const override;
    
private:
    ReadParadigm        m_Behaviour;
    const void * const  m_Mem;
    const uint64_t      m_Size;
    ssize_t             m_Pos = 0;
    bool                m_Opened = false;
};


TestGenericMemReadOnlyFile::TestGenericMemReadOnlyFile(const char* _relative_path,
                                                     shared_ptr<VFSHost> _host,
                                                     const void *_memory,
                                                     uint64_t _mem_size,
                                                     ReadParadigm _behave_as):
    VFSFile(_relative_path, _host),
    m_Mem(_memory),
    m_Size(_mem_size),
    m_Behaviour(_behave_as)
{
}

ssize_t TestGenericMemReadOnlyFile::Read(void *_buf, size_t _size)
{
    if(!IsOpened())
        return VFSError::InvalidCall;
    
    if(_buf == 0)
        return VFSError::InvalidCall;
    
    if(_size == 0)
        return 0;
    
    // we can only deal with cache buffer now, need another branch later
    if(m_Pos == m_Size)
        return 0;
    
    size_t to_read = MIN(m_Size - m_Pos, _size);
    memcpy(_buf, (char*)m_Mem + m_Pos, to_read);
    m_Pos += to_read;
    assert(m_Pos <= m_Size); // just a sanity check
    
    return to_read;
}

ssize_t TestGenericMemReadOnlyFile::ReadAt(off_t _pos, void *_buf, size_t _size)
{
    if(m_Behaviour < VFSFile::ReadParadigm::Random)
        return VFSError::NotSupported;
    
    if(!IsOpened())
        return VFSError::InvalidCall;
    
    // we can only deal with cache buffer now, need another branch later
    if(_pos < 0 || _pos > m_Size)
        return VFSError::InvalidCall;
    
    ssize_t toread = MIN(m_Size - _pos, _size);
    memcpy(_buf, (char*)m_Mem + _pos, toread);
    return toread;
}

off_t TestGenericMemReadOnlyFile::Seek(off_t _off, int _basis)
{
    if(m_Behaviour < VFSFile::ReadParadigm::Seek)
        return VFSError::NotSupported;
    
    if(!IsOpened())
        return VFSError::InvalidCall;
    
    off_t req_pos = 0;
    if(_basis == VFSFile::Seek_Set)
        req_pos = _off;
    else if(_basis == VFSFile::Seek_End)
        req_pos = m_Size + _off;
    else if(_basis == VFSFile::Seek_Cur)
        req_pos = m_Pos + _off;
    else
        return VFSError::InvalidCall;
    
    if(req_pos < 0)
        return VFSError::InvalidCall;
    if(req_pos > m_Size)
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
    if(!IsOpened())
        return VFSError::InvalidCall;
    return m_Pos;
}

ssize_t TestGenericMemReadOnlyFile::Size() const
{
    return m_Size;
}

bool TestGenericMemReadOnlyFile::Eof() const
{
    if(!IsOpened())
        return true;
    return m_Pos == m_Size;
}

int TestGenericMemReadOnlyFile::Open(unsigned long _open_flags, const VFSCancelChecker &_cancel_checker)
{
    m_Opened = true;
    return 0;
}

int TestGenericMemReadOnlyFile::Close()
{
    m_Opened = false;
    return 0;
}

@interface FileWindow_Tests : XCTestCase

@end


@implementation FileWindow_Tests

- (void)testRandomAccess
{
    const size_t data_size = 1024*1024;
    unique_ptr<uint8_t[]> data(new uint8_t[data_size]);
    for(int i = 0; i < data_size; ++i)
        data[i] = rand() % 256;
    
    auto vfs_file = make_shared<TestGenericMemReadOnlyFile>(nullptr, nullptr,
                                                            data.get(), data_size,
                                                            VFSFile::ReadParadigm::Random);
    vfs_file->Open(0, 0);
    
    FileWindow fw;
    int ret = fw.OpenFile(vfs_file);
    XCTAssert(ret == 0);

    mt19937 mt((random_device())());
    uniform_int_distribution<size_t> dist(0, fw.FileSize() - fw.WindowSize());

    for(int i = 0; i < 10000; ++i)
    {
        auto pos = dist(mt);
        fw.MoveWindow(pos);
        int cmp = memcmp(fw.Window(),
                         &data[pos],
                         fw.WindowSize());
        XCTAssert(cmp == 0);
    }
}

- (void)testSequentialAccess
{
    const size_t data_size = 100*1024*1024;
    unique_ptr<uint8_t[]> data(new uint8_t[data_size]);
    for(int i = 0; i < data_size; ++i)
        data[i] = rand() % 256;
    
    auto vfs_file = make_shared<TestGenericMemReadOnlyFile>(nullptr, nullptr,
                                                            data.get(), data_size,
                                                            VFSFile::ReadParadigm::Sequential);
    vfs_file->Open(0, 0);
    
    FileWindow fw;
    int ret = fw.OpenFile(vfs_file);
    XCTAssert(ret == 0);
    
    mt19937 mt((random_device())());
    uniform_int_distribution<size_t> dist(0, fw.WindowSize()*10);

    while(true) {
        int cmp = memcmp(fw.Window(),
                         &data[fw.WindowPos()],
                         fw.WindowSize());
        XCTAssert(cmp == 0);
        
        auto off = dist(mt);
        auto pos = fw.WindowPos()+off;
        if(pos > fw.FileSize() - fw.WindowSize())
            break;
        
        fw.MoveWindow(pos);
    }
}

- (void)testSeekAccess
{
    const size_t data_size = 10*1024*1024;
    unique_ptr<uint8_t[]> data(new uint8_t[data_size]);
    for(int i = 0; i < data_size; ++i)
        data[i] = rand() % 256;
    
    auto vfs_file = make_shared<TestGenericMemReadOnlyFile>(nullptr, nullptr,
                                                            data.get(), data_size,
                                                            VFSFile::ReadParadigm::Seek);
    vfs_file->Open(0, 0);
    
    FileWindow fw;
    int ret = fw.OpenFile(vfs_file);
    XCTAssert(ret == 0);
    
    mt19937 mt((random_device())());
    uniform_int_distribution<size_t> dist(0, fw.FileSize() - fw.WindowSize());
    
    for(int i = 0; i < 10000; ++i)
    {
        auto pos = dist(mt);
        fw.MoveWindow(pos);
        int cmp = memcmp(fw.Window(),
                         &data[pos],
                         fw.WindowSize());
        XCTAssert(cmp == 0);
    }
}

@end

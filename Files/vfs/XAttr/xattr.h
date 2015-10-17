#pragma once

#include "../VFSHost.h"
#include "../VFSFile.h"

class VFSXAttrFile;

class VFSXAttrHost final: public VFSHost
{
public:
    VFSXAttrHost( const string &_file_path, const VFSHostPtr& _host ); // _host must be native currently
    ~VFSXAttrHost();

    static const char *Tag;
    virtual VFSConfiguration Configuration() const override;
    static VFSMeta Meta();
    
    virtual int CreateFile(const char* _path,
                           shared_ptr<VFSFile> &_target,
                           VFSCancelChecker _cancel_checker) override;

    virtual int FetchFlexibleListing(const char *_path,
                                     shared_ptr<VFSFlexibleListing> &_target,
                                     int _flags,
                                     VFSCancelChecker _cancel_checker) override;
    
    virtual int Stat(const char *_path, VFSStat &_st, int _flags, VFSCancelChecker _cancel_checker) override;    
    
private:
    VFSConfiguration                m_Configuration;    
    int                             m_FD = -1;
    struct stat                     m_Stat;
    vector< pair<string, unsigned>> m_Attrs;
};

class VFSXAttrFile final: public VFSFile
{
public:
    VFSXAttrFile( const string &_xattr_path, const shared_ptr<VFSXAttrHost> &_parent, int _fd );
    virtual int Open(int _open_flags, VFSCancelChecker _cancel_checker = nullptr) override;
    virtual int  Close() override;
    virtual bool IsOpened() const override;
    virtual ReadParadigm  GetReadParadigm() const override;
    virtual ssize_t Pos() const override;
    virtual off_t Seek(off_t _off, int _basis) override;    
    virtual ssize_t Size() const override;
    virtual bool Eof() const override;
    virtual ssize_t Read(void *_buf, size_t _size) override;    
    virtual ssize_t ReadAt(off_t _pos, void *_buf, size_t _size) override;
    
private:
    bool IsOpenedForReading() const noexcept;
    bool IsOpenedForWriting() const noexcept;
    
    const int               m_FD; // non-owning
    int                     m_OpenFlags;
    unique_ptr<uint8_t[]>   m_FileBuf;
    ssize_t                 m_Position;
    ssize_t                 m_Size;
};

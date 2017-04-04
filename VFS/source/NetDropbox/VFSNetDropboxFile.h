#pragma once

#include "VFSNetDropboxHost.h"

class VFSNetDropboxFile : public VFSFile
{
public:
    VFSNetDropboxFile(const char* _relative_path, const shared_ptr<VFSNetDropboxHost> &_host);
    ~VFSNetDropboxFile();

    virtual int Open(int _open_flags, VFSCancelChecker _cancel_checker) override;
    virtual int PreferredIOSize() const override;
    virtual bool    IsOpened() const override;
    virtual ReadParadigm GetReadParadigm() const override;
    virtual ssize_t Read(void *_buf, size_t _size) override;
    virtual ssize_t Pos() const override;
    virtual ssize_t Size() const override;
    virtual bool Eof() const override;



    bool ProcessDownloadResponse( NSURLResponse *_response );
    void AppendDownloadedData( NSData *_data );

private:
    enum State {
        Cold        = 0,
        Initiated   = 1,
        Downloading = 2,
        Uploading   = 3,
        Canceled    = 4,
        Completed   = 5
    };

    long                m_FilePos = 0;
    long                m_FileSize = -1;

    atomic<State>       m_State { Cold };

    mutex               m_SignalLock;
    condition_variable  m_Signal;
    
    mutex           m_DataLock;
    deque<uint8_t>  m_DownloadFIFO;
    long            m_DownloadFIFOOffset = 0; // is it always equal to m_FilePos???


};

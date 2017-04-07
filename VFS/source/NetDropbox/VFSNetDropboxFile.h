#pragma once

#include "VFSNetDropboxHost.h"

@class VFSNetDropboxFileUploadStream;
@class VFSNetDropboxFileUploadDelegate;

class VFSNetDropboxFile : public VFSFile
{
public:
    VFSNetDropboxFile(const char* _relative_path, const shared_ptr<VFSNetDropboxHost> &_host);
    ~VFSNetDropboxFile();

    virtual int Open(int _open_flags, VFSCancelChecker _cancel_checker) override;
    virtual int Close() override;
    virtual int PreferredIOSize() const override;
    virtual bool    IsOpened() const override;
    virtual ReadParadigm GetReadParadigm() const override;
    virtual WriteParadigm GetWriteParadigm() const override;    
    virtual ssize_t Read(void *_buf, size_t _size) override;
    virtual ssize_t Write(const void *_buf, size_t _size) override;
    virtual ssize_t Pos() const override;
    virtual ssize_t Size() const override;
    virtual bool Eof() const override;
    virtual int SetUploadSize(size_t _size) override;


    // download hooks
    bool ProcessDownloadResponse( NSURLResponse *_response );
    void AppendDownloadedData( NSData *_data );

    // upload hooks
    bool ProcessUploadResponse( NSURLResponse *_response );

    
private:
    ssize_t FeedUploadTask( uint8_t *_buffer, size_t _sz ); // called from a background thread
    bool HasDataToFeedUploadTask(); // called from a background thread

    /**
     * Download flow: Cold -> Initiated -> Downloading -> (Canceled|Completed)
     * Upload flow:   Cold -> Initiated -> Uploading ->   (Canceled|Completed)
     */
    enum State {
        Cold        = 0,
        Initiated   = 1,
        Downloading = 2,
        Uploading   = 3, // Initiated upload switches to Uploading in SetUploadSize()
        Canceled    = 4,
        Completed   = 5
    };


    struct Download {
        deque<uint8_t>          fifo;
        long                    fifo_offset = 0; // is it always equal to m_FilePos???
        NSURLSessionDataTask   *task;
    };
    struct Upload {
        deque<uint8_t>                  fifo;
        long                            fifo_offset = 0;
        long                            upload_size = -1;
        NSMutableURLRequest            *request;
        NSURLSessionUploadTask         *task;
        VFSNetDropboxFileUploadDelegate*delegate;
        VFSNetDropboxFileUploadStream  *stream;
    };


    long                m_FilePos = 0;
    long                m_FileSize = -1;

    atomic<State>       m_State { Cold };

    mutex               m_SignalLock;
    condition_variable  m_Signal;
    
    mutex               m_DataLock; // any access to m_Download/m_Upload must be guarded
    unique_ptr<Download>m_Download; // exists only on reading
    unique_ptr<Upload>  m_Upload;   // exists only on writing    
};

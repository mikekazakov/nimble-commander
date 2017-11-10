// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "Host.h"

@class NCVFSDropboxFileDownloadDelegate;
@class NCVFSDropboxFileUploadStream;
@class NCVFSDropboxFileUploadDelegate;

namespace nc::vfs::dropbox {

class File final : public VFSFile
{
public:
    File(const char* _relative_path, const shared_ptr<class DropboxHost> &_host);
    ~File();

    virtual int Open(unsigned long _open_flags, const VFSCancelChecker &_cancel_checker) override;
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
    int SetChunkSize( size_t _size );

private:
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
        Completed   = 5,
        StatesAmount
    };

    void CheckStateTransition( State _new_state ) const;
    void SwitchToState( State _new_state );
    ssize_t FeedUploadTaskAsync( uint8_t *_buffer, size_t _sz );
    bool HasDataToFeedUploadTaskAsync() const;
    void AppendDownloadedDataAsync( NSData *_data );
    void HandleDownloadResponseAsync( ssize_t _download_size );
    void HandleDownloadError( int _error );
    void StartSmallUpload();
    void StartSession();
    void StartSessionAppend();
    void StartSessionFinish();
    NSURLRequest *BuildDownloadRequest() const;
    NSURLRequest *BuildRequestForSinglePartUpload() const;
    NSURLRequest *BuildRequestForUploadSessionInit() const;
    NSURLRequest *BuildRequestForUploadSessionAppend() const;
    NSURLRequest *BuildRequestForUploadSessionFinish() const;
    string BuildUploadPathspec() const;
    const DropboxHost &DropboxHost() const;
    ssize_t WaitForUploadBufferConsumption() const;
    void PushUploadDataIntoFIFOAndNotifyStream( const void *_buf, size_t _size );
    void ExtractSessionIdOrCancelUploadAsync( NSData *_data );
    void WaitForSessionIdOrError() const;
    void WaitForDownloadResponse() const;
    void WaitForAppendToComplete() const;

    struct Download {
        deque<uint8_t>          fifo;
        long                    fifo_offset = 0; // is it always equal to m_FilePos???
        NSURLSessionDataTask   *task;
        NCVFSDropboxFileDownloadDelegate *delegate = nil;
    };
    struct Upload {
        deque<uint8_t>                  fifo;
        atomic_long                     fifo_offset {0};
        long                            upload_size = -1;
        bool                            partitioned = false;
        int                             part_no = 0;
        int                             parts_count = 0;
        NSURLSessionUploadTask         *task = nil;
        NCVFSDropboxFileUploadDelegate *delegate = nil;
        NCVFSDropboxFileUploadStream   *stream = nil;
        string                          session_id;
        atomic_bool                     append_accepted{false};
    };

    unsigned long       m_OpenFlags = 0;
    long                m_FilePos = 0;
    long                m_FileSize = -1;
    long                m_ChunkSize = 150 * 1000 * 1000; // 150Mb according to dropbox docs

    atomic<State>       m_State { Cold };

    mutable mutex               m_SignalLock;
    mutable condition_variable  m_Signal;
    
    mutable mutex       m_DataLock; // any access to m_Download/m_Upload must be guarded
    unique_ptr<Download>m_Download; // exists only on reading
    unique_ptr<Upload>  m_Upload;   // exists only on writing    
};

}

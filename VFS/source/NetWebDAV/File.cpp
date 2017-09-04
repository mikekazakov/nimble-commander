#include "File.h"
#include "Internal.h"
#include "Cache.h"

namespace nc::vfs::webdav {

constexpr static const struct timeval g_SelectTimeout = {0, 10000};

File::File(const char* _relative_path, const shared_ptr<WebDAVHost> &_host):
    VFSFile(_relative_path, _host),
    m_Host(*_host)
{
}

File::~File()
{
    Close();
}

int File::Open(int _open_flags, VFSCancelChecker _cancel_checker)
{
    if( _open_flags & VFSFlags::OF_Append )
        return VFSError::FromErrno(EPERM);

    if( _open_flags & VFSFlags::OF_Read ) {
        VFSStat st;
        const auto stat_rc = m_Host.Stat(Path(), st, 0, _cancel_checker);
        if( stat_rc != VFSError::Ok )
            return stat_rc;
        
        if( !S_ISREG(st.mode) )
            return VFSError::FromErrno(EPERM);
    
        m_Size = st.size;
        m_OpenFlags = _open_flags;
        return VFSError::Ok;
    }
    if( _open_flags & VFSFlags::OF_Write ) {
        if( _open_flags & VFSFlags::OF_NoExist ) {
            VFSStat st;
            const auto stat_rc = m_Host.Stat(Path(), st, 0, _cancel_checker);
            if( stat_rc == VFSError::Ok )
                return VFSError::FromErrno(EEXIST);
        }
        m_OpenFlags = _open_flags;
        return VFSError::Ok;
    }
    return VFSError::FromErrno(EINVAL);
}

static bool SelectMulti( CURLM *_multi )
{
    struct timeval timeout = g_SelectTimeout;
    
    fd_set fdread, fdwrite, fdexcep;
    int maxfd;
    
    FD_ZERO(&fdread);
    FD_ZERO(&fdwrite);
    FD_ZERO(&fdexcep);
    curl_multi_fdset(_multi, &fdread, &fdwrite, &fdexcep, &maxfd);
    
    const auto rc = select(maxfd+1, &fdread, &fdwrite, &fdexcep, &timeout);
    return rc != -1;
}

static bool HasErrors( CURLM *_multi )
{
    bool has_error = false;
    int msgs_left = 1;
    while( msgs_left ) {
        const auto msg = curl_multi_info_read(_multi, &msgs_left);
        if( msg == nullptr ||
            msg->msg != CURLMSG_DONE ||
            msg->data.result != CURLE_OK )
            has_error = true;
    }
    return has_error;
}

ssize_t File::Read(void *_buf, size_t _size)
{
    if( !IsOpened() || !(m_OpenFlags & VFSFlags::OF_Read) )
        return VFSError::FromErrno(EINVAL);
    if( _size == 0 || Eof() )
        return 0;

    bool error = false;
    
    if( m_ReadBuffer.Size() < _size ) {
        SpawnDownloadConnectionIfNeeded();
        const auto multi = m_Conn->MultiHandle();
        
        int running_handles = 0;
        while( CURLM_CALL_MULTI_PERFORM == curl_multi_perform(multi, &running_handles) );
        
        while( m_ReadBuffer.Size() < _size && running_handles) {
            if( !SelectMulti(multi) ) {
                error = true;
                break;
            }
            while( CURLM_CALL_MULTI_PERFORM == curl_multi_perform(multi, &running_handles) );
        }

        if( running_handles == 0 )
            if( HasErrors(multi) )
                error  = true;
    }

    if( error )
        return VFSError::FromErrno(EIO);

    const auto has_read = m_ReadBuffer.Read(_buf, _size);
    m_Pos += has_read;

    return has_read;
}

ssize_t File::Write(const void *_buf, size_t _size)
{
    if( !IsOpened() ||
        !(m_OpenFlags & VFSFlags::OF_Write) ||
        m_Size < 0 )
        return VFSError::FromErrno(EINVAL);

    m_WriteBuffer.Write(_buf, _size);

    SpawnUploadConnectionIfNeeded();

    bool error = false;
    
    const auto multi = m_Conn->MultiHandle();
    int running_handles = 0;
    while( CURLM_CALL_MULTI_PERFORM == curl_multi_perform(multi, &running_handles) ) ;
    
    do  {
        if( !SelectMulti(multi) ) {
            error = true;
            break;
        }
        while( CURLM_CALL_MULTI_PERFORM == curl_multi_perform(multi, &running_handles) );
    } while( !m_WriteBuffer.Empty() && running_handles);

    if( running_handles == 0 )
        if( HasErrors(multi) )
            error  = true;

    if( error )
        return VFSError::FromErrno(EIO);

    const auto has_written = _size - m_WriteBuffer.Size();
    m_Pos += has_written;
    m_WriteBuffer.Discard( _size - has_written );

    return has_written;
}

static size_t NullWrite(void *_buffer, size_t _size, size_t _nmemb, void *_userp)
{
    return _size * _nmemb;
}

void File::SpawnUploadConnectionIfNeeded()
{
    if( m_Conn )
        return;
    
    m_Conn = m_Host.ConnectionsPool().GetRaw();
    assert(m_Conn);
    const auto curl = m_Conn->EasyHandle();
    const auto url = URIForPath(m_Host.Config(), Path());
    curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
    curl_easy_setopt(curl, CURLOPT_UPLOAD, 1L);
    curl_easy_setopt(curl, CURLOPT_READFUNCTION, WriteBuffer::Read);
    curl_easy_setopt(curl, CURLOPT_READDATA, &m_WriteBuffer);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, NullWrite);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, nullptr);
    curl_easy_setopt(curl, CURLOPT_INFILESIZE_LARGE, m_Size);
    
    m_Conn->AttachMultiHandle();
}

void File::SpawnDownloadConnectionIfNeeded()
{
    if( m_Conn )
        return;
    
    m_Conn = m_Host.ConnectionsPool().GetRaw();
    assert(m_Conn);
    const auto curl = m_Conn->EasyHandle();
    const auto url = URIForPath(m_Host.Config(), Path());
    curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
    curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, "GET");
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, ReadBuffer::Write);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &m_ReadBuffer);
    
    m_Conn->AttachMultiHandle();
}

bool File::IsOpened() const
{
    return m_OpenFlags != 0;
}

static void AbortPendingDownload(Connection &_conn)
{
    _conn.SetProgreessCallback([](long, long, long, long){
        return false;
    });
    const auto multi = _conn.MultiHandle();
    int running_handles = 0;
    do {
        while( CURLM_CALL_MULTI_PERFORM == curl_multi_perform(multi, &running_handles) );
    } while(running_handles);
}

static void ConcludePendingUpload( Connection &_conn, bool _abort)
{
    if( _abort )
        _conn.SetProgreessCallback([](long, long, long, long){
            return false;
        });

    const auto multi = _conn.MultiHandle();
    int running_handles = 0;
    while( CURLM_CALL_MULTI_PERFORM == curl_multi_perform(multi, &running_handles) );
    
    if( running_handles == 0)
        return;
    
    while( CURLM_CALL_MULTI_PERFORM == curl_multi_perform(multi, &running_handles) );
    
    while( running_handles ) {
        if( !SelectMulti( multi ) )
            break;
        while( CURLM_CALL_MULTI_PERFORM == curl_multi_perform(multi, &running_handles) );
    }
}

int File::Close()
{
    if( m_OpenFlags & VFSFlags::OF_Read ) {
        if( m_Conn ) {
            AbortPendingDownload(*m_Conn);
            m_Host.ConnectionsPool().Return( move(m_Conn) );
        }
    }
    else if( m_OpenFlags & VFSFlags::OF_Write ) {
        if( !m_Conn )
            Write("", 0);
        
        if( m_Conn ) {
            ConcludePendingUpload( *m_Conn, m_Pos < m_Size );
            m_Host.ConnectionsPool().Return( move(m_Conn) );
        }
        
        m_Conn.reset();
        
        m_Host.Cache().CommitMkFile(Path());
    }
    
    m_ReadBuffer.Clear();
    m_WriteBuffer.Clear();
    
    m_OpenFlags = 0;
    m_Pos = 0;
    m_Size = -1;
        
    return 0;
}

File::ReadParadigm File::GetReadParadigm() const
{
    return ReadParadigm::Sequential;
}

File::WriteParadigm File::GetWriteParadigm() const
{
    return WriteParadigm::Upload;
}

ssize_t File::Pos() const
{
    return m_Pos;
}

ssize_t File::Size() const
{
    return m_Size;
}

bool File::Eof() const
{
    if( !IsOpened() )
        return true;
    return m_Pos == m_Size;
}

int File::SetUploadSize(size_t _size)
{
    if( !IsOpened() || m_Size >= 0 )
        return VFSError::FromErrno(EINVAL);
    
    m_Size = _size;
    
    return VFSError::Ok;
}

}

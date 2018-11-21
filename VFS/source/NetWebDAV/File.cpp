// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "File.h"
#include "Internal.h"
#include "Cache.h"
#include "PathRoutines.h"

namespace nc::vfs::webdav {

constexpr static const struct timeval g_SelectTimeout = {0, 10000};

File::File(const char* _relative_path, const std::shared_ptr<WebDAVHost> &_host):
    VFSFile(_relative_path, _host),
    m_Host(*_host)
{
}

File::~File()
{
    Close();
}

int File::Open(unsigned long _open_flags, const VFSCancelChecker &_cancel_checker)
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

static int ErrorIfAny( CURLM *_multi )
{
    CURLMsg *msg;
    int msgs_left = 0;
    while( (msg = curl_multi_info_read(_multi, &msgs_left)) != nullptr ) {
        if( msg->msg == CURLMSG_DONE ) {
            const auto curle_rc = msg->data.result;
            if( curle_rc != CURLE_OK )
                return ToVFSError(curle_rc, 0);

            const auto http_rc = curl_easy_get_response_code(msg->easy_handle);
            if( http_rc >= 300 )
                return ToVFSError(curle_rc, http_rc);
        }
    }
    return VFSError::Ok;
}

ssize_t File::Read(void *_buf, size_t _size)
{
    if( !IsOpened() || !(m_OpenFlags & VFSFlags::OF_Read) )
        return SetLastError(VFSError::FromErrno(EINVAL));
    if( _size == 0 || Eof() )
        return 0;

    int vfs_error = VFSError::Ok;
    
    if( m_ReadBuffer.Size() < _size ) {
        SpawnDownloadConnectionIfNeeded();
        const auto multi = m_Conn->MultiHandle();
        
        int running_handles = 0;
        while( CURLM_CALL_MULTI_PERFORM == curl_multi_perform(multi, &running_handles) );
        
        while( m_ReadBuffer.Size() < _size && running_handles) {
            if( !SelectMulti(multi) ) {
                vfs_error = VFSError::FromErrno();
                break;
            }
            while( CURLM_CALL_MULTI_PERFORM == curl_multi_perform(multi, &running_handles) );
        }

        if( running_handles == 0 )
            vfs_error = ErrorIfAny(multi);
    }

    if( vfs_error != VFSError::Ok )
        return SetLastError(vfs_error);

    const auto has_read = m_ReadBuffer.Read(_buf, _size);
    m_Pos += has_read;

    return has_read;
}

ssize_t File::Write(const void *_buf, size_t _size)
{
    if( !IsOpened() ||
        !(m_OpenFlags & VFSFlags::OF_Write) ||
        m_Size < 0 )
        return SetLastError(VFSError::FromErrno(EINVAL));

    m_WriteBuffer.Write(_buf, _size);

    SpawnUploadConnectionIfNeeded();

    int vfs_error = VFSError::Ok;
    
    const auto multi = m_Conn->MultiHandle();
    int running_handles = 0;
    while( CURLM_CALL_MULTI_PERFORM == curl_multi_perform(multi, &running_handles) ) ;
    
    do  {
        if( !SelectMulti(multi) ) {
            vfs_error = VFSError::FromErrno();
            break;
        }
        while( CURLM_CALL_MULTI_PERFORM == curl_multi_perform(multi, &running_handles) );
    } while( !m_WriteBuffer.Empty() && running_handles );

    if( running_handles == 0 )
        vfs_error = ErrorIfAny(multi);

    if( vfs_error != VFSError::Ok )
        return SetLastError(vfs_error);

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

static int ConcludePendingUpload( Connection &_conn, bool _abort)
{
    if( _abort )
        _conn.SetProgreessCallback([](long, long, long, long){
            return false;
        });

    const auto multi = _conn.MultiHandle();
    int running_handles = 0;
    while( CURLM_CALL_MULTI_PERFORM == curl_multi_perform(multi, &running_handles) );
    
    if( running_handles == 0)
        return ErrorIfAny(multi);
    
    while( CURLM_CALL_MULTI_PERFORM == curl_multi_perform(multi, &running_handles) );
    
    while( running_handles ) {
        if( !SelectMulti( multi ) )
            return VFSError::FromErrno();
        while( CURLM_CALL_MULTI_PERFORM == curl_multi_perform(multi, &running_handles) );
    }
    return ErrorIfAny(multi);
}

int File::Close()
{
    if( !IsOpened() )
        return VFSError::FromErrno(EINVAL);
    
    int result = VFSError::Ok;
    
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
            result = ConcludePendingUpload( *m_Conn, m_Pos < m_Size );
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
        
    return SetLastError(result);
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
        return SetLastError(VFSError::FromErrno(EINVAL));
    
    m_Size = _size;
    
    return VFSError::Ok;
}

}

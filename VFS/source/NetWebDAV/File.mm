#include "File.h"
#include "Internal.h"

namespace nc::vfs::webdav {

constexpr static const struct timeval g_SelectTimeout = {0, 10000};

File::File(const char* _relative_path, const shared_ptr<WebDAVHost> &_host):
    VFSFile(_relative_path, _host),
    m_Host(*_host)
{
}

File::~File()
{
    // TODO: return the connection to the host

    Close();
}

int File::Open(int _open_flags, VFSCancelChecker _cancel_checker)
{
    if( _open_flags & VFSFlags::OF_Read ) {
        VFSStat st;
        const auto stat_rc = m_Host.Stat(RelativePath(), st, 0, _cancel_checker);
        if( stat_rc != VFSError::Ok )
            return stat_rc;
        
        if( !S_ISREG(st.mode) )
            return VFSError::FromErrno(EPERM);
    
        m_Size = st.size;
        m_OpenFlags = _open_flags;
    }

    return 0;
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

void File::SpawnDownloadConnectionIfNeeded()
{
    if( m_Conn )
        return;
    
    m_Conn = m_Host.ConnectionsPool().GetRaw();
    assert(m_Conn);
    const auto curl = m_Conn->EasyHandle();
    curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, "GET");
    
    const auto url = URIForPath(m_Host.Config(), RelativePath());
    curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
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

int File::Close()
{
    m_ReadBuffer.Clear();
    
    if( m_OpenFlags & VFSFlags::OF_Read ) {
        if( m_Conn ) {
            AbortPendingDownload(*m_Conn);
            m_Host.ConnectionsPool().Return( move(m_Conn) );
        }
    }
    
    m_OpenFlags = 0;
    m_Pos = 0;
    m_Size = -1;
    return 0;
}

File::ReadParadigm File::GetReadParadigm() const
{
    return ReadParadigm::Sequential;
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
    return m_Pos == m_Size;
}


}

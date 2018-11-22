// Copyright (C) 2016-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include <sys/xattr.h>
#include "xattr.h"
#include <VFS/VFSFile.h>
#include "../ListingInput.h"
#include <dirent.h>

using namespace std::literals;

namespace nc::vfs {

class XAttrFile final: public VFSFile
{
public:
    XAttrFile( const std::string &_xattr_path, const std::shared_ptr<XAttrHost> &_parent, int _fd );
    virtual int Open(unsigned long _open_flags, const VFSCancelChecker &_cancel_checker = nullptr) override;
    virtual int  Close() override;
    virtual bool IsOpened() const override;
    virtual ReadParadigm  GetReadParadigm() const override;
    virtual WriteParadigm GetWriteParadigm() const override;
    virtual ssize_t Pos() const override;
    virtual off_t Seek(off_t _off, int _basis) override;
    virtual ssize_t Size() const override;
    virtual bool Eof() const override;
    virtual ssize_t Read(void *_buf, size_t _size) override;
    virtual ssize_t ReadAt(off_t _pos, void *_buf, size_t _size) override;
    virtual ssize_t Write(const void *_buf, size_t _size) override;
    virtual int SetUploadSize(size_t _size) override;
    
private:
    const char *XAttrName() const noexcept;
    bool IsOpenedForReading() const noexcept;
    bool IsOpenedForWriting() const noexcept;
    
    const int               m_FD; // non-owning
    unsigned long           m_OpenFlags = 0;
    std::unique_ptr<uint8_t[]>m_FileBuf;
    ssize_t                 m_Position = 0;
    ssize_t                 m_Size = 0;
    ssize_t                 m_UploadSize = -1;
};

static bool is_absolute_path( const char *_s ) noexcept
{
    return _s != nullptr && _s[0] == '/';
}

static bool TurnOffBlockingMode( int _fd ) noexcept
{
    int fcntl_ret = fcntl(_fd, F_GETFL);
    if( fcntl_ret < 0 )
        return false;
    
    fcntl_ret = fcntl(_fd, F_SETFL, fcntl_ret & ~O_NONBLOCK);
    if( fcntl_ret < 0 )
        return false;
    
    return true;
}

static int EnumerateAttrs( int _fd, std::vector<std::pair<std::string, unsigned>> &_attrs )
{
    const auto buf_sz = 65536;
    char buf[buf_sz];
    auto used_size = flistxattr(_fd, buf, buf_sz, 0);
    if( used_size < 0) // need to process ERANGE later. if somebody wanna mess with 65536/XATTR_MAXNAMELEN=512 xattrs per entry...
        return VFSError::FromErrno();

    for( auto s = buf, e = buf + used_size; s < e; s += strlen(s) + 1 ) { // iterate thru xattr names..
        auto xattr_size = fgetxattr(_fd, s, nullptr, 0, 0, 0);
        if( xattr_size >= 0 )
            _attrs.emplace_back(s, xattr_size);
    }
    
    return 0;
}

const char *XAttrHost::UniqueTag = "xattr";
static const mode_t g_RegMode = S_IRUSR | S_IWUSR | S_IFREG;
static const mode_t g_RootMode = S_IRUSR | S_IXUSR | S_IFDIR;

class VFSXAttrHostConfiguration
{
public:
    VFSXAttrHostConfiguration(const std::string &_path):
        path(_path),
        verbose_junction("[xattr]:"s + _path)
    {
    }
    
    const std::string path;
    const std::string verbose_junction;
    
    const char *Tag() const
    {
        return XAttrHost::UniqueTag;
    }
    
    const char *Junction() const
    {
        return path.c_str();
    }
    
    const char *VerboseJunction() const
    {
        return verbose_junction.c_str();
    }
    
    bool operator==(const VFSXAttrHostConfiguration&_rhs) const
    {
        return path == _rhs.path;
    }
};

XAttrHost::XAttrHost( const std::string &_file_path, const VFSHostPtr& _host ):
    XAttrHost( _host,
                 VFSConfiguration( VFSXAttrHostConfiguration(_file_path) )
                 )
{
}

XAttrHost::XAttrHost(const VFSHostPtr &_parent, const VFSConfiguration &_config):
    Host( _config.Get<VFSXAttrHostConfiguration>().path.c_str(), _parent, UniqueTag ),
    m_Configuration(_config)
{
    auto path = JunctionPath();
    if( !_parent->IsNativeFS() )
        throw VFSErrorException(VFSError::InvalidCall);
    
    int fd =          open( path, O_RDONLY|O_NONBLOCK|O_EXLOCK);
    if( fd < 0 ) fd = open( path, O_RDONLY|O_NONBLOCK|O_SHLOCK);
    if( fd < 0 ) fd = open( path, O_RDONLY|O_NONBLOCK);
    if( fd < 0 )
        throw VFSErrorException( VFSError::FromErrno(EIO) );
    
    if( !TurnOffBlockingMode(fd) ) {
        close(fd);
        throw VFSErrorException( VFSError::FromErrno(EIO) );
    }
    
    if( fstat(fd, &m_Stat) != 0) {
        close(fd);
        throw VFSErrorException( VFSError::FromErrno(EIO) );
    }
    
    int ret = EnumerateAttrs( fd, m_Attrs );
    if( ret != 0) {
        close(fd);
        throw VFSErrorException(ret);
    }
    
    m_FD = fd;
}

XAttrHost::~XAttrHost()
{
    close(m_FD);
}

VFSConfiguration XAttrHost::Configuration() const
{
    return m_Configuration;
}

VFSMeta XAttrHost::Meta()
{
    VFSMeta m;
    m.Tag = UniqueTag;
    m.SpawnWithConfig = [](const VFSHostPtr &_parent, const VFSConfiguration& _config, VFSCancelChecker _cancel_checker) {
        return std::make_shared<XAttrHost>(_parent, _config);
    };
    return m;
}

bool XAttrHost::IsWritable() const
{
    return true;
}

int XAttrHost::Fetch()
{
    std::vector<std::pair<std::string, unsigned>> info;
    int ret = EnumerateAttrs(m_FD, info);
    if( ret != 0)
        return ret;
    
    std::lock_guard<spinlock> lock(m_AttrsLock);
    m_Attrs = move(info);
    return VFSError::Ok;
}

int XAttrHost::FetchDirectoryListing(const char *_path,
                                     std::shared_ptr<VFSListing> &_target,
                                     unsigned long _flags,
                                     const VFSCancelChecker &_cancel_checker)
{
    if( !_path || _path != std::string_view("/") )
        return VFSError::InvalidCall;
    
    // set up or listing structure
    ListingInput listing_source;
    listing_source.hosts[0] = shared_from_this();
    listing_source.directories[0] = "/";
    listing_source.atimes.reset( variable_container<>::type::common );
    listing_source.mtimes.reset( variable_container<>::type::common );
    listing_source.ctimes.reset( variable_container<>::type::common );
    listing_source.btimes.reset( variable_container<>::type::common );
    listing_source.sizes.reset( variable_container<>::type::dense );
    listing_source.atimes[0] = m_Stat.st_atime;
    listing_source.ctimes[0] = m_Stat.st_ctime;
    listing_source.btimes[0] = m_Stat.st_birthtime;
    listing_source.mtimes[0] = m_Stat.st_mtime;
    
    {
        std::lock_guard<spinlock> lock(m_AttrsLock);
        
        if( !(_flags & VFSFlags::F_NoDotDot) ) {
            listing_source.filenames.emplace_back( ".." );
            listing_source.unix_types.emplace_back( DT_DIR );
            listing_source.unix_modes.emplace_back( g_RootMode );
            listing_source.sizes.insert( 0, ListingInput::unknown_size );
        }
        
        for( const auto &i: m_Attrs ) {
            listing_source.filenames.emplace_back( i.first );
            listing_source.unix_types.emplace_back( DT_REG );
            listing_source.unix_modes.emplace_back( g_RegMode );
            listing_source.sizes.insert( listing_source.filenames.size()-1, i.second );
        }
    }
    
    _target = VFSListing::Build(std::move(listing_source));
    return VFSError::Ok;
}

int XAttrHost::Stat(const char *_path, VFSStat &_st, unsigned long _flags, const VFSCancelChecker &_cancel_checker)
{
    if( !is_absolute_path(_path) )
        return VFSError::NotFound;

    memset(&_st, sizeof(_st), 0);
    _st.meaning.size = true;
    _st.meaning.mode = true;
    _st.meaning.atime = true;
    _st.meaning.btime = true;
    _st.meaning.ctime = true;
    _st.meaning.mtime = true;
    _st.atime = m_Stat.st_atimespec;
    _st.mtime = m_Stat.st_mtimespec;
    _st.btime = m_Stat.st_birthtimespec;
    _st.ctime = m_Stat.st_ctimespec;
    
    auto path = std::string_view(_path);
    if( path == "/" ) {
        _st.mode = g_RootMode;
        _st.size = 0;
        return VFSError::Ok;
    }
    else if( path.length() > 1 ) {
        path.remove_prefix(1);    
        for( auto &i: m_Attrs )
            if( path == i.first ) {
                _st.mode = g_RegMode;
                _st.size = i.second;
                return 0;
            }
    }
    
    return VFSError::FromErrno(ENOENT);
}

int XAttrHost::CreateFile(const char* _path,
                          std::shared_ptr<VFSFile> &_target,
                          const VFSCancelChecker &_cancel_checker)
{
    auto file = std::make_shared<XAttrFile>(_path,
                                            std::static_pointer_cast<XAttrHost>(shared_from_this()), m_FD);
    if(_cancel_checker && _cancel_checker())
        return VFSError::Cancelled;
    _target = file;
    return VFSError::Ok;
}

int XAttrHost::Unlink(const char *_path, const VFSCancelChecker &_cancel_checker)
{
    if( !_path || _path[0] != '/' )
        return VFSError::FromErrno(ENOENT);
    
    if( fremovexattr(m_FD, _path+1, 0) == -1 )
        return VFSError::FromErrno();
    
    ReportChange();
    
    return VFSError::Ok;
}

int XAttrHost::Rename(const char *_old_path, const char *_new_path, const VFSCancelChecker &_cancel_checker)
{
    if( !_old_path || _old_path[0] != '/' ||
        !_new_path || _new_path[0] != '/' )
        return VFSError::FromErrno(ENOENT);
    
    const auto old_path = _old_path+1;
    const auto new_path = _new_path+1;
    
    const auto xattr_size = fgetxattr(m_FD, old_path, nullptr, 0, 0, 0);
    if( xattr_size < 0 )
        return VFSError::FromErrno();
    
    const auto buf = std::make_unique<uint8_t[]>(xattr_size);
    if( fgetxattr(m_FD, old_path, buf.get(), xattr_size, 0, 0) < 0 )
        return VFSError::FromErrno();
    
    if( fsetxattr(m_FD, new_path, buf.get(), xattr_size, 0, 0) < 0 )
        return VFSError::FromErrno();
    
    if( fremovexattr(m_FD, old_path, 0) < 0 )
        return VFSError::FromErrno();
    
    ReportChange();
    
    return VFSError::Ok;
}

void XAttrHost::ReportChange()
{
    Fetch();

    // observers
}

// hardly needs own version of this, since xattr will happily work with abra:cadabra filenames
//bool VFSHost::ValidateFilename(const char *_filename) const


XAttrFile::XAttrFile(const std::string &_xattr_path,
                     const std::shared_ptr<XAttrHost> &_parent,
                     int _fd ):
    VFSFile(_xattr_path.c_str(), _parent),
    m_FD(_fd)
{
}

int XAttrFile::Open(unsigned long _open_flags, const VFSCancelChecker &_cancel_checker)
{
    if( IsOpened() )
        return VFSError::InvalidCall;
    
    Close();

    const auto path = XAttrName();
    if( !path )
        return VFSError::FromErrno(ENOENT);
    
    if( _open_flags & VFSFlags::OF_Write ) {
        if( _open_flags & VFSFlags::OF_Append )
            return VFSError::NotSupported;
        // TODO: OF_NoExist
        
        m_OpenFlags = _open_flags;
    }
    else if( _open_flags & VFSFlags::OF_Read ) {
        auto xattr_size = fgetxattr(m_FD, path, nullptr, 0, 0, 0);
        if( xattr_size < 0 )
            return VFSError::FromErrno(ENOENT);
    
        m_FileBuf = std::make_unique<uint8_t[]>(xattr_size);
        if( fgetxattr(m_FD, path, m_FileBuf.get(), xattr_size, 0, 0) < 0 )
            return VFSError::FromErrno();
        
        m_Size = xattr_size;
        m_OpenFlags = _open_flags;
    }
    
    return VFSError::Ok;
}

int XAttrFile::Close()
{
    m_Size = 0;
    m_FileBuf.reset();
    m_OpenFlags = 0;
    m_Position = 0;
    m_UploadSize = -1;
    return 0;
}

bool XAttrFile::IsOpened() const
{
    return m_OpenFlags != 0;
}

VFSFile::ReadParadigm XAttrFile::GetReadParadigm() const
{
    return VFSFile::ReadParadigm::Random;
}

VFSFile::WriteParadigm XAttrFile::GetWriteParadigm() const
{
    return VFSFile::WriteParadigm::Upload;
}

ssize_t XAttrFile::Pos() const
{
    return m_Position;
}

ssize_t XAttrFile::Size() const
{
    return m_Size;
}

bool XAttrFile::Eof() const
{
    return m_Position >= m_Size;
}

off_t XAttrFile::Seek(off_t _off, int _basis)
{
    if(!IsOpened())
        return VFSError::InvalidCall;
    
    if( !IsOpenedForReading() )
        return VFSError::InvalidCall;
        
    off_t req_pos = 0;
    if(_basis == VFSFile::Seek_Set)
        req_pos = _off;
    else if(_basis == VFSFile::Seek_End)
        req_pos = m_Size + _off;
    else if(_basis == VFSFile::Seek_Cur)
        req_pos = m_Position + _off;
    else
        return VFSError::InvalidCall;
    
    if(req_pos < 0)
        return VFSError::InvalidCall;
    if(req_pos > m_Size)
        req_pos = m_Size;
    m_Position = req_pos;
    
    return m_Position;
}

ssize_t XAttrFile::Read(void *_buf, size_t _size)
{
    if( !IsOpened() || !IsOpenedForReading() )
        return SetLastError(VFSError::InvalidCall);

    if( m_Position == m_Size )
        return 0;
    
    ssize_t to_read = std::min( m_Size - m_Position, ssize_t(_size) );
    if( to_read <= 0 )
        return 0;
    
    memcpy( _buf, m_FileBuf.get() + m_Position, to_read );
    m_Position += to_read;
    
    return to_read;
}

ssize_t XAttrFile::ReadAt(off_t _pos, void *_buf, size_t _size)
{
    if( !IsOpened() || !IsOpenedForReading() )
        return SetLastError(VFSError::InvalidCall);
    
    if( _pos < 0 || _pos > m_Size )
        return SetLastError( VFSError::FromErrno(EINVAL) );
    
    auto sz = std::min( m_Size - _pos, off_t(_size) );
    memcpy(_buf, m_FileBuf.get() + _pos, sz );
    return sz;
}

bool XAttrFile::IsOpenedForReading() const noexcept
{
    return m_OpenFlags & VFSFlags::OF_Read;
}

bool XAttrFile::IsOpenedForWriting() const noexcept
{
    return m_OpenFlags & VFSFlags::OF_Write;
}

int XAttrFile::SetUploadSize(size_t _size)
{
    if( !IsOpenedForWriting() )
        return VFSError::FromErrno( EINVAL );
    
    if( m_UploadSize >= 0 )
        return VFSError::FromErrno( EINVAL ); // already reported before
    
    // TODO: check max xattr size and reject huge ones

    m_UploadSize = _size;
    m_FileBuf = std::make_unique<uint8_t[]>(_size);
    
    if( _size == 0 ) {
        // for zero-size uploading - do it right here        
        char buf[1];
        if( fsetxattr(m_FD, XAttrName(), buf, 0, 0, 0) != 0 )
            return VFSError::FromErrno();
        
        std::dynamic_pointer_cast<XAttrHost>(Host())->ReportChange();
    }
    
    return 0;
}

ssize_t XAttrFile::Write(const void *_buf, size_t _size)
{
    if( !IsOpenedForWriting() ||
        !m_FileBuf )
        return VFSError::FromErrno(EIO);
    
    if( m_Position < m_UploadSize ) {
        ssize_t to_write = std::min( m_UploadSize - m_Position, (ssize_t)_size );
        memcpy( m_FileBuf.get() + m_Position, _buf, to_write );
        m_Position += to_write;
        
        if( m_Position == m_UploadSize ) {
            // time to flush

            if( fsetxattr(m_FD, XAttrName(), m_FileBuf.get(), m_UploadSize, 0, 0) != 0 )
                return VFSError::FromErrno();
            
            std::dynamic_pointer_cast<XAttrHost>(Host())->ReportChange();
        }
        return to_write;
    }
    return 0;
}

const char *XAttrFile::XAttrName() const noexcept
{
    const char *path = Path();
    if( path[0] != '/' )
        return nullptr;
    return path + 1;
}

}

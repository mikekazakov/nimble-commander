#include <sys/xattr.h>
#include "xattr.h"
#include "../VFSNativeHost.h"

//The maximum supported size of extended attribute can be found out using pathconf(2) with
//_PC_XATTR_SIZE_BITS option.

//// get current file descriptor's open flags
//{


///* Options for pathname based xattr calls */
//#define XATTR_NOFOLLOW   0x0001     /* Don't follow symbolic links */
//
///* Options for setxattr calls */
//#define XATTR_CREATE     0x0002     /* set the value, fail if attr already exists */
//#define XATTR_REPLACE    0x0004     /* set the value, fail if attr does not exist */
//
///* Set this to bypass authorization checking (eg. if doing auth-related work) */
//#define XATTR_NOSECURITY 0x0008
//
///* Set this to bypass the default extended attribute file (dot-underscore file) */
//#define XATTR_NODEFAULT  0x0010
//
///* option for f/getxattr() and f/listxattr() to expose the HFS Compression extended attributes */
//#define XATTR_SHOWCOMPRESSION 0x0020
//
//#define	XATTR_MAXNAMELEN   127
//
///* See the ATTR_CMN_FNDRINFO section of getattrlist(2) for details on FinderInfo */
//#define	XATTR_FINDERINFO_NAME	  "com.apple.FinderInfo"
//
//#define	XATTR_RESOURCEFORK_NAME	  "com.apple.ResourceFork"
//ssize_t getxattr(const char *path, const char *name, void *value, size_t size, u_int32_t position, int options);
//ssize_t fgetxattr(int fd, const char *name, void *value, size_t size, u_int32_t position, int options);
//int setxattr(const char *path, const char *name, const void *value, size_t size, u_int32_t position, int options);
//int fsetxattr(int fd, const char *name, const void *value, size_t size, u_int32_t position, int options);
//int removexattr(const char *path, const char *name, int options);
//int fremovexattr(int fd, const char *name, int options);
//ssize_t listxattr(const char *path, char *namebuff, size_t size, int options);
//ssize_t flistxattr(int fd, char *namebuff, size_t size, int options);

//    if( !_path || _path[0] != '/' )
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

//void FileCopyOperationJobNew::CopyXattrsFromNativeFDToNativeFD(int _fd_from, int _fd_to) const
//{
//    auto xnames = (char*)m_Buffers[0].get();
//    auto xdata = m_Buffers[1].get();
//    auto xnamesizes = flistxattr(_fd_from, xnames, m_BufferSize, 0);
//    for( auto s = xnames, e = xnames + xnamesizes; s < e; s += strlen(s) + 1 ) { // iterate thru xattr names..
//        auto xattrsize = fgetxattr(_fd_from, s, xdata, m_BufferSize, 0, 0); // and read all these xattrs
//        if( xattrsize >= 0 ) // xattr can be zero-length, just a tag itself
//            fsetxattr(_fd_to, s, xdata, xattrsize, 0, 0); // write them into _fd_to
//    }
//}


static int EnumerateAttrs( int _fd, vector<pair<string, unsigned>> &_attrs )
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
//        cout << s << ": " << xattr_size << endl;
        
    }
    
    return 0;
}

//static int aa = []{
//    VFSXAttrHost h("/users/migun/car4.jpg", VFSNativeHost::SharedHost());
//    
//    
//    return 0;
//}();

VFSXAttrHost::VFSXAttrHost( const string &_file_path, const VFSHostPtr& _host ):
    VFSHost( _file_path.c_str(), _host )
{
    if( !_host->IsNativeFS() )
        throw VFSErrorException(VFSError::InvalidCall);

    int fd = open( _file_path.c_str(), O_RDONLY|O_NONBLOCK|O_SHLOCK);
    if( fd < 0 )
        fd = open( _file_path.c_str(), O_RDONLY|O_NONBLOCK);
    if( fd < 0 )
        throw VFSErrorException( VFSError::FromErrno(EIO) );
    
    if( !TurnOffBlockingMode(fd) ) {
        close(fd);
        throw VFSErrorException( VFSError::FromErrno(EIO) );
    }
//    vector< pair<string, unsigned>> attrs;
//    EnumerateAttrs( fd, attrs );
    
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

VFSXAttrHost::~VFSXAttrHost()
{
    close(m_FD);
}

int VFSXAttrHost::FetchFlexibleListing(const char *_path,
                                       shared_ptr<VFSFlexibleListing> &_target,
                                       int _flags,
                                       VFSCancelChecker _cancel_checker)
{
    if( !_path || _path != string_view("/") )
        return VFSError::InvalidCall;
    
    // set up or listing structure
    VFSFlexibleListingInput listing_source;
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
    
    vector< pair<string, unsigned>> attrs;
    int ret = EnumerateAttrs( m_FD, attrs );
    if( ret != 0)
        return ret;

    for( auto &i: attrs ) {
        listing_source.filenames.emplace_back( move(i.first) );
        listing_source.unix_types.emplace_back( DT_REG );
        listing_source.unix_modes.emplace_back( S_IRUSR | S_IWUSR | S_IFREG );
        listing_source.sizes.insert( listing_source.filenames.size()-1, i.second );
    }
    
    _target = VFSFlexibleListing::Build(move(listing_source));
    return VFSError::Ok;
}

int VFSXAttrHost::Stat(const char *_path, VFSStat &_st, int _flags, VFSCancelChecker _cancel_checker)
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
    
    auto path = string_view(_path);
    if( path == "/" ) {
        _st.mode = S_IRUSR | S_IXUSR | S_IFDIR;
        _st.size = 0;
        return VFSError::Ok;
    }
    else if( path.length() > 1 ) {
        path.remove_prefix(1);    
        for( auto &i: m_Attrs )
            if( path == i.first ) {
                _st.mode = S_IRUSR | S_IXUSR | S_IFREG;
                _st.size = i.second;
                return 0;
            }
    }
    
    return VFSError::FromErrno(ENOENT);
}

int VFSXAttrHost::CreateFile(const char* _path,
                             shared_ptr<VFSFile> &_target,
                             VFSCancelChecker _cancel_checker)
{
    auto file = make_shared<VFSXAttrFile>(_path, static_pointer_cast<VFSXAttrHost>(shared_from_this()), m_FD);
    if(_cancel_checker && _cancel_checker())
        return VFSError::Cancelled;
    _target = file;
    return VFSError::Ok;
}


// hardly needs own version of this, since xattr will happily work with abra:cadabra filenames
//bool VFSHost::ValidateFilename(const char *_filename) const


VFSXAttrFile::VFSXAttrFile( const string &_xattr_path, const shared_ptr<VFSXAttrHost> &_parent, int _fd ):
    VFSFile(_xattr_path.c_str(), _parent),
    m_FD(_fd),
    m_OpenFlags(0),
    m_Size(0),
    m_Position(0)
{
}

int VFSXAttrFile::Open(int _open_flags, VFSCancelChecker _cancel_checker)
{
//    OF_IXOth    = 0x00000001, // = S_IXOTH
//    OF_IWOth    = 0x00000002, // = S_IWOTH
//    OF_IROth    = 0x00000004, // = S_IROTH
//    OF_IXGrp    = 0x00000008, // = S_IXGRP
//    OF_IWGrp    = 0x00000010, // = S_IWGRP
//    OF_IRGrp    = 0x00000020, // = S_IRGRP
//    OF_IXUsr    = 0x00000040, // = S_IXUSR
//    OF_IWUsr    = 0x00000080, // = S_IWUSR
//    OF_IRUsr    = 0x00000100, // = S_IRUSR
//    OF_Read     = 0x00010000,
//    OF_Write    = 0x00020000,
//    OF_Create   = 0x00040000,
//    OF_NoExist  = 0x00080000, // POSIX O_EXCL actucally, for clarity
//    OF_ShLock   = 0x00100000, // not yet implemented
//    OF_ExLock   = 0x00200000, // not yet implemented
//    OF_NoCache  = 0x00400000, // turns off caching if supported
//    OF_Append   = 0x00800000, // appends file on writing
//    OF_Truncate = 0x01000000, // truncates files upon opening
//    
//    // Flags altering host behaviour
//    /** do not follow symlinks when resolving item name */
//    F_NoFollow  = 0x02000000,
//    
//    // Flags altering listing building
//    /** for listing. don't fetch dot-dot entry in directory listing */
//    F_NoDotDot  = 0x04000000,
//    /** for listing. ask system to provide localized display names */
//    F_LoadDisplayNames  = 0x08000000
    if( IsOpened() )
        return VFSError::InvalidCall;
    
    if( _open_flags & VFSFlags::OF_Write )
        return VFSError::NotSupported;
    
    if( _open_flags & VFSFlags::OF_Read ) {
        string path = RelativePath();
        if( path.length() <= 1 )
            return VFSError::FromErrno(ENOENT);
        path.erase(0, 1);
        
        auto xattr_size = fgetxattr(m_FD, path.c_str(), nullptr, 0, 0, 0);
        if( xattr_size < 0 )
            return VFSError::FromErrno(ENOENT);
    
        m_FileBuf = make_unique<uint8_t[]>(xattr_size);
        if( fgetxattr(m_FD, path.c_str(), m_FileBuf.get(), xattr_size, 0, 0) < 0 )
            return VFSError::FromErrno();
        
        m_Size = xattr_size;
        m_OpenFlags = _open_flags;
    }
    
    return VFSError::Ok;
}

bool VFSXAttrFile::IsOpened() const
{
    return m_OpenFlags != 0;
}

VFSFile::ReadParadigm VFSXAttrFile::GetReadParadigm() const
{
    return VFSFile::ReadParadigm::Random;
}

ssize_t VFSXAttrFile::Pos() const
{
    return m_Position;
}

ssize_t VFSXAttrFile::Size() const
{
    return m_Size;
}

bool VFSXAttrFile::Eof() const
{
    return m_Position >= m_Size;
}

ssize_t VFSXAttrFile::ReadAt(off_t _pos, void *_buf, size_t _size)
{
    if( !IsOpened() )
        return SetLastError(VFSError::InvalidCall);
    
    if( _pos < 0 || _pos > m_Size )
        return SetLastError( VFSError::FromErrno(EINVAL) );
    
    auto sz = min( m_Size - _pos, off_t(_size) );
    memcpy(_buf, m_FileBuf.get() + _pos, sz);
    return sz;
}

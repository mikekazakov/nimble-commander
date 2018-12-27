// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "TemporaryFileStorageImpl.h"
#include <Utility/PathManip.h>
#include <unistd.h>
#include <sys/stat.h>
#include <exception>

namespace nc::utility {

static bool CheckRWAccess(const std::string &_path);
static bool CheckExistence(const std::string &_path);
static std::string MakeRandomFilename();

TemporaryFileStorageImpl::TemporaryFileStorageImpl(std::string_view _base_directory,
                                                   std::string_view _sub_directories_prefix):
    m_BaseDirectory{ EnsureTrailingSlash( std::string{_base_directory} ) },
    m_SubDirectoriesPrefix{ _sub_directories_prefix }
{
    if( CheckRWAccess(m_BaseDirectory) == false )
        throw std::invalid_argument("TemporaryFileStorageImpl: can't access the base directory");
    if( m_SubDirectoriesPrefix.empty() )
        throw std::invalid_argument("TemporaryFileStorageImpl: empty sub directories prefix");
}

std::optional<std::string> TemporaryFileStorageImpl::MakeDirectory( std::string_view _filename )
{
    const auto filename = _filename.empty() ? MakeRandomFilename() : std::string(_filename);
    
    auto temp_dir = FindTempDir( filename );
    if( temp_dir == std::nullopt )
        return std::nullopt;
    
    auto result_filepath = std::move( *temp_dir );
    result_filepath += filename;
    result_filepath += '/';
    if( mkdir(result_filepath.c_str(), S_IRWXU) != 0 )
        return {};
    
    return std::make_optional(result_filepath);
}

std::optional<TemporaryFileStorageImpl::OpenedFile>
    TemporaryFileStorageImpl::OpenFile( std::string_view _filename )
{
    const auto filename = _filename.empty() ? MakeRandomFilename() : std::string(_filename);
    
    auto temp_dir = FindTempDir( filename );
    if( temp_dir == std::nullopt )
        return std::nullopt;
    
    auto result_filepath = std::move( *temp_dir );
    result_filepath += filename;
    
    int fd = open(result_filepath.c_str(),
                  O_EXLOCK|O_NONBLOCK|O_RDWR|O_CREAT|O_EXCL,
                  S_IRUSR|S_IWUSR);
    if( fd < 0 )
        return std::nullopt;
    fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) & ~O_NONBLOCK);
    
    OpenedFile opened_file;
    opened_file.path = std::move(result_filepath);
    opened_file.file_descriptor = fd;
    return std::make_optional( std::move(opened_file) );
}

std::optional<std::string> TemporaryFileStorageImpl::SpawnNewTempDir() const
{
    auto pattern_buffer = m_BaseDirectory + m_SubDirectoriesPrefix + "XXXXXX";
    if( mkdtemp(pattern_buffer.data()) != nullptr ) {
        pattern_buffer += '/';
        return std::make_optional( std::move(pattern_buffer) );
    }
    else {
        return std::nullopt;
    }
}

std::optional<std::string> TemporaryFileStorageImpl::
    FindSuitableExistingTempDir( std::string_view _for_filename )
{
    if( _for_filename.empty() )
        return {};
    
    std::lock_guard guard{m_TempDirectoriesLock};
    std::vector<int> indices_to_remove;
    std::string chosen_dir;
    
    // traverse each temp dir to check if this entry is already in there
    for( int i = 0, e = (int)m_TempDirectories.size(); i != e; ++i ) {
        auto &directory = m_TempDirectories[i];
        if( CheckRWAccess( directory ) == false ) {
            // either this directory was purged or tampered in some other way - so remove it
            indices_to_remove.push_back(i);
            continue;
        }
        auto full_path = directory;
        full_path += _for_filename;
        if( CheckExistence( full_path ) == false  ) {
            // there's no such entry in this directory - use this one then
            chosen_dir = directory;
            break;
        }
    }
    
    // purge rotten directories - erase backwards to simpify indices tracking
    for( int i = ((int)indices_to_remove.size()) - 1; i >= 0; --i ) {
        m_TempDirectories.erase( std::next(m_TempDirectories.begin(), i) );
    }
    
    if( chosen_dir.empty() )
        return std::nullopt;
    else
        return std::make_optional( std::move(chosen_dir) );
}
    
std::optional<std::string> TemporaryFileStorageImpl::FindTempDir( std::string_view _for_filename )
{
    auto existing = FindSuitableExistingTempDir(_for_filename);
    if( existing ) {
        // just use some existing temp directory
        return existing;
    }
    
    auto new_dir = SpawnNewTempDir();
    if( new_dir == std::nullopt ) {
        // can't allocate a new temp directory - something is very broken at this moment
        return {};
    }
    
    // memorize this new temp dir for later usage
    std::lock_guard guard{m_TempDirectoriesLock};
    m_TempDirectories.emplace_back( *new_dir );
    
    return new_dir;
}

static bool CheckRWAccess(const std::string &_path)
{
    return access(_path.c_str(), R_OK|W_OK) == 0;
}
    
static bool CheckExistence(const std::string &_path)
{
    return access(_path.c_str(), F_OK) == 0;
}
    
static std::string MakeRandomFilename()
{
    // TODO: write something more reasonable
    std::string filename;
    for(int i = 0; i < 6; ++i)
        filename += 'A' + rand() % ('Z'-'A');
    return filename;
}
    
}

// Copyright (C) 2018-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "TemporaryFileStorageImpl.h"
#include <Utility/PathManip.h>
#include <Habanero/algo.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/fcntl.h>
#include <sys/dirent.h>
#include <dirent.h>
#include <exception>
#include <ftw.h>

namespace nc::utility {
    
using namespace std::literals;

static bool CheckRWAccess(const std::string &_path);
static bool CheckExistence(const std::string &_path);
static std::string MakeRandomFilename();
static int RMRF(const std::string& _path);

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
    
void TemporaryFileStorageImpl::Purge( time_t _older_than )
{
    const auto directories = FindExistingTempDirectories();
    for( const auto &directory: directories ) {
        if( PurgeSubDirectory(directory, _older_than) == true )
            RMRF(directory);
    }
}
    
std::vector<std::string> TemporaryFileStorageImpl::FindExistingTempDirectories() const
{
    const auto directory = opendir( m_BaseDirectory.c_str() );
    if( directory == nullptr )
        return {};
    const auto close_directory = at_scope_end([=]{ closedir(directory); });

    std::vector<std::string> directories;
    const auto &prefix = m_SubDirectoriesPrefix;
    dirent *entry = nullptr;
    while( (entry = readdir(directory)) != nullptr ) {
        if( entry->d_type != DT_DIR )
            continue;
        if( entry->d_namlen <= prefix.length() ||
            strncmp(entry->d_name, prefix.c_str(), prefix.length()) != 0 )
            continue;
        
        directories.emplace_back( m_BaseDirectory + entry->d_name + "/" );
    }
    
    return directories;
}
    
bool TemporaryFileStorageImpl::PurgeSubDirectory(const std::string &_path, time_t _older_than)
{
    const auto directory = opendir( _path.c_str() );
    if( directory == nullptr )
        return true;
    const auto close_directory = at_scope_end([=]{ closedir(directory); });

    dirent *entry = nullptr;
    auto entries_left = 0;
    while( (entry = readdir(directory)) != nullptr ) {
        if( entry->d_name == "."sv  || entry->d_name ==  ".."sv )
            continue;
     
        ++entries_left;
        
        const auto entry_path = _path + entry->d_name;
        struct stat st;
        if( lstat(entry_path.c_str(), &st) != 0 )
            continue;
            
        if( st.st_mtime >= _older_than )
            continue;
        
        if( S_ISREG(st.st_mode) ) {
            if( unlink(entry_path.c_str()) == 0 )
                --entries_left;
        }
        else if( S_ISDIR(st.st_mode) ) {
            if( RMRF(entry_path) == 0 )
                --entries_left;
        }
    }
    
    return entries_left == 0;
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
    
static int RMRF(const std::string& _path)
{
    auto unlink_cb = [](const char *fpath,
                        [[maybe_unused]] const struct stat *sb,
                        int typeflag,
                        [[maybe_unused]] struct FTW *ftwbuf) {
        if( typeflag == FTW_F ||
            typeflag == FTW_SL ||
            typeflag == FTW_SLN )
            return unlink(fpath);
        else if( typeflag == FTW_D   ||
                 typeflag == FTW_DNR ||
                 typeflag == FTW_DP   )
            return rmdir(fpath);
        return -1;
    };
    return nftw(_path.c_str(), unlink_cb, 64, FTW_DEPTH | FTW_PHYS | FTW_MOUNT);
}
    
}

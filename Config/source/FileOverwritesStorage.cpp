#include "FileOverwritesStorage.h"
#include <sys/stat.h>
#include <unistd.h>
#include <fstream>
#include <Habanero/CommonPaths.h>

namespace nc::config {

static std::optional<std::string> Load(const std::string &_filepath);
static time_t ModificationTime(const std::string &_filepath);
static bool AtomicallyWriteToFile(const std::string &_file_pathname, std::string_view _data);
    
FileOverwritesStorage::FileOverwritesStorage(std::string_view _file_path):
    m_Path(_file_path)
{
}
    
std::optional<std::string> FileOverwritesStorage::Read() const
{
    return Load(m_Path);
}

void FileOverwritesStorage::Write(std::string_view _overwrites_json)
{        
    AtomicallyWriteToFile(m_Path, _overwrites_json);
}

void FileOverwritesStorage::SetExternalChangeCallback( std::function<void()> _callback )
{
        
}

static std::optional<std::string> Load(const std::string &_filepath)
{
    std::ifstream in( _filepath, std::ios::in | std::ios::binary);
    if( !in )
        return std::nullopt;        
        
    std::string contents;
    in.seekg( 0, std::ios::end );
    contents.resize( in.tellg() );
    in.seekg( 0, std::ios::beg );
    in.read( &contents[0], contents.size() );
    in.close();
    return contents;
}

[[maybe_unused]] static time_t ModificationTime( const std::string &_filepath )
{
    struct stat st;
    if( stat( _filepath.c_str(), &st ) == 0 )
        return st.st_mtime;
    return 0;
}

static bool AtomicallyWriteToFile( const std::string &_file_pathname, std::string_view _data )
{
    if( _file_pathname.empty() )
        return false;

    char filename_temp[1024]; // this will not crash, right?
    sprintf(filename_temp, "%sXXXXXX", CommonPaths::AppTemporaryDirectory().c_str());
    
    const auto fd = mkstemp(filename_temp);
    if( fd < 0 )
        return false;
    
    const auto file = fdopen(fd, "wb");
    const auto length = _data.length();
    const auto successful = fwrite(_data.data(), 1, length, file) == length;
    fclose(file);

    if( !successful ) {
        unlink(filename_temp);
        return false;
    }
    
    if( rename(filename_temp, _file_pathname.c_str()) == 0 ) {
        return true;
    }
    else {
        unlink(filename_temp);
        return false;        
    }
}
    
}

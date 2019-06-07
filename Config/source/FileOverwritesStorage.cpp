// Copyright (C) 2018-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "FileOverwritesStorage.h"
#include <sys/stat.h>
#include <unistd.h>
#include <fstream>
#include <Habanero/CommonPaths.h>
#include <Utility/FSEventsDirUpdate.h>
#include <boost/filesystem.hpp>

namespace nc::config {

using utility::FSEventsDirUpdate;
static std::optional<std::string> Load(const std::string &_filepath);
static time_t ModificationTime(const std::string &_filepath);
static bool AtomicallyWriteToFile(const std::string &_file_pathname, std::string_view _data);
    
FileOverwritesStorage::FileOverwritesStorage(std::string_view _file_path):
    m_Path(_file_path)
{
    auto parent_path = boost::filesystem::path{std::string{_file_path}}.parent_path();
    m_DirObservationTicket = FSEventsDirUpdate::Instance().AddWatchPath(parent_path.c_str(),
                                                                        [this]{
        OverwritesDirChanged(); 
    });
}

FileOverwritesStorage::~FileOverwritesStorage()
{
    FSEventsDirUpdate::Instance().RemoveWatchPathWithTicket(m_DirObservationTicket);
}
    
std::optional<std::string> FileOverwritesStorage::Read() const
{
    auto file_contents = Load(m_Path); 
    if( file_contents ) {
        m_OverwritesTime = ModificationTime(m_Path);
    }
    
    return file_contents;
}

void FileOverwritesStorage::Write(std::string_view _overwrites_json)
{        
    if( AtomicallyWriteToFile(m_Path, _overwrites_json) ) {
        m_OverwritesTime = ModificationTime(m_Path);
    }
}

void FileOverwritesStorage::SetExternalChangeCallback( std::function<void()> _callback )
{
    m_OnChange = std::move(_callback);
}
    
void FileOverwritesStorage::OverwritesDirChanged()
{
    const auto current_time = ModificationTime(m_Path);
    if( current_time != m_OverwritesTime ) {
        m_OverwritesTime = current_time;
        if( m_OnChange )
            m_OnChange();
    }
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

static time_t ModificationTime( const std::string &_filepath )
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

    auto filename_temp = CommonPaths::AppTemporaryDirectory() + "XXXXXX"; 
        
    const auto fd = mkstemp(filename_temp.data());
    if( fd < 0 )
        return false;
    
    const auto file = fdopen(fd, "wb");
    const auto length = _data.length();
    const auto successful = fwrite(_data.data(), 1, length, file) == length;
    fclose(file);

    if( !successful ) {
        unlink(filename_temp.c_str());
        return false;
    }
    
    if( rename(filename_temp.c_str(), _file_pathname.c_str()) == 0 ) {
        return true;
    }
    else {
        unlink(filename_temp.c_str());
        return false;        
    }
}
    
}

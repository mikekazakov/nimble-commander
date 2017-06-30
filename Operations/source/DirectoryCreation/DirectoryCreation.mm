#include "DirectoryCreation.h"
#include "DirectoryCreationJob.h"
#include <boost/algorithm/string/split.hpp>
#include "../Internal.h"

namespace nc::ops {

static vector<string> Split( const string &_directory );

DirectoryCreation::DirectoryCreation( string _directory_name, string _root_folder, VFSHost &_vfs )
{
    m_Directories = Split(_directory_name);
    m_Job.reset( new DirectoryCreationJob{m_Directories, _root_folder, _vfs.shared_from_this()} );
 
    const auto title = [NSString localizedStringWithFormat:
        NSLocalizedStringFromTableInBundle(@"Creating a directory \u201c%@\u201d",
                                           @"Localizable.strings",
                                           Bundle(),
                                           "Creating a directory \u201c%@\u201d"),
                [NSString stringWithUTF8StdString:_directory_name]];
    SetTitle(title.UTF8String);
}

DirectoryCreation::~DirectoryCreation()
{
    Wait();
}

Job *DirectoryCreation::GetJob() noexcept
{
    return m_Job.get();
}

const vector<string> &DirectoryCreation::DirectoryNames() const
{
    return m_Directories;
}

static vector<string> Split( const string &_directory )
{
    vector<string> parts;
    boost::split( parts, _directory, [](char _c){ return _c == '/';}, boost::token_compress_on );
    parts.erase( remove( begin(parts), end(parts), ""s), end(parts));
    return parts;
}



}

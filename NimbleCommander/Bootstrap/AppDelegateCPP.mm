#include <Utility/PathManip.h>
#include "../../3rd_Party/NSFileManagerDirectoryLocations/NSFileManager+DirectoryLocations.h"
#include "AppDelegate.h"
#include "AppDelegateCPP.h"

const string &AppDelegateCPP::ConfigDirectory()
{
    return AppDelegate.me.configDirectory;
}

const string &AppDelegateCPP::StateDirectory()
{
    return AppDelegate.me.stateDirectory;
}

const string &AppDelegateCPP::SupportDirectory()
{
    if( AppDelegate.me )
        return AppDelegate.me.supportDirectory;
    
    static string support_dir = EnsureTrailingSlash( NSFileManager.defaultManager.applicationSupportDirectory.fileSystemRepresentationSafe );
    return support_dir;
}

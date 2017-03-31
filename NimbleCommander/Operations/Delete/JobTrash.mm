#include <sys/stat.h>
#include "Job.h"

int FileDeletionOperationJobNew::TrashItem(const string& _path, uint16_t _mode)
{
    CFURLRef url = CFURLCreateFromFileSystemRepresentation(0, (const UInt8*)_path.c_str(), _path.length(), S_ISDIR(_mode));
    if( !url )
        return VFSError::FromErrno(EINVAL);
    
    NSError *error;
    bool result = [NSFileManager.defaultManager trashItemAtURL:(__bridge NSURL*)url
                                              resultingItemURL:nil
                                                         error:&error];
    CFRelease(url);
    
    if(result)
        return VFSError::Ok;
    else
        return VFSError::FromNSError(error);
}

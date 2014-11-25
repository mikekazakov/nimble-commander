//
//  path_manip.h
//  Files
//
//  Created by Michael G. Kazakov on 24.10.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Converts path like "/Dir/Abra/" to "/Dir/Abra".
 * Will preserve "/" as "/".
 * Will return false on NULL and on empty paths and on paths not starting with slash.
 */
bool EliminateTrailingSlashInPath(char *_path);
    
/**
 * GetFilenameFromPath assumes that _path is absolute and there's a leading slash in it.
 * Also assume, that it is not a directory path, like /Dir/, it will return false on such case.
 */
bool GetFilenameFromPath(const char* _path, char *_buf);

/**
 * GetDirectoryNameFromPath returns a rightmost directory name.
 * Assuming that path has a form /Abra/Cadabra/ or /Abra/Cadabra/1.txt, function will return Cadabra.
 */
bool GetDirectoryNameFromPath(const char *_path, char *_dir_out, size_t _dir_size);
    
/**
 * GetDirectoryContainingItemFromPath will parse path like /Dir/wtf and return /Dir/.
 * For paths like /Dir/wtf/ will return /Dir/.
 * Will return false on relative paths.
 */
bool GetDirectoryContainingItemFromPath(const char* _path, char *_buf);
    
/**
 * GetFilenameFromRelPath can work with relative paths like "Filename".
 */
bool GetFilenameFromRelPath(const char* _path, char *_buf);
    
/**
 * GetDirectoryContainingItemFromRelPath can work on paths like "Filename", will simply return "".
 * Assume that it's not a directory path like "/Dir/"
 */
bool GetDirectoryContainingItemFromRelPath(const char* _path, char *_buf);

/**
 * GetExtensionFromPath works with absolute paths and will not work with some relative paths like "filename.txt".
 * It will not extract extensions from filenames like ".filename" or "filename."
 */
bool GetExtensionFromPath(const char* _path, char *_buf);    

/**
 * GetExtensionFromRelPath can work with absolute path and paths like "filename.txt"
 * It will not extract extensions from filenames like ".filename" or "filename."
 */
bool GetExtensionFromRelPath(const char* _path, char *_buf);
    
/**
 * IsPathWithTrailingSlash actually does _path[strlen(_path)-1] == '/' and some prior checking.
 * Will return true on "/" path.
 */
inline bool IsPathWithTrailingSlash(const char* _path)
{
    if(_path[0] == 0)
        return false;
        
    return _path[ strlen(_path) - 1 ] == '/';
}

#ifdef __cplusplus
}
#endif

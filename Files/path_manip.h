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
 * GetFilenameFromPath assumes that _path is absolute and there's a leading slash in it.
 * Also assume, that it is not a directory path, like /Dir/, it will return false on such case.
 */
bool GetFilenameFromPath(const char* _path, char *_buf);

/**
 * GetDirectoryContainingItemFromPath will parse path like /Dir/wtf and return /Dir/.
 * Will return false on relative paths
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

#ifdef __cplusplus
}
#endif

// Copyright (C) 2013-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include <string.h>
#include <stdlib.h>
#include <assert.h>
#include <Utility/PathManip.h>

bool EliminateTrailingSlashInPath(char *_path)
{
    if(_path == 0)
        return false;
    
    size_t len = strlen(_path);
    if(len == 0 ||
       _path[0] != '/')
        return false;
    
    if(len == 1)
        return true;
    
    if(_path[len-1] == '/')
        _path[len-1] = 0;
    
    return true;
}

bool GetFilenameFromPath(const char* _path, char *_buf)
{
    if(_path[0] != '/')
        return false;
    const char* last_sl  = strrchr(_path, '/');
    if(!last_sl)
        return false;
    if(last_sl == _path + strlen(_path) - 1)
        return false;
    strcpy(_buf, last_sl+1);
    return true;
}

bool GetDirectoryContainingItemFromPath(const char* _path, char *_buf)
{
    if(_path[0] != '/')
        return false;
    size_t sz = strlen(_path);
    if(sz == 1)
        return false;
    
    const char* last_sl = strrchr(_path, '/');
    if(last_sl ==  _path + sz - 1)
        while(*(--last_sl) != '/');
    memcpy(_buf, _path, last_sl - _path + 1);
    _buf[last_sl - _path + 1] = 0;
    return true;
}

bool GetFilenameFromRelPath(const char* _path, char *_buf)
{
    const char* last_sl  = strrchr(_path, '/');
    if(last_sl == 0) {
        strcpy(_buf, _path); // assume that there's no directories in this path, so return the entire original path
        return true;
    }
    else {
        if(last_sl == _path + strlen(_path) - 1)
            return false; // don't handle paths like "Dir/"
        strcpy(_buf, last_sl+1);
        return true;
    }
}

bool GetDirectoryContainingItemFromRelPath(const char* _path, char *_buf)
{
    const char* last_sl = strrchr(_path, '/');
    if(!last_sl) {
        _buf[0] = 0;
        return true;
    }
    memcpy(_buf, _path, last_sl - _path + 1);
    _buf[last_sl - _path + 1] = 0;
    return true;
}

bool GetExtensionFromPath(const char* _path, char *_buf)
{
    const char* last_sl  = strrchr(_path, '/');
    const char* last_dot = strrchr(_path, '.');
    if(!last_sl || !last_dot) return false;
    if(last_dot == last_sl+1) return false;
    if(last_dot == _path + strlen(_path) - 1) return false;
    if(last_dot < last_sl) return false;
    strcpy(_buf, last_dot+1);
    return true;
}

bool GetExtensionFromRelPath(const char* _path, char *_buf)
{
    const char* last_sl  = strrchr(_path, '/');
    const char* last_dot = strrchr(_path, '.');
    if(last_dot == 0)
        return false;
    
    if(last_sl)
    {
        if(last_dot == last_sl+1)
            return false;
        if(last_dot == _path + strlen(_path) - 1)
            return false;
        if(last_dot < last_sl)
            return false;
        strcpy(_buf, last_dot+1);
        return true;
    }
    else
    {
        if(last_dot == _path)
            return false;
        if(last_dot == _path + strlen(_path) - 1)
            return false;
        strcpy(_buf, last_dot+1);
        return true;
    }
}

bool GetDirectoryNameFromPath(const char *_path, char *_dir_out, size_t _dir_size)
{
    const char *second_sep = strrchr(_path, '/');
    if (!second_sep) return false;
    
    // Path contains single / in the beginning.
    if (second_sep == _path)
    {
        assert(_dir_size >= 2);
        _dir_out[0] = '/';
        _dir_out[1] = 0;
        return true;
    }
    
    // Searching for the second separator.
    const char *first_sep = second_sep - 1;
    for (; first_sep != _path && *first_sep != '/'; --first_sep);
    
    if (*first_sep != '/')
    {
        // Peculiar situation. Path contains only one /, and it is in the middle of the path.
        // Assume that directory name is part of the path located to the left of the /.
        first_sep = _path - 1;
    }
    
    size_t len = second_sep - first_sep - 1;
    assert(len + 1 <= _dir_size);
    memcpy(_dir_out, first_sep + 1, len);
    _dir_out[len + 1] = 0;
    
    return true;
}

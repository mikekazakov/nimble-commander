//
//  FileCopyOperation.h
//  Directories
//
//  Created by Michael G. Kazakov on 09.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "Operation.h"
#import "chained_strings.h"
#import "OperationDialogAlert.h"
#import "FileAlreadyExistSheetController.h"
#import "VFS.h"

namespace FileCopyOperationDR
{
enum
{
    Overwrite = OperationDialogResult::Custom,
    Append
};
}

struct FileCopyOperationOptions
{
    bool docopy = true;      // it it false then operation will do renaming/moving
    bool preserve_symlinks = true;
    bool copy_xattrs = true;
    bool copy_file_times = true;
    bool copy_unix_flags = true;
    bool copy_unix_owners = true;    
};

@interface FileCopyOperation : Operation


// native->native copying
- (id)initWithFiles:(chained_strings)_files
               root:(const char*)_root
               dest:(const char*)_dest
            options:(const FileCopyOperationOptions&)_opts;

// VFS->native copying
- (id)initWithFiles:(chained_strings)_files
               root:(const char*)_root
            rootvfs:(shared_ptr<VFSHost>)_vfs
               dest:(const char*)_dest
            options:(const FileCopyOperationOptions&)_opts;

// VFS->VFS copying
- (id)initWithFiles:(chained_strings)_files
               root:(const char*)_root
             srcvfs:(shared_ptr<VFSHost>)_vfs
               dest:(const char*)_dest
             dstvfs:(shared_ptr<VFSHost>)_dst_vfs
            options:(const FileCopyOperationOptions&)_opts;


- (void)Update;

- (OperationDialogAlert *)OnCantCreateDir:(NSError*)_error ForDir:(const char *)_path;
- (OperationDialogAlert *)OnCopyCantAccessSrcFile:(NSError*)_error ForFile:(const char *)_path;
- (OperationDialogAlert *)OnCopyCantOpenDestFile:(NSError*)_error ForFile:(const char *)_path;
- (OperationDialogAlert *)OnCopyReadError:(NSError*)_error ForFile:(const char *)_path;
- (OperationDialogAlert *)OnCopyWriteError:(NSError*)_error ForFile:(const char *)_path;
- (FileAlreadyExistSheetController *)OnFileExist: (const char*)_path
                                         newsize: (unsigned long)_newsize
                                         newtime: (time_t) _newtime
                                         exisize: (unsigned long)_exisize
                                         exitime: (time_t) _exitime
                                        remember: (bool*)  _remb;
- (OperationDialogAlert *)OnRenameDestinationExists:(const char *)_dest
                                             Source:(const char *)_src;

@end

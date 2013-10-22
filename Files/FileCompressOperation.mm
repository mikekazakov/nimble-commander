//
//  FileCompressOperation.m
//  Files
//
//  Created by Michael G. Kazakov on 21.10.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "FileCompressOperation.h"
#import "FileCompressOperationJob.h"

@implementation FileCompressOperation
{
    FileCompressOperationJob m_Job;
}

- (id)initWithFiles:(FlexChainedStringsChunk*)_src_files // passing with ownership, operation will free it on finish
            srcroot:(const char*)_src_root
             srcvfs:(std::shared_ptr<VFSHost>)_src_vfs
            dstroot:(const char*)_dst_root
             dstvfs:(std::shared_ptr<VFSHost>)_dst_vfs
{
    self = [super initWithJob:&m_Job];
    if (self)
    {
//        strcpy(m_OriginalPathRequest, _path);
//        m_OperationStart = GetTimeInNanoseconds();
//        m_Job.Init(_path, _rootpath, self);
//        self.Caption = [NSString stringWithFormat:@"Creating directory \"%@\"",
//                        [NSString stringWithUTF8String:_path]];
        
        m_Job.Init(_src_files, _src_root, _src_vfs, _dst_root, _dst_vfs, self);
        
        self.Caption = @"Compressing...";
    }
    return self;
}


@end

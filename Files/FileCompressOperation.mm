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
    int m_LastInfoUpdateTime;    
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
        m_Job.Init(_src_files, _src_root, _src_vfs, _dst_root, _dst_vfs, self);
        m_LastInfoUpdateTime = 0;
        
        self.Caption = @"Compressing..."; // TODO: need good title here, not a dummy
    }
    return self;
}

- (void)Update
{
    OperationStats &stats = m_Job.GetStats();
    float progress = stats.GetProgress();
    if (self.Progress != progress)
        self.Progress = progress;
    
    int time = stats.GetTime();
    if (time - m_LastInfoUpdateTime >= 1000) {
        self.ShortInfo = [self ProduceDescriptionStringForBytesProcess];
        m_LastInfoUpdateTime = time;
    }
}

@end

//
//  VFSNativeHost.h
//  Files
//
//  Created by Michael G. Kazakov on 26.08.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#import "VFSHost.h"

class VFSNativeHost : public VFSHost
{
public:
    VFSNativeHost();
    
    virtual bool IsDirectory(const char *_path,
                             int _flags,
                             bool (^_cancel_checker)()) override;
    
    virtual int FetchDirectoryListing(const char *_path,
                                      std::shared_ptr<VFSListing> *_target,
                                      bool (^_cancel_checker)()) override;

    virtual int CreateFile(const char* _path,
                           std::shared_ptr<VFSFile> *_target,
                           bool (^_cancel_checker)()) override;
    
    
    virtual int CalculateDirectoriesSizes(
                                        FlexChainedStringsChunk *_dirs, // transfered ownership
                                        const std::string &_root_path, // relative to current host path
                                        bool (^_cancel_checker)(),
                                        void (^_completion_handler)(const char* _dir_sh_name, uint64_t _size)
                                        ) override;
    virtual int CalculateDirectoryDotDotSize( // will pass ".." as _dir_sh_name upon completion
                                             const std::string &_root_path, // relative to current host path
                                             bool (^_cancel_checker)(),
                                             void (^_completion_handler)(const char* _dir_sh_name, uint64_t _size)
                                             ) override;
    
    std::shared_ptr<const VFSNativeHost> SharedPtr() const {return std::static_pointer_cast<const VFSNativeHost>(VFSHost::SharedPtr());}
    std::shared_ptr<VFSNativeHost> SharedPtr() {return std::static_pointer_cast<VFSNativeHost>(VFSHost::SharedPtr());}
    static std::shared_ptr<VFSNativeHost> SharedHost();
    
private:
    
    

};

//
//  VFSHost.h
//  Files
//
//  Created by Michael G. Kazakov on 25.08.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#import <string>
#import <memory>

#import "VFSError.h"
#import "FlexChainedStringsChunk.h"

class VFSListing;
class VFSFile;

class VFSHost : public std::enable_shared_from_this<VFSHost>
{
public:
    VFSHost(const char *_junction_path,         // junction path and parent can be nil
            std::shared_ptr<VFSHost> _parent);
    virtual ~VFSHost();
    
    enum {
        F_NoFollow = 1
        
    };
    
    virtual bool IsWriteable() const;
    // TODO: IsWriteableAtPath
    
    virtual const char *FSTag() const;
    const char *JunctionPath() const;
    std::shared_ptr<VFSHost> Parent() const;
    
    virtual bool IsDirectory(const char *_path,
                             int _flags,
                             bool (^_cancel_checker)());
    
    virtual bool FindLastValidItem(const char *_orig_path,
                                   char *_valid_path,
                                   int _flags,
                                   bool (^_cancel_checker)());
    
    virtual int FetchDirectoryListing(const char *_path,
                                      std::shared_ptr<VFSListing> *_target,
                                      bool (^_cancel_checker)());
    
    virtual int CreateFile(const char* _path,
                           std::shared_ptr<VFSFile> *_target,
                           bool (^_cancel_checker)());
    
    virtual int CalculateDirectoriesSizes(
                                        FlexChainedStringsChunk *_dirs, // transfered ownership
                                        const std::string &_root_path, // relative to current host path
                                        bool (^_cancel_checker)(),
                                        void (^_completion_handler)(const char* _dir_sh_name, uint64_t _size)
                                        );
    virtual int CalculateDirectoryDotDotSize( // will pass ".." as _dir_sh_name upon completion
                                          const std::string &_root_path, // relative to current host path
                                          bool (^_cancel_checker)(),
                                          void (^_completion_handler)(const char* _dir_sh_name, uint64_t _size)
                                          );
    
    /*
     typedef bool (^PanelDirectorySizeCalculate_CancelChecker)(void);
     typedef void (^PanelDirectorySizeCalculate_CompletionHandler)(const char*_dir, unsigned long _size);
     
    void PanelDirectorySizeCalculate( FlexChainedStringsChunk *_dirs, // transfered ownership
                                     const char *_root_path,           // transfered ownership, allocated with malloc
                                     bool _is_dotdot,
                                     PanelDirectorySizeCalculate_CancelChecker _checker,
                                     PanelDirectorySizeCalculate_CompletionHandler _handler);*/
    
    
    
    

    inline std::shared_ptr<VFSHost> SharedPtr() { return shared_from_this(); }
    inline std::shared_ptr<const VFSHost> SharedPtr() const { return shared_from_this(); }
private:
    std::string m_JunctionPath;         // path in Parent VFS, relative to it's root
    std::shared_ptr<VFSHost> m_Parent;
    
    // forbid copying
    VFSHost(const VFSHost& _r) = delete;
    void operator=(const VFSHost& _r) = delete;
};

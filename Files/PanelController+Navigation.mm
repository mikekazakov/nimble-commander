//
//  PanelController+Navigation.m
//  Files
//
//  Created by Michael G. Kazakov on 21.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "PanelController.h"
#import "Common.h"

@implementation PanelController (Navigation)

- (void) GoToVFSPathStack:(const VFSPathStack&)_stack
{
    // TODO: make this async and run in appropriate queue
    
    // 1st - build current hosts stack
    vector<VFSHostPtr> curr_stack;
    VFSHostPtr cur = self.VFS;
    while(cur) {
        curr_stack.emplace_back(cur);
        cur = cur->Parent();
    }
    reverse(begin(curr_stack), end(curr_stack));
    
    // 2nd - compare with required stack and left only what matches
    vector<VFSHostPtr> res_stack;
    for(size_t i = 0; i < _stack.size(); ++i)
    {
        if(i >= curr_stack.size())
            break;
        if(!_stack[i].host.owner_before(curr_stack[i]) && !curr_stack[i].owner_before(_stack[i].host))
        {
            // exact match of an alive host, just use it and go on
            res_stack.emplace_back(curr_stack[i]);
            continue;
        }
        
        if(_stack[i].fs_tag != curr_stack[i]->FSTag()) break;
        if(_stack[i].junction != curr_stack[i]->JunctionPath()) break;
        
        auto opts1 = _stack[i].options;
        auto opts2 = curr_stack[i]->Options();
        if(opts1 == nullptr && opts2 != nullptr) break;
        if(opts1 != nullptr && opts2 == nullptr) break;
        if(opts1 != nullptr && !opts1->Equal(*opts2)) break;

        // this is not the object which was used before, but it matches and seems that can be used
        res_stack.emplace_back(curr_stack[i]);
    }
    
    // 3rd - build what's absent
    for(size_t i = res_stack.size(); i < _stack.size(); ++i)
    {
        // refactor this in separate functions
        const auto &part = _stack[i];
        if(part.fs_tag == VFSNativeHost::Tag) {
            res_stack.emplace_back(VFSNativeHost::SharedHost());
        }
        else if(part.fs_tag == VFSPSHost::Tag) {
            res_stack.emplace_back(VFSPSHost::GetSharedOrNew());
        }
        else if(part.fs_tag == VFSArchiveHost::Tag) {
            assert(i > 0);
            auto arhost = make_shared<VFSArchiveHost>(part.junction.c_str(), res_stack.back());
            if(arhost->Open() >= 0)
                res_stack.emplace_back(arhost);
            else
                break;
        }
        else if(part.fs_tag == VFSArchiveUnRARHost::Tag) {
            assert(i > 0);
            if(!res_stack.back()->IsNativeFS())
                break;
            auto arhost = make_shared<VFSArchiveUnRARHost>(part.junction.c_str());
            if(arhost->Open() >= 0)
                res_stack.emplace_back(arhost);
            else
                break;
        }
        else if(part.fs_tag == VFSNetFTPHost::Tag) {
            assert(i == 0);
            assert(i == _stack.size() - 1); // need to return here later
            auto options = dynamic_pointer_cast<VFSNetFTPOptions>(part.options);
            if(!options)
                break;
            auto ftp = make_shared<VFSNetFTPHost>(part.junction.c_str());
            if(ftp->Open(_stack.path().c_str(), *options) >= 0)
                res_stack.emplace_back(ftp);
            else
                break;
        }
        else
            assert(0);
    }
    
    // TODO: need an ability to show errors at least
    
    if(res_stack.size() == _stack.size())
        [self GoToDir:_stack.path()
                  vfs:res_stack.back()
         select_entry:""
                async:true];
}

- (int) GoToDir:(string)_dir
            vfs:(VFSHostPtr)_vfs
   select_entry:(string)_filename
          async:(bool)_asynchronous
{
    if(_dir.empty() || _dir.front() != '/' || !_vfs)
        return VFSError::InvalidCall;
    
    if(_asynchronous == false)
    {
        assert(dispatch_is_main_queue());
        m_DirectoryLoadingQ->Stop();
        m_DirectoryLoadingQ->Wait();
    }
    else
    {
        if(!m_DirectoryLoadingQ->Empty())
            return 0;
    }
    
    __block int ret = 0;
    auto workblock = ^(SerialQueue _q) {
        if(!_vfs->IsDirectory(_dir.c_str(), 0, 0))
        {
            ret = VFSError::FromErrno(ENOTDIR);
            return;
        }
        shared_ptr<VFSListing> listing;
        ret = _vfs->FetchDirectoryListing(_dir.c_str(),
                                          &listing,
                                          m_VFSFetchingFlags,
                                          ^{return _q->IsStopped();});
        if(ret < 0)
            return;
        // TODO: need an ability to show errors at least        
        
        [self CancelBackgroundOperations]; // clean running operations if any
        dispatch_or_run_in_main_queue( ^{
            [m_View SavePathState];
            m_Data.Load(listing);
            [m_View DirectoryChanged:_filename.c_str()];
            m_View.needsDisplay = true;
            [self OnPathChanged];
        });
    };
    
    if(_asynchronous == false)
    {
        m_DirectoryLoadingQ->RunSyncHere(workblock);
        return ret;
    }
    else
    {
        m_DirectoryLoadingQ->Run(workblock);
        return 0;
    }
}


@end

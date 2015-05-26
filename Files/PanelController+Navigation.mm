//
//  PanelController+Navigation.m
//  Files
//
//  Created by Michael G. Kazakov on 21.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "PanelController.h"
#import "Common.h"
#import "common_paths.h"

@implementation PanelController (Navigation)

- (void) GoToVFSPathStack:(const VFSPathStack&)_stack
{
    // TODO: make this async and run in appropriate queue
    
    // 1st - build current hosts stack
    vector<VFSHostPtr> curr_stack;
    VFSHostPtr cur = self.vfs;
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
        else if(part.fs_tag == VFSNetSFTPHost::Tag) {
            assert(i == 0);
            assert(i == _stack.size() - 1); // need to return here later
            auto options = dynamic_pointer_cast<VFSNetSFTPOptions>(part.options);
            if(!options)
                break;
            auto sftp = make_shared<VFSNetSFTPHost>(part.junction.c_str());
            if(sftp->Open(*options) >= 0)
                res_stack.emplace_back(sftp);
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
    loadPreviousState:true
                async:true];
}

- (int) GoToDir:(string)_dir
            vfs:(VFSHostPtr)_vfs
   select_entry:(string)_filename
          async:(bool)_asynchronous
{
    return [self GoToDir:_dir
                     vfs:_vfs
            select_entry:_filename
       loadPreviousState:false
                   async:_asynchronous];
}

- (int) GoToDir:(string)_dir
            vfs:(VFSHostPtr)_vfs
   select_entry:(string)_filename
loadPreviousState:(bool)_load_state
          async:(bool)_asynchronous
{
    auto c = make_shared<PanelControllerGoToDirContext>();
    c->RequestedDirectory = _dir;
    c->VFS = _vfs;
    c->RequestFocusedEntry = _filename;
    c->LoadPreviousViewState = _load_state;
    c->PerformAsynchronous = _asynchronous;
    
    return [self GoToDirWithContext:c];
}

- (int) GoToDirWithContext:(shared_ptr<PanelControllerGoToDirContext>)_context
{
    auto &c = _context;
    if(c->RequestedDirectory.empty() ||
       c->RequestedDirectory.front() != '/' ||
       !c->VFS)
        return VFSError::InvalidCall;
    
    if(c->PerformAsynchronous == false) {
        assert(dispatch_is_main_queue());
        m_DirectoryLoadingQ->Stop();
        m_DirectoryLoadingQ->Wait();
    }
    else {
        if(!m_DirectoryLoadingQ->Empty())
            return 0;
    }
    
    auto workblock = [=](const SerialQueue &_q) {
        if(!c->VFS->IsDirectory(c->RequestedDirectory.c_str(), 0, 0)) {
            c->LoadingResultCode = VFSError::FromErrno(ENOTDIR);
            if( c->LoadingResultCallback )
                c->LoadingResultCallback( c->LoadingResultCode );            
            return;
        }
        
        unique_ptr<VFSListing> listing;
        c->LoadingResultCode = c->VFS->FetchDirectoryListing(c->RequestedDirectory.c_str(),
                                                                    listing,
                                                                    m_VFSFetchingFlags,
                                                                    [&] {
                                                                        return _q->IsStopped();
                                                                    });
        if( c->LoadingResultCallback )
            c->LoadingResultCallback( c->LoadingResultCode );
            
        if( c->LoadingResultCode < 0 )
            return;
        // TODO: need an ability to show errors at least        
        
        [self CancelBackgroundOperations]; // clean running operations if any
        dispatch_or_run_in_main_queue([=,listing=move(listing)]()mutable {
            [m_View SavePathState];
            m_Data.Load(move(listing));
            [m_View dataUpdated];
            [m_View directoryChangedWithFocusedFilename:c->RequestFocusedEntry
                                      loadPreviousState:c->LoadPreviousViewState];
            [m_View setNeedsDisplay];
            [self OnPathChanged];
        });
    };
    
    if(c->PerformAsynchronous == false) {
        m_DirectoryLoadingQ->RunSyncHere(workblock);
        return c->LoadingResultCode;
    }
    else {
        m_DirectoryLoadingQ->Run(workblock);
        return 0;
    }
}

- (void) RecoverFromInvalidDirectory
{
    path initial_path = self.currentDirectoryPath;
    auto initial_vfs = self.vfs;
    m_DirectoryLoadingQ->Run([=](const SerialQueue &_que) {
        // 1st - try to locate a valid dir in current host
        path path = initial_path;
        auto vfs = initial_vfs;
        
        while(true)
        {
            if(vfs->IterateDirectoryListing(path.c_str(), [](const VFSDirEnt &_dirent) {
                    return false;
                }) >= 0) {
                dispatch_to_main_queue([=]{
                    [self GoToDir:path.native()
                              vfs:vfs
                     select_entry:""
                            async:true];
                });
                break;
            }
            
            if(path == "/")
                break;
            
            if(path.filename() == ".") path.remove_filename();
            path = path.parent_path();
        }
        
        // we can't work on this vfs. currently for simplicity - just go home
        dispatch_to_main_queue([=]{
            [self GoToDir:CommonPaths::Get(CommonPaths::Home)
                      vfs:VFSNativeHost::SharedHost()
             select_entry:""
                    async:true];
        });
    });
}

@end

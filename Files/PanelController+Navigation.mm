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
#if 0
- (void) AsyncGoToVFSPathStack:(const VFSPathStack&)_path
                     withFlags:(int)_flags
                      andFocus:(string)_filename
{

    if(!m_DirectoryLoadingQ->Empty())
        return;
    
    if(_path.empty())
        return;
 
    VFSPathStack path = _path;
    
    m_DirectoryLoadingQ->Run(^(SerialQueue _q) {
        vector<shared_ptr<VFSHost>> current_hosts_stack = m_HostsStack;
        vector<shared_ptr<VFSHost>> hosts_stack;
        bool following = true;
        for(int pp = 0; pp < path.size(); ++pp) {
            if( following &&
                pp < current_hosts_stack.size() &&
                path[pp].fs_tag == current_hosts_stack[pp]->FSTag() &&
                (pp == 0 || path[pp-1].path == current_hosts_stack[pp]->JunctionPath() )
               ) {
                hosts_stack.push_back(current_hosts_stack[pp]);
                continue;
            }
            following = false;
            
            // process junction here
            auto &part = path[pp];
            
            if(part.fs_tag == VFSNativeHost::Tag)
                hosts_stack.push_back(VFSNativeHost::SharedHost());
            else if(part.fs_tag == VFSPSHost::Tag)
                hosts_stack.push_back(make_shared<VFSPSHost>());
            else if(part.fs_tag == VFSArchiveHost::Tag)
            {
                auto arhost = make_shared<VFSArchiveHost>(path[pp-1].path.c_str(), hosts_stack.back());
                if(arhost->Open() >= 0) {
                    hosts_stack.push_back(arhost);
                }
                else {
                    break;
                }
            }
            else if(part.fs_tag == VFSArchiveUnRARHost::Tag &&
                    hosts_stack.back()->IsNativeFS() )
            {
                auto arhost = make_shared<VFSArchiveUnRARHost>(path[pp-1].path.c_str());
                if(arhost->Open() >= 0) {
                    hosts_stack.push_back(arhost);
                }
                else {
                    break;
                }
            }
        }
    
        if(hosts_stack.size() == path.size()) {
            if(hosts_stack.back()->IsDirectory(path.back().path.c_str(), 0, 0)) {
                shared_ptr<VFSListing> listing;
                int ret = hosts_stack.back()->FetchDirectoryListing(path.back().path.c_str(), &listing, m_VFSFetchingFlags, ^{return _q->IsStopped();});
                if(ret >= 0)
                    dispatch_to_main_queue( ^{
                        [self CancelBackgroundOperations]; // clean running operations if any
                        [m_View SavePathState];
                        m_HostsStack = hosts_stack;
                        m_Data.Load(listing);
                        [m_View DirectoryChanged:_filename.c_str()];
                        [self OnPathChanged:_flags];
                    });
            }
        }
    });

}
#endif
#if 0
- (void) AsyncGoToVFSHostsStack:(vector<shared_ptr<VFSHost>>)_hosts
                       withPath:(string)_path
                      withFlags:(int)_flags
                       andFocus:(string)_filename
{

    m_DirectoryLoadingQ->Run(^(SerialQueue _q) {
        if(_hosts.back()->IsDirectory(_path.c_str(), 0, 0)) {
            shared_ptr<VFSListing> listing;
            int ret = _hosts.back()->FetchDirectoryListing(_path.c_str(), &listing, m_VFSFetchingFlags, ^{return _q->IsStopped();});
            if(ret >= 0)
                dispatch_to_main_queue( ^{
                    [self CancelBackgroundOperations]; // clean running operations if any
                    [m_View SavePathState];
                    m_HostsStack = _hosts;
                    m_Data.Load(listing);
                    [m_View DirectoryChanged:_filename.c_str()];
                    [self OnPathChanged:_flags];
                });
        }
    });

}
#endif
- (void) OnGoBack
{
    if(!m_History.CanMoveBack())
        return;
    m_History.MoveBack();
    [self GoToVFSPathStack:*m_History.Current()];
}

- (void) OnGoForward
{
    if(!m_History.CanMoveForth())
        return;
    m_History.MoveForth();
    [self GoToVFSPathStack:*m_History.Current()];
}

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

@end

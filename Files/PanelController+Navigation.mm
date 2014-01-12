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
                hosts_stack.push_back(make_shared<VFSNativeHost>());
            else if(part.fs_tag == VFSPSHost::Tag)
                hosts_stack.push_back(make_shared<VFSPSHost>());
            else if(part.fs_tag == VFSArchiveHost::Tag)
            {
                shared_ptr<VFSArchiveHost> arhost = make_shared<VFSArchiveHost>(path[pp-1].path.c_str(), hosts_stack.back());
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
                        m_Data->Load(listing);
                        [m_View DirectoryChanged:_filename.c_str()];
                        [self OnPathChanged:_flags];
                    });
            }
        }
    });
    
}


- (void) OnGoBack
{
    if(m_History.Length() < 2)
        return;
    if(m_History.IsBack())
        return;
    
    if(m_History.IsBeyond())
        m_History.MoveBack();
    
    if(!m_History.IsBack())
        m_History.MoveBack();

    [self AsyncGoToVFSPathStack:*m_History.Current()
                      withFlags:PanelControllerNavigation::NoHistory
                       andFocus:""
     ];
}

- (void) OnGoForward
{
    if(m_History.Length() < 2)
        return;
    if(m_History.IsBeyond())
        return;

    m_History.MoveForth();
    
    if(!m_History.IsBeyond())
        [self AsyncGoToVFSPathStack:*m_History.Current()
                          withFlags:PanelControllerNavigation::NoHistory
                           andFocus:""];
}

@end

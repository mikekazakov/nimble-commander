//
//  MainWindowFilePanelState+Menu.m
//  Files
//
//  Created by Michael G. Kazakov on 19.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "MainWindowFilePanelState+Menu.h"
#import "ActionsShortcutsManager.h"
#import "PanelController.h"
#import "FileDeletionOperation.h"
#import "FilePanelMainSplitView.h"
#import "OperationsController.h"
#import "Common.h"
#import "common_paths.h"
#import "ExternalEditorInfo.h"
#import "MainWindowController.h"
#import "FileCompressOperation.h"
#import "FileLinkNewSymlinkSheetController.h"
#import "FileLinkAlterSymlinkSheetController.h"
#import "FileLinkNewHardlinkSheetController.h"
#import "FileLinkOperation.h"
#import "FileCopyOperation.h"
#import "MassCopySheetController.h"

@implementation MainWindowFilePanelState (Menu)

- (BOOL) validateMenuItem:(NSMenuItem *)item
{
#define TAG(name, str) static const int name = ActionsShortcutsManager::Instance().TagFromAction(str)
    TAG(tag_view_swap_panels,           "menu.view.swap_panels");
    TAG(tag_view_sync_panels,           "menu.view.sync_panels");
    TAG(tag_file_open_in_opp,           "menu.file.open_in_opposite_panel");
    TAG(tag_cmd_compress,               "menu.command.compress");
    TAG(tag_cmd_link_soft,              "menu.command.link_create_soft");
    TAG(tag_cmd_link_hard,              "menu.command.link_create_hard");
    TAG(tag_cmd_link_edit,              "menu.command.link_edit");
    TAG(tag_cmd_copy_to,                "menu.command.copy_to");
    TAG(tag_cmd_copy_as,                "menu.command.copy_as");
    TAG(tag_cmd_move_to,                "menu.command.move_to");
    TAG(tag_cmd_move_as,                "menu.command.move_as");
#undef TAG
    
    auto tag = item.tag;
#define IF(a) else if(tag == a)
    if(false);
    IF(tag_view_swap_panels)        return self.isPanelActive && !m_MainSplitView.anyCollapsedOrOverlayed;
    IF(tag_view_sync_panels)        return self.isPanelActive && !m_MainSplitView.anyCollapsedOrOverlayed;
    IF(tag_file_open_in_opp)        return self.isPanelActive && !m_MainSplitView.anyCollapsedOrOverlayed && self.activePanelView.item && self.activePanelView.item->IsDir();
    IF(tag_cmd_compress)            return self.isPanelActive && !m_MainSplitView.anyCollapsedOrOverlayed && self.activePanelView.item && !self.activePanelView.item->IsDotDot();
    IF(tag_cmd_link_soft)           return self.isPanelActive && !m_MainSplitView.anyCollapsedOrOverlayed && self.activePanelView.item && !self.activePanelView.item->IsDotDot() && self.leftPanelController.VFS->IsNativeFS() && self.rightPanelController.VFS->IsNativeFS();
    IF(tag_cmd_link_hard)           return self.isPanelActive && !m_MainSplitView.anyCollapsedOrOverlayed && self.activePanelView.item && self.leftPanelController.VFS->IsNativeFS() && self.rightPanelController.VFS->IsNativeFS() && !self.activePanelView.item->IsDir();
    IF(tag_cmd_link_edit)           return self.isPanelActive && !m_MainSplitView.anyCollapsedOrOverlayed && self.activePanelView.item && self.activePanelController.VFS->IsNativeFS() && !self.activePanelView.item->IsDir() && self.activePanelView.item->IsSymlink();
    IF(tag_cmd_copy_to)             return self.isPanelActive && !m_MainSplitView.anyCollapsedOrOverlayed;
    IF(tag_cmd_copy_as)             return self.isPanelActive && !m_MainSplitView.anyCollapsedOrOverlayed;
    IF(tag_cmd_move_to)             return self.isPanelActive && !m_MainSplitView.anyCollapsedOrOverlayed;
    IF(tag_cmd_move_as)             return self.isPanelActive && !m_MainSplitView.anyCollapsedOrOverlayed;
#undef IF

    return true;
}

- (IBAction)OnSyncPanels:(id)sender
{
    if(!self.activePanelController || !self.oppositePanelController || m_MainSplitView.anyCollapsedOrOverlayed)
        return;
    
    [self.oppositePanelController GoToDir:self.activePanelController.GetCurrentDirectoryPathRelativeToHost
                                      vfs:self.activePanelController.VFS
                             select_entry:""
                                    async:true];
}

- (IBAction)OnSwapPanels:(id)sender
{
    if(m_MainSplitView.anyCollapsedOrOverlayed)
        return;
    
    swap(m_LeftPanelControllers, m_RightPanelControllers);
    [m_MainSplitView SwapViews];
    
    [self.leftPanelController AttachToControls:m_LeftPanelSpinningIndicator share:m_LeftPanelShareButton];
    [self.rightPanelController AttachToControls:m_RightPanelSpinningIndicator share:m_RightPanelShareButton];
    
    [self savePanelsOptions];
}

- (IBAction)OnShowTerminal:(id)sender
{
    string path = "";
    if(self.isPanelActive && self.activePanelController.VFS->IsNativeFS())
        path = self.activePanelController.GetCurrentDirectoryPathRelativeToHost;
    [(MainWindowController*)self.window.delegate RequestTerminal:path];
}

- (IBAction)OnFileOpenInOppositePanel:(id)sender
{
    if(!self.isPanelActive || m_MainSplitView.anyCollapsedOrOverlayed || !self.activePanelView.item || !self.activePanelView.item->IsDir()) return;
    auto cur = self.activePanelController;
    auto opp = self.oppositePanelController;
    [opp GoToDir:cur.GetCurrentFocusedEntryFilePathRelativeToHost
             vfs:cur.VFS
    select_entry:""
           async:true];
}

- (IBAction)OnCompressFiles:(id)sender
{
    if(!self.isPanelActive || m_MainSplitView.anyCollapsedOrOverlayed) return;
    
    auto files = [self.activePanelController GetSelectedEntriesOrFocusedEntryWithoutDotDot];
    if(files.empty())
        return;
    shared_ptr<VFSHost> srcvfs, dstvfs;
    string srcroot, dstroot;
    PanelController *target_pc;
    srcvfs = self.activePanelController.VFS;
    dstvfs = self.oppositePanelController.VFS;
    srcroot = [self.activePanelController GetCurrentDirectoryPathRelativeToHost];
    dstroot = [self.oppositePanelController GetCurrentDirectoryPathRelativeToHost];
    target_pc = self.oppositePanelController;
    
    FileCompressOperation *op = [[FileCompressOperation alloc] initWithFiles:move(files)
                                                                     srcroot:srcroot.c_str()
                                                                      srcvfs:srcvfs
                                                                     dstroot:dstroot.c_str()
                                                                      dstvfs:dstvfs];
    op.TargetPanel = target_pc;
    [m_OperationsController AddOperation:op];
}

- (IBAction)OnCreateSymbolicLinkCommand:(id)sender
{
    if(!self.activePanelController || !self.oppositePanelController)
        return;
    
    auto const *item = self.activePanelView.item;
    if(!item)
        return;
    
    string source_path = [self activePanelData]->DirectoryPathWithTrailingSlash();
    if(!item->IsDotDot())
        source_path += item->Name();
    
    string link_path = self.oppositePanelController.GetCurrentDirectoryPathRelativeToHost;
    
    if(!item->IsDotDot())
        link_path += item->Name();
    else
        link_path += [self activePanelData]->DirectoryPathShort();
    
    FileLinkNewSymlinkSheetController *sheet = [FileLinkNewSymlinkSheetController new];
    [sheet ShowSheet:[self window]
          sourcepath:[NSString stringWithUTF8String:source_path.c_str()]
            linkpath:[NSString stringWithUTF8String:link_path.c_str()]
             handler:^(int result){
                 if(result == DialogResult::Create && [[sheet.LinkPath stringValue] length] > 0)
                     [m_OperationsController AddOperation:
                      [[FileLinkOperation alloc] initWithNewSymbolinkLink:[[sheet.SourcePath stringValue] fileSystemRepresentation]
                                                                 linkname:[[sheet.LinkPath stringValue] fileSystemRepresentation]
                       ]
                      ];
             }];
}

- (IBAction)OnEditSymbolicLinkCommand:(id)sender
{
    auto data = self.activePanelData;
    auto const *item = self.activePanelView.item;
    assert(item->IsSymlink());
    
    string link_path = data->DirectoryPathWithTrailingSlash() + item->Name();
    NSString *linkpath = [NSString stringWithUTF8String:link_path.c_str()];
    
    FileLinkAlterSymlinkSheetController *sheet = [FileLinkAlterSymlinkSheetController new];
    [sheet ShowSheet:[self window]
          sourcepath:[NSString stringWithUTF8String:item->Symlink()]
            linkname:[NSString stringWithUTF8String:item->Name()]
             handler:^(int _result){
                 if(_result == DialogResult::OK)
                 {
                     [m_OperationsController AddOperation:
                      [[FileLinkOperation alloc] initWithAlteringOfSymbolicLink:[[sheet.SourcePath stringValue] fileSystemRepresentation]
                                                                       linkname:[linkpath fileSystemRepresentation]]
                      ];
                 }
             }];
}

- (IBAction)OnCreateHardLinkCommand:(id)sender
{
    auto const *item = self.activePanelView.item;
    assert(not item->IsDir());
    
    string dir_path = [self activePanelData]->DirectoryPathWithTrailingSlash();
    string src_path = dir_path + item->Name();
    NSString *srcpath = [NSString stringWithUTF8String:src_path.c_str()];
    NSString *dirpath = [NSString stringWithUTF8String:dir_path.c_str()];
    
    FileLinkNewHardlinkSheetController *sheet = [FileLinkNewHardlinkSheetController new];
    [sheet ShowSheet:[self window]
          sourcename:[NSString stringWithUTF8String:item->Name()]
             handler:^(int _result){
                 if(_result == DialogResult::Create)
                 {
                     NSString *name = [sheet.LinkName stringValue];
                     if([name length] == 0) return;
                     
                     if([name fileSystemRepresentation][0] != '/')
                         name = [NSString stringWithFormat:@"%@%@", dirpath, name];
                     
                     [m_OperationsController AddOperation:
                      [[FileLinkOperation alloc] initWithNewHardLink:[srcpath fileSystemRepresentation]
                                                            linkname:[name fileSystemRepresentation]]
                      ];
                 }
             }];
}

- (IBAction)OnFileCopyCommand:(id)sender{
    if(!self.activePanelController || !self.oppositePanelController) return;
    if([m_MainSplitView anyCollapsedOrOverlayed])
        return;
    
    const PanelData *source, *destination;
    source = &self.activePanelController.data;
    destination = &self.oppositePanelController.data;
    __weak PanelController *act = self.activePanelController;
    __weak PanelController *opp = self.oppositePanelController;
    
    auto files = make_shared<chained_strings>([self.activePanelController GetSelectedEntriesOrFocusedEntryWithoutDotDot]);
    if(files->empty())
        return;
    
    string dest_path = destination->DirectoryPathWithTrailingSlash();
    NSString *nsdirpath = [NSString stringWithUTF8String:dest_path.c_str()];
    MassCopySheetController *mc = [MassCopySheetController new];
    [mc ShowSheet:self.window initpath:nsdirpath iscopying:true items:files.get() handler:^(int _ret)
     {
         path root_path = source->DirectoryPathWithTrailingSlash();
         path req_path = mc.TextField.stringValue.fileSystemRepresentation;
         if(_ret == DialogResult::Copy && !req_path.empty())
         {
             FileCopyOperationOptions opts;
             opts.docopy = true;
             [mc FillOptions:&opts];
             
             FileCopyOperation *op = [FileCopyOperation alloc];
             if(source->Host()->IsNativeFS() && destination->Host()->IsNativeFS())
                 op = [op initWithFiles:move(*files.get())
                                   root:root_path.c_str()
                                   dest:req_path.c_str()
                                options:opts];
             else if(destination->Host()->IsNativeFS() && req_path.is_absolute() )
                 op = [op initWithFiles:move(*files.get())
                                   root:root_path.c_str()
                                rootvfs:source->Host()
                                   dest:req_path.c_str()
                                options:opts];
             else if( ( req_path.is_absolute() && destination->Host()->IsWriteable()) ||
                     (!req_path.is_absolute() && source->Host()->IsWriteable() )      )
                 op = [op initWithFiles:move(*files.get())
                                   root:root_path.c_str()
                                 srcvfs:source->Host()
                                   dest:req_path.c_str()
                                 dstvfs:destination->Host()
                                options:opts];
             else
                 op = nil;
             
             if(op) {
                 [op AddOnFinishHandler:^{
                     dispatch_to_main_queue( ^{
                         [(PanelController*)act RefreshDirectory];
                         [(PanelController*)opp RefreshDirectory];
                     });
                 }];
                 [m_OperationsController AddOperation:op];
             }
         }
     }];
}

- (IBAction)OnFileCopyAsCommand:(id)sender{
    // process only current cursor item
    if(!self.activePanelController || !self.oppositePanelController) return;
    if([m_MainSplitView isViewCollapsedOrOverlayed:self.activePanelView])
        return;
    const PanelData *source, *destination;
    source = &self.activePanelController.data;
    destination = &self.oppositePanelController.data;
    __weak PanelController *act = self.activePanelController;
    __weak PanelController *opp = self.oppositePanelController;
    
    auto const *item = self.activePanelView.item;
    if(!item || item->IsDotDot())
        return;
    
    auto files = make_shared<chained_strings>(item->Name());
    
    MassCopySheetController *mc = [MassCopySheetController new];
    [mc ShowSheet:self.window initpath:[NSString stringWithUTF8String:item->Name()] iscopying:true items:files.get() handler:^(int _ret)
     {
         path root_path = self.activePanelData->DirectoryPathWithTrailingSlash();
         path req_path = mc.TextField.stringValue.fileSystemRepresentation;
         if(_ret == DialogResult::Copy && !req_path.empty())
         {
             FileCopyOperationOptions opts;
             opts.docopy = true;
             [mc FillOptions:&opts];
             
             FileCopyOperation *op = [FileCopyOperation alloc];
             if(source->Host()->IsNativeFS() &&
                ( destination->Host()->IsNativeFS() || !req_path.is_absolute() ) )
                 op = [op initWithFiles:move(*files.get())
                                   root:root_path.c_str()
                                   dest:req_path.c_str()
                                options:opts];
             else if(destination->Host()->IsNativeFS() && req_path.is_absolute() )
                 op = [op initWithFiles:move(*files.get())
                                   root:root_path.c_str()
                                rootvfs:source->Host()
                                   dest:req_path.c_str()
                                options:opts];
             else if( (destination->Host()->IsWriteable() && req_path.is_absolute()) ||
                     (source->Host()->IsWriteable()      &&!req_path.is_absolute())  )
                 op = [op initWithFiles:move(*files.get())
                                   root:root_path.c_str()
                                 srcvfs:source->Host()
                                   dest:req_path.c_str()
                                 dstvfs:destination->Host()
                                options:opts];
             else
                 op = nil;
             
             if(op)
             {
                 [op AddOnFinishHandler:^{
                     dispatch_to_main_queue( ^{
                         [(PanelController*)act RefreshDirectory];
                         [(PanelController*)opp RefreshDirectory];
                     });
                 }];
                 [m_OperationsController AddOperation:op];
             }
         }
     }];
}

- (IBAction)OnFileRenameMoveCommand:(id)sender{
    if(!self.activePanelController || !self.oppositePanelController) return;
    if([m_MainSplitView anyCollapsedOrOverlayed])
        return;
    const PanelData *source, *destination;
    source = &self.activePanelController.data;
    destination = &self.oppositePanelController.data;
    __weak PanelController *act = self.activePanelController;
    __weak PanelController *opp = self.oppositePanelController;
    
    if(!source->Host()->IsWriteable())
        return;
    
    auto files = make_shared<chained_strings>([self.activePanelController GetSelectedEntriesOrFocusedEntryWithoutDotDot]);
    if(files->empty())
        return;
    
    string dest_path = destination->DirectoryPathWithTrailingSlash();
    NSString *nsdirpath = [NSString stringWithUTF8String:dest_path.c_str()];
    
    MassCopySheetController *mc = [MassCopySheetController new];
    [mc ShowSheet:self.window initpath:nsdirpath iscopying:false items:files.get() handler:^(int _ret)
     {
         path root_path = source->DirectoryPathWithTrailingSlash();
         path req_path = mc.TextField.stringValue.fileSystemRepresentation;
         if(_ret == DialogResult::Copy && !req_path.empty())
         {
             FileCopyOperationOptions opts;
             opts.docopy = false;
             [mc FillOptions:&opts];
             
             FileCopyOperation *op = [FileCopyOperation alloc];
             if(source->Host()->IsNativeFS() &&
                ( destination->Host()->IsNativeFS() || !req_path.is_absolute() ) )
                 op = [op initWithFiles:move(*files.get())
                                   root:root_path.c_str()
                                   dest:req_path.c_str()
                                options:opts];
             else if( destination->Host()->IsWriteable() )
                 op = [op initWithFiles:move(*files.get())
                                   root:root_path.c_str()
                                 srcvfs:source->Host()
                                   dest:req_path.c_str()
                                 dstvfs:destination->Host()
                                options:opts];
             else
                 op = nil;
             
             
             if(op) {
                 [op AddOnFinishHandler:^{
                     dispatch_to_main_queue( ^{
                         [(PanelController*)act RefreshDirectory];
                         [(PanelController*)opp RefreshDirectory];
                     });
                 }];
                 [m_OperationsController AddOperation:op];
             }
         }
     }];
}

- (IBAction)OnFileRenameMoveAsCommand:(id)sender {
    
    // process only current cursor item
    if(!self.activePanelController || !self.oppositePanelController) return;
    if([m_MainSplitView isViewCollapsedOrOverlayed:self.activePanelView])
        return;
    
    const PanelData *source, *destination;
    source = &self.activePanelController.data;
    destination = &self.oppositePanelController.data;
    __weak PanelController *act = self.activePanelController;
    __weak PanelController *opp = self.oppositePanelController;
    
    if(!source->Host()->IsWriteable())
        return;
    
    auto const *item = self.activePanelView.item;
    if(!item || item->IsDotDot())
        return;
    
    auto files = make_shared<chained_strings>(item->Name());
    
    MassCopySheetController *mc = [MassCopySheetController new];
    [mc ShowSheet:self.window initpath:[NSString stringWithUTF8String:item->Name()] iscopying:false items:files.get() handler:^(int _ret)
     {
         path root_path = source->DirectoryPathWithTrailingSlash();
         path req_path = mc.TextField.stringValue.fileSystemRepresentation;
         if(_ret == DialogResult::Copy && !req_path.empty())
         {
             FileCopyOperationOptions opts;
             opts.docopy = false;
             [mc FillOptions:&opts];
             
             FileCopyOperation *op = [FileCopyOperation alloc];
             
             if(source->Host()->IsNativeFS() &&
                ( destination->Host()->IsNativeFS() || !req_path.is_absolute() ))
                 op = [op initWithFiles:move(*files.get())
                                   root:root_path.c_str()
                                   dest:req_path.c_str()
                                options:opts];
             else if( destination->Host()->IsWriteable() )
                 op = [op initWithFiles:move(*files.get())
                                   root:root_path.c_str()
                                 srcvfs:source->Host()
                                   dest:req_path.c_str()
                                 dstvfs:destination->Host()
                                options:opts];
             else
                 op = nil;
             
             if(op) {
                 string single_fn_rename;
                 if( req_path.native().find('/') == string::npos )
                     single_fn_rename = req_path.filename().native();
                 
                 [op AddOnFinishHandler:^{
                     dispatch_to_main_queue( ^{
                         PanelController* active = act;
                         [active RefreshDirectory];
                         [(PanelController*)opp RefreshDirectory];
                         PanelControllerDelayedSelection req;
                         req.filename = single_fn_rename;
                         [active ScheduleDelayedSelectionChangeFor:req checknow:true];
                     });
                 }];
                 [m_OperationsController AddOperation:op];
             }
         }
     }];
}

@end

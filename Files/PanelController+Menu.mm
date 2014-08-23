//
//  PanelController+Menu.m
//  Files
//
//  Created by Michael G. Kazakov on 24.05.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import "ActionsShortcutsManager.h"
#import "PanelController+Menu.h"
#import "common_paths.h"
#import "GoToFolderSheetController.h"
#import "FileSysAttrChangeOperation.h"
#import "FileSysEntryAttrSheetController.h"
#import "Common.h"
#import "MainWindowFilePanelState.h"
#import "DetailedVolumeInformationSheetController.h"
#import "FindFilesSheetController.h"
#import "MainWindowController.h"
#import "SelectionWithMaskSheetController.h"
#import "ExternalEditorInfo.h"
#import "FileDeletionSheetController.h"
#import "CreateDirectorySheetController.h"
#import "CreateDirectoryOperation.h"
#import "FTPConnectionSheetController.h"
#import "FileMask.h"

@implementation PanelController (Menu)

- (BOOL) validateMenuItem:(NSMenuItem *)item
{
    auto upd_for_sort = [](NSMenuItem * _item, PanelSortMode _mode, PanelSortMode::Mode _mask){
        static NSImage *img = [NSImage imageNamed:NSImageNameRemoveTemplate];
        if(_mode.sort & _mask) {
            _item.image = _mode.isrevert() ? img : nil;
            _item.state = NSOnState;
        }
        else {
            _item.image = nil;
            _item.state = NSOffState;
        }
    };
    
#define TAG(name, str) static const int name = ActionsShortcutsManager::Instance().TagFromAction(str)
    TAG(tag_short_mode,         "menu.view.toggle_short_mode");
    TAG(tag_medium_mode,        "menu.view.toggle_medium_mode");
    TAG(tag_full_mode,          "menu.view.toggle_full_mode");
    TAG(tag_wide_mode,          "menu.view.toggle_wide_mode");
    TAG(tag_sort_name,          "menu.view.sorting_by_name");
    TAG(tag_sort_ext,           "menu.view.sorting_by_extension");
    TAG(tag_sort_mod,           "menu.view.sorting_by_modify_time");
    TAG(tag_sort_size,          "menu.view.sorting_by_size");
    TAG(tag_sort_creat,         "menu.view.sorting_by_creation_time");
    TAG(tag_sort_viewhidden,    "menu.view.sorting_view_hidden");
    TAG(tag_sort_sepfolders,    "menu.view.sorting_separate_folders");
    TAG(tag_sort_casesens,      "menu.view.sorting_case_sensitive");
    TAG(tag_sort_numeric,       "menu.view.sorting_numeric_comparison");
    TAG(tag_go_back,            "menu.go.back");
    TAG(tag_go_forward,         "menu.go.forward");
    TAG(tag_go_up,              "menu.go.enclosing_folder");
    TAG(tag_go_down,            "menu.go.into_folder");
    TAG(tag_cmd_file_attrs,     "menu.command.file_attributes");
    TAG(tag_cmd_vol_info,       "menu.command.volume_information");
    TAG(tag_cmd_int_view,       "menu.command.internal_viewer");
    TAG(tag_cmd_ext_edit,       "menu.command.external_editor");
    TAG(tag_cmd_eject_vol,      "menu.command.eject_volume");
    TAG(tag_cmd_copy_filename,  "menu.command.copy_file_name");
    TAG(tag_cmd_copy_filepath,  "menu.command.copy_file_path");
    TAG(tag_cmd_move_to_trash,  "menu.command.move_to_trash");
    TAG(tag_cmd_delete,         "menu.command.delete");
    TAG(tag_cmd_delete_alt,     "menu.command.delete_alternative");
    TAG(tag_cmd_mkdir,          "menu.command.create_directory");
    TAG(tag_file_calc_sizes,    "menu.file.calculate_sizes");
#undef TAG
    
    auto tag = item.tag;
#define IF(a) else if(tag == a)
    if(false);
    IF(tag_short_mode)      item.state = m_View.type == PanelViewType::ViewShort;
    IF(tag_medium_mode)     item.state = m_View.type == PanelViewType::ViewMedium;
    IF(tag_full_mode)       item.state = m_View.type == PanelViewType::ViewFull;
    IF(tag_wide_mode)       item.state = m_View.type == PanelViewType::ViewWide;
    IF(tag_sort_viewhidden) item.state = m_Data.HardFiltering().show_hidden;
    IF(tag_sort_sepfolders) item.state = m_Data.SortMode().sep_dirs;
    IF(tag_sort_casesens)   item.state = m_Data.SortMode().case_sens;
    IF(tag_sort_numeric)    item.state = m_Data.SortMode().numeric_sort;
    IF(tag_sort_name)       upd_for_sort(item, m_Data.SortMode(), PanelSortMode::SortByNameMask);
    IF(tag_sort_ext)        upd_for_sort(item, m_Data.SortMode(), PanelSortMode::SortByExtMask);
    IF(tag_sort_mod)        upd_for_sort(item, m_Data.SortMode(), PanelSortMode::SortByMTimeMask);
    IF(tag_sort_size)       upd_for_sort(item, m_Data.SortMode(), PanelSortMode::SortBySizeMask);
    IF(tag_sort_creat)      upd_for_sort(item, m_Data.SortMode(), PanelSortMode::SortByBTimeMask);
    IF(tag_go_back)         return m_History.CanMoveBack();
    IF(tag_go_forward)      return m_History.CanMoveForth();
    IF(tag_go_up)           return self.GetCurrentDirectoryPathRelativeToHost != "/" || self.VFS->Parent() != nullptr;
    IF(tag_go_down)         return m_View.item && !m_View.item->IsDotDot();
    IF(tag_cmd_file_attrs)  return self.VFS->IsNativeFS() && m_View.item && !m_View.item->IsDotDot();
    IF(tag_cmd_vol_info)    return self.VFS->IsNativeFS();
    IF(tag_cmd_int_view)    return m_View.item && !m_View.item->IsDir();
    IF(tag_cmd_ext_edit)    return self.VFS->IsNativeFS() && m_View.item && !m_View.item->IsDotDot();
    IF(tag_cmd_eject_vol)   return self.VFS->IsNativeFS() && IsVolumeContainingPathEjectable(self.GetCurrentDirectoryPathRelativeToHost);
    IF(tag_file_calc_sizes) return m_View.item != nullptr;
    IF(tag_cmd_copy_filename) return m_View.item != nullptr;
    IF(tag_cmd_copy_filepath) return m_View.item != nullptr;
    IF(tag_cmd_move_to_trash) return m_View.item && (!m_View.item->IsDotDot() || m_Data.Stats().selected_entries_amount > 0) && (self.VFS->IsNativeFS() || self.VFS->IsWriteable());
    IF(tag_cmd_delete)      return m_View.item && (!m_View.item->IsDotDot() || m_Data.Stats().selected_entries_amount > 0) && (self.VFS->IsNativeFS() || self.VFS->IsWriteable());
    IF(tag_cmd_delete_alt)  return m_View.item && (!m_View.item->IsDotDot() || m_Data.Stats().selected_entries_amount > 0) && (self.VFS->IsNativeFS() || self.VFS->IsWriteable());
    IF(tag_cmd_mkdir)       return self.VFS->IsWriteable();
#undef IF
    
    return true; // will disable some items in the future
}

- (IBAction)OnGoBack:(id)sender {
    if(!m_History.CanMoveBack())
        return;
    m_History.MoveBack();
    [self GoToVFSPathStack:*m_History.Current()];
}

- (IBAction)OnGoForward:(id)sender {
    if(!m_History.CanMoveForth())
        return;
    m_History.MoveForth();
    [self GoToVFSPathStack:*m_History.Current()];
}

- (IBAction)OnGoToHome:(id)sender {
    if(![self ensureCanGoToNativeFolderSync:CommonPaths::Get(CommonPaths::Home)])
        return;
    [self GoToDir:CommonPaths::Get(CommonPaths::Home) vfs:VFSNativeHost::SharedHost() select_entry:"" async:true];
}

- (IBAction)OnGoToDocuments:(id)sender {
    if(![self ensureCanGoToNativeFolderSync:CommonPaths::Get(CommonPaths::Documents)])
        return;
    [self GoToDir:CommonPaths::Get(CommonPaths::Documents) vfs:VFSNativeHost::SharedHost() select_entry:"" async:true];
}

- (IBAction)OnGoToDesktop:(id)sender {
    if(![self ensureCanGoToNativeFolderSync:CommonPaths::Get(CommonPaths::Desktop)])
        return;
    [self GoToDir:CommonPaths::Get(CommonPaths::Desktop) vfs:VFSNativeHost::SharedHost() select_entry:"" async:true];
}

- (IBAction)OnGoToDownloads:(id)sender {
    if(![self ensureCanGoToNativeFolderSync:CommonPaths::Get(CommonPaths::Downloads)])
        return;
    [self GoToDir:CommonPaths::Get(CommonPaths::Downloads) vfs:VFSNativeHost::SharedHost() select_entry:"" async:true];
}

- (IBAction)OnGoToApplications:(id)sender {
    if(![self ensureCanGoToNativeFolderSync:CommonPaths::Get(CommonPaths::Applications)])
        return;
    [self GoToDir:CommonPaths::Get(CommonPaths::Applications) vfs:VFSNativeHost::SharedHost() select_entry:"" async:true];
}

- (IBAction)OnGoToUtilities:(id)sender {
    if(![self ensureCanGoToNativeFolderSync:CommonPaths::Get(CommonPaths::Utilities)])
        return;
    [self GoToDir:CommonPaths::Get(CommonPaths::Utilities) vfs:VFSNativeHost::SharedHost() select_entry:"" async:true];
}

- (IBAction)OnGoToLibrary:(id)sender {
    if(![self ensureCanGoToNativeFolderSync:CommonPaths::Get(CommonPaths::Library)])
        return;
    [self GoToDir:CommonPaths::Get(CommonPaths::Library) vfs:VFSNativeHost::SharedHost() select_entry:"" async:true];
}

- (IBAction)OnGoToProcessesList:(id)sender {
    [self GoToDir:"/" vfs:VFSPSHost::GetSharedOrNew() select_entry:"" async:true];
}

- (IBAction)OnGoToFolder:(id)sender {
    GoToFolderSheetController *sheet = [GoToFolderSheetController new];
    [sheet ShowSheet:self.window handler:^int(){
        string path = sheet.Text.stringValue.fileSystemRepresentation;
        assert(!path.empty());
        if(path[0] == '/'); // absolute path
        else if(path[0] == '~') // relative to home
            path.replace(0, 1, CommonPaths::Get(CommonPaths::Home));
        else // sub-dir
            path.insert(0, self.GetCurrentDirectoryPathRelativeToHost);

        // TODO: check reachability from sandbox
        
        return [self GoToDir:path
                         vfs:VFSNativeHost::SharedHost() // not sure if this is right, mb .VFS in case of sub-dir?
                select_entry:""
                       async:false];
    }];
}

- (IBAction)OnGoToUpperDirectory:(id)sender { // cmd+up
    [self HandleGoToUpperDirectory];
}

- (IBAction)OnGoIntoDirectory:(id)sender { // cmd+down
    auto item = m_View.item;
    if(item != nullptr && item->IsDotDot() == false)
        [self HandleGoIntoDirOrArchive];
}

- (IBAction) OnGoToFTP:(id)sender {
    FTPConnectionSheetController *sheet = [FTPConnectionSheetController new];
    [sheet ShowSheet:self.window
             handler:^{
                 m_DirectoryLoadingQ->Run(^{
                     if(sheet.server == nil)
                         return;
                     
                     string server =  sheet.server.UTF8String;
                     string username = sheet.username ? sheet.username.UTF8String : "";
                     string password = sheet.password ? sheet.password.UTF8String : "";
                     string path = sheet.path ? sheet.path.UTF8String : "/";
                     if(path.empty() || path[0] != '/')
                         path = "/";
                     
                     VFSNetFTPOptions opts;
                     opts.user = username;
                     opts.passwd = password;
                     if(sheet.port.intValue != 0)
                         opts.port = sheet.port.intValue;
                     
                     auto host = make_shared<VFSNetFTPHost>(server.c_str());
                     int ret = host->Open(path.c_str(), opts);
                     if(ret != 0)
                         return dispatch_async(dispatch_get_main_queue(), ^{
                             NSAlert *alert = [[NSAlert alloc] init];
                             alert.messageText = @"FTP connection error:";
                             alert.informativeText = VFSError::ToNSError(ret).localizedDescription;
                             [alert addButtonWithTitle:@"OK"];
                             [alert runModal];
                         });
                     dispatch_to_main_queue(^{
                         m_DirectoryLoadingQ->Wait(); // just to be sure that GoToDir will not exit immed due to non-empty loading que
                         [self GoToDir:path vfs:host select_entry:"" async:true];
                     });
                 });
             }];
}


- (IBAction)OnOpen:(id)sender { // enter
    [self HandleGoIntoDirOrOpenInSystem];
}

- (IBAction)OnOpenNatively:(id)sender { // shift+enter
    [self HandleOpenInSystem];
}

- (IBAction)OnFileAttributes:(id)sender {
    if(!m_Data.Host()->IsNativeFS())
        return; // currently support file info only on native fs
    
    FileSysEntryAttrSheetController *sheet = [FileSysEntryAttrSheetController new];
    FileSysEntryAttrSheetCompletionHandler handler = ^(int result){
        if(result == DialogResult::Apply)
            [self.state AddOperation:[[FileSysAttrChangeOperation alloc] initWithCommand:sheet.Result]];
    };
    
    if(m_Data.Stats().selected_entries_amount > 0 )
        [sheet ShowSheet:self.window selentries:&m_Data handler:handler];
    else if(m_View.item && !m_View.item->IsDotDot())
        [sheet ShowSheet:self.window
                    data:&m_Data
                   index:m_Data.RawIndexForSortIndex(m_View.curpos)
                 handler:handler];
}

- (IBAction)OnDetailedVolumeInformation:(id)sender {
    if(!m_Data.Host()->IsNativeFS())
        return; // currently support volume info only on native fs
    
    string path = self.GetCurrentDirectoryPathRelativeToHost;
    if(m_View.item && !m_View.item->IsDotDot())
        path += m_View.item->Name();
    
    [[DetailedVolumeInformationSheetController new] ShowSheet:self.window destpath:path.c_str()];
}

- (IBAction)performFindPanelAction:(id)sender {
    FindFilesSheetController *sheet = [FindFilesSheetController new];
    [sheet ShowSheet:self.window
             withVFS:self.VFS
            fromPath:self.GetCurrentDirectoryPathRelativeToHost
             handler:^{
                 if(auto item = sheet.SelectedItem)
                     [self GoToDir:item->dir_path vfs:self.VFS select_entry:item->filename async:true];
             }
     ];
}

- (IBAction)OnFileInternalBigViewCommand:(id)sender {
    if(!m_View.item || m_View.item->IsDir())
        return;
    string path = m_Data.DirectoryPathWithTrailingSlash() + m_View.item->Name();
    [(MainWindowController*)self.window.delegate RequestBigFileView:path with_fs:self.VFS];
}

- (IBAction)OnSelectByMask:(id)sender {
    SelectionWithMaskSheetController *sheet = [SelectionWithMaskSheetController new];
    [sheet ShowSheet:self.window handler:^{
        NSString *mask = sheet.Mask;
        if( !FileMask::IsWildCard(mask) )
            mask = FileMask::ToWildCard(mask);
        [self SelectEntriesByMask:mask select:true];
    }];
}

- (IBAction)OnDeselectByMask:(id)sender {
    SelectionWithMaskSheetController *sheet = [SelectionWithMaskSheetController new];
    [sheet SetIsDeselect:true];
    [sheet ShowSheet:self.window handler:^{
        NSString *mask = sheet.Mask;
        if( !FileMask::IsWildCard(mask) )
            mask = FileMask::ToWildCard(mask);        
        [self SelectEntriesByMask:mask select:false];
    }];
}

- (IBAction)OnEjectVolume:(id)sender {
    if(self.VFS->IsNativeFS() && IsVolumeContainingPathEjectable(self.GetCurrentDirectoryPathRelativeToHost))
        EjectVolumeContainingPath(self.GetCurrentDirectoryPathRelativeToHost);
}

- (IBAction)OnCopyCurrentFileName:(id)sender {
    [NSPasteboard writeSingleString:self.GetCurrentFocusedEntryFilename.c_str()];
}

- (IBAction)OnCopyCurrentFilePath:(id)sender {
    [NSPasteboard writeSingleString:self.GetCurrentFocusedEntryFilePathRelativeToHost.c_str()];
}

- (IBAction)OnBriefSystemOverviewCommand:(id)sender {
    if(m_BriefSystemOverview) {
        [self.state CloseOverlay:self];
        m_BriefSystemOverview = nil;
        return;
    }
    m_BriefSystemOverview = [self.state RequestBriefSystemOverview:self];
    [self UpdateBriefSystemOverview];
}

- (IBAction)OnFileViewCommand:(id)sender
{
    // Close quick preview, if it is open.
    if(m_QuickLook) {
        [self.state CloseOverlay:self];
        m_QuickLook = nil;
        return;
    }
    
    m_QuickLook = [self.state RequestQuickLookView:self];
    [self OnCursorChanged];
}

- (void)selectAll:(id)sender {
    [self SelectAllEntries:true];
}

- (void)deselectAll:(id)sender {
    [self SelectAllEntries:false];
}

- (IBAction)OnRefreshPanel:(id)sender {
    [self RefreshDirectory];
}

- (IBAction)OnCalculateSizes:(id)sender {
    // suboptimal - may have regular files inside (not dirs)
    [self CalculateSizesWithNames:self.GetSelectedEntriesOrFocusedEntryWithDotDot];
}

- (IBAction)OnCalculateAllSizes:(id)sender {
    chained_strings filenames;
    for(auto &i: *m_Data.Listing())
        if(i.IsDir() && !i.IsDotDot())
            filenames.push_back(i.Name(), nullptr);
    
    [self CalculateSizesWithNames:move(filenames)];
}

- (IBAction)ToggleViewHiddenFiles:(id)sender{
    auto filtering = m_Data.HardFiltering();
    filtering.show_hidden = !filtering.show_hidden;
    [self ChangeHardFilteringTo:filtering];
    [self.state savePanelOptionsFor:self];
}
- (IBAction)ToggleSeparateFoldersFromFiles:(id)sender{
    PanelSortMode mode = m_Data.SortMode();
    mode.sep_dirs = !mode.sep_dirs;
    [self ChangeSortingModeTo:mode];
    [self.state savePanelOptionsFor:self];
}
- (IBAction)ToggleCaseSensitiveComparison:(id)sender{
    PanelSortMode mode = m_Data.SortMode();
    mode.case_sens = !mode.case_sens;
    [self ChangeSortingModeTo:mode];
    [self.state savePanelOptionsFor:self];
}
- (IBAction)ToggleNumericComparison:(id)sender{
    PanelSortMode mode = m_Data.SortMode();
    mode.numeric_sort = !mode.numeric_sort;
    [self ChangeSortingModeTo:mode];
    [self.state savePanelOptionsFor:self];
}
- (IBAction)ToggleSortByName:(id)sender{
    [self MakeSortWith:PanelSortMode::SortByName Rev:PanelSortMode::SortByNameRev];
}
- (IBAction)ToggleSortByExt:(id)sender{
    [self MakeSortWith:PanelSortMode::SortByExt Rev:PanelSortMode::SortByExtRev];
}
- (IBAction)ToggleSortByMTime:(id)sender{
    [self MakeSortWith:PanelSortMode::SortByMTime Rev:PanelSortMode::SortByMTimeRev];
}
- (IBAction)ToggleSortBySize:(id)sender{
    [self MakeSortWith:PanelSortMode::SortBySize Rev:PanelSortMode::SortBySizeRev];
}
- (IBAction)ToggleSortByBTime:(id)sender{
    [self MakeSortWith:PanelSortMode::SortByBTime Rev:PanelSortMode::SortByBTimeRev];
}
- (IBAction)ToggleShortViewMode:(id)sender {
    m_View.type = PanelViewType::ViewShort;
    [self.state savePanelOptionsFor:self];
}
- (IBAction)ToggleMediumViewMode:(id)sender {
    m_View.type = PanelViewType::ViewMedium;
    [self.state savePanelOptionsFor:self];
}
- (IBAction)ToggleFullViewMode:(id)sender{
    m_View.type = PanelViewType::ViewFull;
    [self.state savePanelOptionsFor:self];
}
- (IBAction)ToggleWideViewMode:(id)sender{
    m_View.type = PanelViewType::ViewWide;
    [self.state savePanelOptionsFor:self];
}

- (IBAction)OnOpenWithExternalEditor:(id)sender {
    if(self.VFS->IsNativeFS() == false)
        return;
    
    auto item = m_View.item;
    if(item == nullptr || item->IsDotDot())
        return;
    
    ExternalEditorInfo *ed = [ExternalEditorsList.sharedList FindViableEditorForItem:*item];
    if(ed == nil) {
        NSBeep();
        return;
    }
    
    string fn_path = self.GetCurrentDirectoryPathRelativeToHost + item->Name();
    if(ed.terminal == false) {
        if (![NSWorkspace.sharedWorkspace openFile:[NSString stringWithUTF8String:fn_path.c_str()]
                                   withApplication:ed.path
                                     andDeactivate:true])
            NSBeep();
    }
    else {
        MainWindowController* wnd = (MainWindowController*)self.window.delegate;
        [wnd RequestExternalEditorTerminalExecution:ed.path.fileSystemRepresentation
                                             params:[ed substituteFileName:fn_path]
                                               file:fn_path
         ];
    }
}

- (void)DeleteFiles:(BOOL)_shift_behavior
{
    auto files = make_shared<chained_strings>(self.GetSelectedEntriesOrFocusedEntryWithoutDotDot);
    if(files->empty())
        return;
    
    if(self.VFS->IsNativeFS())
    {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        
        FileDeletionOperationType type = (FileDeletionOperationType)(_shift_behavior
                                                                     ? [defaults integerForKey:@"FilePanelsShiftDeleteBehavior"]
                                                                     : [defaults integerForKey:@"FilePanelsDeleteBehavior"]);
        
        FileDeletionSheetController *sheet = [[FileDeletionSheetController alloc] init];
        [sheet ShowSheet:self.window Files:files.get() Type:type
                 Handler:^(int result){
                     if (result == DialogResult::Delete)
                     {
                         FileDeletionOperationType type = [sheet GetType];
                         
                         string root_path = m_Data.DirectoryPathWithTrailingSlash();
                         
                         FileDeletionOperation *op = [[FileDeletionOperation alloc]
                                                      initWithFiles:move(*files.get())
                                                      type:type
                                                      rootpath:root_path.c_str()];
                         op.TargetPanel = self;
                         [self.state AddOperation:op];
                     }
                 }];
    }
    else if(self.VFS->IsWriteable())
    {
        FileDeletionSheetController *sheet = [[FileDeletionSheetController alloc] init];
        [sheet ShowSheetForVFS:self.window
                         Files:files.get()
                       Handler:^(int result){
                           if (result == DialogResult::Delete)
                           {
                               string root_path = m_Data.DirectoryPathWithTrailingSlash();
                               FileDeletionOperation *op = [[FileDeletionOperation alloc]
                                                            initWithFiles:move(*files.get())
                                                            rootpath:root_path
                                                            at:self.VFS];
                               op.TargetPanel = self;
                               [self.state AddOperation:op];
                           }
                       }];
    }
}

- (IBAction)OnDeleteCommand:(id)sender
{
    [self DeleteFiles:NO];
}

- (IBAction)OnAlternativeDeleteCommand:(id)sender
{
    [self DeleteFiles:YES];
}

- (IBAction)OnMoveToTrash:(id)sender
{
    if(self.VFS->IsNativeFS() == false &&
       self.VFS->IsWriteable() == true )
    {
        // instead of trying to silently reap files on VFS like FTP (that means we'll erase it, not move to trash) -
        // forward request as a regular F8 delete
        [self OnDeleteCommand:self];
        return;
    }
    
    auto files = self.GetSelectedEntriesOrFocusedEntryWithoutDotDot;
    if(files.empty())
        return;
    
    FileDeletionOperation *op = [[FileDeletionOperation alloc]
                                 initWithFiles:move(files)
                                 type:FileDeletionOperationType::MoveToTrash
                                 rootpath:m_Data.DirectoryPathWithTrailingSlash().c_str()];
    op.TargetPanel = self;
    [self.state AddOperation:op];
}

- (IBAction)OnCreateDirectoryCommand:(id)sender
{
    CreateDirectorySheetController *cd = [CreateDirectorySheetController new];
    [cd ShowSheet:self.window handler:^(int _ret)
     {
         if(_ret == DialogResult::Create &&
            cd.TextField.stringValue.fileSystemRepresentation)
         {
             string pdir = m_Data.DirectoryPathWithoutTrailingSlash();
             
             CreateDirectoryOperation *op = [CreateDirectoryOperation alloc];
             if(self.VFS->IsNativeFS())
                 op = [op initWithPath:cd.TextField.stringValue.fileSystemRepresentation
                              rootpath:pdir.c_str()
                       ];
             else
                 op = [op initWithPath:cd.TextField.stringValue.fileSystemRepresentation
                              rootpath:pdir.c_str()
                                    at:self.VFS
                       ];
             op.TargetPanel = self;
             [self.state AddOperation:op];
         }
     }];
}

@end

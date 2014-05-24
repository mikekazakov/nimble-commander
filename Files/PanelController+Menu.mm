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
#undef TAG
    
    NSInteger tag = item.tag;
#define IF(a) else if(tag == a)
    if(false) void();
    IF(tag_short_mode)      item.State = m_View.type == PanelViewType::ViewShort;
    IF(tag_medium_mode)     item.State = m_View.type == PanelViewType::ViewMedium;
    IF(tag_full_mode)       item.State = m_View.type == PanelViewType::ViewFull;
    IF(tag_wide_mode)       item.State = m_View.type == PanelViewType::ViewWide;
    IF(tag_sort_viewhidden) item.State = m_Data.HardFiltering().show_hidden;
    IF(tag_sort_sepfolders) item.State = m_Data.SortMode().sep_dirs;
    IF(tag_sort_casesens)   item.State = m_Data.SortMode().case_sens;
    IF(tag_sort_numeric)    item.State = m_Data.SortMode().numeric_sort;
    IF(tag_sort_name)       upd_for_sort(item, m_Data.SortMode(), PanelSortMode::SortByNameMask);
    IF(tag_sort_ext)        upd_for_sort(item, m_Data.SortMode(), PanelSortMode::SortByExtMask);
    IF(tag_sort_mod)        upd_for_sort(item, m_Data.SortMode(), PanelSortMode::SortByMTimeMask);
    IF(tag_sort_size)       upd_for_sort(item, m_Data.SortMode(), PanelSortMode::SortBySizeMask);
    IF(tag_sort_creat)      upd_for_sort(item, m_Data.SortMode(), PanelSortMode::SortByBTimeMask);
    IF(tag_go_back)         return m_History.CanMoveBack();
    IF(tag_go_forward)      return m_History.CanMoveForth();
    IF(tag_go_up)           return self.GetCurrentDirectoryPathRelativeToHost != "/" || self.VFS->Parent() != nullptr;
    IF(tag_go_down)         return m_View.item && !m_View.item->IsDotDot();
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
    [self GoToDir:CommonPaths::Get(CommonPaths::Home) vfs:VFSNativeHost::SharedHost() select_entry:"" async:true];
}

- (IBAction)OnGoToDocuments:(id)sender {
    [self GoToDir:CommonPaths::Get(CommonPaths::Documents) vfs:VFSNativeHost::SharedHost() select_entry:"" async:true];
}

- (IBAction)OnGoToDesktop:(id)sender {
    [self GoToDir:CommonPaths::Get(CommonPaths::Desktop) vfs:VFSNativeHost::SharedHost() select_entry:"" async:true];
}

- (IBAction)OnGoToDownloads:(id)sender {
    [self GoToDir:CommonPaths::Get(CommonPaths::Downloads) vfs:VFSNativeHost::SharedHost() select_entry:"" async:true];
}

- (IBAction)OnGoToApplications:(id)sender {
    [self GoToDir:CommonPaths::Get(CommonPaths::Applications) vfs:VFSNativeHost::SharedHost() select_entry:"" async:true];
}

- (IBAction)OnGoToUtilities:(id)sender {
    [self GoToDir:CommonPaths::Get(CommonPaths::Utilities) vfs:VFSNativeHost::SharedHost() select_entry:"" async:true];
}

- (IBAction)OnGoToLibrary:(id)sender {
    [self GoToDir:CommonPaths::Get(CommonPaths::Library) vfs:VFSNativeHost::SharedHost() select_entry:"" async:true];
}

- (IBAction)OnGoToProcessesList:(id)sender {
    [self GoToDir:"/" vfs:VFSPSHost::GetSharedOrNew() select_entry:"" async:true];
}

- (IBAction)OnGoToFolder:(id)sender {
    GoToFolderSheetController *sheet = [GoToFolderSheetController new];
    [sheet ShowSheet:self.window handler:^int(){
        string path = [sheet.Text.stringValue fileSystemRepresentation];
        assert(!path.empty());
        if(path[0] == '/'); // absolute path
        else if(path[0] == '~') // relative to home
            path.replace(0, 1, CommonPaths::Get(CommonPaths::Home));
        else // sub-dir
            path.insert(0, self.GetCurrentDirectoryPathRelativeToHost);

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

@end

#pragma once

#include "../../vfs/VFS.h"
#include "../../OperationJob.h"
#include "Options.h"
#include "DialogResults.h"

class FileDeletionOperationJobNew : public OperationJob
{
public:
    void Init(vector<VFSListingItem> _files, FileDeletionOperationType _type);
    
    void ToggleSkipAll();    
    
private:
    enum class StepResult
    {
        // operation was successful
        Ok = 0,
        
        // user asked us to stop
        Stop,
        
        // an error has occured, but current step was skipped since user asked us to do so or if SkipAll flag is on
        Skipped,
        
        // an error has occured, but current step was skipped since user asked us to do so and to skip any other errors
        SkipAll
    };
    
    class SourceItems
    {
    public:
        int             InsertItem( uint16_t _host_index, unsigned _base_dir_index, int _parent_index, string _item_name, const VFSStat &_stat );
        
        //        uint64_t        TotalRegBytes() const noexcept;
        int             ItemsAmount() const noexcept;
        //
        string          ComposeFullPath( int _item_no ) const;
        string          ComposeRelativePath( int _item_no ) const;
        const string&   ItemName( int _item_no ) const;
        mode_t          ItemMode( int _item_no ) const;
        //        uint64_t        ItemSize( int _item_no ) const;
        //        dev_t           ItemDev( int _item_no ) const; // meaningful only for native vfs (yet?)
        VFSHost        &ItemHost( int _item_no ) const;
        //
        VFSHost &Host( uint16_t _host_ind ) const;
        uint16_t InsertOrFindHost( const VFSHostPtr &_host );
        
        const string &BaseDir( unsigned _base_dir_ind ) const;
        unsigned InsertOrFindBaseDir( const string &_dir );
        
        
    private:
        struct SourceItem
        {
            // full path = m_SourceItemsBaseDirectories[base_dir_index] + ... + m_Items[m_Items[parent_index].parent_index].item_name +  m_Items[parent_index].item_name + item_name;
            string      item_name;
            int         parent_index;
            unsigned    base_dir_index;
            uint16_t    host_index;
            uint16_t    mode;
        };
        
        vector<SourceItem>                      m_Items;
        vector<VFSHostPtr>                      m_SourceItemsHosts;
        vector<string>                          m_SourceItemsBaseDirectories;
    };
    
    virtual void Do() override;
    void            DoScan();
    void            DoProcess();
    StepResult      DoVFSDelete(VFSHost &_host, const string& _path, uint16_t _mode) const;
    StepResult      DoNativeDelete(const string& _path, uint16_t _mode) const;
    StepResult      DoNativeTrash(const string& _path, uint16_t _mode) const;
    
    static int      TrashItem(const string& _path, uint16_t _mode);

    
    
    vector<VFSListingItem>      m_OriginalItems;
    SourceItems                 m_SourceItems;
    vector<int>                 m_DeleteOrder;

    FileDeletionOperationType   m_Type = FileDeletionOperationType::MoveToTrash;
    bool                        m_SkipAll = false;
    
public:
    
//    namespace FileDeletionOperationDR
//    {
//        using namespace OperationDialogResult;
//        
//        constexpr int DeletePermanently = Custom + 1;
//    }
    
    // expect: FileDeletionOperationDR::Retry, FileDeletionOperationDR::Skip, FileDeletionOperationDR::SkipAll, FileDeletionOperationDR::Stop
    function<int(int _vfs_error, string _path)> m_OnCantUnlink
        = [](int, string){ return FileDeletionOperationDR::Stop; };
    
    // expect: FileDeletionOperationDR::Retry, FileDeletionOperationDR::Skip, FileDeletionOperationDR::SkipAll, FileDeletionOperationDR::Stop
    function<int(int _vfs_error, string _path)> m_OnCantRmdir
        = [](int, string){ return FileDeletionOperationDR::Stop; };

    // expect: FileDeletionOperationDR::DeletePermanently, FileDeletionOperationDR::Retry, FileDeletionOperationDR::Skip, FileDeletionOperationDR::SkipAll, FileDeletionOperationDR::Stop
    function<int(int _vfs_error, string _path)> m_OnCantTrash
        = [](int, string){ return FileDeletionOperationDR::Stop; };
    
//    
//    int result = [[m_Operation DialogOnUnlinkError:ErrnoToNSError() ForPath:_full_path] WaitForResult];
//    if (result == OperationDialogResult::Retry) goto retry_unlink;
//    else if (result == OperationDialogResult::SkipAll) m_SkipAll = true;
//    else if (result == OperationDialogResult::Stop) RequestStop();
};

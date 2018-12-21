// Copyright (C) 2014-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Habanero/Hash.h>
#include <Habanero/SerialQueue.h>
#include <NimbleCommander/Bootstrap/Config.h>
#include <NimbleCommander/Core/Alert.h>
#include <NimbleCommander/Core/GoogleAnalytics.h>
#include <NimbleCommander/Core/Theming/CocoaAppearanceManager.h>
#include "CalculateChecksumSheetController.h"
#include <numeric>

static const auto g_ConfigAlgo = "filePanel.general.checksumCalculationAlgorithm";
const static std::string g_SumsFilename = "checksums.txt";

const static std::vector<std::pair<NSString*,int>> g_Algos = {
    {@"Adler32",     Hash::Adler32},
    {@"CRC32",       Hash::CRC32},
    {@"MD2",         Hash::MD2},
    {@"MD4",         Hash::MD4},
    {@"MD5",         Hash::MD5},
    {@"SHA1-160",    Hash::SHA1_160},
    {@"SHA2-224",    Hash::SHA2_224},
    {@"SHA2-256",    Hash::SHA2_256},
    {@"SHA2-384",    Hash::SHA2_384},
    {@"SHA2-512",    Hash::SHA2_512},
};

@implementation CalculateChecksumSheetController
{
    VFSHostPtr          m_Host;
    std::vector<std::string> m_Filenames;
    std::vector<uint64_t>m_Sizes;
    std::vector<std::string> m_Checksums;
    std::vector<std::string> m_Errors;
    std::string              m_Path;
    SerialQueue         m_WorkQue;
    uint64_t            m_TotalSize;
}

- (id)initWithFiles:(std::vector<std::string>)files
          withSizes:(std::vector<uint64_t>)sizes
             atHost:(const VFSHostPtr&)host
             atPath:(std::string)path
{
    self = [super init];
    if(self) {
        m_Host = host;
        m_Filenames = files;
        m_Sizes = sizes;
        m_TotalSize = std::accumulate(begin(m_Sizes), end(m_Sizes), 0ull);
        assert(files.size() == sizes.size());
        m_Checksums.resize(m_Filenames.size());
        m_Errors.resize(m_Filenames.size());
        m_Path = path;
        self.isWorking = false;
        self.sumsAvailable = false;
        self.didSaved = false;
        m_WorkQue.SetOnWet([=]{
            dispatch_to_main_queue([self]{
                self.isWorking = true;
                self.sumsAvailable = false;
            });
        });
        m_WorkQue.SetOnDry([=]{
            dispatch_to_main_queue([self]{
                self.isWorking = false;
                self.sumsAvailable = count_if(begin(m_Checksums), end(m_Checksums), [](auto &i){return !i.empty();}) > 0;
            });
        });
    }
    return self;
}

- (IBAction)OnCalc:(id)sender
{
    if( !m_WorkQue.Empty() )
        return;

    GlobalConfig().Set(g_ConfigAlgo, self.HashMethod.titleOfSelectedItem.UTF8String);
    
    const int chunk_sz = 16*1024*1024;

    int method = g_Algos[self.HashMethod.indexOfSelectedItem].second;
    self.Progress.doubleValue = 0;
    
    m_WorkQue.Run([=]{
        auto buf = std::make_unique<uint8_t[]>(chunk_sz);
        uint64_t total_fed = 0;
        for(auto &i:m_Filenames) {
            if( m_WorkQue.IsStopped() )
                break;
            const auto item_index = int(&i - &m_Filenames[0]); 
            
            VFSFilePtr file;
            int rc = m_Host->CreateFile((boost::filesystem::path(m_Path) / i).c_str(),
                                        file,
                                        [self]{ return m_WorkQue.IsStopped(); } );
            if(rc != 0) {
                dispatch_to_main_queue([self, rc, item_index]{
                    [self reportError:rc forFilenameAtIndex:item_index];
                });
                continue;
            }
            
            rc = file->Open( VFSFlags::OF_Read | VFSFlags::OF_ShLock | VFSFlags::OF_NoCache,
                            [self]{ return m_WorkQue.IsStopped(); } );
            if(rc != 0) {
                dispatch_to_main_queue([self, rc, item_index]{
                    [self reportError:rc forFilenameAtIndex:item_index];
                });
                continue;
            }

            Hash h( (Hash::Mode)method );
            
            ssize_t rn = 0;
            while( (rn = file->Read(buf.get(), chunk_sz)) > 0) {
                if(m_WorkQue.IsStopped())
                    break;
                h.Feed(buf.get(), rn);
                total_fed += rn;
                dispatch_to_main_queue([self, progress = double(total_fed)]{                
                    self.Progress.doubleValue = progress;
                });
            }
            
            if( rn < 0 ) {
                dispatch_to_main_queue([self, rn, item_index]{
                    [self reportError:(int)rn forFilenameAtIndex:item_index];
                });
                continue;
            }
        
            auto result = h.Final();
            
            dispatch_to_main_queue([self, result=std::move(result), item_index]{
                [self reportChecksum:Hash::Hex(result) forFilenameAtIndex:item_index];
            });
        }
    });
    
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    CocoaAppearanceManager::Instance().ManageWindowApperance(self.window);
    
    for(auto &i:g_Algos)
        [self.HashMethod addItemWithTitle:i.first];
    
    NSString *def_algo = @"MD5";
    if( GlobalConfig().Has(g_ConfigAlgo) )
        def_algo = [NSString stringWithUTF8String:GlobalConfig().GetString(g_ConfigAlgo).c_str()];
    [self.HashMethod selectItemWithTitle:def_algo];
    
    self.Table.delegate = self;
    self.Table.dataSource = self;

    NSTableColumn *column = self.filenameTableColumn;
    [self.Table addTableColumn:column];
    
    column = self.checksumTableColumn;
    [self.Table addTableColumn:column];
    
    column = [[NSTableColumn alloc] initWithIdentifier:@"dummy"];
    column.width = 10;
    column.minWidth = 10;
    column.maxWidth = 10;
    ((NSTableHeaderCell*)column.headerCell).stringValue = @"";    
    [self.Table addTableColumn:column];
    
    self.Progress.doubleValue = 0;
    self.Progress.minValue = 0;
    self.Progress.maxValue = double(m_TotalSize);
    self.Progress.controlSize = NSMiniControlSize;
    [self.Progress setIndeterminate:false];
    
    GA().PostScreenView("Calculate Checksum");
}

- (IBAction)OnClose:(id)sender
{
    m_WorkQue.Stop();
    m_WorkQue.Wait();
    [self endSheet:NSModalResponseCancel];
}

- (void)reportChecksum:(std::string)checksum forFilenameAtIndex:(int)ind
{
    m_Checksums[ind] = checksum;
    [self.Table reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:ind]
                          columnIndexes:[NSIndexSet indexSetWithIndex:1]];
}

- (void)reportError:(int)error forFilenameAtIndex:(int)ind
{
    m_Errors[ind] = [NSString stringWithFormat:@"Error: %@", VFSError::ToNSError(error).localizedDescription].UTF8String;
    [self.Table reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:ind]
                          columnIndexes:[NSIndexSet indexSetWithIndex:1]];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return m_Filenames.size();
}

- (NSView *)tableView:(NSTableView *)tableView
   viewForTableColumn:(NSTableColumn *)tableColumn
                  row:(NSInteger)row
{
    auto mktf = []{
        NSTextField *tf = [[NSTextField alloc] initWithFrame:NSRect()];
        tf.bordered = false;
        tf.editable = false;
        tf.selectable = true;
        tf.drawsBackground = false;
        [[tf cell] setLineBreakMode:NSLineBreakByTruncatingTail];
        return tf;
    };
    
    assert(row < (int)m_Filenames.size());
    if([tableColumn.identifier isEqualToString:@"filename"]) {
        NSTextField *tf = mktf();
        tf.stringValue = [NSString stringWithUTF8String:m_Filenames[row].c_str()];
        return tf;
    }
    if([tableColumn.identifier isEqualToString:@"checksum"]) {
        NSString *val;
        if(!m_Checksums[row].empty()) val = [NSString stringWithUTF8String:m_Checksums[row].c_str()];
        if(!val && !m_Errors[row].empty()) val = [NSString stringWithUTF8String:m_Errors[row].c_str()];
        if(!val) val = @"";

        NSTextField *tf = mktf();
        tf.stringValue = val;
        return tf;
    }
    return nil;
}

- (IBAction)OnSave:(id)sender
{
    // currently doing all stuff on main thread synchronously. may be bad for some vfs like ftp
    std::string str;
    for(auto &i: m_Checksums)
        if(!i.empty())
            str += i + "  " + m_Filenames[ &i-&m_Checksums[0] ] + "\n";
  
    if(str.empty())
        return;
    
    VFSFilePtr file;
    m_Host->CreateFile( (boost::filesystem::path(m_Path) / g_SumsFilename).c_str(), file);
    int rc = file->Open(VFSFlags::OF_Write | VFSFlags::OF_NoExist | VFSFlags::OF_Create | S_IWUSR | S_IRUSR | S_IRGRP );
    if(rc < 0) {
        [[Alert alertWithError:VFSError::ToNSError(rc)] runModal];
        return;
    }
    
    rc = file->WriteFile(str.data(), str.size());
    if(rc < 0)
        [[Alert alertWithError:VFSError::ToNSError(rc)] runModal];
    
    self.didSaved = true;
}

- (std::string) savedFilename
{
    return g_SumsFilename;
}

@end

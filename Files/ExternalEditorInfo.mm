//
//  ExternalEditorInfo.m
//  Files
//
//  Created by Michael G. Kazakov on 31.03.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import "3rd_party/NSFileManager+DirectoryLocations.h"
#import "ExternalEditorInfo.h"
#import "FileMask.h"

static NSString *g_FileName = @"/externaleditors.bplist"; // bplist file name
static ExternalEditorsList* g_SharedList = nil;

static NSString* StorageFileName()
{
    return [NSFileManager.defaultManager.applicationSupportDirectory stringByAppendingString:g_FileName];
}

@implementation ExternalEditorInfo
{
    NSString    *m_Name;
    NSString    *m_Path;
    NSString    *m_Arguments;
    NSString    *m_Mask;
    bool        m_OnlyFiles;
    bool        m_Terminal;
    uint64_t    m_MaxSize;
    
    unique_ptr<FileMask> m_FileMask;
}

@synthesize name = m_Name;
@synthesize path = m_Path;
@synthesize arguments = m_Arguments;
@synthesize mask = m_Mask;
@synthesize only_files = m_OnlyFiles;
@synthesize terminal = m_Terminal;
@synthesize max_size = m_MaxSize;

/*
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *path;
@property (nonatomic, strong) NSString *arguments;
@property (nonatomic, strong) NSString *mask;
@property (nonatomic) bool only_files;
@property (nonatomic) uint64_t max_size;
@property (nonatomic) bool terminal;
*/

- (id) init
{
    if(self = [super init])
    {
        self.name = @"";    
        self.path = @"";
        self.arguments = @"";
        self.mask = @"";
        self.only_files = false;
        self.max_size = 0;
        self.terminal = false;
    }
    return self;
}

- (id) initWithCoder:(NSCoder *)decoder
{
    if(self = [super init])
    {
        // redundant, rewrite
        self.name = @"";
        self.path = @"";
        self.arguments = @"";
        self.mask = @"";
        self.only_files = false;
        self.max_size = 0;
        self.terminal = false;
        
        
        if([decoder containsValueForKey:@"name"])
            self.name = [decoder decodeObjectForKey:@"name"];
        if([decoder containsValueForKey:@"path"])
            self.path = [decoder decodeObjectForKey:@"path"];
        if([decoder containsValueForKey:@"arguments"])
            self.arguments = [decoder decodeObjectForKey:@"arguments"];
        if([decoder containsValueForKey:@"mask"])
            self.mask = [decoder decodeObjectForKey:@"mask"];
        if([decoder containsValueForKey:@"only_files"])
            self.only_files = [decoder decodeBoolForKey:@"only_files"];
        if([decoder containsValueForKey:@"max_size"])
            self.max_size = [decoder decodeInt64ForKey:@"max_size"];
        if([decoder containsValueForKey:@"terminal"])
            self.terminal = [decoder decodeBoolForKey:@"terminal"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeObject:self.name forKey:@"name"];
    [encoder encodeObject:self.path forKey:@"path"];
    [encoder encodeObject:self.arguments forKey:@"arguments"];
    [encoder encodeObject:self.mask forKey:@"mask"];
    [encoder encodeBool:self.only_files forKey:@"only_files"];
    [encoder encodeInt64:self.max_size forKey:@"max_size"];
    [encoder encodeBool:self.terminal forKey:@"terminal"];
}

- (bool) isValidItem:(const VFSListingItem&)_it
{
    if(m_FileMask)
    {
        if(m_FileMask->MatchName((__bridge NSString*)_it.CFName()) == false)
            return false;
    }
    
    if(m_OnlyFiles == true && _it.IsReg() == false)
        return false;
    
    if(m_OnlyFiles == true &&
       m_MaxSize > 0 &&
       _it.Size() > m_MaxSize)
        return false;
    
    return true;
}

- (void) setMask:(NSString *)mask
{
    if([m_Mask isEqualToString:mask])
        return;
    
    [self willChangeValueForKey:@"mask"];
    m_Mask = mask;
    [self didChangeValueForKey:@"mask"];
    
    if(m_Mask == nil || m_Mask.length == 0)
        m_FileMask.reset();
    else
        m_FileMask = make_unique<FileMask>(m_Mask);
}

@end


@implementation ExternalEditorsList
{
    NSMutableArray *m_Editors;
    bool m_IsDirty;
}

- (id) init
{
    if(self = [super init])
    {
        m_IsDirty = false;
        
        // try to load history from file
        m_Editors = [NSKeyedUnarchiver unarchiveObjectWithFile:StorageFileName()];
        if(m_Editors == nil)
        {
            m_Editors = [NSMutableArray new];
            
            
            ExternalEditorInfo *dummy = [ExternalEditorInfo new];
            dummy.name = @"vi";
            dummy.path = @"/usr/bin/vi";
            dummy.arguments = @"%%";
            dummy.mask = @"*";
            dummy.terminal = true;

/*            dummy.name = @"TextEdit";
            dummy.path = @"/Applications/TextEdit.app";
            dummy.mask = @"*";
             dummy.terminal = false;*/
            
            [m_Editors addObject:dummy];
            m_IsDirty = true;
        }
        
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(OnTerminate:)
                                                   name:NSApplicationWillTerminateNotification
                                                 object:NSApplication.sharedApplication];
    }
    return self;
}

- (void) dealloc
{
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

+ (ExternalEditorsList*) sharedList
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        g_SharedList = [ExternalEditorsList new];
    });
    
    return g_SharedList;
}

- (void)OnTerminate:(NSNotification *)note
{
    if(m_IsDirty)
        [NSKeyedArchiver archiveRootObject:m_Editors toFile:StorageFileName()];
}

- (ExternalEditorInfo*) FindViableEditorForItem:(const VFSListingItem&)_item
{
    for(ExternalEditorInfo *ed in m_Editors)
        if([ed isValidItem:_item])
            return ed;
    return nil;
}

@end

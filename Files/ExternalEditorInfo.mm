//
//  ExternalEditorInfo.m
//  Files
//
//  Created by Michael G. Kazakov on 31.03.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#include "3rd_party/NSFileManager+DirectoryLocations.h"
#include "States/Terminal/TermSingleTask.h"
#include "../NimbleCommander/Core/FileMask.h"
#include "ExternalEditorInfo.h"
#include "ActivationManager.h"

static NSString *g_FileName = @"/externaleditors.bplist"; // bplist file name

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

-(id)copyWithZone:(NSZone *)zone
{
    ExternalEditorInfo *copy = [[ExternalEditorInfo alloc] init];
    copy.name = [self.name copyWithZone:zone];
    copy.path = [self.path copyWithZone:zone];
    copy.arguments = [self.arguments copyWithZone:zone];
    copy.mask = [self.mask copyWithZone:zone];
    copy.only_files = self.only_files;
    copy.max_size = self.max_size;
    copy.terminal = self.terminal;
    return copy;
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
    if(m_FileMask == nullptr)
        return false;
    
    if(m_FileMask->MatchName(_it.NSName()) == false)
        return false;
    
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

- (string) substituteFileName:(const string &)_path
{
    char esc_buf[MAXPATHLEN];
    strcpy(esc_buf, _path.c_str());
    TermSingleTask::EscapeSpaces(esc_buf);
    
    if(m_Arguments.length == 0)
        return esc_buf; // just return escaped file path
    
    string args = m_Arguments.fileSystemRepresentation;
    string path = " "s + esc_buf + " ";

    size_t start_pos;
    if((start_pos = args.find("%%")) != std::string::npos)
        args.replace(start_pos, 2, path);

    return args;
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
            
            ExternalEditorInfo *deflt = [ExternalEditorInfo new];
            if( ActivationManager::Instance().HasTerminal() ) {
                deflt.name = @"vi";
                deflt.path = @"/usr/bin/vi";
                deflt.arguments = @"%%";
                deflt.mask = @"*";
                deflt.terminal = true;
            }
            else {
                deflt.name = @"TextEdit";
                deflt.path = @"/Applications/TextEdit.app";
                deflt.arguments = @"";
                deflt.mask = @"*";
                deflt.terminal = false;
            }
            
            [m_Editors addObject:deflt];
            m_IsDirty = true;
        }
        else
            m_Editors = m_Editors.mutableCopy; // convert into NSMutableArray
        
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

- (NSMutableArray*) Editors
{
    m_IsDirty = true; // badly approach
    return m_Editors;
}

- (void) setEditors:(NSMutableArray*)_editors
{
    m_IsDirty = true;
    m_Editors = _editors;
}

+ (ExternalEditorsList*) sharedList
{
    static ExternalEditorsList* list = [ExternalEditorsList new];
    return list;
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

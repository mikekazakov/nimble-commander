#include "../../../3rd_Party/NSFileManagerDirectoryLocations/NSFileManager+DirectoryLocations.h"
#include <VFS/VFS.h>
#include <Term/SingleTask.h>
#include <NimbleCommander/Core/FileMask.h>
#include <NimbleCommander/Core/rapidjson.h>
#include <NimbleCommander/Bootstrap/Config.h>
#include <NimbleCommander/Bootstrap/ActivationManager.h>
#include "ExternalEditorInfo.h"
#include "ExternalEditorInfoPrivate.h"

static NSString *g_FileName = @"/externaleditors.bplist"; // bplist file name

static NSString* StorageFileName()
{
    return [NSFileManager.defaultManager.applicationSupportDirectory
        stringByAppendingString:g_FileName];
}

struct ExternalEditorsPersistence
{
    constexpr static const auto name = "name";
    constexpr static const auto path = "path";
    constexpr static const auto args = "args";
    constexpr static const auto mask = "mask";
    constexpr static const auto maxfilesize = "maxFileSize";
    constexpr static const auto onlyfiles = "onlyFiles";
    constexpr static const auto terminal = "openInTerminal";

    static optional<ExternalEditorStartupInfo> LoadFromJSON( const GenericConfig::ConfigValue &_v )
    {
        if( !_v.IsObject() )
            return nullopt;
    
        ExternalEditorStartupInfo ed;
        
        if( _v.HasMember(name) && _v[name].IsString() )
            ed.m_Name = _v[name].GetString();
        else
            return nullopt;
        
        if( _v.HasMember(path) && _v[path].IsString() )
            ed.m_Path = _v[path].GetString();
        else
            return nullopt;

        if( _v.HasMember(args) && _v[args].IsString() )
            ed.m_Arguments = _v[args].GetString();
        else
            return nullopt;

        if( _v.HasMember(mask) && _v[mask].IsString() )
            ed.m_Mask = _v[mask].GetString();
        else
            return nullopt;

        if( _v.HasMember(maxfilesize) && _v[maxfilesize].IsInt() )
            ed.m_MaxFileSize = _v[maxfilesize].GetInt();

        if( _v.HasMember(onlyfiles) && _v[onlyfiles].IsBool() )
            ed.m_OnlyFiles = _v[onlyfiles].GetBool();

        if( _v.HasMember(terminal) && _v[terminal].IsBool() )
            ed.m_OpenInTerminal = _v[terminal].GetBool();

        return ed;
    }
    
    static ExternalEditorStartupInfo LoadFromLegacyObjC( ExternalEditorInfo *_ed )
    {
        ExternalEditorStartupInfo ed;
        ed.m_Name = _ed.name.UTF8String;
        ed.m_Path = _ed.path.fileSystemRepresentationSafe;
        ed.m_Arguments = _ed.arguments.UTF8String;
        ed.m_Mask = _ed.mask.UTF8String;
        ed.m_MaxFileSize = _ed.max_size;
        ed.m_OnlyFiles = _ed.only_files;
        ed.m_OpenInTerminal = _ed.terminal;
        return ed;
    }
    
    static GenericConfig::ConfigValue SaveToJSON( const ExternalEditorStartupInfo& _ed )
    {
        using namespace rapidjson;
        GenericConfig::ConfigValue v {kObjectType};
        v.AddMember(MakeStandaloneString(name),
                    MakeStandaloneString(_ed.Name()),
                    g_CrtAllocator);
        v.AddMember(MakeStandaloneString(path),
                    MakeStandaloneString(_ed.Path()),
                    g_CrtAllocator);
        v.AddMember(MakeStandaloneString(args),
                    MakeStandaloneString(_ed.Arguments()),
                    g_CrtAllocator);
        v.AddMember(MakeStandaloneString(mask),
                    MakeStandaloneString(_ed.Mask()),
                    g_CrtAllocator);
        v.AddMember(MakeStandaloneString(maxfilesize),
                    GenericConfig::ConfigValue {_ed.MaxFileSize()},
                    g_CrtAllocator);
        v.AddMember(MakeStandaloneString(onlyfiles),
                    GenericConfig::ConfigValue {_ed.OnlyFiles()},
                    g_CrtAllocator);
        v.AddMember(MakeStandaloneString(terminal),
                    GenericConfig::ConfigValue {_ed.OpenInTerminal()},
                    g_CrtAllocator);
        return v;
    }
};

@implementation ExternalEditorInfo
{
    NSString    *m_Name;
    NSString    *m_Path;
    NSString    *m_Arguments;
    NSString    *m_Mask;
    bool        m_OnlyFiles;
    bool        m_Terminal;
    uint64_t    m_MaxSize;
    
//    unique_ptr<FileMask> m_FileMask;
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

//- (bool) isValidItem:(const VFSListingItem&)_it
//{
//    if(m_FileMask == nullptr)
//        return false;
//    
//    if(m_FileMask->MatchName(_it.Filename()) == false)
//        return false;
//    
//    if(m_OnlyFiles == true && _it.IsReg() == false)
//        return false;
//    
//    if(m_OnlyFiles == true &&
//       m_MaxSize > 0 &&
//       _it.Size() > m_MaxSize)
//        return false;
//    
//    return true;
//}

//- (void) setMask:(NSString *)mask
//{
//    if([m_Mask isEqualToString:mask])
//        return;
//    
//    [self willChangeValueForKey:@"mask"];
//    m_Mask = mask;
//    [self didChangeValueForKey:@"mask"];
//    
//    if(m_Mask == nil || m_Mask.length == 0)
//        m_FileMask.reset();
//    else
//        m_FileMask = make_unique<FileMask>(m_Mask.UTF8String);
//}

//- (string) substituteFileName:(const string &)_path
//{
//    char esc_buf[MAXPATHLEN];
//    strcpy(esc_buf, _path.c_str());
//    TermSingleTask::EscapeSpaces(esc_buf);
//    
//    if(m_Arguments.length == 0)
//        return esc_buf; // just return escaped file path
//    
//    string args = m_Arguments.fileSystemRepresentation;
//    string path = " "s + esc_buf + " ";
//
//    size_t start_pos;
//    if((start_pos = args.find("%%")) != std::string::npos)
//        args.replace(start_pos, 2, path);
//
//    return args;
//}

- (shared_ptr<ExternalEditorStartupInfo>) toStartupInfo
{
    return make_shared<ExternalEditorStartupInfo>(
        ExternalEditorsPersistence::LoadFromLegacyObjC( self )
    );
}

@end


//@implementation ExternalEditorsList
//{
//    NSMutableArray *m_Editors;
//    bool m_IsDirty;
//}
//
//- (id) init
//{
//    if(self = [super init])
//    {
//        m_IsDirty = false;
//        
//        // try to load history from file
//        m_Editors = [NSKeyedUnarchiver unarchiveObjectWithFile:StorageFileName()];
//        if(m_Editors == nil)
//        {
//            m_Editors = [NSMutableArray new];
//            
//            ExternalEditorInfo *deflt = [ExternalEditorInfo new];
//            if( ActivationManager::Instance().HasTerminal() ) {
//                deflt.name = @"vi";
//                deflt.path = @"/usr/bin/vi";
//                deflt.arguments = @"%%";
//                deflt.mask = @"*";
//                deflt.terminal = true;
//            }
//            else {
//                deflt.name = @"TextEdit";
//                deflt.path = @"/Applications/TextEdit.app";
//                deflt.arguments = @"";
//                deflt.mask = @"*";
//                deflt.terminal = false;
//            }
//            
//            [m_Editors addObject:deflt];
//            m_IsDirty = true;
//        }
//        else
//            m_Editors = m_Editors.mutableCopy; // convert into NSMutableArray
//        
//        [NSNotificationCenter.defaultCenter addObserver:self
//                                               selector:@selector(OnTerminate:)
//                                                   name:NSApplicationWillTerminateNotification
//                                                 object:NSApplication.sharedApplication];
//    }
//    return self;
//}
//
//- (void) dealloc
//{
//    [NSNotificationCenter.defaultCenter removeObserver:self];
//}
//
//- (NSMutableArray*) Editors
//{
//    m_IsDirty = true; // badly approach
//    return m_Editors;
//}
//
//- (void) setEditors:(NSMutableArray*)_editors
//{
//    m_IsDirty = true;
//    m_Editors = _editors;
//}
//
//+ (ExternalEditorsList*) sharedList
//{
//    static ExternalEditorsList* list = [ExternalEditorsList new];
//    return list;
//}
//
//- (void)OnTerminate:(NSNotification *)note
//{
//    if(m_IsDirty)
//        [NSKeyedArchiver archiveRootObject:m_Editors toFile:StorageFileName()];
//}
//
//- (ExternalEditorInfo*) FindViableEditorForItem:(const VFSListingItem&)_item
//{
//    for(ExternalEditorInfo *ed in m_Editors)
//        if([ed isValidItem:_item])
//            return ed;
//    return nil;
//}
//
//@end


ExternalEditorStartupInfo::ExternalEditorStartupInfo() noexcept :
    m_MaxFileSize(0),
    m_OnlyFiles(true),
    m_OpenInTerminal(false)
{
}

const string &ExternalEditorStartupInfo::Name() const noexcept
{
    return m_Name;
}

const string &ExternalEditorStartupInfo::Path() const noexcept
{
    return m_Path;
}

const string &ExternalEditorStartupInfo::Arguments() const noexcept
{
    return m_Arguments;
}

const string &ExternalEditorStartupInfo::Mask() const noexcept
{
    return m_Mask;
}

bool ExternalEditorStartupInfo::OnlyFiles() const noexcept
{
    return m_OnlyFiles;
}

uint64_t ExternalEditorStartupInfo::MaxFileSize() const noexcept
{
    return m_MaxFileSize;
}

bool ExternalEditorStartupInfo::OpenInTerminal() const noexcept
{
    return m_OpenInTerminal;
}

bool ExternalEditorStartupInfo::IsValidForItem(const VFSListingItem&_item) const
{
    if( !ActivationManager::Instance().HasTerminal() &&
        m_OpenInTerminal )
        return false;

    if( m_Mask.empty() ) // why is this?
        return false;
    
    if( m_OnlyFiles == true && _item.IsReg() == false)
        return false;
    
    if( m_Mask != "*" ) {
        FileMask mask{ m_Mask };
        if( !mask.MatchName(_item.Filename()) )
            return false;
    }

    if( m_OnlyFiles == true &&
        m_MaxFileSize > 0 &&
        _item.Size() > m_MaxFileSize )
        return false;
    
    return true;
}

string ExternalEditorStartupInfo::SubstituteFileName(const string &_path) const
{
    char esc_buf[MAXPATHLEN];
    strcpy(esc_buf, _path.c_str());
    nc::term::SingleTask::EscapeSpaces(esc_buf);
    
    if( m_Arguments.empty() )
        return esc_buf; // just return escaped file path
    
    string args = m_Arguments;
    string path = " "s + esc_buf + " ";
    
    size_t start_pos;
    if((start_pos = args.find("%%")) != std::string::npos)
        args.replace(start_pos, 2, path);
    
    return args;
}

ExternalEditorsStorage::ExternalEditorsStorage(const char* _config_path):
    m_ConfigPath(_config_path)
{
    // TODO: remove this after 1.2.0:
    if( NSArray *a = [NSKeyedUnarchiver unarchiveObjectWithFile:StorageFileName()] ) {
        for( id v in a )
            if( auto ed = objc_cast<ExternalEditorInfo>(v) )
                m_ExternalEditors.emplace_back( [ed toStartupInfo] );

        SaveToConfig();
        [NSFileManager.defaultManager trashItemAtURL:[NSURL fileURLWithPath:StorageFileName()]
                                    resultingItemURL:nil
                                               error:nil];
    }
    else {
        LoadFromConfig();    
    }
}

void ExternalEditorsStorage::LoadFromConfig()
{
    m_ExternalEditors.clear();
    
    auto v = GlobalConfig().Get(m_ConfigPath);
    if( v.IsArray() )
        for( auto i = v.Begin(), e = v.End(); i != e; ++i )
            if( auto ed = ExternalEditorsPersistence::LoadFromJSON(*i) )
                m_ExternalEditors.emplace_back( make_shared<ExternalEditorStartupInfo>(move(*ed)) );
}

void ExternalEditorsStorage::SaveToConfig()
{
    using namespace rapidjson;
    GenericConfig::ConfigValue v{kArrayType};
    for( auto &ed: m_ExternalEditors)
        v.PushBack( ExternalEditorsPersistence::SaveToJSON(*ed),
                   g_CrtAllocator);
    GlobalConfig().Set(m_ConfigPath, v);
}

shared_ptr<ExternalEditorStartupInfo> ExternalEditorsStorage::
    ViableEditorForItem(const VFSListingItem&_item) const
{
    for( auto &ed: m_ExternalEditors )
        if( ed->IsValidForItem(_item) )
            return ed;
    return nullptr;
}

vector<shared_ptr<ExternalEditorStartupInfo>> ExternalEditorsStorage::AllExternalEditors() const
{
    return m_ExternalEditors;
}

void ExternalEditorsStorage::
    SetExternalEditors( const vector<shared_ptr<ExternalEditorStartupInfo>>& _editors )
{
    m_ExternalEditors = _editors;
    SaveToConfig();
}

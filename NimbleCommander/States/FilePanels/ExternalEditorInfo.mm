// Copyright (C) 2014-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ExternalEditorInfo.h"
#include "../../../3rd_Party/NSFileManagerDirectoryLocations/NSFileManager+DirectoryLocations.h"
#include <VFS/VFS.h>
#include <Term/SingleTask.h>
#include <Utility/FileMask.h>
#include <Utility/StringExtras.h>
#include <Config/RapidJSON.h>
#include <NimbleCommander/Bootstrap/Config.h>
#include <NimbleCommander/Bootstrap/ActivationManager.h>
#include "ExternalEditorInfoPrivate.h"

using namespace nc::config;
using namespace std::literals;

struct ExternalEditorsPersistence
{
    constexpr static const auto name = "name";
    constexpr static const auto path = "path";
    constexpr static const auto args = "args";
    constexpr static const auto mask = "mask";
    constexpr static const auto maxfilesize = "maxFileSize";
    constexpr static const auto onlyfiles = "onlyFiles";
    constexpr static const auto terminal = "openInTerminal";

    static std::optional<ExternalEditorStartupInfo> LoadFromJSON( const Value &_v )
    {
        if( !_v.IsObject() )
            return std::nullopt;
    
        ExternalEditorStartupInfo ed;
        
        if( _v.HasMember(name) && _v[name].IsString() )
            ed.m_Name = _v[name].GetString();
        else
            return std::nullopt;
        
        if( _v.HasMember(path) && _v[path].IsString() )
            ed.m_Path = _v[path].GetString();
        else
            return std::nullopt;

        if( _v.HasMember(args) && _v[args].IsString() )
            ed.m_Arguments = _v[args].GetString();
        else
            return std::nullopt;

        if( _v.HasMember(mask) && _v[mask].IsString() )
            ed.m_Mask = _v[mask].GetString();
        else
            return std::nullopt;

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
    
    static Value SaveToJSON( const ExternalEditorStartupInfo& _ed )
    {
        using namespace rapidjson;
        nc::config::Value v {kObjectType};
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
                    nc::config::Value {_ed.MaxFileSize()},
                    g_CrtAllocator);
        v.AddMember(MakeStandaloneString(onlyfiles),
                    nc::config::Value {_ed.OnlyFiles()},
                    g_CrtAllocator);
        v.AddMember(MakeStandaloneString(terminal),
                    nc::config::Value {_ed.OpenInTerminal()},
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

- (std::shared_ptr<ExternalEditorStartupInfo>) toStartupInfo
{
    return std::make_shared<ExternalEditorStartupInfo>(
        ExternalEditorsPersistence::LoadFromLegacyObjC( self )
    );
}

@end

ExternalEditorStartupInfo::ExternalEditorStartupInfo() noexcept :
    m_MaxFileSize(0),
    m_OnlyFiles(true),
    m_OpenInTerminal(false)
{
}

const std::string &ExternalEditorStartupInfo::Name() const noexcept
{
    return m_Name;
}

const std::string &ExternalEditorStartupInfo::Path() const noexcept
{
    return m_Path;
}

const std::string &ExternalEditorStartupInfo::Arguments() const noexcept
{
    return m_Arguments;
}

const std::string &ExternalEditorStartupInfo::Mask() const noexcept
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
    if( !nc::bootstrap::ActivationManager::Instance().HasTerminal() &&
        m_OpenInTerminal )
        return false;

    if( m_Mask.empty() ) // why is this?
        return false;
    
    if( m_OnlyFiles == true && _item.IsReg() == false)
        return false;
    
    if( m_Mask != "*" ) {
        nc::utility::FileMask mask{ m_Mask };
        if( !mask.MatchName(_item.Filename()) )
            return false;
    }

    if( m_OnlyFiles == true &&
        m_MaxFileSize > 0 &&
        _item.Size() > m_MaxFileSize )
        return false;
    
    return true;
}

std::string ExternalEditorStartupInfo::SubstituteFileName(const std::string &_path) const
{
    char esc_buf[MAXPATHLEN];
    strcpy(esc_buf, _path.c_str());
    nc::term::SingleTask::EscapeSpaces(esc_buf);
    
    if( m_Arguments.empty() )
        return esc_buf; // just return escaped file path
    
    std::string args = m_Arguments;
    std::string path = " "s + esc_buf + " ";
    
    size_t start_pos;
    if((start_pos = args.find("%%")) != std::string::npos)
        args.replace(start_pos, 2, path);
    
    return args;
}

ExternalEditorsStorage::ExternalEditorsStorage(const char* _config_path):
    m_ConfigPath(_config_path)
{
    LoadFromConfig();
}

void ExternalEditorsStorage::LoadFromConfig()
{
    m_ExternalEditors.clear();
    
    auto v = GlobalConfig().Get(m_ConfigPath);
    if( v.IsArray() )
        for( auto i = v.Begin(), e = v.End(); i != e; ++i )
            if( auto ed = ExternalEditorsPersistence::LoadFromJSON(*i) ) {
                auto shared_ed = std::make_shared<ExternalEditorStartupInfo>(std::move(*ed));
                m_ExternalEditors.emplace_back( std::move(shared_ed) );
            }
}

void ExternalEditorsStorage::SaveToConfig()
{
    using namespace rapidjson;
    nc::config::Value v{kArrayType};
    for( auto &ed: m_ExternalEditors)
        v.PushBack( ExternalEditorsPersistence::SaveToJSON(*ed),
                   g_CrtAllocator);
    GlobalConfig().Set(m_ConfigPath, v);
}

std::shared_ptr<ExternalEditorStartupInfo> ExternalEditorsStorage::
    ViableEditorForItem(const VFSListingItem&_item) const
{
    for( auto &ed: m_ExternalEditors )
        if( ed->IsValidForItem(_item) )
            return ed;
    return nullptr;
}

std::vector<std::shared_ptr<ExternalEditorStartupInfo>>
ExternalEditorsStorage::AllExternalEditors() const
{
    return m_ExternalEditors;
}

void ExternalEditorsStorage::
    SetExternalEditors( const std::vector<std::shared_ptr<ExternalEditorStartupInfo>>& _editors )
{
    m_ExternalEditors = _editors;
    SaveToConfig();
}

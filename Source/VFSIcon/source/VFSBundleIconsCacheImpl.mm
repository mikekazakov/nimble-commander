// Copyright (C) 2018-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include <VFSIcon/VFSBundleIconsCacheImpl.h>
#include <Utility/ObjCpp.h>

namespace nc::vfsicon {

static NSImage *ProduceBundleIcon(const std::string &_path, VFSHost &_host);
static NSDictionary *ReadDictionary(const std::string &_path, VFSHost &_host);
static NSData *ToTempNSData(std::span<const uint8_t> _data);
static NSImage *ReadImageFromFile(const std::string &_path, VFSHost &_host);
static std::expected<std::vector<uint8_t>, Error> ReadEntireFile(const std::string &_path, VFSHost &_host);

VFSBundleIconsCacheImpl::VFSBundleIconsCacheImpl() = default;

VFSBundleIconsCacheImpl::~VFSBundleIconsCacheImpl() = default;

NSImage *VFSBundleIconsCacheImpl::IconIfHas(const std::string &_file_path, VFSHost &_host)
{
    auto key = MakeKey(_file_path, _host);

    {
        auto lock = std::lock_guard{m_Lock};
        if( m_Icons.count(key) )
            return m_Icons.at(key);
    }

    return nil;
}

NSImage *VFSBundleIconsCacheImpl::ProduceIcon(const std::string &_file_path, VFSHost &_host)
{
    auto key = MakeKey(_file_path, _host);

    {
        auto lock = std::lock_guard{m_Lock};
        if( m_Icons.count(key) )
            return m_Icons.at(key);
    }

    auto image = ProduceBundleIcon(_file_path, _host);

    {
        auto lock = std::lock_guard{m_Lock};
        m_Icons.insert(std::move(key), image);
    }

    return image;
}

std::string VFSBundleIconsCacheImpl::MakeKey(const std::string &_file_path, VFSHost &_host)
{
    return _host.MakePathVerbose(_file_path);
}

static std::expected<std::vector<uint8_t>, Error> ReadEntireFile(const std::string &_path, VFSHost &_host)
{
    const std::expected<std::shared_ptr<VFSFile>, Error> exp_file = _host.CreateFile(_path);
    if( !exp_file )
        return std::unexpected(exp_file.error());

    VFSFile &file = **exp_file;

    if( const int rc = file.Open(VFSFlags::OF_Read); rc < 0 )
        return std::unexpected(VFSError::ToError(rc));

    return file.ReadFile();
}

static NSData *ToTempNSData(const std::span<const uint8_t> _data)
{
    return [NSData dataWithBytesNoCopy:const_cast<void *>(reinterpret_cast<const void *>(_data.data()))
                                length:_data.size()
                          freeWhenDone:false];
}

static NSDictionary *ReadDictionary(const std::string &_path, VFSHost &_host)
{
    const std::expected<std::vector<uint8_t>, Error> data = ReadEntireFile(_path, _host);
    if( !data.has_value() )
        return nil;

    const auto objc_data = ToTempNSData(data.value());
    if( objc_data == nil )
        return nil;

    const id dictionary = [NSPropertyListSerialization propertyListWithData:objc_data
                                                                    options:NSPropertyListImmutable
                                                                     format:nil
                                                                      error:nil];
    return objc_cast<NSDictionary>(dictionary);
}

static NSImage *ReadImageFromFile(const std::string &_path, VFSHost &_host)
{
    const std::expected<std::vector<uint8_t>, Error> data = ReadEntireFile(_path, _host);
    if( !data.has_value() )
        return nil;

    const auto objc_data = ToTempNSData(data.value());
    if( objc_data == nil )
        return nil;

    return [[NSImage alloc] initWithData:objc_data];
}

static NSImage *ProduceBundleIcon(const std::string &_path, VFSHost &_host)
{
    const auto info_plist_path = std::filesystem::path(_path) / "Contents/Info.plist";
    const auto plist = ReadDictionary(info_plist_path.native(), _host);
    if( !plist )
        return nullptr;

    auto icon_str = objc_cast<NSString>([plist objectForKey:@"CFBundleIconFile"]);
    if( !icon_str )
        return nil;
    if( !icon_str.fileSystemRepresentation )
        return nil;

    const auto img_path = std::filesystem::path(_path) / "Contents/Resources/" / icon_str.fileSystemRepresentation;
    return ReadImageFromFile(img_path, _host);
}

} // namespace nc::vfsicon

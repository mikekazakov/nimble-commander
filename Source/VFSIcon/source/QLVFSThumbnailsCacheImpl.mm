// Copyright (C) 2018-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#include <VFSIcon/QLVFSThumbnailsCacheImpl.h>
#include <Quartz/Quartz.h>
#include <filesystem>

namespace nc::vfsicon {

static NSImage *ProduceThumbnailForTempFile(const std::string &_path, CGSize _px_size);
static std::optional<std::vector<uint8_t>> ReadEntireFile(const std::string &_path, VFSHost &_host);

QLVFSThumbnailsCacheImpl::QLVFSThumbnailsCacheImpl(const std::shared_ptr<utility::BriefOnDiskStorage> &_temp_storage)
    : m_TempStorage(_temp_storage)
{
}

QLVFSThumbnailsCacheImpl::~QLVFSThumbnailsCacheImpl() = default;

NSImage *QLVFSThumbnailsCacheImpl::ThumbnailIfHas(const std::string &_file_path, VFSHost &_host, int _px_size)
{
    auto key = MakeKey(_file_path, _host, _px_size);

    {
        auto lock = std::lock_guard{m_Lock};
        if( m_Thumbnails.count(key) )
            return m_Thumbnails.at(key);
    }

    return nil;
}

NSImage *QLVFSThumbnailsCacheImpl::ProduceThumbnail(const std::string &_file_path, VFSHost &_host, int _px_size)
{
    auto key = MakeKey(_file_path, _host, _px_size);

    {
        auto lock = std::lock_guard{m_Lock};
        if( m_Thumbnails.count(key) )
            return m_Thumbnails.at(key);
    }

    auto image = ProduceThumbnail(_file_path,
                                  std::filesystem::path(_file_path).extension(),
                                  _host,
                                  CGSizeMake(double(_px_size), double(_px_size)));

    {
        auto lock = std::lock_guard{m_Lock};
        m_Thumbnails.insert(std::move(key), image);
    }

    return image;
}

NSImage *QLVFSThumbnailsCacheImpl::ProduceThumbnail(const std::string &_path,
                                                    const std::string &_ext,
                                                    VFSHost &_host,
                                                    CGSize _sz)
{
    auto data = ReadEntireFile(_path, _host);
    if( data.has_value() == false )
        return nil;

    auto placement_result = m_TempStorage->PlaceWithExtension(data->data(), data->size(), _ext);
    if( placement_result.has_value() == false )
        return nil;

    return ProduceThumbnailForTempFile(placement_result->Path(), _sz);
}

std::string QLVFSThumbnailsCacheImpl::MakeKey(const std::string &_file_path, VFSHost &_host, int _px_size)
{
    auto key = _host.MakePathVerbose(_file_path.c_str());
    key += "\x01";
    key += std::to_string(_px_size);
    return key;
}

static NSImage *ProduceThumbnailForTempFile(const std::string &_path, CGSize _px_size)
{

    CFURLRef url = CFURLCreateFromFileSystemRepresentation(
        nullptr, reinterpret_cast<const UInt8 *>(_path.c_str()), _path.length(), false);
    const void *keys[] = {static_cast<const void *>(kQLThumbnailOptionIconModeKey)};
    const void *values[] = {static_cast<const void *>(kCFBooleanTrue)};
    static CFDictionaryRef dict = CFDictionaryCreate(nullptr, keys, values, 1, nullptr, nullptr);
    NSImage *result = nullptr;
    if( CGImageRef thumbnail = QLThumbnailImageCreate(nullptr, url, _px_size, dict) ) {
        result = [[NSImage alloc] initWithCGImage:thumbnail size:_px_size];
        CGImageRelease(thumbnail);
    }
    CFRelease(url);
    return result;
}

static std::optional<std::vector<uint8_t>> ReadEntireFile(const std::string &_path, VFSHost &_host)
{
    VFSFilePtr vfs_file;

    if( _host.CreateFile(_path.c_str(), vfs_file, nullptr) < 0 )
        return std::nullopt;

    if( vfs_file->Open(VFSFlags::OF_Read) < 0 )
        return std::nullopt;

    return vfs_file->ReadFile();
}

} // namespace nc::vfsicon

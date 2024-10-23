// Copyright (C) 2014-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#include <VFSIcon/QLThumbnailsCacheImpl.h>
#include <VFSIcon/Log.h>
#include <Quartz/Quartz.h>
#include <sys/stat.h>
#include <Base/algo.h>

namespace nc::vfsicon {

static inline void hash_combine(size_t & /*unused*/)
{
}

template <typename T, typename... Rest>
static inline void hash_combine(size_t &seed, const T &v, Rest... rest)
{
    const std::hash<T> hasher;
    seed ^= hasher(v) + 0x9e3779b9 + (seed << 6) + (seed >> 2);
    hash_combine(seed, rest...);
}

inline size_t QLThumbnailsCacheImpl::KeyHash::operator()(const Key &c) const noexcept
{
    return c.hash;
}

inline QLThumbnailsCacheImpl::Key::Key()
{
    static_assert(sizeof(Key) == 56);
    path = path_storage;
    hash_combine(hash, path, px_size);
}

inline QLThumbnailsCacheImpl::Key::Key(const Key &_key)
{
    if( _key.path.data() == _key.path_storage.data() ) {
        path_storage = _key.path_storage;
        path = path_storage;
    }
    else {
        assert(_key.path_storage.empty());
        path = _key.path;
    }
    px_size = _key.px_size;
    hash = _key.hash;
}

QLThumbnailsCacheImpl::Key::Key(Key &&_key) noexcept
{
    if( _key.path.data() == _key.path_storage.data() ) {
        path_storage = std::move(_key.path_storage);
        path = path_storage;
    }
    else {
        assert(_key.path_storage.empty());
        path = _key.path;
    }
    px_size = _key.px_size;
    hash = _key.hash;
}

inline QLThumbnailsCacheImpl::Key::Key(std::string_view _path, int _px_size, no_ownership_tag /*unused*/)
{
    px_size = _px_size;
    path = _path;
    hash_combine(hash, path, px_size);
}

inline QLThumbnailsCacheImpl::Key::Key(const std::string &_path, int _px_size)
{
    path_storage = _path;
    px_size = _px_size;
    path = path_storage;
    hash_combine(hash, path, px_size);
}

QLThumbnailsCacheImpl::Key &QLThumbnailsCacheImpl::Key::operator=(const Key &_rhs)
{
    if( _rhs.path.data() == _rhs.path_storage.data() ) {
        path_storage = _rhs.path_storage;
        path = path_storage;
    }
    else {
        assert(_rhs.path_storage.empty());
        path = _rhs.path;
        path_storage.clear();
    }
    px_size = _rhs.px_size;
    hash = _rhs.hash;
    return *this;
}

inline bool QLThumbnailsCacheImpl::Key::operator==(const Key &_rhs) const noexcept
{
    return hash == _rhs.hash && px_size == _rhs.px_size && path == _rhs.path;
}

inline bool QLThumbnailsCacheImpl::Key::operator!=(const Key &_rhs) const noexcept
{
    return !(*this == _rhs);
}

static const auto g_QLOptions = [] {
    const void *keys[] = {static_cast<const void *>(kQLThumbnailOptionIconModeKey)};
    const void *values[] = {static_cast<const void *>(kCFBooleanTrue)};
    return CFDictionaryCreate(nullptr, keys, values, 1, nullptr, nullptr);
}();

static NSImage *BuildRep(const std::string &_filename, int _px_size)
{
    Log::Info("BuildRep(): building QL tumbnail for '{}' ({}px)", _filename, _px_size);
    CFURLRef url = CFURLCreateFromFileSystemRepresentation(
        nullptr, reinterpret_cast<const UInt8 *>(_filename.c_str()), _filename.length(), false);
    if( !url ) {
        Log::Warn("BuildRep(): failed to create NSURL for '{}'", _filename);
        return nil;
    }

    NSImage *result = nil;
    const auto sz = NSMakeSize(_px_size, _px_size);
    if( auto thumbnail = QLThumbnailImageCreate(nullptr, url, sz, g_QLOptions) ) {
        result = [[NSImage alloc] initWithCGImage:thumbnail size:sz];
        CGImageRelease(thumbnail);
    }
    else {
        Log::Warn("BuildRep(): failed to build a thumbnail image for '{}'", _filename);
    }
    CFRelease(url);
    return result;
}

QLThumbnailsCacheImpl::QLThumbnailsCacheImpl() = default;

QLThumbnailsCacheImpl::~QLThumbnailsCacheImpl() = default;

NSImage *QLThumbnailsCacheImpl::ProduceThumbnail(const std::string &_filename, int _px_size)
{
    return Produce(_filename, _px_size, std::nullopt);
}

NSImage *QLThumbnailsCacheImpl::ProduceThumbnail(const std::string &_filename, int _px_size, const FileStateHint &_hint)
{
    return Produce(_filename, _px_size, _hint);
}

NSImage *
QLThumbnailsCacheImpl::Produce(const std::string &_filename, int _px_size, const std::optional<FileStateHint> &_hint)
{
    Log::Info("Produce(): request for '{}' ({}px)", _filename, _px_size);
    const auto temp_key = Key{std::string_view{_filename}, _px_size, Key::no_ownership};
    auto lock = std::unique_lock{m_ItemsLock};
    if( m_Items.count(temp_key) ) { // O(1)
        Log::Debug("found a cached item for '{}' ({}px)", _filename, _px_size);
        auto info = m_Items[temp_key]; // acquiring a copy of intrusive_ptr **by*value**! O(1)
        lock.unlock();
        assert(info != nullptr);
        CheckCacheAndUpdateIfNeeded(_filename, _px_size, *info, _hint);
        return info->image;
    }
    else {
        Log::Debug("didn't find a cached item for '{}' ({}px). Adding new item, current cache size = {}",
                   _filename,
                   _px_size,
                   m_Items.size());
        // insert dummy info into the structure, so no one else can try producing it
        // concurrently - prohibit wasting of resources
        auto key = Key{_filename, _px_size};
        auto info = base::intrusive_ptr{new Info};
        info->is_in_work.test_and_set();
        m_Items.insert(std::move(key), info); // O(1)
        lock.unlock();
        ProduceNew(_filename, _px_size, *info);
        return info->image;
    }
}

static std::optional<QLThumbnailsCache::FileStateHint> ReadFileState(const std::string &_file_path)
{
    Log::Trace("ReadFileState(): requested a state for '{}'", _file_path);
    struct stat st;
    if( stat(_file_path.c_str(), &st) != 0 ) {
        Log::Warn("ReadFileState(): failed to stat() at '{}'", _file_path);
        return std::nullopt; // for some reason the file is not accessible - can't do anything
    }
    QLThumbnailsCache::FileStateHint hint;
    hint.size = static_cast<uint64_t>(st.st_size);
    hint.mtime = static_cast<uint64_t>(st.st_mtime);
    return hint;
}

void QLThumbnailsCacheImpl::CheckCacheAndUpdateIfNeeded(const std::string &_filename,
                                                        int _px_size,
                                                        Info &_info,
                                                        const std::optional<FileStateHint> &_hint)
{
    Log::Trace("CheckCacheAndUpdateIfNeeded(): called for '{}' ({}px)", _filename, _px_size);
    if( !_info.is_in_work.test_and_set() ) {
        auto clear_lock = at_scope_end([&] { _info.is_in_work.clear(); });
        // we're first to take control of this item

        const auto file_state_hint = _hint ? _hint : ReadFileState(_filename);
        if( !file_state_hint.has_value() ) {
            Log::Warn("CheckCacheAndUpdateIfNeeded(): can't get a file state hint for '{}'", _filename);
            return; // can't proceed without information about the file.
        }

        // check if cache is up-to-date
        if( _info.file_size == file_state_hint->size && _info.mtime == file_state_hint->mtime ) {
            Log::Trace("CheckCacheAndUpdateIfNeeded(): up-to-date for '{}'", _filename);
            return; // is up-to-date => nothing to do
        }

        _info.file_size = file_state_hint->size;
        _info.mtime = file_state_hint->mtime;

        // we prefer to keep the previous version of a thumbnail in case if QL can't produce a new
        // version for the changed file.
        if( auto new_image = BuildRep(_filename, _px_size) ) {
            Log::Info("CheckCacheAndUpdateIfNeeded(): update the image for '{}'", _filename);
            _info.image = new_image;
        }
        else {
            Log::Warn("CheckCacheAndUpdateIfNeeded(): failed to update the image for '{}'", _filename);
        }
    }
    else {
        // the item is currently in updating state, let's use the current image
        Log::Trace("CheckCacheAndUpdateIfNeeded(): already updating now");
    }
}

void QLThumbnailsCacheImpl::ProduceNew(const std::string &_filename, int _px_size, Info &_info)
{
    Log::Trace("ProduceNew(): called for '{}' ({}px)", _filename, _px_size);
    assert(_info.is_in_work.test_and_set() == true); // _info should be locked initially
    auto clear_lock = at_scope_end([&] { _info.is_in_work.clear(); });

    // file must exist and be accessible
    struct stat st;
    if( stat(_filename.c_str(), &st) != 0 ) {
        Log::Warn("ProduceNew(): failed to stat() at '{}", _filename);
        return;
    }

    _info.file_size = st.st_size;
    _info.mtime = st.st_mtime;
    _info.image = BuildRep(_filename, _px_size); // img may be nil - it's ok
}

NSImage *QLThumbnailsCacheImpl::ThumbnailIfHas(const std::string &_filename, int _px_size)
{
    Log::Trace("ThumbnailIfHas(): called for '{}' ({}px)", _filename, _px_size);
    const auto temp_key = Key{std::string_view{_filename}, _px_size, Key::no_ownership};
    auto lock = std::lock_guard{m_ItemsLock};
    if( m_Items.count(temp_key) != 0 ) { // O(1)
        Log::Trace("ThumbnailIfHas(): found a cached entry for '{}' ({}px)", _filename, _px_size);
        auto &info = m_Items[temp_key]; // O(1)
        assert(info != nullptr);
        return info->image;
    }
    else {
        Log::Trace("ThumbnailIfHas(): doesn't have a cached entry for '{}' ({}px)", _filename, _px_size);
        return nil;
    }
}

} // namespace nc::vfsicon

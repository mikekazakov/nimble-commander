// Copyright (C) 2019-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Utility/NativeFSManagerVolumeLookup.h>
#include <algorithm>
#include <cassert>

namespace nc::utility {

void NativeFSManagerVolumeLookup::Insert(const std::shared_ptr<const NativeFileSystemInfo> &_volume,
                                         std::string_view _at)
{
    if( _volume == nullptr )
        throw std::invalid_argument("VolumeLookup::Insert(): _volume can't be nullptr");
    if( _at.empty() || _at.front() != '/' )
        throw std::invalid_argument("VolumeLookup::Insert(): _at must be an absolute path");
    if( _at.back() != '/' )
        throw std::invalid_argument("VolumeLookup::Insert(): _at must end with /");

    const auto it = std::ranges::find(m_Targets, _at);
    if( it == m_Targets.end() ) {
        m_Targets.emplace_back(_at);
        m_Sources.push_back(_volume);
    }
    else {
        const auto dist = static_cast<size_t>(std::distance(m_Targets.begin(), it));
        assert(dist < m_Sources.size());
        m_Sources[dist] = _volume;
    }
}

void NativeFSManagerVolumeLookup::Remove(std::string_view _from)
{
    if( _from.empty() || _from.front() != '/' )
        throw std::invalid_argument("VolumeLookup::Remove(): _from must be an absolute path");
    if( _from.back() != '/' )
        throw std::invalid_argument("VolumeLookup::Remove(): _from must end with /");

    const auto it = std::ranges::find(m_Targets, _from);
    if( it != m_Targets.end() ) {
        const auto dist = std::distance(m_Targets.begin(), it);
        m_Targets.erase(it);
        m_Sources.erase(std::next(m_Sources.begin(), dist));
    }
}

std::shared_ptr<const NativeFileSystemInfo>
NativeFSManagerVolumeLookup::FindVolumeForLocation(std::string_view _location) const noexcept
{
    const size_t size = m_Targets.size();
    assert(m_Sources.size() == size);

    if( size == 0 )
        return nullptr;

    ssize_t best_fit_index = -1;
    size_t best_fit_len = 0;

    for( size_t index = 0; index != size; ++index ) {
        const std::string &target = m_Targets[index];
        const size_t target_len = target.length();
        if( target_len <= best_fit_len )
            continue;
        if( target_len > _location.size() )
            continue;

        if( _location.compare(0, target_len, target) == 0 ) {
            best_fit_index = static_cast<ssize_t>(index);
            best_fit_len = target_len;
        }
    }

    if( best_fit_index >= 0 ) {
        return m_Sources[best_fit_index];
    }
    else {
        return nullptr;
    }
}

} // namespace nc::utility

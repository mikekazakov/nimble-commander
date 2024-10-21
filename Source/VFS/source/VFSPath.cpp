// Copyright (C) 2013-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include <algorithm>

#include "../include/VFS/Host.h"
#include "../include/VFS/VFSPath.h"

namespace nc::vfs {

VFSPath::VFSPath() noexcept = default;

VFSPath::VFSPath(const VFSHostPtr &_host, std::filesystem::path _path) : m_Host(_host), m_Path(std::move(_path))
{
}

VFSPath::VFSPath(VFSHost &_host, std::filesystem::path _path) : VFSPath(_host.shared_from_this(), std::move(_path))
{
}

const VFSHostPtr &VFSPath::Host() const noexcept
{
    return m_Host;
}

const std::string &VFSPath::Path() const noexcept
{
    return m_Path.native();
}

VFSPath::operator bool() const noexcept
{
    return static_cast<bool>(m_Host);
}

void VFSPath::Reset()
{
    m_Host.reset();
    m_Path.clear();
}

bool operator<(const VFSPath &_lhs, const VFSPath &_rhs) noexcept
{
    return _lhs.Host() != _rhs.Host() ? _lhs.Host() < _rhs.Host() : _lhs.Path() < _rhs.Path();
}

bool operator==(const VFSPath &_lhs, const VFSPath &_rhs) noexcept
{
    return _lhs.Host() == _rhs.Host() && _lhs.Path() == _rhs.Path();
}

bool operator!=(const VFSPath &_lhs, const VFSPath &_rhs) noexcept
{
    return !(_lhs == _rhs);
}

VFSPathStack::Part::Part(VFSHost &_host)
    : fs_tag(_host.Tag()), junction(_host.JunctionPath()), host(_host.shared_from_this()),
      configuration(_host.Configuration())
{
}

bool VFSPathStack::Part::operator==(const Part &_r) const
{
    return fs_tag == _r.fs_tag && junction == _r.junction && !host.owner_before(_r.host) &&
           !_r.host.owner_before(host) && // tricky weak_ptr comparison
           configuration == _r.configuration;
}

bool VFSPathStack::Part::operator!=(const Part &_r) const
{
    return !(*this == _r);
}

bool VFSPathStack::Part::weak_equal(const Part &_r) const
{
    if( *this == _r )
        return true;

    if( fs_tag != _r.fs_tag )
        return false;
    if( junction != _r.junction )
        return false;
    if( configuration != _r.configuration )
        return false;
    return true;
}

VFSPathStack::VFSPathStack() = default;

VFSPathStack::VFSPathStack(const VFSHostPtr &_vfs, const std::string &_path) : m_Path(_path)
{
    auto curr_host = _vfs.get();
    while( curr_host != nullptr ) {
        m_Stack.emplace_back(*curr_host);
        curr_host = curr_host->Parent().get();
    }
    std::ranges::reverse(m_Stack);
}

bool VFSPathStack::weak_equal(const VFSPathStack &_r) const
{
    if( m_Stack.size() != _r.m_Stack.size() )
        return false;
    if( m_Path != _r.m_Path )
        return false;
    auto i = begin(m_Stack);
    auto j = begin(_r.m_Stack);
    auto e = end(m_Stack);
    for( ; i != e; ++i, ++j )
        if( !i->weak_equal(*j) )
            return false;
    return true;
}

std::string VFSPathStack::verbose_string() const
{
    std::string res;
    for( auto &i : m_Stack )
        res += i.configuration.VerboseJunction();
    res += m_Path;
    return res;
}

bool VFSPathStack::operator==(const VFSPathStack &_r) const
{
    return m_Stack == _r.m_Stack && m_Path == _r.m_Path;
}

bool VFSPathStack::operator!=(const VFSPathStack &_r) const
{
    return !(*this == _r);
}

const VFSPathStack::Part &VFSPathStack::operator[](size_t _n) const
{
    return m_Stack[_n];
}

bool VFSPathStack::empty() const
{
    return m_Stack.empty();
}

size_t VFSPathStack::size() const
{
    return m_Stack.size();
}

const VFSPathStack::Part &VFSPathStack::back() const
{
    return m_Stack.back();
}

const std::string &VFSPathStack::path() const
{
    return m_Path;
}

} // namespace nc::vfs

std::hash<nc::vfs::VFSPathStack>::value_type
std::hash<nc::vfs::VFSPathStack>::operator()(const hash<nc::vfs::VFSPathStack>::argument_type &_v) const
{
    std::string str;
    for( auto &i : _v.m_Stack ) {
        str += i.fs_tag;
        str += i.junction;
        // we need to incorporate options somehow here. or not?
        str += "|"; // really need this?
    }
    str += _v.m_Path;
    return std::hash<std::string>()(str);
}

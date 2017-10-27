// Copyright (C) 2013-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "../include/VFS/Host.h"
#include "../include/VFS/VFSPath.h"

VFSPath::VFSPath()
{
}

VFSPath::VFSPath(const VFSHostPtr &_host, string _path):
    m_Host(_host),
    m_Path(move(_path))
{
}

VFSPath::VFSPath(VFSHost &_host, string _path):
    VFSPath(_host.shared_from_this(), move(_path))
{
}

const VFSHostPtr& VFSPath::Host() const noexcept
{
    return m_Host;
}
const string& VFSPath::Path() const noexcept
{
    return m_Path;
}

VFSPath::operator bool() const noexcept
{
    return (bool)m_Host;
}

void VFSPath::Reset()
{
    m_Host.reset();
    m_Path.clear();
}

bool operator <(const VFSPath& _lhs, const VFSPath& _rhs) noexcept
{
    return _lhs.Host() != _rhs.Host() ?
        _lhs.Host() < _rhs.Host():
        _lhs.Path() < _rhs.Path();
}

bool operator ==(const VFSPath& _lhs, const VFSPath& _rhs) noexcept
{
    return _lhs.Host() == _rhs.Host() && _lhs.Path() == _rhs.Path();
}

bool operator !=(const VFSPath& _lhs, const VFSPath& _rhs) noexcept
{
    return !( _lhs == _rhs );
}

VFSPathStack::Part::Part(VFSHost &_host):
    fs_tag(_host.Tag()),
    junction(_host.JunctionPath()),
    host(_host.shared_from_this()),
    configuration(_host.Configuration())
{
}

bool VFSPathStack::Part::operator==(const Part&_r) const
{
    return fs_tag == _r.fs_tag &&
            junction == _r.junction &&
            !host.owner_before(_r.host) && !_r.host.owner_before(host) && // tricky weak_ptr comparison
            configuration == _r.configuration
            ;
}

bool VFSPathStack::Part::operator!=(const Part&_r) const
{
    return !(*this == _r);
}

bool VFSPathStack::Part::weak_equal(const Part&_r) const
{
    if(*this == _r)
        return true;
       
    if(fs_tag != _r.fs_tag) return false;
    if(junction != _r.junction) return false;
    if(configuration != _r.configuration ) return false;
    return true;
}

VFSPathStack::VFSPathStack()
{
}

VFSPathStack::VFSPathStack(const VFSHostPtr &_vfs, const string &_path):
    m_Path(_path)
{
    auto curr_host = _vfs.get();
    while( curr_host != nullptr  ) {
        m_Stack.emplace_back( *curr_host );
        curr_host = curr_host->Parent().get();
    }
    reverse(begin(m_Stack), end(m_Stack));
}

bool VFSPathStack::weak_equal(const VFSPathStack&_r) const
{
    if(m_Stack.size() != _r.m_Stack.size()) return false;
    if(m_Path != _r.m_Path) return false;
    auto i = begin(m_Stack), j = begin(_r.m_Stack), e = end(m_Stack);
    for(;i != e; ++i, ++j)
        if(!i->weak_equal(*j))
            return false;
    return true;
}

string VFSPathStack::verbose_string() const
{
    string res;
    for( auto &i: m_Stack )
        res += i.configuration.VerboseJunction();
    res += m_Path;
    return res;
}


//class VFSPathStack
//{
//public:
//    struct Part
//    {
//        Part() = default;
//        Part(VFSHost &_host);
//        
//        const char* fs_tag; // this tag is redundant since configuration already able to provide it
//        string junction;
//        weak_ptr<VFSHost> host;
//        VFSConfiguration configuration;
//        
//        /**
//         * operation== performs fast comparison by ptrs.
//         */
//        bool operator==(const Part&_r) const;
//        inline bool operator!=(const Part&_r) const { return !(*this == _r); }
//        
//        /**
//         * Will compare parts without respect to host ptr and will compare options by it's content.
//         */
//        bool weak_equal(const Part&_r) const;
//    };
//    
//    VFSPathStack();
//    VFSPathStack(const VFSHostPtr &_vfs, const string &_path);
//
bool VFSPathStack::operator==(const VFSPathStack& _r) const
{
    return m_Stack == _r.m_Stack && m_Path == _r.m_Path;
}

bool VFSPathStack::operator!=(const VFSPathStack& _r) const
{
    return !(*this == _r);
}

const VFSPathStack::Part& VFSPathStack::operator[](size_t _n) const
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

const VFSPathStack::Part& VFSPathStack::back() const
{
    return m_Stack.back();
}

const string& VFSPathStack::path() const
{
    return m_Path;
}

hash<VFSPathStack>::value_type hash<VFSPathStack>::operator()(hash<VFSPathStack>::argument_type const& _v) const
{
    string str;
    for(auto &i:_v.m_Stack)
    {
        str += i.fs_tag;
        str += i.junction;
        // we need to incorporate options somehow here. or not?
        str += "|"; // really need this?
    }
    str += _v.m_Path;
    return hash<string>()(str);
}
